package com.pulse.pulse.capture

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

/**
 * Receives incoming SMS (RECEIVE_SMS). Only messages from known bank sender IDs are kept, and
 * one-time-code messages are discarded. Everything else is ignored without being read further.
 */
class SmsReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (messages.isNullOrEmpty()) return

        val config = CaptureConfig.get(context)
        // The inbox "date" column is the device receive time, so use the same clock here; that keeps
        // ids from this receiver identical to the ones the inbox backfill computes.
        val receivedAt = System.currentTimeMillis()

        val items = messages
            .groupBy { it.originatingAddress.orEmpty() }
            .mapNotNull { (address, parts) ->
                if (!config.isBankSender(address)) return@mapNotNull null
                val body = parts.joinToString("") { it.messageBody.orEmpty() }
                if (body.isBlank() || CaptureConfig.looksLikeOtp(body)) return@mapNotNull null
                CapturedItem(
                    id = CaptureIds.sms(address, body, receivedAt),
                    kind = "sms",
                    body = body,
                    sender = address,
                    title = null,
                    app = null,
                    timestampMs = receivedAt,
                )
            }

        if (items.isNotEmpty() && CaptureStore.add(context, items)) {
            CaptureEvents.notifyPending()
        }
    }
}
