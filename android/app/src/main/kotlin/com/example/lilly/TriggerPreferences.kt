package com.example.lilly

import android.content.Context

class TriggerPreferences(context: Context) {
    private val prefs = context.getSharedPreferences("lilly_trigger_prefs", Context.MODE_PRIVATE)

    fun isAutostartEnabled(): Boolean {
        return prefs.getBoolean(KEY_AUTOSTART_ENABLED, false)
    }

    fun setAutostartEnabled(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_AUTOSTART_ENABLED, enabled).apply()
    }

    companion object {
        private const val KEY_AUTOSTART_ENABLED = "autostart_enabled"
    }
}
