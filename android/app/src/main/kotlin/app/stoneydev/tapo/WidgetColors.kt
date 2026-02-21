package app.stoneydev.tapo

import android.content.Context
import androidx.core.content.ContextCompat

object WidgetColors {
    fun iconTint(context: Context, isOnline: Boolean, deviceOn: Boolean): Int {
        if (!isOnline) return ContextCompat.getColor(context, R.color.widget_offline_icon_tint)
        return if (deviceOn) ContextCompat.getColor(context, R.color.widget_on_icon_tint)
        else ContextCompat.getColor(context, R.color.widget_off_icon_tint)
    }

    fun iconBgDrawable(isOnline: Boolean, deviceOn: Boolean): Int {
        if (!isOnline) return R.drawable.widget_icon_bg_offline
        return if (deviceOn) R.drawable.widget_icon_bg_on else R.drawable.widget_icon_bg_off
    }

    fun iconDrawable(isOnline: Boolean): Int {
        return if (isOnline) R.drawable.ic_plug else R.drawable.ic_plug_offline
    }
}
