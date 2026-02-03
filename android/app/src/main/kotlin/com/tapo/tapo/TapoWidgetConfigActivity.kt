package com.tapo.tapo

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.widget.ArrayAdapter
import android.widget.ListView
import android.widget.TextView
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

class TapoWidgetConfigActivity : Activity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

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
        val emptyView = findViewById<TextView>(R.id.config_empty_text)

        // Read device list from widget storage
        val widgetData = HomeWidgetPlugin.getData(this)
        val devicesJson = widgetData.getString("devices", null)

        data class DeviceItem(val ip: String, val model: String) {
            override fun toString(): String = model
        }

        val devices = mutableListOf<DeviceItem>()
        if (devicesJson != null) {
            try {
                val jsonArray = JSONArray(devicesJson)
                for (i in 0 until jsonArray.length()) {
                    val obj = jsonArray.getJSONObject(i)
                    devices.add(DeviceItem(obj.getString("ip"), obj.getString("model")))
                }
            } catch (_: Exception) {
                // ignore parse errors
            }
        }

        if (devices.isEmpty()) {
            listView.visibility = android.view.View.GONE
            emptyView.visibility = android.view.View.VISIBLE
            return
        }

        emptyView.visibility = android.view.View.GONE
        listView.visibility = android.view.View.VISIBLE

        val adapter = ArrayAdapter(
            this,
            android.R.layout.simple_list_item_1,
            devices
        )
        listView.adapter = adapter

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
}
