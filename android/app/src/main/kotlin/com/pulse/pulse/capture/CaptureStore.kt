package com.pulse.pulse.capture

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest

/** One captured SMS or notification, as handed to Dart. */
data class CapturedItem(
    val id: String,
    val kind: String, // "sms" | "notification"
    val body: String,
    val sender: String?,
    val title: String?,
    val app: String?,
    val timestampMs: Long,
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("id", id)
        put("kind", kind)
        put("body", body)
        put("ts", timestampMs)
        sender?.let { put("sender", it) }
        title?.let { put("title", it) }
        app?.let { put("app", it) }
    }

    fun toMap(): Map<String, Any?> = mapOf(
        "id" to id,
        "kind" to kind,
        "body" to body,
        "sender" to sender,
        "title" to title,
        "app" to app,
        "ts" to timestampMs,
    )

    companion object {
        fun fromJson(o: JSONObject) = CapturedItem(
            id = o.getString("id"),
            kind = o.getString("kind"),
            body = o.optString("body"),
            sender = o.optString("sender").ifEmpty { null },
            title = o.optString("title").ifEmpty { null },
            app = o.optString("app").ifEmpty { null },
            timestampMs = o.getLong("ts"),
        )
    }
}

/**
 * Durable native buffer between the receivers and Dart.
 *
 * Receivers may run while the Flutter engine is not alive, so every captured item is written here
 * first. Dart reads with [peek] and removes with [ack] only after it has persisted the item in its
 * own queue, which makes delivery at-least-once (the backend de-duplicates on `external_id`).
 */
object CaptureStore {
    private const val PREFS = "pulse_capture_store"
    private const val KEY_PENDING = "pending"
    private const val MAX_ITEMS = 1000
    private val lock = Any()

    /** Adds [items], skipping ids already buffered. Returns true if anything new was stored. */
    fun add(context: Context, items: List<CapturedItem>): Boolean = synchronized(lock) {
        val current = read(context).toMutableList()
        val known = current.mapTo(HashSet()) { it.id }
        val fresh = items.filter { known.add(it.id) }
        if (fresh.isEmpty()) return false
        current.addAll(fresh)
        while (current.size > MAX_ITEMS) current.removeAt(0)
        write(context, current)
        true
    }

    fun peek(context: Context, limit: Int = 200): List<CapturedItem> = synchronized(lock) {
        read(context).take(limit)
    }

    fun ack(context: Context, ids: Set<String>) = synchronized(lock) {
        if (ids.isEmpty()) return@synchronized
        write(context, read(context).filterNot { it.id in ids })
    }

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun read(context: Context): List<CapturedItem> {
        val raw = prefs(context).getString(KEY_PENDING, null) ?: return emptyList()
        return try {
            val arr = JSONArray(raw)
            List(arr.length()) { CapturedItem.fromJson(arr.getJSONObject(it)) }
        } catch (_: Exception) {
            emptyList() // Corrupt buffer: start clean instead of crashing the receiver.
        }
    }

    private fun write(context: Context, items: List<CapturedItem>) {
        val arr = JSONArray()
        items.forEach { arr.put(it.toJson()) }
        // commit(), not apply(): a receiver's process can be killed right after onReceive returns.
        prefs(context).edit().putString(KEY_PENDING, arr.toString()).commit()
    }
}

/**
 * Stable ids so the live receiver and the inbox backfill agree on the same message, and so
 * re-posted notifications collapse. Sent to the backend as `external_id`.
 */
object CaptureIds {
    private const val MINUTE_MS = 60_000L

    fun sms(sender: String, body: String, timestampMs: Long): String =
        "sms:" + sha256("sms|${normalize(sender)}|${normalize(body)}|${timestampMs / MINUTE_MS}")

    fun notification(pkg: String, title: String?, text: String, timestampMs: Long): String =
        "ntf:" + sha256("ntf|$pkg|${normalize(title.orEmpty())}|${normalize(text)}|${timestampMs / MINUTE_MS}")

    private fun normalize(s: String) = s.trim().replace(Regex("\\s+"), " ").lowercase()

    private fun sha256(s: String): String =
        MessageDigest.getInstance("SHA-256").digest(s.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }
            .take(32)
}
