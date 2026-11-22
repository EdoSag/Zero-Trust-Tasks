package dev.sagron.zerotrusttasks

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * FlutterFragmentActivity: biometric unlock (local_auth) needs a FragmentActivity.
 *
 * `zt_tasks/apps` opens a sibling Zero-Trust app (ZT Notes for a linked
 * note, say), or its Play Store page when it isn't installed.
 *
 * `zt_tasks/links` holds shared-list invite links the app was opened with,
 * until the unlocked app takes them.
 *
 * `zt_tasks/share` hands text shared to ZT Tasks (ZT Browser's "Read later
 * in ZT Tasks", or Android's share sheet) to the app, which opens the task
 * editor filled in. Only text: nothing is saved until the person taps Save.
 *
 * `zt_tasks/text_pick` answers ZT Keyboard's "Insert from ZT apps" key (see
 * [TextPick]): the keyboard opens Tasks, the user unlocks and taps what to type.
 * With WANT_ITEM (ZT Time), the task's id and title go with the answer.
 *
 * `zt_tasks/time` hands a task to ZT Time (focus timer, "Track time"):
 * bz.zerotrust.action.TRACK_TIME, started for a result so Time can tell
 * which app asks. `zt_tasks/open_item` holds a task id another Zero-Trust
 * app asked to open (bz.zerotrust.action.OPEN_ITEM) until the unlocked app
 * takes it.
 */
class MainActivity : FlutterFragmentActivity() {
    private var links: MethodChannel? = null
    private val pendingLinks = mutableListOf<String>()
    private var shareChannel: MethodChannel? = null
    private var pendingShare: Map<String, String?>? = null

    /** ZT Keyboard is waiting for the user to pick a text here (see [TextPick]). */
    private var pickingText = false

    private var openItemChannel: MethodChannel? = null
    private var pendingOpenItem: String? = null
    private var timeResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Not again when the activity is recreated (rotation).
        if (savedInstanceState == null) {
            pendingShare = shared(intent)
            pendingOpenItem = openItem(intent)
        }
        if (TextPick.isPick(intent)) {
            // Only another Zero-Trust app may ask; anyone else gets nothing.
            if (TextPick.callerAllowed(this)) pickingText = true else TextPick.answer(this, null)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // A pick request is only honoured when it opens its own screen (onCreate), where
        // Android tells who is asking.
        if (TextPick.isPick(intent)) return
        setIntent(intent)
        val item = openItem(intent)
        if (item != null) {
            val channel = openItemChannel
            if (channel != null) channel.invokeMethod("open", item) else pendingOpenItem = item
            return
        }
        val share = shared(intent)
        if (share != null) {
            val channel = shareChannel
            if (channel != null) channel.invokeMethod("shared", share) else pendingShare = share
            return
        }
        handleLink(intent)
    }

    private fun handleLink(intent: Intent?) {
        if (intent?.action != Intent.ACTION_VIEW) return
        val uri = intent.data ?: return
        if (uri.scheme != "https" || uri.host != "zerotrust.bz" || uri.path?.startsWith("/join") != true) return
        // Taken once: rotating the screen must not open it again.
        intent.action = null
        pendingLinks.add(uri.toString())
        links?.invokeMethod("linksArrived", null)
    }

    private fun openItem(intent: Intent?): String? {
        if (intent?.action != ACTION_OPEN_ITEM) return null
        return intent.getStringExtra(EXTRA_ITEM_ID)?.takeIf { it.isNotBlank() && it.length <= 200 }
    }

