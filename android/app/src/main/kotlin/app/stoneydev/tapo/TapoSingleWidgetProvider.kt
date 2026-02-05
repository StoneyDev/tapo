package app.stoneydev.tapo

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
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
            var modelText = "No device"
            var deviceOn = false
            var isOnline = true

            if (deviceIp != null && devicesJson != null) {
                try {
                    val devices = JSONArray(devicesJson)
                    for (i in 0 until devices.length()) {
                        val device = devices.getJSONObject(i)
                        if (device.getString("ip") == deviceIp) {
                            modelText = device.getString("model")
                            deviceOn = device.getBoolean("deviceOn")
                            isOnline = device.optBoolean("isOnline", true)
                            break
                        }
                    }
                } catch (_: Exception) {
                    modelText = "Error"
                }
            }

            views.setTextViewText(R.id.widget_model_text, modelText)

            val bgColor = WidgetColors.statusColor(isOnline, deviceOn)
            views.setInt(R.id.widget_container, "setBackgroundColor", bgColor)

            if (deviceIp != null) {
                val intent = HomeWidgetBackgroundIntent.getBroadcast(
                    context,
                    Uri.parse("tapotoggle://toggle?ip=$deviceIp")
                )
                views.setOnClickPendingIntent(R.id.widget_container, intent)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
