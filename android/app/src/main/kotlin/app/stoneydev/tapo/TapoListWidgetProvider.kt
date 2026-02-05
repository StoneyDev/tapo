package app.stoneydev.tapo

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent

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
            val views = RemoteViews(context.packageName, R.layout.tapo_list_widget)

            // Set up RemoteViewsService for ListView
            val serviceIntent = Intent(context, TapoListWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            views.setRemoteAdapter(R.id.list_widget_listview, serviceIntent)

            // Set up PendingIntent template for list item clicks
            val templateIntent = HomeWidgetBackgroundIntent.getBroadcast(
                context,
                Uri.parse("tapotoggle://toggle?ip=template")
            )
            views.setPendingIntentTemplate(R.id.list_widget_listview, templateIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.list_widget_listview)
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
