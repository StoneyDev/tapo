package app.stoneydev.tapo

import android.content.Context

object WidgetColors {
    fun statusText(context: Context, isOnline: Boolean, deviceOn: Boolean): String {
        val resource = when {
            !isOnline -> R.string.widget_status_offline
            deviceOn -> R.string.widget_status_on
            else -> R.string.widget_status_off
        }
        return context.getString(resource)
    }

    fun iconBgDrawable(isOnline: Boolean, deviceOn: Boolean): Int {
        if (!isOnline) return R.drawable.widget_icon_bg_offline
        return if (deviceOn) R.drawable.widget_icon_bg_on else R.drawable.widget_icon_bg_off
    }

    fun iconDrawable(isOnline: Boolean, deviceOn: Boolean): Int {
        if (!isOnline) return R.drawable.ic_plug_offline
        return if (deviceOn) R.drawable.ic_plug_on else R.drawable.ic_plug
    }
}
