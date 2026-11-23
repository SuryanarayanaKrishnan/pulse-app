package com.pulse.pulse.capture

import android.content.Context
import android.provider.Telephony

/** One-time read of the SMS inbox (READ_SMS), limited to known bank senders. */
object SmsBackfill {
    private const val DAY_MS = 24L * 60 * 60 * 1000

    /**
     * Buffers bank SMS from the last [days] days and returns how many were found.
     *
     * @throws SecurityException if READ_SMS has not been granted.
     */
    fun run(context: Context, days: Int): Int {
        val config = CaptureConfig.get(context)
        val since = System.currentTimeMillis() - days.coerceIn(1, 365) * DAY_MS
        val items = ArrayList<CapturedItem>()

        context.contentResolver.query(
            Telephony.Sms.Inbox.CONTENT_URI,
            arrayOf(Telephony.Sms.ADDRESS, Telephony.Sms.BODY, Telephony.Sms.DATE),
            "${Telephony.Sms.DATE} >= ?",
            arrayOf(since.toString()),
            "${Telephony.Sms.DATE} DESC",
        )?.use { cursor ->
            val iAddress = cursor.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
            val iBody = cursor.getColumnIndexOrThrow(Telephony.Sms.BODY)
            val iDate = cursor.getColumnIndexOrThrow(Telephony.Sms.DATE)
            while (cursor.moveToNext()) {
                val address = cursor.getString(iAddress)
                if (!config.isBankSender(address)) continue
                val body = cursor.getString(iBody).orEmpty()
                if (body.isBlank() || CaptureConfig.looksLikeOtp(body)) continue
                val date = cursor.getLong(iDate)
                items += CapturedItem(
                    id = CaptureIds.sms(address, body, date),
                    kind = "sms",
                    body = body,
                    sender = address,
                    title = null,
                    app = null,
                    timestampMs = date,
                )
            }
        }

        if (items.isNotEmpty()) CaptureStore.add(context, items)
        return items.size
    }
}
