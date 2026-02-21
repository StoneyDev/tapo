package app.stoneydev.tapo

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Intercepts widget tap clicks to set loading state immediately in Kotlin
 * before forwarding to the Dart background callback.
 *
 * Without this, loading only appears after the Dart isolate has spun up,
 * causing a noticeable delay.
 */
class TapoWidgetClickReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val uri = intent.data ?: return
        val ip = uri.getQueryParameter("ip") ?: return

        // Set loading immediately in shared prefs
        val prefs = HomeWidgetPlugin.getData(context)
        prefs.edit().putBoolean("loading_$ip", true).apply()

        // Refresh all widgets so loading state shows instantly
        refreshWidgets(context)

        // Forward to Dart background callback
        HomeWidgetBackgroundIntent.getBroadcast(context, uri).send()
    }

    private fun refreshWidgets(context: Context) {
        val mgr = AppWidgetManager.getInstance(context)

        // Refresh single widgets
        val singleIds = mgr.getAppWidgetIds(
            ComponentName(context, TapoSingleWidgetProvider::class.java)
        )
        for (id in singleIds) {
            TapoSingleWidgetProvider.updateWidget(context, mgr, id)
        }

        // Refresh list widgets
        val listIds = mgr.getAppWidgetIds(
            ComponentName(context, TapoListWidgetProvider::class.java)
        )
        for (id in listIds) {
            mgr.notifyAppWidgetViewDataChanged(id, R.id.list_widget_listview)
        }
    }

    companion object {
        /**
         * Creates a PendingIntent that routes through this receiver
         * for instant loading feedback.
         */
        fun getBroadcast(context: Context, uri: android.net.Uri): android.app.PendingIntent {
            val intent = Intent(context, TapoWidgetClickReceiver::class.java).apply {
                data = uri
            }
            return android.app.PendingIntent.getBroadcast(
                context,
                uri.hashCode(),
                intent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_MUTABLE
            )
        }
    }
}
