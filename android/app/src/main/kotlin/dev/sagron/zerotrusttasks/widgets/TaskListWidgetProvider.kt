package dev.sagron.zerotrusttasks.widgets

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import dev.sagron.zerotrusttasks.MainActivity
import dev.sagron.zerotrusttasks.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

/**
 * Open tasks on the home screen, with a tick circle per task and a + to add
 * one. Each widget shows the scope picked when it was placed (W6, see
 * TaskListWidgetConfigureActivity): all lists, Today, Starred or one list,
 * stored as `tasks_widget_<id>_scope`. Renders only what HomeWidgetService
 * (Dart) wrote under `tasks_widget_scopes`: task titles exist there only if
 * the user turned on "Show details on the home screen".
 *
 * A tick works without the vault: the task id is queued under
 * `widget_pending_ticks` and the row disappears; the app completes the task
 * the next time it is unlocked.
 *
 * Shared Zero-Trust widget look (Zero-Trust-Core/android-widget-kit). The
 * number of rows follows the widget's height; at one cell high it is just the
 * title, the counts and +.
 */
class TaskListWidgetProvider : HomeWidgetProvider() {

    companion object {
        const val ACTION_TICK = "dev.sagron.zerotrusttasks.widgets.TICK"
        const val EXTRA_TASK_ID = "task_id"
        private const val ACTION_MIDNIGHT = "dev.sagron.zerotrusttasks.widgets.MIDNIGHT"
        private const val MAX_ROWS = 5
        private val ROW_IDS = intArrayOf(R.id.row_0, R.id.row_1, R.id.row_2, R.id.row_3, R.id.row_4)
        private val CHECK_IDS = intArrayOf(R.id.row_0_check, R.id.row_1_check, R.id.row_2_check, R.id.row_3_check, R.id.row_4_check)
        private val TEXT_IDS = intArrayOf(R.id.row_0_text, R.id.row_1_text, R.id.row_2_text, R.id.row_3_text, R.id.row_4_text)
        private val TITLE_IDS = intArrayOf(R.id.row_0_title, R.id.row_1_title, R.id.row_2_title, R.id.row_3_title, R.id.row_4_title)
        private val DUE_IDS = intArrayOf(R.id.row_0_due, R.id.row_1_due, R.id.row_2_due, R.id.row_3_due, R.id.row_4_due)

        private const val SCOPES_KEY = "tasks_widget_scopes"

        /** The same scopes worked out for tomorrow, used once the day changes. */
        private const val SCOPES_NEXT_KEY = "tasks_widget_scopes_next"

        private fun dayKey(c: Calendar) = String.format(
            java.util.Locale.ROOT,
            "%04d-%02d-%02d",
            c.get(Calendar.YEAR),
            c.get(Calendar.MONTH) + 1,
            c.get(Calendar.DAY_OF_MONTH),
        )

        /**
         * Which scopes are current: the app writes today's and tomorrow's, so
         * Today (and "due today") stay right past midnight while it is closed.
         */
        private fun currentScopesKey(prefs: SharedPreferences): String {
            val written = prefs.getString("tasks_widget_day", null) ?: return SCOPES_KEY
            if (written >= dayKey(Calendar.getInstance())) return SCOPES_KEY
            return if (prefs.getString(SCOPES_NEXT_KEY, null) != null) SCOPES_NEXT_KEY else SCOPES_KEY
        }

        private fun readScopes(prefs: SharedPreferences): JSONObject? = try {
            prefs.getString(currentScopesKey(prefs), null)?.let { JSONObject(it) }
        } catch (e: Exception) {
            null
        }

        /**
         * A widget whose list was deleted falls back to the default list's
         * scope, then all lists, instead of staying empty for good.
         */
        private fun resolveScope(prefs: SharedPreferences, scopes: JSONObject?, widgetId: Int): String {
            val picked = scopeOf(prefs, widgetId)
            if (scopes == null || scopes.has(picked)) return picked
            val fallback = prefs.getString("tasks_widget_default_scope", null)
            return if (fallback != null && scopes.has(fallback)) fallback else "all"
        }

        /** Redraws at the next midnight, when tomorrow's scopes take over. */
        private fun scheduleMidnight(context: Context) {
            val next = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_MONTH, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 5)
                set(Calendar.MILLISECOND, 0)
            }
            val intent = Intent(context, TaskListWidgetProvider::class.java).setAction(ACTION_MIDNIGHT)
            val pending = PendingIntent.getBroadcast(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            // Inexact is fine: a few minutes late costs nothing.
            alarms.set(AlarmManager.RTC, next.timeInMillis, pending)
        }

