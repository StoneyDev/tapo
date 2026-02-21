package app.stoneydev.tapo

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

class TapoSingleWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val widgetData = HomeWidgetPlugin.getData(context)
            val views = RemoteViews(context.packageName, R.layout.tapo_single_widget)

            val deviceIp = widgetData.getString("widget_${appWidgetId}_ip", null)
            val devicesJson = widgetData.getString("devices", null)
            var nickname = "No device"
            var model = ""
            var deviceOn = false
            var isOnline = true

            if (deviceIp != null && devicesJson != null) {
                try {
                    val devices = JSONArray(devicesJson)
                    for (i in 0 until devices.length()) {
                        val device = devices.getJSONObject(i)
                        if (device.getString("ip") == deviceIp) {
                            model = device.getString("model")
                            nickname = device.optString("nickname", model)
                            deviceOn = device.getBoolean("deviceOn")
                            isOnline = device.optBoolean("isOnline", true)
                            break
                        }
                    }
                } catch (_: Exception) {
                    nickname = "Error"
                }
            }

            val isLoading = deviceIp != null && widgetData.getBoolean("loading_$deviceIp", false)

            views.setTextViewText(R.id.widget_nickname_text, nickname)
            views.setTextViewText(R.id.widget_model_text, model)

            views.setViewVisibility(R.id.widget_content, if (isLoading) View.GONE else View.VISIBLE)
            views.setViewVisibility(R.id.widget_loading, if (isLoading) View.VISIBLE else View.GONE)

            views.setImageViewResource(R.id.widget_icon, WidgetColors.iconDrawable(isOnline))
            views.setInt(R.id.widget_icon, "setColorFilter", WidgetColors.iconTint(context, isOnline, deviceOn))
            views.setInt(R.id.widget_icon_container, "setBackgroundResource", WidgetColors.iconBgDrawable(isOnline, deviceOn))

            if (deviceIp != null) {
                val intent = TapoWidgetClickReceiver.getBroadcast(
                    context,
                    Uri.parse("tapotoggle://toggle?ip=$deviceIp")
                )
                views.setOnClickPendingIntent(R.id.widget_container, intent)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val widgetIds = appWidgetManager.getAppWidgetIds(
                ComponentName(context, TapoSingleWidgetProvider::class.java)
            )
            for (id in widgetIds) {
                updateWidget(context, appWidgetManager, id)
            }
        }
    }
}
