package com.example.lilly

import android.app.ActivityOptions
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import kotlin.concurrent.thread

private const val TAG = "LillyTriggerService"

class LillyTriggerService : Service() {
    companion object {
        const val ACTION_PAUSE_FOR_VOICE_CHAT = "com.example.lilly.action.PAUSE_FOR_VOICE_CHAT"
        const val ACTION_RESUME_AFTER_VOICE_CHAT = "com.example.lilly.action.RESUME_AFTER_VOICE_CHAT"

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

    @Volatile
    private var pausedForVoiceChat = false

    @Volatile
    private var shouldRestartOnDestroy = true

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
        shouldRestartOnDestroy = true

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

        when (intent?.action) {
            ACTION_PAUSE_FOR_VOICE_CHAT -> pauseWakeWordForVoiceChat()
            ACTION_RESUME_AFTER_VOICE_CHAT -> resumeWakeWordAfterVoiceChat()
            else -> {
                if (pausedForVoiceChat) {
                    updateStatus("Voice chat active. Wake word paused.")
                } else {
                    startWakeWordLoopIfNeeded()
                }
            }
        }

        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        if (shouldRestartService()) {
            scheduleRestart()
        }
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        serviceActive = false
        stopWakeWordLoop()
        isRunning = false

        if (shouldRestartService()) {
            scheduleRestart()
        }

        super.onDestroy()
    }

    private fun startWakeWordLoopIfNeeded() {
        if (pausedForVoiceChat) {
            updateStatus("Voice chat active. Wake word paused.")
            return
        }

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

                if (!serviceActive || pausedForVoiceChat) return@thread

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
            } finally {
                initThread = null
            }
        }
    }

    private fun stopWakeWordLoop() {
        initThread?.interrupt()
        initThread = null
        detector?.stop()
        detector = null
    }

    private fun pauseWakeWordForVoiceChat() {
        pausedForVoiceChat = true
        stopWakeWordLoop()
        cancelWakeAlert()
        updateStatus("Voice chat active. Wake word paused.")
    }

    private fun resumeWakeWordAfterVoiceChat() {
        cancelWakeAlert()
        pausedForVoiceChat = false
        if (!serviceActive) return

        updateStatus("Resuming wake word...")
        startWakeWordLoopIfNeeded()
    }

    private fun shouldRestartService(): Boolean {
        val preferences = TriggerPreferences(this)
        return shouldRestartOnDestroy && preferences.isAutostartEnabled() && !pausedForVoiceChat
    }

    private fun handleWakeWordDetected() {
        pauseWakeWordForVoiceChat()
        updateStatus("Opening Lilly voice chat...")
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
                updateStatus("Opening blocked by Android. Using priority launch.")
            }
        }
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
            .setContentText("Opening voice chat...")
            .setContentIntent(buildVoiceChatPendingIntent())
            .setFullScreenIntent(buildVoiceChatPendingIntent(), true)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .addAction(0, "Open Voice Chat", buildVoiceChatPendingIntent())
            .build()
    }

    private fun showWakeAlert() {
        val manager = getSystemService(NotificationManager::class.java)
        manager?.notify(ALERT_NOTIFICATION_ID, buildWakeAlertNotification())
    }

    private fun cancelWakeAlert() {
        val manager = getSystemService(NotificationManager::class.java)
        manager?.cancel(ALERT_NOTIFICATION_ID)
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

        return buildActivityPendingIntent(
            requestCode = 10,
            intent = openAppIntent,
        )
    }

    private fun buildVoiceChatPendingIntent(): PendingIntent {
        return buildActivityPendingIntent(
            requestCode = 11,
            intent = buildVoiceChatIntent(),
        )
    }

    private fun buildVoiceChatIntent(): Intent {
        return Intent(this, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP,
            )
            putExtra("open_voice_chat", true)
        }
    }

    private fun buildActivityPendingIntent(
        requestCode: Int,
        intent: Intent,
    ): PendingIntent {
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val options = creatorBackgroundActivityOptions()

        return if (options != null) {
            PendingIntent.getActivity(this, requestCode, intent, flags, options)
        } else {
            PendingIntent.getActivity(this, requestCode, intent, flags)
        }
    }

    private fun creatorBackgroundActivityOptions(): Bundle? {
        if (Build.VERSION.SDK_INT < 34) return null

        return ActivityOptions.makeBasic()
            .setPendingIntentCreatorBackgroundActivityStartMode(
                backgroundActivityStartMode(),
            )
            .toBundle()
    }

    private fun senderBackgroundActivityOptions(): Bundle? {
        if (Build.VERSION.SDK_INT < 34) return null

        return ActivityOptions.makeBasic()
            .setPendingIntentBackgroundActivityStartMode(
                backgroundActivityStartMode(),
            )
            .toBundle()
    }

    @Suppress("DEPRECATION")
    private fun backgroundActivityStartMode(): Int {
        return if (Build.VERSION.SDK_INT >= 36) {
            ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOW_ALWAYS
        } else {
            ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED
        }
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
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            description = "Wake word detected alerts"
        }

        manager.createNotificationChannel(statusChannel)
        manager.createNotificationChannel(alertChannel)
    }
}
