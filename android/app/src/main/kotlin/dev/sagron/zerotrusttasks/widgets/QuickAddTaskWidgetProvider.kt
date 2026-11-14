package dev.sagron.zerotrusttasks.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import dev.sagron.zerotrusttasks.MainActivity
import dev.sagron.zerotrusttasks.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * 1x1 "Add a task" (W6): a round + in the app's accent that opens the quick
 * add sheet. It shows no task content, so it needs no privacy switch.
 */
class QuickAddTaskWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val label = WidgetText.get(context, widgetData, "add_task", R.string.widget_add_task)
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_quick_add_task).apply {
                setContentDescription(R.id.quick_add_task_button, label)
                setOnClickPendingIntent(
                    R.id.quick_add_task_root,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("zerotrusttasks://new-task"),
                    ),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
