package dev.sagron.zerotrusttasks.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import dev.sagron.zerotrusttasks.MainActivity
import dev.sagron.zerotrusttasks.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Open tasks on the home screen, with a tick circle per task and a + to add
 * one. Renders only what HomeWidgetService (Dart) wrote: task titles exist
 * there only if the user turned on "Show tasks on the home-screen widget".
 *
 * A tick works without the vault: the task id is queued under
 * `widget_pending_ticks` and the row disappears; the app completes the task
 * the next time it is unlocked.
 */
class TaskListWidgetProvider : HomeWidgetProvider() {

    companion object {
        const val ACTION_TICK = "dev.sagron.zerotrusttasks.widgets.TICK"
        const val EXTRA_TASK_ID = "task_id"
        private const val MAX_ROWS = 5
        private val ROW_IDS = intArrayOf(R.id.row_0, R.id.row_1, R.id.row_2, R.id.row_3, R.id.row_4)
        private val CHECK_IDS = intArrayOf(R.id.row_0_check, R.id.row_1_check, R.id.row_2_check, R.id.row_3_check, R.id.row_4_check)
        private val TEXT_IDS = intArrayOf(R.id.row_0_text, R.id.row_1_text, R.id.row_2_text, R.id.row_3_text, R.id.row_4_text)
        private val TITLE_IDS = intArrayOf(R.id.row_0_title, R.id.row_1_title, R.id.row_2_title, R.id.row_3_title, R.id.row_4_title)
        private val DUE_IDS = intArrayOf(R.id.row_0_due, R.id.row_1_due, R.id.row_2_due, R.id.row_3_due, R.id.row_4_due)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            appWidgetManager.updateAppWidget(widgetId, buildViews(context, widgetData))
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_TICK) {
            val taskId = intent.getStringExtra(EXTRA_TASK_ID) ?: return
            tick(context, taskId)
            return
        }
        super.onReceive(context, intent)
    }

    private fun tick(context: Context, taskId: String) {
        val prefs = HomeWidgetPlugin.getData(context)
        val count = prefs.getInt("tasks_widget_count", 0).coerceIn(0, MAX_ROWS)
        val rows = (0 until count).map { i ->
            Triple(
                prefs.getString("tasks_widget_row_${i}_id", null),
                prefs.getString("tasks_widget_row_${i}_title", null),
                prefs.getString("tasks_widget_row_${i}_due", null),
            )
        }.filter { it.first != null && it.first != taskId }
        val pending = prefs.getString("widget_pending_ticks", null).orEmpty()
        val editor = prefs.edit()
        editor.putString("widget_pending_ticks", if (pending.isEmpty()) taskId else "$pending\n$taskId")
        for (i in 0 until MAX_ROWS) {
            val row = rows.getOrNull(i)
            if (row == null) {
                editor.remove("tasks_widget_row_${i}_id")
                editor.remove("tasks_widget_row_${i}_title")
                editor.remove("tasks_widget_row_${i}_due")
            } else {
                editor.putString("tasks_widget_row_${i}_id", row.first)
                editor.putString("tasks_widget_row_${i}_title", row.second)
                editor.putString("tasks_widget_row_${i}_due", row.third)
            }
        }
        editor.putInt("tasks_widget_count", rows.size)
        editor.putString("tasks_widget_summary", "Done. Saved when you next open the app")
        editor.apply()

        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, TaskListWidgetProvider::class.java))
        ids.forEach { manager.updateAppWidget(it, buildViews(context, prefs)) }
    }

    private fun buildViews(context: Context, prefs: SharedPreferences): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_task_list)
        views.setTextViewText(R.id.list_name, prefs.getString("tasks_widget_title", null) ?: "ZT Tasks")
        views.setTextViewText(
            R.id.summary,
            prefs.getString("tasks_widget_summary", null) ?: "Open the app to see your tasks",
        )
        views.setOnClickPendingIntent(
            R.id.header,
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("zerotrusttasks://open")),
        )
        views.setOnClickPendingIntent(
            R.id.add_button,
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("zerotrusttasks://new-task")),
        )

        val count = prefs.getInt("tasks_widget_count", 0).coerceIn(0, MAX_ROWS)
        for (i in 0 until MAX_ROWS) {
            val id = if (i < count) prefs.getString("tasks_widget_row_${i}_id", null) else null
            val title = if (i < count) prefs.getString("tasks_widget_row_${i}_title", null) else null
            if (id == null || title == null) {
                views.setViewVisibility(ROW_IDS[i], View.GONE)
                continue
            }
            views.setViewVisibility(ROW_IDS[i], View.VISIBLE)
            views.setTextViewText(TITLE_IDS[i], title)
            val due = prefs.getString("tasks_widget_row_${i}_due", null)
            if (due.isNullOrEmpty()) {
                views.setViewVisibility(DUE_IDS[i], View.GONE)
            } else {
                views.setViewVisibility(DUE_IDS[i], View.VISIBLE)
                views.setTextViewText(DUE_IDS[i], due)
            }
            val tickIntent = Intent(context, TaskListWidgetProvider::class.java).apply {
                action = ACTION_TICK
                putExtra(EXTRA_TASK_ID, id)
                // Distinct data per task, or Android reuses one PendingIntent.
                data = Uri.parse("zerotrusttasks://tick/$id")
            }
            views.setOnClickPendingIntent(
                CHECK_IDS[i],
                PendingIntent.getBroadcast(
                    context,
                    id.hashCode(),
                    tickIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
            views.setOnClickPendingIntent(
                TEXT_IDS[i],
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("zerotrusttasks://task?id=" + Uri.encode(id)),
                ),
            )
        }
        return views
    }
}
