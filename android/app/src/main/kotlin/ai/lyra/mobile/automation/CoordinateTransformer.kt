package ai.lyra.mobile.automation

import kotlin.math.roundToInt

/**
 * Port of Stonic Computer Agent S3 coordinate transformer (OSWorldACI.resize_coordinates).
 * Converts UI-TARS grounding model coordinates (relative to the scaled screenshot)
 * into exact physical Android screen pixel coordinates.
 */
object CoordinateTransformer {

    fun scaleCoordsToScreen(
        groundingX: Float,
        groundingY: Float,
        scaledWidth: Int,
        scaledHeight: Int,
        screenWidth: Int,
        screenHeight: Int
    ): Pair<Int, Int> {
        if (scaledWidth <= 0 || scaledHeight <= 0) {
            return Pair(groundingX.roundToInt(), groundingY.roundToInt())
        }
        val sx = screenWidth.toFloat() / scaledWidth.toFloat()
        val sy = screenHeight.toFloat() / scaledHeight.toFloat()

        val screenX = (groundingX * sx).roundToInt()
        val screenY = (groundingY * sy).roundToInt()

        val clampedX = screenX.coerceIn(0, screenWidth - 1)
        val clampedY = screenY.coerceIn(0, screenHeight - 1)

        return Pair(clampedX, clampedY)
    }

    /**
     * Downscales the physical screen dimensions maintaining aspect ratio, capped at maxDim (1920)
     */
    fun calculateScaledDimensions(width: Int, height: Int, maxDim: Int = 1920): Pair<Int, Int> {
        val maxVal = maxOf(width, height)
        if (maxVal <= maxDim) {
            return Pair(width, height)
        }
        val scale = maxDim.toFloat() / maxVal.toFloat()
        return Pair((width * scale).roundToInt(), (height * scale).roundToInt())
    }
}