    @Deprecated("Deprecated in Android, still the simplest hook here")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_TRACK_TIME) {
            timeResult?.success(if (resultCode == Activity.RESULT_OK) "done" else "cancelled")
            timeResult = null
        }
    }

    private fun shared(intent: Intent?): Map<String, String?>? {
        if (intent?.action != Intent.ACTION_SEND || intent.type?.startsWith("text/") != true) {
            return null
        }
        val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()?.take(10_000)
        val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT)?.take(500)
        if (text.isNullOrBlank() && subject.isNullOrBlank()) return null
        return mapOf("text" to text, "subject" to subject)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        links = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zt_tasks/links").also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "takePending" -> {
                        val out = ArrayList(pendingLinks)
                        pendingLinks.clear()
                        result.success(out)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        handleLink(intent)
        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zt_tasks/share").also {
            it.setMethodCallHandler { call, result ->
                if (call.method == "take") {
                    result.success(pendingShare)
                    pendingShare = null
                } else {
                    result.notImplemented()
                }
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zt_tasks/text_pick")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // configureFlutterEngine runs inside super.onCreate, before pickingText
                    // is set, so the question is answered from the intent and the caller check.
                    "isPick" -> result.success(TextPick.isPick(intent) && TextPick.callerAllowed(this))
                    "wantsItem" -> result.success(TextPick.wantsItem(intent))
                    "finish" -> {
                        // Answers only the screen the keyboard itself opened.
                        if (pickingText) {
                            pickingText = false
                            TextPick.answer(
                                this,
                                call.argument<String>("text"),
                                call.argument<String>("itemId"),
                                call.argument<String>("title"),
                            )
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        openItemChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zt_tasks/open_item").also {
            it.setMethodCallHandler { call, result ->
                if (call.method == "take") {
                    result.success(pendingOpenItem)
                    pendingOpenItem = null
                } else {
                    result.notImplemented()
                }
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zt_tasks/time")
            .setMethodCallHandler { call, result ->
                if (call.method != "track") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val track = Intent(ACTION_TRACK_TIME)
                    .setPackage(TIME_PACKAGE)
                    .putExtra(EXTRA_ITEM_ID, call.argument<String>("id"))
                    .putExtra(EXTRA_TITLE, call.argument<String>("title"))
                call.argument<Number>("start")?.let { track.putExtra(EXTRA_START_MS, it.toLong()) }
                call.argument<Number>("end")?.let { track.putExtra(EXTRA_END_MS, it.toLong()) }
                if (track.resolveActivity(packageManager) == null) {
                    result.success("missing")
                    return@setMethodCallHandler
                }
                // A result is asked for so Time can see which app asks.
                timeResult?.success("cancelled")
                timeResult = result
                try {
                    @Suppress("DEPRECATION")
                    startActivityForResult(track, REQUEST_TRACK_TIME)
                } catch (e: Exception) {
                    timeResult = null
                    result.success("missing")
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zt_tasks/apps")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "open" -> {
                        val pkg = call.argument<String>("package")
                        if (pkg == null || !pkg.startsWith("dev.sagron.")) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        val launch = packageManager.getLaunchIntentForPackage(pkg)
                        if (launch != null) {
                            startActivity(launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                            result.success(true)
                        } else {
                            try {
                                startActivity(
                                    Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$pkg"))
                                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                                )
                            } catch (e: Exception) {
                                startActivity(
                                    Intent(
                                        Intent.ACTION_VIEW,
                                        Uri.parse("https://play.google.com/store/apps/details?id=$pkg"),
                                    ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                                )
                            }
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    companion object {
        private const val REQUEST_TRACK_TIME = 4107
        private const val TIME_PACKAGE = "dev.sagron.zerotrusttime"
        private const val ACTION_TRACK_TIME = "bz.zerotrust.action.TRACK_TIME"
        private const val ACTION_OPEN_ITEM = "bz.zerotrust.action.OPEN_ITEM"
        private const val EXTRA_ITEM_ID = "bz.zerotrust.extra.ITEM_ID"
        private const val EXTRA_TITLE = "bz.zerotrust.extra.TITLE"
        private const val EXTRA_START_MS = "bz.zerotrust.extra.START_MS"
        private const val EXTRA_END_MS = "bz.zerotrust.extra.END_MS"
    }
}