        fun scopeKey(widgetId: Int) = "tasks_widget_${widgetId}_scope"

        /** Redraws every task widget, after a widget's scope was picked. */
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val prefs = HomeWidgetPlugin.getData(context)
            manager.getAppWidgetIds(ComponentName(context, TaskListWidgetProvider::class.java)).forEach {
                manager.updateAppWidget(it, buildViews(context, prefs, it, manager.getAppWidgetOptions(it)))
            }
        }

        /** The scope [widgetId] shows; widgets placed before W6 keep the old setting's. */
        private fun scopeOf(prefs: SharedPreferences, widgetId: Int): String =
            prefs.getString(scopeKey(widgetId), null)
                ?: prefs.getString("tasks_widget_default_scope", null)
                ?: "all"

        private data class Row(val id: String, val title: String, val due: String?)

        private data class Content(val title: String?, val summary: String?, val rows: List<Row>)

        private fun readContent(all: JSONObject?, scope: String): Content? {
            val one = all?.optJSONObject(scope) ?: return null
            val rows = one.optJSONArray("r") ?: JSONArray()
            return Content(
                title = one.optString("t").ifEmpty { null },
                summary = one.optString("s").ifEmpty { null },
                rows = (0 until rows.length()).mapNotNull { i ->
                    val row = rows.optJSONObject(i) ?: return@mapNotNull null
                    val id = row.optString("id").ifEmpty { return@mapNotNull null }
                    Row(id, row.optString("t"), row.optString("d").ifEmpty { null })
                },
            )
        }

        private fun buildViews(context: Context, prefs: SharedPreferences, widgetId: Int, options: Bundle?): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_task_list)
            // Portrait height; 0 when the launcher hasn't said yet.
            val height = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0) ?: 0
            val showAppRow = height == 0 || height >= 160
            val maxRows = rowsFor(height, showAppRow)
            val locked = prefs.getBoolean("tasks_widget_locked", false)
            val scopes = if (locked) null else readScopes(prefs)
            val scope = resolveScope(prefs, scopes, widgetId)
            val content = readContent(scopes, scope)
            views.setViewVisibility(R.id.app_row, if (showAppRow) View.VISIBLE else View.GONE)
            // Signed out: a lock and one line, unless only the header fits.
            val roomForLock = height == 0 || height >= 100
            views.setViewVisibility(R.id.locked, if (locked && roomForLock) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.rows, if (locked || maxRows == 0) View.GONE else View.VISIBLE)
            views.setTextViewText(R.id.list_name, content?.title ?: when (scope) {
                "today" -> WidgetText.get(context, prefs, "today", R.string.widget_today)
                "starred" -> WidgetText.get(context, prefs, "starred", R.string.widget_starred)
                else -> WidgetText.get(context, prefs, "your_tasks", R.string.widget_your_tasks)
            })
            views.setTextViewText(
                R.id.summary,
                when {
                    locked -> WidgetText.get(context, prefs, "signed_out", R.string.widget_signed_out)
                    else -> content?.summary
                        ?: WidgetText.get(context, prefs, "open_app_summary", R.string.widget_open_app_summary)
                },
            )
            views.setTextViewText(R.id.locked_text, WidgetText.get(context, prefs, "open_to_see", R.string.widget_open_to_see))
            views.setContentDescription(R.id.add_button, WidgetText.get(context, prefs, "add_task", R.string.widget_add_task))
            val completeTask = WidgetText.get(context, prefs, "complete_task", R.string.widget_complete_task)
            CHECK_IDS.forEach { views.setContentDescription(it, completeTask) }
            views.setOnClickPendingIntent(
                R.id.header,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("zerotrusttasks://open")),
            )
            // + adds to the list (or Starred) this widget shows.
            val addUri = when {
                scope.startsWith("list:") -> "zerotrusttasks://new-task?list=" + Uri.encode(scope.removePrefix("list:"))
                scope == "starred" -> "zerotrusttasks://new-task?starred=1"
                else -> "zerotrusttasks://new-task"
            }
            views.setOnClickPendingIntent(
                R.id.add_button,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(addUri)),
            )

            val rows = content?.rows.orEmpty().take(maxRows)
            for (i in 0 until MAX_ROWS) {
                val row = rows.getOrNull(i)
                if (row == null) {
                    views.setViewVisibility(ROW_IDS[i], View.GONE)
                    continue
                }
                val id = row.id
                views.setViewVisibility(ROW_IDS[i], View.VISIBLE)
                views.setTextViewText(TITLE_IDS[i], row.title)
                val due = row.due
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
                    data = Uri.parse("zerotrusttasks://tick/" + Uri.encode(id))
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

        /** Rows that fit under the header at [height] dp (0: unknown, all). */
        private fun rowsFor(height: Int, showAppRow: Boolean): Int {
            if (height == 0) return MAX_ROWS
            // Padding 28, title and counts 44, gap 6, app name row 26; rows 40 each.
            val free = height - 78 - (if (showAppRow) 26 else 0)
            return (free / 40).coerceIn(0, MAX_ROWS)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        scheduleMidnight(context)
        appWidgetIds.forEach { widgetId ->
            appWidgetManager.updateAppWidget(
                widgetId,
                buildViews(context, widgetData, widgetId, appWidgetManager.getAppWidgetOptions(widgetId)),
            )
        }
    }

    /** Resized: redraw with as many rows as now fit. */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        appWidgetManager.updateAppWidget(
            appWidgetId,
            buildViews(context, HomeWidgetPlugin.getData(context), appWidgetId, newOptions),
        )
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_TICK) {
            val taskId = intent.getStringExtra(EXTRA_TASK_ID) ?: return
            tick(context, taskId)
            return
        }
        if (intent.action == ACTION_MIDNIGHT) {
            scheduleMidnight(context)
            updateAll(context)
            return
        }
        super.onReceive(context, intent)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        val editor = HomeWidgetPlugin.getData(context).edit()
        appWidgetIds.forEach { editor.remove(scopeKey(it)) }
        editor.apply()
    }

    /**
     * Queues the tick for the app and takes the task off every scope at once,
     * so it disappears from all widgets that showed it.
     */
    private fun tick(context: Context, taskId: String) {
        val prefs = HomeWidgetPlugin.getData(context)
        // Only a task a widget shows can be ticked: the provider has to be
        // exported for the launcher, so another app could send this too.
        val current = currentScopesKey(prefs)
        val doneSaved = WidgetText.get(context, prefs, "done_saved", R.string.widget_done_saved)
        val editor = prefs.edit()
        var shown = false
        for (key in listOf(SCOPES_KEY, SCOPES_NEXT_KEY)) {
            val scopes = try {
                prefs.getString(key, null)?.let { JSONObject(it) }
            } catch (e: Exception) {
                null
            } ?: continue
            if (removeTask(scopes, taskId, doneSaved)) {
                if (key == current) shown = true
                editor.putString(key, scopes.toString())
            }
        }
        if (!shown) return
        val pending = prefs.getString("widget_pending_ticks", null).orEmpty()
        editor
            .putString("widget_pending_ticks", if (pending.isEmpty()) taskId else "$pending\n$taskId")
            .apply()
        updateAll(context)
    }

    /** Takes [taskId] off every scope in [scopes]; true if any showed it. */
    private fun removeTask(scopes: JSONObject, taskId: String, doneSaved: String): Boolean {
        var removed = false
        for (key in scopes.keys()) {
            val scope = scopes.optJSONObject(key) ?: continue
            val rows = scope.optJSONArray("r") ?: continue
            val kept = JSONArray()
            for (i in 0 until rows.length()) {
                val row = rows.optJSONObject(i) ?: continue
                if (row.optString("id") != taskId) kept.put(row)
            }
            if (kept.length() != rows.length()) {
                removed = true
                scope.put("r", kept)
                scope.put("s", doneSaved)
            }
        }
        return removed
    }
}
