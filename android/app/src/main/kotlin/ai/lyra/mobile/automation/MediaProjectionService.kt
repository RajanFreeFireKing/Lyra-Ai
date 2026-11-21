package ai.lyra.mobile.automation

import android.app.*
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import java.io.ByteArrayOutputStream

class MediaProjectionService : Service() {

    companion object {
        private const val CHANNEL_ID = "LyraMediaProjection"
        private const val NOTIFICATION_ID = 2049
        var currentProjection: MediaProjection? = null
        var lastCapturedBitmap: Bitmap? = null
            private set

        fun captureScreenPng(width: Int, height: Int, maxDim: Int = 1920): ByteArray? {
            val projection = currentProjection ?: return null
            val (scaledW, scaledH) = CoordinateTransformer.calculateScaledDimensions(width, height, maxDim)

            val imageReader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2)
            val virtualDisplay: VirtualDisplay = projection.createVirtualDisplay(
                "LyraCapture",
                width,
                height,
                1,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                imageReader.surface,
                null,
                null
            )

            try {
                // Sleep briefly to capture current frame
                Thread.sleep(120)
                val image = imageReader.acquireLatestImage() ?: return null
                val planes = image.planes
                val buffer = planes[0].buffer
                val pixelStride = planes[0].pixelStride
                val rowStride = planes[0].rowStride
                val rowPadding = rowStride - pixelStride * width

                val rawBitmap = Bitmap.createBitmap(
                    width + rowPadding / pixelStride,
                    height,
                    Bitmap.Config.ARGB_8888
                )
                rawBitmap.copyPixelsFromBuffer(buffer)
                image.close()

                val croppedBitmap = Bitmap.createBitmap(rawBitmap, 0, 0, width, height)
                rawBitmap.recycle()

                val finalBitmap = if (width != scaledW || height != scaledH) {
                    val scaled = Bitmap.createScaledBitmap(croppedBitmap, scaledW, scaledH, true)
                    croppedBitmap.recycle()
                    scaled
                } else {
                    croppedBitmap
                }

                lastCapturedBitmap = finalBitmap
                val stream = ByteArrayOutputStream()
                finalBitmap.compress(Bitmap.CompressFormat.PNG, 90, stream)
                return stream.toByteArray()
            } catch (e: Exception) {
                e.printStackTrace()
                return null
            } finally {
                virtualDisplay.release()
                imageReader.close()
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Lyra Screen Agent")
            .setContentText("Screen capture service active")
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
        startForeground(NOTIFICATION_ID, notification)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Lyra Screen Capture",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
}
