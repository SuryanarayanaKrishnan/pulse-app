package com.pulse.pulse.capture

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Pushes a lightweight "new items buffered" ping to Dart over the EventChannel. The payload itself
 * is read from [CaptureStore], so a ping lost while the app is closed costs nothing: Dart drains
 * the buffer on startup.
 */
object CaptureEvents : EventChannel.StreamHandler {
    private val main = Handler(Looper.getMainLooper())

    @Volatile
    private var sink: EventChannel.EventSink? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    fun notifyPending() {
        main.post { sink?.success("pending") }
    }
}
