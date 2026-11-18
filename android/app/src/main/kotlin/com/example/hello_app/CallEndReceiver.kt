package com.example.hello_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.TelephonyManager

class CallEndReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        when (action) {
            TelephonyManager.ACTION_PHONE_STATE_CHANGED -> {
                val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE)
                if (state == TelephonyManager.EXTRA_STATE_IDLE) {
                    // Delay 3 seconds so Android OS finishes writing the CallLog row first
                    CallLogSyncWorker.enqueue(context, delaySeconds = 3L)
                }
            }
            Intent.ACTION_BOOT_COMPLETED -> {
                CallLogSyncWorker.enqueue(context, delaySeconds = 15L)
            }
        }
    }
}
