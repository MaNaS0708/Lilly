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
import androidx.core.app.NotificationCompat

class LillyTriggerService : Service() {
    companion object {
        private const val CHANNEL_ID = "lilly_trigger_channel"
        private const val CHANNEL_NAME = "Lilly Trigger Service"
        private const val NOTIFICATION_ID = 4107

        private const val RESTART_ACTION = "com.example.lilly.action.RESTART_TRIGGER_SERVICE"
        private const val OPEN_APP_ACTION = "com.example.lilly.action.OPEN_APP"
        private const val START_VOICE_CHAT_ACTION = "com.example.lilly.action.START_VOICE_CHAT"

        @Volatile
        var isRunning: Boolean = false
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            OPEN_APP_ACTION -> {
                openApp(openVoiceChat = false)
                return START_STICKY
            }

            START_VOICE_CHAT_ACTION -> {
                openApp(openVoiceChat = true)
                return START_STICKY
            }
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

        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        scheduleRestart()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        isRunning = false
        val preferences = TriggerPreferences(this)
        if (preferences.isAutostartEnabled()) {
            scheduleRestart()
        }
        super.onDestroy()
    }

    private fun openApp(openVoiceChat: Boolean) {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP,
            )
            putExtra("open_voice_chat", openVoiceChat)
            putExtra("open_app_only", !openVoiceChat)
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

        val voiceChatIntent = Intent(this, LillyTriggerService::class.java).apply {
            action = START_VOICE_CHAT_ACTION
        }
        val voiceChatPendingIntent = PendingIntent.getService(
            this,
            11,
            voiceChatIntent,
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
            .setContentText("Notification trigger is active. Model stays unloaded until needed.")
            .setContentIntent(activityPendingIntent)
            .addAction(0, "Open Lilly", openAppPendingIntent)
            .addAction(0, "Start Voice Chat", voiceChatPendingIntent)
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
