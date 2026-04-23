package com.example.lilly

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import android.app.ActivityOptions



private const val TAG = "LillyTriggerService"

class LillyTriggerService : Service() {
    companion object {
        private const val CHANNEL_ID = "lilly_trigger_channel"
        private const val CHANNEL_NAME = "Lilly Trigger Service"
        private const val NOTIFICATION_ID = 4107
        private const val RESTART_ACTION = "com.example.lilly.action.RESTART_TRIGGER_SERVICE"

        @Volatile
        var isRunning: Boolean = false
    }

    @Volatile
    private var currentStatusText: String = "Preparing wake word..."

    @Volatile
    private var serviceActive = false

    private var initThread: Thread? = null
    private var detector: WakeWordDetector? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        isRunning = true
        serviceActive = true

        val notification = buildNotification(currentStatusText)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        startWakeWordLoopIfNeeded()
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        scheduleRestart()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        serviceActive = false
        detector?.stop()
        detector = null
        isRunning = false

        val preferences = TriggerPreferences(this)
        if (preferences.isAutostartEnabled()) {
            scheduleRestart()
        }

        super.onDestroy()
    }

    private fun startWakeWordLoopIfNeeded() {
        if (detector != null || initThread?.isAlive == true) return

        initThread = kotlin.concurrent.thread(
            start = true,
            isDaemon = true,
            name = "lilly-trigger-init",
        ) {
            try {
                val modelManager = WakeWordModelManager(applicationContext)
                modelManager.ensureInstalled { status ->
                    updateStatus(status)
                }

                if (!serviceActive) return@thread

                detector = WakeWordDetector(
                    context = applicationContext,
                    onKeywordDetected = { _ ->
                        handleWakeWordDetected()
                    },
                    onStatusChanged = { status ->
                        updateStatus(status)
                    },
                )
                detector!!.start()
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start wake word detector", e)
                updateStatus("Wake word unavailable. Tap to open Lilly.")
            }
        }
    }

    private fun handleWakeWordDetected() {
        updateStatus("Opening voice chat...")

        try {
            val pendingIntent = buildVoiceChatPendingIntent()

            if (Build.VERSION.SDK_INT >= 34) {
                val sendOptions = ActivityOptions.makeBasic().apply {
                    setPendingIntentBackgroundActivityStartMode(
                        ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED
                    )
                }.toBundle()

                pendingIntent.send(
                    this,
                    0,
                    null,
                    null,
                    null,
                    null,
                    sendOptions,
                )
            } else {
                pendingIntent.send()
            }
        } catch (e: PendingIntent.CanceledException) {
            Log.e(TAG, "Failed to open voice chat", e)
        }

        updateStatus("Listening for \"${WakeWordConstants.wakePhraseLabel}\"")
    }


    private fun buildNotification(contentText: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Lilly assistant standby")
            .setContentText(contentText)
            .setContentIntent(buildOpenAppPendingIntent())
            .addAction(0, "Open Lilly", buildOpenAppPendingIntent())
            .addAction(0, "Start Voice Chat", buildVoiceChatPendingIntent())
            .setOngoing(true)
            .setSilent(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun buildOpenAppPendingIntent(): PendingIntent {
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP,
            )
            putExtra("open_app_only", true)
        }

        return PendingIntent.getActivity(
            this,
            10,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

        private fun buildVoiceChatPendingIntent(): PendingIntent {
        val voiceChatIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP,
            )
            putExtra("open_voice_chat", true)
        }

        val options = if (Build.VERSION.SDK_INT >= 34) {
            ActivityOptions.makeBasic().apply {
                setPendingIntentCreatorBackgroundActivityStartMode(
                    ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED
                )
            }.toBundle()
        } else {
            null
        }

        return PendingIntent.getActivity(
            this,
            11,
            voiceChatIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            options,
        )
    }


    private fun updateStatus(text: String) {
        currentStatusText = text
        val manager = getSystemService(NotificationManager::class.java)
        manager?.notify(NOTIFICATION_ID, buildNotification(text))
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
