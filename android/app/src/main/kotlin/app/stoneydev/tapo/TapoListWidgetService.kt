package app.stoneydev.tapo

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject

class TapoListWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return TapoListRemoteViewsFactory(applicationContext)
    }
}

class TapoListRemoteViewsFactory(
    private val context: Context
) : RemoteViewsService.RemoteViewsFactory {

    private val devices = mutableListOf<JSONObject>()

    override fun onCreate() {
        loadDevices()
    }

    override fun onDataSetChanged() {
        loadDevices()
    }

    override fun onDestroy() {
        devices.clear()
    }

    override fun getCount(): Int = devices.size

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.tapo_list_widget_item)

        if (position < devices.size) {
            val device = devices[position]
            val model = device.getString("model")
            val deviceOn = device.getBoolean("deviceOn")
            val isOnline = device.optBoolean("isOnline", true)
            val ip = device.getString("ip")

            views.setTextViewText(R.id.list_item_model, model)

            val color = WidgetColors.statusColor(isOnline, deviceOn)
            views.setInt(R.id.list_item_indicator, "setBackgroundColor", color)
            views.setInt(R.id.list_item_container, "setBackgroundColor", color)

            // FillInIntent with device IP for tap handling
            val fillInIntent = Intent().apply {
                data = Uri.parse("tapotoggle://toggle?ip=$ip")
            }
            views.setOnClickFillInIntent(R.id.list_item_container, fillInIntent)
        }

        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = false

    private fun loadDevices() {
        devices.clear()
        try {
            val widgetData = HomeWidgetPlugin.getData(context)
            val devicesJson = widgetData.getString("devices", null) ?: return
            val jsonArray = JSONArray(devicesJson)
            for (i in 0 until jsonArray.length()) {
                devices.add(jsonArray.getJSONObject(i))
            }
        } catch (_: Exception) {
            // ignore parse errors
        }
    }
}
