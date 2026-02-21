package app.stoneydev.tapo

object WidgetColors {
    const val COLOR_ON = 0xFF673AB7.toInt()
    const val COLOR_OFF = 0xFF757575.toInt()
    const val COLOR_OFFLINE = 0xFFD32F2F.toInt()

    fun statusColor(isOnline: Boolean, deviceOn: Boolean): Int {
        if (!isOnline) return COLOR_OFFLINE
        return if (deviceOn) COLOR_ON else COLOR_OFF
    }

    fun iconTint(isOnline: Boolean, deviceOn: Boolean): Int {
        if (!isOnline) return COLOR_OFFLINE
        return if (deviceOn) COLOR_ON else COLOR_OFF
    }

    fun iconBgDrawable(isOnline: Boolean, deviceOn: Boolean): Int {
        if (!isOnline) return R.drawable.widget_icon_bg_offline
        return if (deviceOn) R.drawable.widget_icon_bg_on else R.drawable.widget_icon_bg_off
    }

    fun iconDrawable(isOnline: Boolean): Int {
        return if (isOnline) R.drawable.ic_plug else R.drawable.ic_plug_offline
    }
}
