package ai.lyra.mobile

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.speech.tts.TextToSpeech
import java.util.Locale
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import ai.lyra.mobile.audio.AudioRecorderEngine
import ai.lyra.mobile.audio.AudioTrackPlayer
import ai.lyra.mobile.live.LyraLiveClient
import ai.lyra.mobile.automation.CoordinateTransformer
import ai.lyra.mobile.automation.LyraAccessibilityService
import ai.lyra.mobile.automation.MediaProjectionService
import ai.lyra.mobile.awareness.AndroidAwarenessService
import ai.lyra.mobile.memory.LyraDbHelper
import ai.lyra.mobile.overlay.FloatingHudService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val AUDIO_CHANNEL = "ai.lyra.mobile/audio"
    private val AUDIO_STREAM_CHANNEL = "ai.lyra.mobile/audio_stream"
    private val LIVE_CHANNEL = "ai.lyra.mobile/live"
    private val LIVE_EVENT_CHANNEL = "ai.lyra.mobile/live_events"
    private val AUTOMATION_CHANNEL = "ai.lyra.mobile/automation"
    private val OVERLAY_CHANNEL = "ai.lyra.mobile/overlay"
    private val MEMORY_CHANNEL = "ai.lyra.mobile/memory"
    private val AWARENESS_CHANNEL = "ai.lyra.mobile/awareness"

    private val REQUEST_MEDIA_PROJECTION = 1001
    private val REQUEST_RECORD_AUDIO = 1002
    private var pendingAudioPermissionResult: MethodChannel.Result? = null

    private var audioRecorder: AudioRecorderEngine? = null
    private var audioPlayer: AudioTrackPlayer? = null
    private var liveClient: LyraLiveClient? = null
    private var nativeTts: TextToSpeech? = null
    private var dbHelper: LyraDbHelper? = null
    private var awarenessService: AndroidAwarenessService? = null

    private var audioEventSink: EventChannel.EventSink? = null
    private var liveEventSink: EventChannel.EventSink? = null
    private var projectionResultData: Intent? = null
    private var projectionResultCode: Int = 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        dbHelper = LyraDbHelper(this)
        awarenessService = AndroidAwarenessService(this)
        audioPlayer = AudioTrackPlayer(24000)

        nativeTts = TextToSpeech(this) { status ->
            if (status == TextToSpeech.SUCCESS) {
                nativeTts?.language = Locale.getDefault()
            }
        }

        audioRecorder = AudioRecorderEngine { chunk, isSpeech, rms ->
            runOnUiThread {
                audioEventSink?.success(
                    mapOf(
                        "data" to chunk,
                        "isSpeech" to isSpeech,
                        "rms" to rms.toDouble()
                    )
                )
            }
            // Stream raw PCM chunk directly to Gemini Live WebSocket
            liveClient?.sendAudio(chunk, chunk.size)
        }

        // 1. Audio Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkMicrophonePermission" -> {
                    val granted = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }
                "requestMicrophonePermission" -> {
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
                        result.success(true)
                    } else {
                        pendingAudioPermissionResult = result
                        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.RECORD_AUDIO), REQUEST_RECORD_AUDIO)
                    }
                }
                "startRecording" -> {
                    val hasPerm = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
                    if (!hasPerm) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val ok = audioRecorder?.startRecording() ?: false
                    result.success(ok)
                }
                "stopRecording" -> {
                    audioRecorder?.stopRecording()
                    result.success(true)
                }
                "feedAudioChunk" -> {
                    val pcmBytes = call.argument<ByteArray>("data")
                    if (pcmBytes != null) {
                        audioPlayer?.feedChunk(pcmBytes)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "Missing audio data", null)
                    }
                }
                "stopPlayback" -> {
                    audioPlayer?.stopAndFlush()
                    nativeTts?.stop()
                    result.success(true)
                }
                "speakTextNative" -> {
                    val text = call.argument<String>("text") ?: ""
                    val lang = call.argument<String>("lang") ?: ""
                    if (lang.isNotEmpty()) {
                        nativeTts?.language = Locale.forLanguageTag(lang)
                    }
                    val res = nativeTts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "lyra_${System.currentTimeMillis()}")
                    result.success(res == TextToSpeech.SUCCESS)
                }
                "stopNativePlayback" -> {
                    nativeTts?.stop()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Audio Stream EventChannel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_STREAM_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    audioEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    audioEventSink = null
                }
            }
        )

        // Live Audio Transport Channel (Gemini Live BidiGenerateContent)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LIVE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startLiveSession" -> {
                    val apiKey = call.argument<String>("apiKey") ?: ""
                    val model = call.argument<String>("model") ?: "gemini-2.5-flash-native-audio-preview-12-2025"
                    val voice = call.argument<String>("voice") ?: "Aoede"
                    val systemPrompt = call.argument<String>("systemPrompt") ?: ""
                    val temperature = call.argument<Double>("temperature") ?: 0.85

                    val hasPerm = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
                    if (!hasPerm) {
                        result.success(false)
                        return@setMethodCallHandler
                    }

                    try {
                        liveClient?.close()
                        audioPlayer?.flush()

                        liveClient = LyraLiveClient(
                            apiKey = apiKey,
                            initialModel = model,
                            voiceName = voice,
                            systemPrompt = systemPrompt,
                            temperature = temperature,
                            callback = object : LyraLiveClient.Listener {
                                override fun onReady() {
                                    runOnUiThread {
                                        liveEventSink?.success(mapOf("type" to "ready"))
                                    }
                                }

                                override fun onAudio(pcm24k: ByteArray) {
                                    audioPlayer?.feedChunk(pcm24k)
                                    val rms = calculatePcmRms(pcm24k)
                                    runOnUiThread {
                                        liveEventSink?.success(mapOf("type" to "audio_output", "rms" to rms.toDouble()))
                                    }
                                }

                                override fun onUserText(text: String) {
                                    runOnUiThread {
                                        liveEventSink?.success(mapOf("type" to "user_text", "text" to text))
                                    }
                                }

                                override fun onLyraText(text: String) {
                                    runOnUiThread {
                                        liveEventSink?.success(mapOf("type" to "lyra_text", "text" to text))
                                    }
                                }

                                override fun onInterrupted() {
                                    audioPlayer?.flush()
                                    nativeTts?.stop()
                                    runOnUiThread {
                                        liveEventSink?.success(mapOf("type" to "interrupted"))
                                    }
                                }

                                override fun onTurnComplete() {
                                    runOnUiThread {
                                        liveEventSink?.success(mapOf("type" to "turn_complete"))
                                    }
                                }

                                override fun onGoAway() {
                                    runOnUiThread {
                                        liveEventSink?.success(mapOf("type" to "go_away"))
                                    }
                                }

                                override fun onClosed(reason: String) {
                                    runOnUiThread {
                                        liveEventSink?.success(mapOf("type" to "closed", "reason" to reason))
                                    }
                                }

                                override fun onError(error: String) {
                                    runOnUiThread {
                                        liveEventSink?.success(mapOf("type" to "error", "error" to error))
                                    }
                                }
                            }
                        )
                        liveClient?.connect()
                        audioRecorder?.startRecording()
                        result.success(true)
                    } catch (e: Exception) {
                        e.printStackTrace()
                        result.error("LIVE_START_FAILED", e.message, null)
                    }
                }
                "stopLiveSession" -> {
                    try {
                        liveClient?.close()
                        liveClient = null
                        audioRecorder?.stopRecording()
                        audioPlayer?.flush()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("LIVE_STOP_FAILED", e.message, null)
                    }
                }
                "sendLiveText" -> {
                    val text = call.argument<String>("text") ?: ""
                    liveClient?.sendText(text)
                    result.success(true)
                }
                "sendLiveAudioEnd" -> {
                    liveClient?.sendAudioStreamEnd()
                    result.success(true)
                }
                "isLiveReady" -> {
                    result.success(liveClient?.isReady ?: false)
                }
                else -> result.notImplemented()
            }
        }

        // Live Events Stream Channel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, LIVE_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    liveEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    liveEventSink = null
                }
            }
        )

        // 2. Automation Channel (Agent S3 actions)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUTOMATION_CHANNEL).setMethodCallHandler { call, result ->
            val service = LyraAccessibilityService.instance
            when (call.method) {
                "requestScreenCapturePermission" -> {
                    val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                    startActivityForResult(manager.createScreenCaptureIntent(), REQUEST_MEDIA_PROJECTION)
                    result.success(true)
                }
                "isAccessibilityServiceActive" -> {
                    result.success(LyraAccessibilityService.isRunning())
                }
                "openAccessibilitySettings" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    startActivity(intent)
                    result.success(true)
                }
                "captureScreen" -> {
                    val displayMetrics = resources.displayMetrics
                    val pngBytes = MediaProjectionService.captureScreenPng(displayMetrics.widthPixels, displayMetrics.heightPixels)
                    if (pngBytes != null) {
                        result.success(
                            mapOf(
                                "png" to pngBytes,
                                "width" to displayMetrics.widthPixels,
                                "height" to displayMetrics.heightPixels
                            )
                        )
                    } else {
                        result.error("CAPTURE_FAILED", "MediaProjection capture returned null", null)
                    }
                }
                "click" -> {
                    val x = call.argument<Int>("x") ?: 0
                    val y = call.argument<Int>("y") ?: 0
                    val ok = service?.click(x, y) ?: false
                    result.success(ok)
                }
                "scroll" -> {
                    val direction = call.argument<String>("direction") ?: "down"
                    val x = call.argument<Int>("x") ?: (resources.displayMetrics.widthPixels / 2)
                    val y = call.argument<Int>("y") ?: (resources.displayMetrics.heightPixels / 2)
                    val ok = service?.scroll(direction, x, y) ?: false
                    result.success(ok)
                }
                "typeText" -> {
                    val text = call.argument<String>("text") ?: ""
                    val ok = service?.typeText(text) ?: false
                    result.success(ok)
                }
                "pressBack" -> result.success(service?.pressBack() ?: false)
                "pressHome" -> result.success(service?.pressHome() ?: false)
                else -> result.notImplemented()
            }
        }

        // 3. Overlay Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OVERLAY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkOverlayPermission" -> {
                    val ok = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) Settings.canDrawOverlays(this) else true
                    result.success(ok)
                }
                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
                        val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
                        startActivity(intent)
                    }
                    result.success(true)
                }
                "showOverlay" -> {
                    startService(Intent(this, FloatingHudService::class.java))
                    result.success(true)
                }
                "updateOverlay" -> {
                    val status = call.argument<String>("status") ?: "Working"
                    val detail = call.argument<String>("detail") ?: ""
                    FloatingHudService.updateStatus(status, detail)
                    result.success(true)
                }
                "hideOverlay" -> {
                    FloatingHudService.hide()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // 4. Memory Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEMORY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "compileStateCard" -> {
                    val card = dbHelper?.compileStateCard() ?: ""
                    result.success(card)
                }
                "insertTurn" -> {
                    val role = call.argument<String>("role") ?: "user"
                    val text = call.argument<String>("text") ?: ""
                    val id = dbHelper?.insertTurn(role, text) ?: ""
                    result.success(id)
                }
                "insertMemory" -> {
                    val type = call.argument<String>("type") ?: "identity"
                    val original = call.argument<String>("textOriginal") ?: ""
                    val en = call.argument<String>("textEn") ?: ""
                    val quote = call.argument<String>("quote") ?: ""
                    val origin = call.argument<String>("origin") ?: "stated"
                    val pinned = call.argument<Boolean>("pinned") ?: false
                    val id = dbHelper?.insertMemory(type, original, en, quote, origin, pinned) ?: ""
                    result.success(id)
                }
                "verifyQuote" -> {
                    val quote = call.argument<String>("quote") ?: ""
                    val verified = dbHelper?.verifyQuote(quote) ?: false
                    result.success(verified)
                }
                else -> result.notImplemented()
            }
        }

        // 5. Awareness Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AWARENESS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSnapshot" -> {
                    val snapshot = awarenessService?.getAwarenessSnapshot() ?: emptyMap<String, Any>()
                    result.success(snapshot)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_RECORD_AUDIO) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingAudioPermissionResult?.success(granted)
            pendingAudioPermissionResult = null
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_MEDIA_PROJECTION && resultCode == Activity.RESULT_OK && data != null) {
            projectionResultCode = resultCode
            projectionResultData = data
            val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            MediaProjectionService.currentProjection = manager.getMediaProjection(resultCode, data)
            val serviceIntent = Intent(this, MediaProjectionService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }
        }
    }

    private fun calculatePcmRms(pcm: ByteArray): Float {
        var sum = 0.0
        val count = pcm.size / 2
        if (count == 0) return 0f
        var i = 0
        while (i < pcm.size - 1) {
            val sample = (pcm[i].toInt() and 0xFF) or (pcm[i + 1].toInt() shl 8)
            val s = sample.toShort()
            sum += (s * s).toDouble()
            i += 2
        }
        return kotlin.math.sqrt(sum / count).toFloat()
    }

    override fun onDestroy() {
        super.onDestroy()
        liveClient?.close()
        liveClient = null
        audioPlayer?.release()
        audioRecorder?.stopRecording()
        nativeTts?.stop()
        nativeTts?.shutdown()
    }
}
