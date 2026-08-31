package xyz.nokarin.aqloss

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler

object MediaControlsPlugin : MethodCallHandler {
    const val NOTIF_ID = 1001

    private const val CHANNEL = "xyz.nokarin.aqloss/media_controls"
    private const val NOTIF_CH = "aqloss_playback"
    private const val ACTION_PLAY = "xyz.nokarin.aqloss.PLAY"
    private const val ACTION_PAUSE = "xyz.nokarin.aqloss.PAUSE"
    private const val ACTION_NEXT = "xyz.nokarin.aqloss.NEXT"
    private const val ACTION_PREVIOUS = "xyz.nokarin.aqloss.PREVIOUS"

    private var appContext: Context? = null
    private lateinit var methodChannel: MethodChannel
    private var mediaSession: MediaSessionCompat? = null
    private var notifManager: NotificationManager? = null
    private var receiver: BroadcastReceiver? = null
    private var lastNotification: Notification? = null
    private var serviceStarted = false
    private var title = ""
    private var artist = ""
    private var album = ""
    private var isPlaying = false
    private var posMs = 0L
    private var durMs = 0L
    private var art: Bitmap? = null

    fun register(activity: android.app.Activity, messenger: BinaryMessenger) {
        appContext = activity.applicationContext
        methodChannel = MethodChannel(messenger, CHANNEL)
        methodChannel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> {
                appContext?.let { ensureSession(it) }
                result.success(null)
            }
            "update" -> {
                update(call)
                result.success(null)
            }
            "clear" -> {
                clear()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    fun ensureSession(ctx: Context) {
        if (mediaSession != null) return
        val app = ctx.applicationContext
        appContext = app

        val mgr = app.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notifManager = mgr
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            mgr.createNotificationChannel(
                NotificationChannel(NOTIF_CH, "Playback", NotificationManager.IMPORTANCE_LOW)
                    .apply { description = "Music playback controls" },
            )
        }

        mediaSession = MediaSessionCompat(app, "AqlossMediaSession").apply {
            setCallback(object : MediaSessionCompat.Callback() {
                override fun onPlay() { emit("onPlay") }
                override fun onPause() { emit("onPause") }
                override fun onSkipToNext() { emit("onNext") }
                override fun onSkipToPrevious() { emit("onPrevious") }
                override fun onSeekTo(pos: Long) { emit("onSeek", pos) }
            })
            isActive = true
        }

        receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                when (intent.action) {
                    ACTION_PLAY -> emit("onPlay")
                    ACTION_PAUSE -> emit("onPause")
                    ACTION_NEXT -> emit("onNext")
                    ACTION_PREVIOUS -> emit("onPrevious")
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(ACTION_PLAY)
            addAction(ACTION_PAUSE)
            addAction(ACTION_NEXT)
            addAction(ACTION_PREVIOUS)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            app.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            app.registerReceiver(receiver, filter)
        }
    }

    fun notification(ctx: Context): Notification {
        lastNotification?.let { return it }
        return placeholder(ctx)
    }

    fun onServiceStopped() {
        lastNotification = null
        serviceStarted = false
    }

    private fun update(call: MethodCall) {
        val ctx = appContext ?: return
        ensureSession(ctx)
        val session = mediaSession ?: return

        title = call.argument<String>("title") ?: ""
        artist = call.argument<String>("artist") ?: ""
        album = call.argument<String>("album") ?: ""
        isPlaying = call.argument<Boolean>("isPlaying") ?: false
        posMs = call.argument<Int>("positionMs")?.toLong() ?: 0L
        durMs = call.argument<Int>("durationMs")?.toLong() ?: 0L
        art = decodeArt(call.argument<ByteArray>("artBytes"))

        val meta = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, artist)
            .putString(MediaMetadataCompat.METADATA_KEY_ALBUM, album)
            .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, durMs)
        art?.let { meta.putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, it) }
        session.setMetadata(meta.build())

        val state = if (isPlaying) PlaybackStateCompat.STATE_PLAYING
        else PlaybackStateCompat.STATE_PAUSED
        session.setPlaybackState(
            PlaybackStateCompat.Builder()
                .setState(state, posMs, 1f)
                .setActions(
                    PlaybackStateCompat.ACTION_PLAY or
                        PlaybackStateCompat.ACTION_PAUSE or
                        PlaybackStateCompat.ACTION_PLAY_PAUSE or
                        PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                        PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
                        PlaybackStateCompat.ACTION_SEEK_TO,
                )
                .build(),
        )

        lastNotification = buildNotification(ctx, session)
        if (!serviceStarted) {
            serviceStarted = true
            ContextCompat.startForegroundService(ctx, Intent(ctx, PlaybackService::class.java))
        } else {
            notifManager?.notify(NOTIF_ID, lastNotification)
        }
    }

    private fun clear() {
        val ctx = appContext ?: return
        notifManager?.cancel(NOTIF_ID)
        mediaSession?.setPlaybackState(
            PlaybackStateCompat.Builder()
                .setState(PlaybackStateCompat.STATE_STOPPED, 0, 1f)
                .build(),
        )
        lastNotification = null
        ctx.stopService(Intent(ctx, PlaybackService::class.java))
    }

    private fun emit(method: String, arg: Any? = null) {
        if (::methodChannel.isInitialized) methodChannel.invokeMethod(method, arg)
    }

    private fun decodeArt(bytes: ByteArray?): Bitmap? {
        if (bytes == null || bytes.isEmpty()) return null
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        var sample = 1
        while (bounds.outWidth / sample > 256 || bounds.outHeight / sample > 256) {
            sample *= 2
        }
        return BitmapFactory.decodeByteArray(
            bytes,
            0,
            bytes.size,
            BitmapFactory.Options().apply { inSampleSize = sample },
        )
    }

    private fun placeholder(ctx: Context): Notification {
        ensureChannel(ctx)
        return NotificationCompat.Builder(ctx, NOTIF_CH)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle("Aqloss")
            .setSilent(true)
            .setOngoing(true)
            .build()
    }

    private fun ensureChannel(ctx: Context) {
        if (notifManager == null) {
            notifManager = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            notifManager?.createNotificationChannel(
                NotificationChannel(NOTIF_CH, "Playback", NotificationManager.IMPORTANCE_LOW),
            )
        }
    }

    private fun buildNotification(ctx: Context, session: MediaSessionCompat): Notification {
        val flags = PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT

        fun actionIntent(action: String) = PendingIntent.getBroadcast(
            ctx,
            action.hashCode(),
            Intent(action).setPackage(ctx.packageName),
            flags,
        )

        val openIntent = PendingIntent.getActivity(
            ctx,
            0,
            ctx.packageManager.getLaunchIntentForPackage(ctx.packageName),
            flags,
        )

        return NotificationCompat.Builder(ctx, NOTIF_CH)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle(title)
            .setContentText(artist)
            .setSubText(album.ifEmpty { null })
            .setLargeIcon(art)
            .setContentIntent(openIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(isPlaying)
            .setSilent(true)
            .setStyle(
                androidx.media.app.NotificationCompat.MediaStyle()
                    .setMediaSession(session.sessionToken)
                    .setShowActionsInCompactView(0, 1, 2),
            )
            .addAction(
                android.R.drawable.ic_media_previous,
                "Previous",
                actionIntent(ACTION_PREVIOUS),
            )
            .addAction(
                if (isPlaying) android.R.drawable.ic_media_pause
                else android.R.drawable.ic_media_play,
                if (isPlaying) "Pause" else "Play",
                actionIntent(if (isPlaying) ACTION_PAUSE else ACTION_PLAY),
            )
            .addAction(
                android.R.drawable.ic_media_next,
                "Next",
                actionIntent(ACTION_NEXT),
            )
            .build()
    }
}
