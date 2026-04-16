package com.example.lilly

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

class TriggerRestartReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val preferences = TriggerPreferences(context)
        if (!preferences.isAutostartEnabled()) return

        val serviceIntent = Intent(context, LillyTriggerService::class.java)
        ContextCompat.startForegroundService(context, serviceIntent)
    }
}
