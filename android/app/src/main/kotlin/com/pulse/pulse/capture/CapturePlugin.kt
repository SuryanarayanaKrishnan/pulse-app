package com.pulse.pulse.capture

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Bridge between Dart and the Android capture components.
 *
 * MethodChannel `pulse/ingest`:
 *  - getStatus                          -> {smsReceive, smsRead, notificationAccess, smsPermanentlyDenied}
 *  - requestSmsPermissions              -> same map, after the system dialog closes
 *  - openNotificationAccessSettings     -> opens the system listener settings
 *  - openAppSettings                    -> opens this app's system settings page
 *  - configure {senders, walletPackages, bankPackages, bankPackageHints}
 *  - backfillSms {days}                 -> number of bank SMS buffered
 *  - peekPending                        -> list of captured items
 *  - ackPending {ids}                   -> removes items Dart has queued
 *
 * EventChannel `pulse/ingest/events` emits "pending" whenever new items are buffered.
 */
class CapturePlugin(
    private val activity: Activity,
    private val messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val main = Handler(Looper.getMainLooper())
    private val worker: ExecutorService = Executors.newSingleThreadExecutor()
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    fun attach() {
        methodChannel = MethodChannel(messenger, METHOD_CHANNEL).also { it.setMethodCallHandler(this) }
        eventChannel = EventChannel(messenger, EVENT_CHANNEL).also { it.setStreamHandler(CaptureEvents) }
    }

    fun detach() {
        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        methodChannel = null
        eventChannel = null
        pendingPermissionResult = null
        worker.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getStatus" -> result.success(status(permanentlyDenied = false))
            "requestSmsPermissions" -> requestSmsPermissions(result)
            "openNotificationAccessSettings" -> {
                openNotificationAccessSettings()
                result.success(null)
            }
            "openAppSettings" -> {
                startSafely(
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        .setData(Uri.fromParts("package", activity.packageName, null)),
                )
                result.success(null)
            }
            "configure" -> {
                CaptureConfig.get(activity).update(
                    senders = call.stringList("senders"),
                    walletPackages = call.stringList("walletPackages"),
                    bankPackages = call.stringList("bankPackages"),
                    bankHints = call.stringList("bankPackageHints"),
                )
                result.success(null)
            }
            "backfillSms" -> backfillSms(call.argument<Int>("days") ?: 90, result)
            "peekPending" -> result.success(CaptureStore.peek(activity).map { it.toMap() })
            "ackPending" -> {
                CaptureStore.ack(activity, call.stringList("ids").orEmpty().toSet())
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // ---- permissions -----------------------------------------------------------------------

    private fun granted(permission: String) =
        activity.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    private fun notificationAccessGranted(): Boolean {
        val enabled = Settings.Secure.getString(activity.contentResolver, "enabled_notification_listeners")
            ?: return false
        val mine = ComponentName(activity, PulseNotificationListener::class.java)
        return enabled.split(":").any { ComponentName.unflattenFromString(it) == mine }
    }

    private fun status(permanentlyDenied: Boolean): Map<String, Any> = mapOf(
        "smsReceive" to granted(Manifest.permission.RECEIVE_SMS),
        "smsRead" to granted(Manifest.permission.READ_SMS),
        "notificationAccess" to notificationAccessGranted(),
        "smsPermanentlyDenied" to permanentlyDenied,
    )

    private fun requestSmsPermissions(result: MethodChannel.Result) {
        val missing = SMS_PERMISSIONS.filterNot { granted(it) }
        if (missing.isEmpty()) {
            result.success(status(permanentlyDenied = false))
            return
        }
        if (pendingPermissionResult != null) {
            result.error("in_progress", "A permission request is already showing", null)
            return
        }
        pendingPermissionResult = result
        activity.requestPermissions(missing.toTypedArray(), REQUEST_SMS)
    }

    /** Called from MainActivity. Returns true if the result belonged to this plugin. */
    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != REQUEST_SMS) return false
        val result = pendingPermissionResult ?: return true
        pendingPermissionResult = null
        // After a denial, "no rationale" means the user ticked "don't ask again" (or the system
        // auto-denied): only the app settings page can grant it now.
        val permanentlyDenied = permissions.indices.any { i ->
            grantResults.getOrNull(i) != PackageManager.PERMISSION_GRANTED &&
                !activity.shouldShowRequestPermissionRationale(permissions[i])
        }
        result.success(status(permanentlyDenied))
        return true
    }

    private fun openNotificationAccessSettings() {
        // API 30+ can open the detail page for this listener; fall back to the general list.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val detail = Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS).putExtra(
                Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                ComponentName(activity, PulseNotificationListener::class.java).flattenToString(),
            )
            if (startSafely(detail)) return
        }
        startSafely(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
    }

    private fun startSafely(intent: Intent): Boolean = try {
        activity.startActivity(intent)
        true
    } catch (_: ActivityNotFoundException) {
        false
    }

    // ---- backfill --------------------------------------------------------------------------

    private fun backfillSms(days: Int, result: MethodChannel.Result) {
        if (!granted(Manifest.permission.READ_SMS)) {
            result.error("permission_denied", "READ_SMS is not granted", null)
            return
        }
        worker.execute {
            try {
                val count = SmsBackfill.run(activity, days)
                main.post {
                    if (count > 0) CaptureEvents.notifyPending()
                    result.success(count)
                }
            } catch (e: SecurityException) {
                main.post { result.error("permission_denied", e.message, null) }
            } catch (e: Exception) {
                main.post { result.error("backfill_failed", e.message, null) }
            }
        }
    }

    private fun MethodCall.stringList(key: String): List<String>? =
        argument<List<*>>(key)?.filterIsInstance<String>()

    companion object {
        const val METHOD_CHANNEL = "pulse/ingest"
        const val EVENT_CHANNEL = "pulse/ingest/events"
        private const val REQUEST_SMS = 4721
        private val SMS_PERMISSIONS = listOf(Manifest.permission.RECEIVE_SMS, Manifest.permission.READ_SMS)
    }
}
