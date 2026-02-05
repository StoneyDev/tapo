package app.stoneydev.tapo

object WidgetColors {
    const val COLOR_ON = 0xFF673AB7.toInt()      // deepPurple
    const val COLOR_OFF = 0xFF9E9E9E.toInt()     // grey
    const val COLOR_OFFLINE = 0xFFD32F2F.toInt() // red

    fun statusColor(isOnline: Boolean, deviceOn: Boolean): Int {
        if (!isOnline) return COLOR_OFFLINE
        return if (deviceOn) COLOR_ON else COLOR_OFF
    }
}
