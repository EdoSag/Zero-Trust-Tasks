package dev.sagron.zerotrusttasks.widgets

import android.app.Activity
import android.app.AlertDialog
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.content.res.Configuration
import android.os.Bundle
import android.widget.TextView
import dev.sagron.zerotrusttasks.R
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

/**
 * "Widget shows" (W6): picked when a task widget is placed, and again from
 * the launcher's widget settings. All lists, Today, Starred, or one of the
 * lists. List names are only offered while "Show details on the home
 * screen" is on (the app writes them to `tasks_widget_lists` only then), so
 * this works while the app is locked and never opens the vault.
 */
class TaskListWidgetConfigureActivity : Activity() {

    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)
        widgetId = intent?.extras?.getInt(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            ?: AppWidgetManager.INVALID_APPWIDGET_ID
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        val prefs = HomeWidgetPlugin.getData(this)
        val scopes = mutableListOf("all", "today", "starred")
        val labels = mutableListOf(
            WidgetText.get(this, prefs, "all_lists", R.string.widget_all_lists),
            WidgetText.get(this, prefs, "today", R.string.widget_today),
            WidgetText.get(this, prefs, "starred", R.string.widget_starred),
        )
        val lists = try {
            prefs.getString("tasks_widget_lists", null)?.let { JSONArray(it) }
        } catch (e: Exception) {
            null
        }
        if (lists != null) {
            for (i in 0 until lists.length()) {
                val list = lists.optJSONObject(i) ?: continue
                val id = list.optString("id").ifEmpty { continue }
                scopes.add("list:$id")
                labels.add(list.optString("name").ifEmpty { id })
            }
        }
        val current = scopes.indexOf(prefs.getString(TaskListWidgetProvider.scopeKey(widgetId), null) ?: "all")

        val night = (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES
        val builder = AlertDialog.Builder(
            this,
            if (night) android.R.style.Theme_DeviceDefault_Dialog_Alert else android.R.style.Theme_DeviceDefault_Light_Dialog_Alert,
        )
            .setTitle(WidgetText.get(this, prefs, "pick_title", R.string.widget_pick_title))
            .setSingleChoiceItems(labels.toTypedArray(), current) { dialog, which ->
                dialog.dismiss()
                save(scopes[which])
            }
            .setNegativeButton(WidgetText.get(this, prefs, "cancel", R.string.widget_cancel)) { dialog, _ -> dialog.cancel() }
            .setOnCancelListener { finish() }
        if (lists == null) {
            // Details off: say why no lists are offered.
            val hint = TextView(this).apply {
                text = WidgetText.get(this@TaskListWidgetConfigureActivity, prefs, "pick_hint", R.string.widget_pick_hint)
                val pad = (24 * resources.displayMetrics.density).toInt()
                setPadding(pad, pad / 3, pad, 0)
            }
            builder.setView(hint)
        }
        builder.show()
    }

    private fun save(scope: String) {
        HomeWidgetPlugin.getData(this).edit()
            .putString(TaskListWidgetProvider.scopeKey(widgetId), scope)
            .apply()
        TaskListWidgetProvider.updateAll(this)
        setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId))
        finish()
    }
}
