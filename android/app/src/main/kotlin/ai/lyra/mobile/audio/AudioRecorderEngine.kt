package ai.lyra.mobile.audio

import android.annotation.SuppressLint
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import kotlinx.coroutines.*
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.sqrt

/**
 * 16kHz 16-bit Mono AudioRecord engine.
 * Streams 100% of raw microphone PCM chunks to Flutter with real-time RMS amplitude.
 */
class AudioRecorderEngine(
    private val onAudioChunk: (ByteArray, Boolean, Float) -> Unit
) {
    private val sampleRate = 16000
    private val channelConfig = AudioFormat.CHANNEL_IN_MONO
    private val audioFormat = AudioFormat.ENCODING_PCM_16BIT
    private val bufferSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat).coerceAtLeast(1280)

    private var audioRecord: AudioRecord? = null
    private val isRecording = AtomicBoolean(false)
    private var recordingJob: Job? = null

    @SuppressLint("MissingPermission")
    fun startRecording(): Boolean {
        if (isRecording.get()) return true

        try {
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                sampleRate,
                channelConfig,
                audioFormat,
                bufferSize
            )

            if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                audioRecord?.release()
                audioRecord = null
                return false
            }

            audioRecord?.startRecording()
            isRecording.set(true)

            recordingJob = CoroutineScope(Dispatchers.IO).launch {
                val buffer = ByteArray(640) // 20ms chunks at 16kHz
                while (isRecording.get() && isActive) {
                    val read = audioRecord?.read(buffer, 0, buffer.size) ?: -1
                    if (read > 0) {
                        val chunk = if (read == buffer.size) buffer.clone() else buffer.copyOf(read)
                        val rms = calculateRms(chunk)
                        val isSpeech = rms > 45.0f // sensitive voice detection for mobile speech
                        // NEVER discard audio! Stream 100% of raw PCM to Flutter
                        onAudioChunk(chunk, isSpeech, rms)
                    }
                }
            }
            return true
        } catch (e: Exception) {
            e.printStackTrace()
            stopRecording()
            return false
        }
    }

    private fun calculateRms(pcm16: ByteArray): Float {
        var sum = 0.0
        val count = pcm16.size / 2
        if (count == 0) return 0f

        var i = 0
        while (i < pcm16.size - 1) {
            val sample = (pcm16[i].toInt() and 0xFF) or (pcm16[i + 1].toInt() shl 8)
            val s = sample.toShort()
            sum += (s * s).toDouble()
            i += 2
        }
        return sqrt(sum / count).toFloat()
    }

    fun stopRecording() {
        isRecording.set(false)
        recordingJob?.cancel()
        recordingJob = null
        try {
            audioRecord?.stop()
            audioRecord?.release()
        } catch (e: Exception) {
            e.printStackTrace()
        }
        audioRecord = null
    }
}
