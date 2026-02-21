package app.stoneydev.tapo

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.BaseAdapter
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ListView
import android.widget.TextView
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

class TapoWidgetConfigActivity : Activity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    private data class DeviceItem(
        val ip: String,
        val nickname: String,
        val model: String,
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Default result is CANCELED in case user backs out
        setResult(RESULT_CANCELED)

        // Get the widget ID from the intent
        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        setContentView(R.layout.tapo_widget_config)

        val listView = findViewById<ListView>(R.id.config_device_list)
        val emptyContainer = findViewById<LinearLayout>(R.id.config_empty_container)

        // Read device list from widget storage
        val widgetData = HomeWidgetPlugin.getData(this)
        val devicesJson = widgetData.getString("devices", null)

        val devices = mutableListOf<DeviceItem>()
        if (devicesJson != null) {
            try {
                val jsonArray = JSONArray(devicesJson)
                for (i in 0 until jsonArray.length()) {
                    val obj = jsonArray.getJSONObject(i)
                    val ip = obj.getString("ip")
                    val model = obj.getString("model")
                    val nickname = obj.optString("nickname", model)
                    devices.add(DeviceItem(ip, nickname, model))
                }
            } catch (_: Exception) {
                // ignore parse errors
            }
        }

        if (devices.isEmpty()) {
            listView.visibility = View.GONE
            emptyContainer.visibility = View.VISIBLE
            return
        }

        emptyContainer.visibility = View.GONE
        listView.visibility = View.VISIBLE

        listView.adapter = DeviceAdapter(devices)

        listView.setOnItemClickListener { _, _, position, _ ->
            val selected = devices[position]

            // Save selected device IP for this widget
            widgetData.edit().putString("widget_${appWidgetId}_ip", selected.ip).apply()

            // Update the widget
            val appWidgetManager = AppWidgetManager.getInstance(this)
            TapoSingleWidgetProvider.updateWidget(this, appWidgetManager, appWidgetId)

            // Return OK result
            val resultValue = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            setResult(RESULT_OK, resultValue)
            finish()
        }
    }

    private inner class DeviceAdapter(
        private val items: List<DeviceItem>,
    ) : BaseAdapter() {

        override fun getCount(): Int = items.size

        override fun getItem(position: Int): DeviceItem = items[position]

        override fun getItemId(position: Int): Long = position.toLong()

        override fun getView(position: Int, convertView: View?, parent: ViewGroup?): View {
            val view = convertView ?: LayoutInflater.from(this@TapoWidgetConfigActivity)
                .inflate(R.layout.tapo_widget_config_item, parent, false)

            val device = items[position]

            view.findViewById<TextView>(R.id.config_item_nickname).text = device.nickname
            view.findViewById<TextView>(R.id.config_item_model).text = device.model

            val icon = view.findViewById<ImageView>(R.id.config_item_icon)
            icon.setColorFilter(getColor(R.color.widget_off_icon_tint))

            return view
        }
    }
}
