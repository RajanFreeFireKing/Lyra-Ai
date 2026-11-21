package ai.lyra.mobile.overlay

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.*
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import kotlin.math.cos
import kotlin.math.sin

/**
 * Android system overlay window mirroring Stonic overlay_hud.py:
 * - Uses TYPE_APPLICATION_OVERLAY
 * - Uses FLAG_SECURE so screen capture ignores this window (matching WDA_EXCLUDEFROMCAPTURE)
 * - Renders animated Comet/Aura ring + dynamic status pill
 */
class FloatingHudService : Service() {

    private var windowManager: WindowManager? = null
    private var hudView: HudCanvasView? = null

    companion object {
        private var instance: FloatingHudService? = null

        fun updateStatus(status: String, detail: String = "") {
            instance?.hudView?.setStatus(status, detail)
        }

        fun hide() {
            instance?.stopSelf()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        hudView = HudCanvasView(this)

        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        // FLAG_SECURE ensures screen capture does not see this window
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            layoutType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_SECURE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            y = 120
        }

        hudView?.setOnTouchListener(object : View.OnTouchListener {
            private var initialY = 0
            private var initialTouchY = 0f

            override fun onTouch(v: View?, event: MotionEvent): Boolean {
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        initialY = params.y
                        initialTouchY = event.rawY
                        return true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        params.y = initialY + (event.rawY - initialTouchY).toInt()
                        windowManager?.updateViewLayout(hudView, params)
                        return true
                    }
                }
                return false
            }
        })

        windowManager?.addView(hudView, params)
    }

    override fun onDestroy() {
        super.onDestroy()
        hudView?.let { windowManager?.removeView(it) }
        instance = null
    }

    private class HudCanvasView(context: Context) : View(context) {
        private var status: String = "Listening"
        private var detail: String = ""
        private var angle = 0f
        private val pillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(220, 15, 18, 25)
            style = Paint.Style.FILL
        }
        private val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(120, 0, 240, 255)
            style = Paint.Style.STROKE
            strokeWidth = 2.5f
        }
        private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textSize = 34f
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        }
        private val detailPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(200, 200, 220, 255)
            textSize = 24f
        }
        private val cometPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.CYAN
            style = Paint.Style.FILL
            maskFilter = BlurMaskFilter(12f, BlurMaskFilter.Blur.NORMAL)
        }

        init {
            post(object : Runnable {
                override fun run() {
                    angle = (angle + 4f) % 360f
                    invalidate()
                    postDelayed(this, 16)
                }
            })
        }

        fun setStatus(newStatus: String, newDetail: String) {
            status = newStatus
            detail = newDetail
            invalidate()
        }

        override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
            setMeasuredDimension(480, 110)
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val rect = RectF(20f, 10f, width - 20f, height - 10f)
            canvas.drawRoundRect(rect, 45f, 45f, pillPaint)
            canvas.drawRoundRect(rect, 45f, 45f, borderPaint)

            // Draw spinning comet indicator
            val cx = 60f
            val cy = height / 2f
            val r = 18f
            val rad = Math.toRadians(angle.toDouble())
            val dotX = cx + (r * cos(rad)).toFloat()
            val dotY = cy + (r * sin(rad)).toFloat()

            canvas.drawCircle(cx, cy, 6f, cometPaint)
            canvas.drawCircle(dotX, dotY, 4f, cometPaint)

            // Draw status text
            canvas.drawText("Lyra: $status", 95f, cy + 5f, textPaint)
            if (detail.isNotBlank()) {
                val clipped = if (detail.length > 25) detail.take(24) + "…" else detail
                canvas.drawText(clipped, 95f, cy + 32f, detailPaint)
            }
        }
    }
}
