package xyz.nokarin.aqloss

import android.app.Activity
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

    private const val CHANNEL   = "xyz.nokarin.aqloss/media_controls"
    private const val NOTIF_ID  = 1001
    private const val NOTIF_CH  = "aqloss_playback"

    // Broadcast actions for notification buttons
    private const val ACTION_PLAY     = "xyz.nokarin.aqloss.PLAY"
    private const val ACTION_PAUSE    = "xyz.nokarin.aqloss.PAUSE"
    private const val ACTION_NEXT     = "xyz.nokarin.aqloss.NEXT"
    private const val ACTION_PREVIOUS = "xyz.nokarin.aqloss.PREVIOUS"

    private lateinit var activity: Activity
    private lateinit var methodChannel: MethodChannel
    private var mediaSession: MediaSessionCompat? = null
    private var notifManager: NotificationManager? = null
    private var receiver: BroadcastReceiver? = null

    fun register(activity: Activity, messenger: BinaryMessenger) {
        this.activity = activity
        methodChannel = MethodChannel(messenger, CHANNEL)
        methodChannel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init"   -> { initSession(); result.success(null) }
            "update" -> { update(call); result.success(null) }
            "clear"  -> { clear(); result.success(null) }
            else     -> result.notImplemented()
        }
    }

    // Init
    private fun initSession() {
        if (mediaSession != null) return

        val ctx = activity.applicationContext

        // Notification channel
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                NOTIF_CH, "Playback", NotificationManager.IMPORTANCE_LOW
            ).apply { description = "Music playback controls" }
            notifManager = ctx.getSystemService(NotificationManager::class.java)
            notifManager?.createNotificationChannel(ch)
        } else {
            notifManager = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        }

        // MediaSession
        mediaSession = MediaSessionCompat(ctx, "AqlossMediaSession").apply {
            setCallback(object : MediaSessionCompat.Callback() {
                override fun onPlay()     { methodChannel.invokeMethod("onPlay", null) }
                override fun onPause()    { methodChannel.invokeMethod("onPause", null) }
                override fun onSkipToNext()     { methodChannel.invokeMethod("onNext", null) }
                override fun onSkipToPrevious() { methodChannel.invokeMethod("onPrevious", null) }
                override fun onSeekTo(pos: Long) {
                    methodChannel.invokeMethod("onSeek", pos)
                }
            })
            isActive = true
        }

        // Broadcast receiver
        receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                when (intent.action) {
                    ACTION_PLAY     -> methodChannel.invokeMethod("onPlay", null)
                    ACTION_PAUSE    -> methodChannel.invokeMethod("onPause", null)
                    ACTION_NEXT     -> methodChannel.invokeMethod("onNext", null)
                    ACTION_PREVIOUS -> methodChannel.invokeMethod("onPrevious", null)
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(ACTION_PLAY); addAction(ACTION_PAUSE)
            addAction(ACTION_NEXT); addAction(ACTION_PREVIOUS)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ctx.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            ctx.registerReceiver(receiver, filter)
        }
    }

    // Update
    private fun update(call: MethodCall) {
        val session = mediaSession ?: return
        val ctx = activity.applicationContext

        val title      = call.argument<String>("title")  ?: ""
        val artist     = call.argument<String>("artist") ?: ""
        val album      = call.argument<String>("album")  ?: ""
        val isPlaying  = call.argument<Boolean>("isPlaying") ?: false
        val posMs      = call.argument<Int>("positionMs")?.toLong() ?: 0L
        val durMs      = call.argument<Int>("durationMs")?.toLong() ?: 0L
        val artBytes   = call.argument<ByteArray>("artBytes")

        // Decode album art
        val art: Bitmap? = artBytes?.let {
            BitmapFactory.decodeByteArray(it, 0, it.size)
        }

        // Update MediaSession metadata
        val metaBuilder = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, artist)
            .putString(MediaMetadataCompat.METADATA_KEY_ALBUM, album)
            .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, durMs)
        if (art != null) metaBuilder.putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, art)
        session.setMetadata(metaBuilder.build())

        // Update playback state
        val state = if (isPlaying) PlaybackStateCompat.STATE_PLAYING
                    else           PlaybackStateCompat.STATE_PAUSED
        session.setPlaybackState(
            PlaybackStateCompat.Builder()
                .setState(state, posMs, 1f)
                .setActions(
                    PlaybackStateCompat.ACTION_PLAY or
                    PlaybackStateCompat.ACTION_PAUSE or
                    PlaybackStateCompat.ACTION_PLAY_PAUSE or
                    PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                    PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
                    PlaybackStateCompat.ACTION_SEEK_TO
                )
                .build()
        )

        // Build and post notification
        val notif = buildNotification(ctx, title, artist, album, isPlaying, art, session)
        notifManager?.notify(NOTIF_ID, notif)
    }

    // Notification builder
    private fun buildNotification(
        ctx: Context,
        title: String,
        artist: String,
        album: String,
        isPlaying: Boolean,
        art: Bitmap?,
        session: MediaSessionCompat,
    ): Notification {
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        else PendingIntent.FLAG_UPDATE_CURRENT

        fun actionIntent(action: String) = PendingIntent.getBroadcast(
            ctx, action.hashCode(), Intent(action), flags
        )

        val openIntent = PendingIntent.getActivity(
            ctx, 0,
            ctx.packageManager.getLaunchIntentForPackage(ctx.packageName),
            flags
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
                    .setShowActionsInCompactView(0, 1, 2) // prev, play/pause, next
            )
            .addAction(
                android.R.drawable.ic_media_previous, "Previous",
                actionIntent(ACTION_PREVIOUS)
            )
            .addAction(
                if (isPlaying) android.R.drawable.ic_media_pause
                else android.R.drawable.ic_media_play,
                if (isPlaying) "Pause" else "Play",
                actionIntent(if (isPlaying) ACTION_PAUSE else ACTION_PLAY)
            )
            .addAction(
                android.R.drawable.ic_media_next, "Next",
                actionIntent(ACTION_NEXT)
            )
            .build()
    }

    // Clear
    private fun clear() {
        notifManager?.cancel(NOTIF_ID)
        mediaSession?.setPlaybackState(
            PlaybackStateCompat.Builder()
                .setState(PlaybackStateCompat.STATE_STOPPED, 0, 1f)
                .build()
        )
    }
}