package ai.lyra.mobile.live

import android.util.Base64
import android.util.Log
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import okio.ByteString
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/**
 * Rock-solid Gemini Live WebSocket client for Lyra AI (based on SiyaLiveClient).
 * Streams 16kHz PCM audio bidirectionally and receives 24kHz PCM live audio with native barge-in.
 */
class LyraLiveClient(
    private val apiKey: String,
    initialModel: String = "gemini-2.5-flash-native-audio-preview-12-2025",
    private val voiceName: String = "Aoede",
    private val systemPrompt: String,
    private val callback: Listener,
    private val temperature: Double = 0.85
) {
    interface Listener {
        fun onReady()
        fun onAudio(pcm24k: ByteArray)
        fun onUserText(text: String)
        fun onLyraText(text: String)
        fun onInterrupted()
        fun onTurnComplete()
        fun onGoAway()
        fun onClosed(reason: String)
        fun onError(error: String)
    }

    companion object {
        private const val TAG = "LYRA_LIVE"
        val FALLBACK_MODELS = listOf(
            "gemini-2.5-flash-native-audio-preview-12-2025",
            "gemini-3.8-live",
            "gemini-3.8-flash"
        )
    }

    private var currentModelIndex = FALLBACK_MODELS.indexOf(initialModel).coerceAtLeast(0)
    private var model: String = FALLBACK_MODELS[currentModelIndex]

    @Volatile private var ready = false
    @Volatile private var closedByUs = false
    private var ws: WebSocket? = null

    private val http = OkHttpClient.Builder()
        .readTimeout(0, TimeUnit.MILLISECONDS)
        .connectTimeout(15, TimeUnit.SECONDS)
        .pingInterval(20, TimeUnit.SECONDS) // Keeps mobile WebSocket alive
        .build()

    val isReady get() = ready

    fun connect() {
        if (apiKey.trim().isEmpty()) {
            callback.onError("Google AI Studio API Key is empty")
            return
        }

        closedByUs = false
        ready = false
        model = FALLBACK_MODELS[currentModelIndex.coerceIn(0, FALLBACK_MODELS.size - 1)]

        val url = "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent?key=$apiKey"
        Log.d(TAG, "Connecting to Gemini Live with model: $model...")

        val request = Request.Builder()
            .url(url)
            .addHeader("Origin", "https://generativelanguage.googleapis.com")
            .build()

        ws = http.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                Log.d(TAG, "WebSocket Connected successfully. Sending setup for $model...")
                sendSetup(webSocket)
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                handleMessage(text)
            }

            override fun onMessage(webSocket: WebSocket, bytes: ByteString) {
                try {
                    handleMessage(bytes.utf8())
                } catch (e: Exception) {
                    Log.e(TAG, "Error parsing byte message: ${e.message}")
                }
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                ready = false
                val errorMsg = t.message ?: "Connection failed"
                Log.e(TAG, "WebSocket Failure ($model): $errorMsg")

                if (!closedByUs) {
                    // Try next fallback model if available
                    if (currentModelIndex < FALLBACK_MODELS.size - 1) {
                        currentModelIndex++
                        Log.w(TAG, "Retrying with fallback model: ${FALLBACK_MODELS[currentModelIndex]}")
                        connect()
                    } else {
                        callback.onError(errorMsg)
                        callback.onClosed(errorMsg)
                    }
                }
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                ready = false
                Log.d(TAG, "WebSocket Closed: $code / $reason")
                if (!closedByUs) {
                    callback.onClosed(if (reason.isNotEmpty()) reason else "closed $code")
                }
            }
        })
    }

    private fun sendSetup(w: WebSocket) {
        try {
            val formattedModel = if (model.startsWith("models/")) model else "models/$model"
            val setup = JSONObject().apply {
                put("model", formattedModel)
                put("generationConfig", JSONObject().apply {
                    put("responseModalities", JSONArray().put("AUDIO"))
                    put("temperature", temperature)
                    put("speechConfig", JSONObject().put("voiceConfig",
                        JSONObject().put("prebuiltVoiceConfig", JSONObject().put("voiceName", voiceName))))
                })
                put("systemInstruction", JSONObject().put("parts", JSONArray().put(JSONObject().put("text", systemPrompt))))
                put("realtimeInputConfig", JSONObject().put("automaticActivityDetection", JSONObject().apply {
                    put("startOfSpeechSensitivity", "START_SENSITIVITY_HIGH")
                    put("endOfSpeechSensitivity", "END_SENSITIVITY_HIGH")
                    put("prefixPaddingMs", 60)
                    put("silenceDurationMs", 250)
                }))
                put("inputAudioTranscription", JSONObject())
                put("outputAudioTranscription", JSONObject())
                put("contextWindowCompression", JSONObject().put("slidingWindow", JSONObject()))
            }
            val payload = JSONObject().put("setup", setup).toString()
            w.send(payload)
            Log.d(TAG, "Live setup sent successfully for $formattedModel")
        } catch (e: Exception) {
            Log.e(TAG, "Setup exception: ${e.message}")
            callback.onError("Setup error: ${e.message}")
        }
    }

    /**
     * Send raw 16kHz 16-bit mono PCM microphone chunk to Gemini Live.
     */
    fun sendAudio(pcm16k: ByteArray, length: Int) {
        if (!ready || ws == null) return
        try {
            val b64 = Base64.encodeToString(pcm16k, 0, length, Base64.NO_WRAP)
            val audioPayload = JSONObject().apply {
                put("realtimeInput", JSONObject().apply {
                    put("mediaChunks", JSONArray().put(JSONObject().apply {
                        put("mimeType", "audio/pcm;rate=16000")
                        put("data", b64)
                    }))
                })
            }
            ws?.send(audioPayload.toString())
        } catch (e: Exception) {
            Log.w(TAG, "Error sending audio chunk: ${e.message}")
        }
    }

    fun sendText(text: String) {
        if (!ready || ws == null) return
        try {
            val textPayload = JSONObject().apply {
                put("realtimeInput", JSONObject().apply {
                    put("text", text)
                })
            }
            ws?.send(textPayload.toString())
        } catch (e: Exception) {
            Log.w(TAG, "Error sending text: ${e.message}")
        }
    }

    fun sendAudioStreamEnd() {
        if (!ready || ws == null) return
        try {
            val endPayload = JSONObject().apply {
                put("realtimeInput", JSONObject().apply {
                    put("audioStreamEnd", true)
                })
            }
            ws?.send(endPayload.toString())
        } catch (e: Exception) {
            Log.w(TAG, "Error ending audio stream: ${e.message}")
        }
    }

    private fun handleMessage(raw: String) {
        try {
            val json = JSONObject(raw)

            if (json.has("setupComplete")) {
                ready = true
                Log.d(TAG, "Live session setupComplete! Ready for streaming.")
                callback.onReady()
                return
            }

            if (json.has("goAway")) {
                callback.onGoAway()
                return
            }

            val sc = json.optJSONObject("serverContent") ?: return

            // Native Barge-in: user spoke while Lyra was speaking
            if (sc.optBoolean("interrupted", false)) {
                Log.d(TAG, "Gemini Live reported barge-in interruption.")
                callback.onInterrupted()
            }

            // Streamed 24kHz audio output
            sc.optJSONObject("modelTurn")?.optJSONArray("parts")?.let { parts ->
                for (i in 0 until parts.length()) {
                    val p = parts.getJSONObject(i)
                    val inlineData = p.optJSONObject("inlineData") ?: p.optJSONObject("inline_data")
                    inlineData?.optString("data")?.takeIf { it.isNotEmpty() }?.let { b64Audio ->
                        val pcm24k = Base64.decode(b64Audio, Base64.DEFAULT)
                        if (pcm24k.isNotEmpty()) {
                            callback.onAudio(pcm24k)
                        }
                    }
                }
            }

            // Transcripts
            sc.optJSONObject("inputTranscription")?.optString("text")?.takeIf { it.isNotEmpty() }?.let {
                callback.onUserText(it)
            }
            sc.optJSONObject("outputTranscription")?.optString("text")?.takeIf { it.isNotEmpty() }?.let {
                callback.onLyraText(it)
            }

            if (sc.optBoolean("turnComplete", false)) {
                callback.onTurnComplete()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error handling message: ${e.message}")
        }
    }

    fun close() {
        closedByUs = true
        ready = false
        try {
            ws?.close(1000, "Normal closure")
        } catch (_: Exception) {}
        ws = null
    }
}
