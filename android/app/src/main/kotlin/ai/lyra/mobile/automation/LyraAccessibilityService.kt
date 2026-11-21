package ai.lyra.mobile.automation

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.Path
import android.os.Bundle
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class LyraAccessibilityService : AccessibilityService() {

    companion object {
        var instance: LyraAccessibilityService? = null
            private set

        fun isRunning(): Boolean = instance != null
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Events monitored for awareness
    }

    override fun onInterrupt() {
        instance = null
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
    }

    fun click(x: Int, y: Int): Boolean {
        val path = Path().apply {
            moveTo(x.toFloat(), y.toFloat())
        }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 50))
            .build()
        return dispatchGestureSynchronously(gesture)
    }

    fun longClick(x: Int, y: Int): Boolean {
        val path = Path().apply {
            moveTo(x.toFloat(), y.toFloat())
        }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 600))
            .build()
        return dispatchGestureSynchronously(gesture)
    }

    fun scroll(direction: String, startX: Int, startY: Int, distance: Int = 500): Boolean {
        val path = Path().apply {
            moveTo(startX.toFloat(), startY.toFloat())
            when (direction.lowercase()) {
                "down" -> lineTo(startX.toFloat(), (startY - distance).toFloat())
                "up" -> lineTo(startX.toFloat(), (startY + distance).toFloat())
                "left" -> lineTo((startX + distance).toFloat(), startY.toFloat())
                "right" -> lineTo((startX - distance).toFloat(), startY.toFloat())
                else -> lineTo(startX.toFloat(), (startY - distance).toFloat())
            }
        }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 300))
            .build()
        return dispatchGestureSynchronously(gesture)
    }

    fun typeText(text: String): Boolean {
        val root = rootInActiveWindow ?: return false
        val focused = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
            ?: root.findFocus(AccessibilityNodeInfo.FOCUS_ACCESSIBILITY)

        if (focused != null && focused.isEditable) {
            val arguments = Bundle().apply {
                putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
            }
            return focused.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)
        } else {
            // Fallback: Copy to clipboard and paste
            val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            clipboard.setPrimaryClip(ClipData.newPlainText("LyraInput", text))
            focused?.performAction(AccessibilityNodeInfo.ACTION_PASTE)
            return true
        }
    }

    fun pressBack(): Boolean = performGlobalAction(GLOBAL_ACTION_BACK)
    fun pressHome(): Boolean = performGlobalAction(GLOBAL_ACTION_HOME)
    fun pressRecents(): Boolean = performGlobalAction(GLOBAL_ACTION_RECENTS)

    fun getActiveWindowSummary(): Map<String, Any> {
        val root = rootInActiveWindow
        val packageName = root?.packageName?.toString() ?: "unknown"
        val texts = mutableListOf<String>()

        fun extractText(node: AccessibilityNodeInfo?) {
            if (node == null) return
            node.text?.toString()?.takeIf { it.isNotBlank() }?.let { texts.add(it) }
            node.contentDescription?.toString()?.takeIf { it.isNotBlank() }?.let { texts.add(it) }
            for (i in 0 until node.childCount) {
                extractText(node.getChild(i))
            }
        }

        extractText(root)
        return mapOf(
            "package" to packageName,
            "visibleTexts" to texts.take(40)
        )
    }

    private fun dispatchGestureSynchronously(gesture: GestureDescription): Boolean {
        val latch = CountDownLatch(1)
        var success = false
        dispatchGesture(gesture, object : GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription?) {
                success = true
                latch.countDown()
            }

            override fun onCancelled(gestureDescription: GestureDescription?) {
                success = false
                latch.countDown()
            }
        }, null)
        try {
            latch.await(1000, TimeUnit.MILLISECONDS)
        } catch (e: InterruptedException) {
            return false
        }
        return success
    }
}
