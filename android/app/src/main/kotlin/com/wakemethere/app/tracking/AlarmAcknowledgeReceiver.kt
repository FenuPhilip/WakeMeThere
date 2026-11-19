package com.wakemethere.app.tracking

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.app.NotificationManager
import com.wakemethere.app.alarms.AlarmAudio
import com.wakemethere.app.bridge.WakeMeThereChannel

class AlarmAcknowledgeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != TrackingNotification.ACTION_ACKNOWLEDGE_ALARM) return
        AlarmAudio.stopAlarm()
        context.getSharedPreferences("active_journey", Context.MODE_PRIVATE)
            .edit().putBoolean("alarmAcknowledged", true).apply()
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager)
            ?.cancel(TrackingNotification.ALARM_NOTIFICATION_ID)
        WakeMeThereChannel.sendAlarmAcknowledged()
    }
}
