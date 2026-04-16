package com.example.lilly

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.VolumeProvider
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat

class LillyTriggerService : Service() {
    companion object {
        private const val CHANNEL_ID = "lilly_trigger_channel"
        private const val CHANNEL_NAME = "Lilly Trigger Service"
        private const val NOTIFICATION_ID = 4107

        private const val RESTART_ACTION = "com.example.lilly.action.RESTART_TRIGGER_SERVICE"
        private const val OPEN_APP_ACTION = "com.example.lilly.action.OPEN_APP"

        private const val LONG_PRESS_WINDOW_MS = 900L
        private const val LONG_PRESS_MIN_STEPS = 3

        @Volatile
        var isRunning: Boolean = false
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    private var mediaSession: MediaSession? = null
    private var volumeProvider: VolumeProvider? = null

    private var triggerPressCount = 0
    private var lastTriggerPressAt = 0L
    private var lastDirection = 0
    private var lastLaunchAt = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        setupMediaSession()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == OPEN_APP_ACTION) {
            openApp()
            return START_STICKY
        }

        isRunning = true
        val notification = buildNotification()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        activateMediaSession()
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        scheduleRestart()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        isRunning = false
        deactivateMediaSession()

        val preferences = TriggerPreferences(this)
        if (preferences.isAutostartEnabled()) {
            scheduleRestart()
        }

        super.onDestroy()
    }

    private fun setupMediaSession() {
        val provider = object : VolumeProvider(
            VOLUME_CONTROL_RELATIVE,
            100,
            50,
        ) {
            override fun onAdjustVolume(direction: Int) {
                handleVolumeAdjust(direction)
            }
        }

        val session = MediaSession(this, "LillyTriggerMediaSession")
        session.setPlaybackToRemote(provider)
        session.setPlaybackState(
            PlaybackState.Builder()
                .setActions(
                    PlaybackState.ACTION_PLAY or
                        PlaybackState.ACTION_PAUSE or
                        PlaybackState.ACTION_PLAY_PAUSE,
                )
                .setState(
                    PlaybackState.STATE_PLAYING,
                    PlaybackState.PLAYBACK_POSITION_UNKNOWN,
                    1.0f,
                )
                .build(),
        )
        session.setCallback(
            object : MediaSession.Callback() {},
            mainHandler,
        )

        volumeProvider = provider
        mediaSession = session
    }

    private fun activateMediaSession() {
        mediaSession?.setFlags(
            MediaSession.FLAG_HANDLES_MEDIA_BUTTONS or
                MediaSession.FLAG_HANDLES_TRANSPORT_CONTROLS,
        )
        mediaSession?.isActive = true
    }

    private fun deactivateMediaSession() {
        mediaSession?.isActive = false
        mediaSession?.release()
        mediaSession = null
        volumeProvider = null
    }

    private fun handleVolumeAdjust(direction: Int) {
        if (direction == 0) return

        val now = System.currentTimeMillis()
        val isSameDirection = direction == lastDirection
        val withinWindow = now - lastTriggerPressAt <= LONG_PRESS_WINDOW_MS

        triggerPressCount = if (isSameDirection && withinWindow) {
            triggerPressCount + 1
        } else {
            1
        }

        lastDirection = direction
        lastTriggerPressAt = now

        if (direction > 0 && triggerPressCount >= LONG_PRESS_MIN_STEPS) {
            triggerPressCount = 0
            if (now - lastLaunchAt > 2500L) {
                lastLaunchAt = now
                openApp()
            }
        }
    }

    private fun openApp() {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP,
            )
            putExtra("open_voice_chat", true)
        }
        startActivity(launchIntent)
    }

    private fun scheduleRestart() {
        val restartIntent = Intent(this, TriggerRestartReceiver::class.java).apply {
            action = RESTART_ACTION
        }

        val pendingIntent = PendingIntent.getBroadcast(
            this,
            2,
            restartIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val alarmManager = getSystemService(AlarmManager::class.java)
        val triggerAtMillis = System.currentTimeMillis() + 1500L

        alarmManager?.setAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            triggerAtMillis,
            pendingIntent,
        )
    }

    private fun buildNotification(): Notification {
        val openAppIntent = Intent(this, LillyTriggerService::class.java).apply {
            action = OPEN_APP_ACTION
        }
        val openAppPendingIntent = PendingIntent.getService(
            this,
            10,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val activityIntent = Intent(this, MainActivity::class.java)
        val activityPendingIntent = PendingIntent.getActivity(
            this,
            0,
            activityIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Lilly assistant standby")
            .setContentText("Volume-up long press trigger is active. Model stays unloaded until needed.")
            .setContentIntent(activityPendingIntent)
            .addAction(
                0,
                "Open Lilly",
                openAppPendingIntent,
            )
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_LOW,
        )
        manager.createNotificationChannel(channel)
    }
}
