package ai.lyra.mobile.audio

import java.io.ByteArrayOutputStream
import kotlin.math.sqrt

/**
 * Port of Stonic Voice SpeechGate & VAD logic.
 * Filters silence so only active speech is transmitted to STT,
 * preserving a 1.0s pre-roll buffer and a 0.8s hangover.
 */
class VadGate(
    private val sampleRate: Int = 16000,
    private val minVolumeRms: Float = 350.0f,
    private val hangoverSecs: Float = 0.8f,
    private val prerollSecs: Float = 1.0f
) {
    private val prerollBuffer = ArrayList<ByteArray>()
    private val prerollMaxChunks: Int = (prerollSecs * sampleRate * 2 / 640).toInt() // ~50 chunks of 20ms
    private var hangoverChunksLeft = 0
    private val hangoverChunksMax: Int = (hangoverSecs * sampleRate * 2 / 640).toInt()

    var isSpeechActive: Boolean = false
        private set

    fun processChunk(pcm16: ByteArray): ByteArray? {
        val rms = calculateRms(pcm16)
        val isVoiceNow = rms > minVolumeRms

        synchronized(prerollBuffer) {
            prerollBuffer.add(pcm16.clone())
            if (prerollBuffer.size > prerollMaxChunks) {
                prerollBuffer.removeAt(0)
            }
        }

        if (isVoiceNow) {
            hangoverChunksLeft = hangoverChunksMax
            if (!isSpeechActive) {
                isSpeechActive = true
                // Return pre-roll concatenated with current chunk
                val stream = ByteArrayOutputStream()
                synchronized(prerollBuffer) {
                    for (chunk in prerollBuffer) {
                        stream.write(chunk)
                    }
                    prerollBuffer.clear()
                }
                return stream.toByteArray()
            }
            return pcm16
        } else if (hangoverChunksLeft > 0) {
            hangoverChunksLeft--
            return pcm16
        } else {
            if (isSpeechActive) {
                isSpeechActive = false
            }
            return null
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

    fun reset() {
        synchronized(prerollBuffer) {
            prerollBuffer.clear()
        }
        hangoverChunksLeft = 0
        isSpeechActive = false
    }
}
