package ai.lyra.mobile.awareness

import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.PowerManager
import ai.lyra.mobile.automation.LyraAccessibilityService

/**
 * Mobile equivalent of Stonic electron/services/awareness-manager.js:
 * Collects foreground app context, screen interactivity, and battery status.
 */
class AndroidAwarenessService(private val context: Context) {

    fun getAwarenessSnapshot(): Map<String, Any> {
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val isScreenInteractive = pm.isInteractive

        val batteryStatus: Intent? = IntentFilter(Intent.ACTION_BATTERY_CHANGED).let { filter ->
            context.registerReceiver(null, filter)
        }
        val level: Int = batteryStatus?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale: Int = batteryStatus?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        val batteryPct = if (level >= 0 && scale > 0) (level * 100 / scale) else 100

        var foregroundApp = "unknown"
        var visibleTexts = emptyList<String>()

        val accService = LyraAccessibilityService.instance
        if (accService != null) {
            val summary = accService.getActiveWindowSummary()
            foregroundApp = summary["package"] as? String ?: "unknown"
            @Suppress("UNCHECKED_CAST")
            visibleTexts = summary["visibleTexts"] as? List<String> ?: emptyList()
        }

        return mapOf(
            "screenInteractive" to isScreenInteractive,
            "batteryPercentage" to batteryPct,
            "foregroundApp" to foregroundApp,
            "screenContent" to visibleTexts.joinToString(" | ")
        )
    }
}
