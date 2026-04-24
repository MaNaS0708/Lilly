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
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import kotlin.concurrent.thread

private const val TAG = "LillyTriggerService"

class LillyTriggerService : Service() {
    companion object {
        private const val STATUS_CHANNEL_ID = "lilly_trigger_status_channel"
        private const val ALERT_CHANNEL_ID = "lilly_trigger_alert_channel"
        private const val STATUS_CHANNEL_NAME = "Lilly Trigger Status"
        private const val ALERT_CHANNEL_NAME = "Lilly Trigger Alerts"
        private const val STATUS_NOTIFICATION_ID = 4107
        private const val ALERT_NOTIFICATION_ID = 4108
        private const val RESTART_ACTION = "com.example.lilly.action.RESTART_TRIGGER_SERVICE"

        @Volatile
        var isRunning: Boolean = false
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var currentStatusText: String = "Preparing wake word..."

    @Volatile
    private var serviceActive = false

    private var initThread: Thread? = null
    private var detector: WakeWordDetector? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        isRunning = true
        serviceActive = true

        val notification = buildStatusNotification(currentStatusText)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                STATUS_NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
            )
        } else {
            startForeground(STATUS_NOTIFICATION_ID, notification)
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

        initThread = thread(
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
        updateStatus("Wake word heard. Tap to start voice chat.")
        showWakeAlert()

        mainHandler.post {
            try {
                val intent = Intent(this, MainActivity::class.java).apply {
                    addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP,
                    )
                    putExtra("open_voice_chat", true)
                }
                startActivity(intent)
            } catch (e: Exception) {
                Log.w(TAG, "Direct voice chat launch was blocked by Android.", e)
            }
        }

        mainHandler.postDelayed(
            {
                if (serviceActive) {
                    updateStatus("Listening for \"${WakeWordConstants.wakePhraseLabel}\"")
                }
            },
            2500L,
        )
    }

    private fun buildStatusNotification(contentText: String): Notification {
        return NotificationCompat.Builder(this, STATUS_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Lilly assistant standby")
            .setContentText(contentText)
            .setContentIntent(buildVoiceChatPendingIntent())
            .addAction(0, "Open Lilly", buildOpenAppPendingIntent())
            .addAction(0, "Start Voice Chat", buildVoiceChatPendingIntent())
            .setOngoing(true)
            .setSilent(true)
            .setOnlyAlertOnce(false)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun buildWakeAlertNotification(): Notification {
        return NotificationCompat.Builder(this, ALERT_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Hey Lilly heard")
            .setContentText("Tap to start voice chat.")
            .setContentIntent(buildVoiceChatPendingIntent())
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .addAction(0, "Start Voice Chat", buildVoiceChatPendingIntent())
            .build()
    }

    private fun showWakeAlert() {
        val manager = getSystemService(NotificationManager::class.java)
        manager?.notify(ALERT_NOTIFICATION_ID, buildWakeAlertNotification())
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

        return PendingIntent.getActivity(
            this,
            11,
            voiceChatIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun updateStatus(text: String) {
        currentStatusText = text
        val manager = getSystemService(NotificationManager::class.java)
        manager?.notify(STATUS_NOTIFICATION_ID, buildStatusNotification(text))
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

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = getSystemService(NotificationManager::class.java)

        val statusChannel = NotificationChannel(
            STATUS_CHANNEL_ID,
            STATUS_CHANNEL_NAME,
            NotificationManager.IMPORTANCE_LOW,
        )

        val alertChannel = NotificationChannel(
            ALERT_CHANNEL_ID,
            ALERT_CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            enableVibration(true)
            description = "Wake word detected alerts"
        }

        manager.createNotificationChannel(statusChannel)
        manager.createNotificationChannel(alertChannel)
    }
}
