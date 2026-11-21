package ai.lyra.mobile.audio

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.atomic.AtomicBoolean

/**
 * 24kHz 16-bit Mono AudioTrack player for Gemini 3.8 TTS streaming audio chunks.
 * Supports instant stop / flush on user interruption.
 */
class AudioTrackPlayer(
    private val sampleRate: Int = 24000
) {
    private val channelConfig = AudioFormat.CHANNEL_OUT_MONO
    private val audioFormat = AudioFormat.ENCODING_PCM_16BIT
    private val bufferSize = AudioTrack.getMinBufferSize(sampleRate, channelConfig, audioFormat).coerceAtLeast(4096)

    private var audioTrack: AudioTrack? = null
    private val isPlaying = AtomicBoolean(false)
    private val audioQueue = LinkedBlockingQueue<ByteArray>()
    private var playbackThread: Thread? = null

    init {
        initAudioTrack()
    }

    private fun initAudioTrack() {
        try {
            audioTrack = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(audioFormat)
                        .setSampleRate(sampleRate)
                        .setChannelMask(channelConfig)
                        .build()
                )
                .setBufferSizeInBytes(bufferSize)
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun start() {
        if (isPlaying.get()) return
        if (audioTrack == null || audioTrack?.state != AudioTrack.STATE_INITIALIZED) {
            initAudioTrack()
        }

        try {
            audioTrack?.play()
            isPlaying.set(true)
            playbackThread = Thread {
                while (isPlaying.get()) {
                    try {
                        val chunk = audioQueue.poll(100, java.util.concurrent.TimeUnit.MILLISECONDS)
                        if (chunk != null && isPlaying.get()) {
                            audioTrack?.write(chunk, 0, chunk.size)
                        }
                    } catch (ie: InterruptedException) {
                        break
                    }
                }
            }.apply {
                priority = Thread.MAX_PRIORITY
                start()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun feedChunk(pcmData: ByteArray) {
        if (!isPlaying.get()) {
            start()
        }
        audioQueue.offer(pcmData)
    }

    /**
     * Stonic / Siya instant barge-in: clears queued audio and flushes track immediately.
     */
    fun flush() {
        audioQueue.clear()
        try {
            audioTrack?.pause()
            audioTrack?.flush()
            audioTrack?.play()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    /**
     * Stonic interrupt behavior: instant audio cut on user speech.
     */
    fun stopAndFlush() {
        audioQueue.clear()
        try {
            audioTrack?.pause()
            audioTrack?.flush()
        } catch (e: Exception) {
            e.printStackTrace()
        }
        isPlaying.set(false)
        playbackThread?.interrupt()
        playbackThread = null
        try {
            audioTrack?.stop()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun release() {
        stopAndFlush()
        try {
            audioTrack?.release()
        } catch (e: Exception) {
            e.printStackTrace()
        }
        audioTrack = null
    }
}
