package dev.sagron.zerotrusttasks

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager

/**
 * ZT Keyboard's "Insert from ZT apps" key: the keyboard opens this app to let the user
 * pick a task (its title, due date, checklist or links), and types what was picked.
 *
 * Only a Zero-Trust app may ask. All of them are signed with the same key, so the caller
 * must carry this app's own signature; anyone else is turned away before anything is
 * shown. The answer is the one text the user tapped, nothing more, and only after the
 * vault was unlocked as usual.
 */
object TextPick {
    const val ACTION = "bz.zerotrust.action.PICK_TEXT"
    const val EXTRA_TEXT = "bz.zerotrust.extra.TEXT"

    /** ZT Time asks for the task itself too (see docs: zt-time-links). */
    const val EXTRA_WANT_ITEM = "bz.zerotrust.extra.WANT_ITEM"
    const val EXTRA_ITEM_ID = "bz.zerotrust.extra.ITEM_ID"
    const val EXTRA_TITLE = "bz.zerotrust.extra.TITLE"

    fun isPick(intent: Intent?): Boolean = intent?.action == ACTION

    /**
     * Whether [activity] was opened, for an answer, by an app signed with this app's key.
     * Android only names the caller when it waits for an answer, and that name cannot be
     * faked by the caller.
     */
    fun callerAllowed(activity: Activity): Boolean {
        val caller = activity.callingPackage ?: return false
        return try {
            activity.packageManager.checkSignatures(activity.packageName, caller) ==
                PackageManager.SIGNATURE_MATCH
        } catch (error: Exception) {
            false
        }
    }

    fun wantsItem(intent: Intent?): Boolean = intent?.getBooleanExtra(EXTRA_WANT_ITEM, false) == true

    /**
     * Answers with [text]; when the asker set WANT_ITEM, also the task's [itemId] and
     * [title], so ZT Time can link its entry back to the task.
     */
    fun answer(activity: Activity, text: String?, itemId: String? = null, title: String? = null) {
        if (text.isNullOrEmpty()) {
            activity.setResult(Activity.RESULT_CANCELED)
        } else {
            val data = Intent().putExtra(EXTRA_TEXT, text)
            if (wantsItem(activity.intent) && !itemId.isNullOrEmpty()) {
                data.putExtra(EXTRA_ITEM_ID, itemId)
                if (!title.isNullOrEmpty()) data.putExtra(EXTRA_TITLE, title)
            }
            activity.setResult(Activity.RESULT_OK, data)
        }
        activity.finish()
    }
}
