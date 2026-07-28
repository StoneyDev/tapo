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

class TapoListWidgetProvider : AppWidgetProvider() {

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
            val views = RemoteViews(context.packageName, R.layout.tapo_list_widget)

            val devicesJson = widgetData.getString("devices", null)

            views.removeAllViews(R.id.list_widget_items)

            val devices = try {
                if (devicesJson != null) JSONArray(devicesJson) else JSONArray()
            } catch (_: Exception) {
                JSONArray()
            }

            if (devices.length() == 0) {
                views.setViewVisibility(R.id.list_widget_empty, View.VISIBLE)
                views.setTextViewText(
                    R.id.list_widget_count,
                    context.resources.getQuantityString(R.plurals.list_widget_count, 0, 0)
                )
                appWidgetManager.updateAppWidget(appWidgetId, views)
                return
            }

            views.setViewVisibility(R.id.list_widget_empty, View.GONE)
            views.setTextViewText(
                R.id.list_widget_count,
                context.resources.getQuantityString(
                    R.plurals.list_widget_count,
                    devices.length(),
                    devices.length()
                )
            )

            try {
                for (i in 0 until devices.length()) {
                    val device = devices.getJSONObject(i)
                    val ip = device.optString("ip", "")
                    val model = device.optString("model", "Unknown")
                    val nickname = device.optString("nickname", model)
                    val deviceOn = device.optBoolean("deviceOn", false)
                    val isOnline = device.optBoolean("isOnline", true)
                    val isLoading = widgetData.getBoolean("loading_$ip", false)
                    val iconColor = WidgetColors.iconTint(context, isOnline, deviceOn)

                    val itemView = RemoteViews(context.packageName, R.layout.tapo_list_widget_item)

                    itemView.setTextViewText(R.id.list_item_nickname, nickname)
                    itemView.setTextViewText(R.id.list_item_model, model)

                    itemView.setImageViewResource(R.id.list_item_icon, WidgetColors.iconDrawable(isOnline))
                    itemView.setInt(R.id.list_item_icon, "setColorFilter", iconColor)
                    itemView.setInt(R.id.list_item_icon_container, "setBackgroundResource", WidgetColors.iconBgDrawable(isOnline, deviceOn))

                    itemView.setViewVisibility(R.id.list_item_loading, if (isLoading) View.VISIBLE else View.GONE)

                    if (ip.isNotEmpty()) {
                        val intent = TapoWidgetClickReceiver.getBroadcast(
                            context,
                            Uri.parse("tapotoggle://toggle?ip=$ip")
                        )
                        itemView.setOnClickPendingIntent(R.id.list_item_container, intent)
                    }

                    views.addView(R.id.list_widget_items, itemView)
                }
            } catch (_: Exception) {
                views.setViewVisibility(R.id.list_widget_empty, View.VISIBLE)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val widgetIds = appWidgetManager.getAppWidgetIds(
                ComponentName(context, TapoListWidgetProvider::class.java)
            )
            for (id in widgetIds) {
                updateWidget(context, appWidgetManager, id)
            }
        }
    }
}
