package com.pulse.pulse.capture

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * Captures payment notifications from wallet apps (Google Wallet / GPay, Samsung Wallet / Pay) and
 * bank apps. Active only while the user has granted "Notification access" in system settings.
 *
 * Notifications from every other app are ignored before their content is read.
 */
class PulseNotificationListener : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val n = sbn ?: return
        val pkg = n.packageName ?: return
        if (pkg == packageName) return
        if (!CaptureConfig.get(this).isCapturedPackage(pkg)) return

        val notification = n.notification ?: return
        if (notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) return

        val extras = notification.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
        val text = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
            ?: extras.getCharSequence(Notification.EXTRA_TEXT))?.toString()
        // Transaction alerts always carry an amount; skip promos and "tap to pay is ready" chatter.
        if (text.isNullOrBlank() || text.none { it.isDigit() }) return
        if (CaptureConfig.looksLikeOtp(text)) return

        val item = CapturedItem(
            id = CaptureIds.notification(pkg, title, text, n.postTime),
            kind = "notification",
            body = text,
            sender = null,
            title = title,
            app = pkg,
            timestampMs = n.postTime,
        )
        if (CaptureStore.add(this, listOf(item))) CaptureEvents.notifyPending()
    }
}
