package dev.sagron.zerotrusttasks

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
 */
class MainActivity : FlutterFragmentActivity() {
    private var links: MethodChannel? = null
    private val pendingLinks = mutableListOf<String>()
    private var shareChannel: MethodChannel? = null
    private var pendingShare: Map<String, String?>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Not again when the activity is recreated (rotation).
        if (savedInstanceState == null) pendingShare = shared(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
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
}
