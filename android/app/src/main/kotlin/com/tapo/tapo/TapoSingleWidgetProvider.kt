package com.tapo.tapo

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.Color
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
        private const val COLOR_ON = 0xFF673AB7.toInt()  // deepPurple
        private const val COLOR_OFF = 0xFF9E9E9E.toInt() // grey

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val widgetData = HomeWidgetPlugin.getData(context)
            val views = RemoteViews(context.packageName, R.layout.tapo_single_widget)

            // Read selected device IP for this widget
            val deviceIp = widgetData.getString("widget_${appWidgetId}_ip", null)

            // Read device list
            val devicesJson = widgetData.getString("devices", null)
            var modelText = "No device"
            var deviceOn = false

            if (deviceIp != null && devicesJson != null) {
                try {
                    val devices = JSONArray(devicesJson)
                    for (i in 0 until devices.length()) {
                        val device = devices.getJSONObject(i)
                        if (device.getString("ip") == deviceIp) {
                            modelText = device.getString("model")
                            deviceOn = device.getBoolean("deviceOn")
                            break
                        }
                    }
                } catch (_: Exception) {
                    modelText = "Error"
                }
            }

            // Set model text
            views.setTextViewText(R.id.widget_model_text, modelText)

            // Set background color based on device state
            val bgColor = if (deviceOn) COLOR_ON else COLOR_OFF
            views.setInt(R.id.widget_container, "setBackgroundColor", bgColor)

            // Set tap action to toggle device via Dart callback
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
