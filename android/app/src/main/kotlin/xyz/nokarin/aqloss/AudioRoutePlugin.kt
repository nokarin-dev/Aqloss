package xyz.nokarin.aqloss

import android.content.Context
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel

object AudioRoutePlugin {
    private const val CHANNEL = "xyz.nokarin.aqloss/audio_route"

    private var sink: EventChannel.EventSink? = null
    private var registered = false

    fun register(context: Context, messenger: BinaryMessenger) {
        if (registered) return
        registered = true

        EventChannel(messenger, CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    sink = events
                }

                override fun onCancel(arguments: Any?) {
                    sink = null
                }
            },
        )

        val audioManager =
            context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val handler = Handler(Looper.getMainLooper())
        val notify = Runnable { sink?.success(null) }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            audioManager.registerAudioDeviceCallback(
                object : AudioDeviceCallback() {
                    override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>) {
                        handler.removeCallbacks(notify)
                        handler.postDelayed(notify, 500)
                    }

                    override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>) {
                        handler.removeCallbacks(notify)
                        handler.postDelayed(notify, 500)
                    }
                },
                handler,
            )
        }
    }
}
