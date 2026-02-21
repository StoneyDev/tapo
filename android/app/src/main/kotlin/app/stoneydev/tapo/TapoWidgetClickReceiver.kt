package app.stoneydev.tapo

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Intercepts widget tap clicks to set loading state immediately in Kotlin
 * before forwarding to the Dart background callback.
 */
class TapoWidgetClickReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val ip = intent.data?.getQueryParameter("ip") ?: return

        val prefs = HomeWidgetPlugin.getData(context)
        prefs.edit().putBoolean("loading_$ip", true).apply()

        refreshWidgets(context)

        // Forward to Dart background callback with canonical URI
        val uri = Uri.parse("tapotoggle://toggle?ip=$ip")
        HomeWidgetBackgroundIntent.getBroadcast(context, uri).send()
    }

    private fun refreshWidgets(context: Context) {
        TapoSingleWidgetProvider.updateAllWidgets(context)
        TapoListWidgetProvider.updateAllWidgets(context)
    }

    companion object {
        fun getBroadcast(context: Context, uri: Uri): PendingIntent {
            val intent = Intent(context, TapoWidgetClickReceiver::class.java).apply {
                data = uri
            }
            return PendingIntent.getBroadcast(
                context,
                uri.hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            )
        }
    }
}
