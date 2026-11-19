package com.wakemethere.app.tracking

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import com.wakemethere.app.MainActivity

object TrackingNotification {
    const val CHANNEL_ID = "wakemethere_tracking_channel"
    const val ALARM_CHANNEL_ID = "wakemethere_alarm_channel_v2"
    const val NOTIFICATION_ID = 1001
    const val ALARM_NOTIFICATION_ID = 1002
    const val ACTION_ACKNOWLEDGE_ALARM = "com.wakemethere.app.ACTION_ACKNOWLEDGE_ALARM"

    fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "WakeMeThere Journey Tracking"
            val descriptionText = "Persistent notification while tracking travel destination"
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
                setShowBadge(false)
            }
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
            val alarmChannel = NotificationChannel(
                ALARM_CHANNEL_ID,
                "WakeMeThere destination alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Destination proximity and arrival alerts"
                setShowBadge(false)
                // AlarmAudio owns the sound and haptic pattern. A second
                // notification sound/vibration would duplicate the alert.
                setSound(null, null)
                enableVibration(false)
            }
            manager.createNotificationChannel(alarmChannel)
        }
    }

    fun buildAlarmNotification(context: Context, title: String, message: String): Notification {
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            data = android.net.Uri.parse("wakemethere://active/alarm")
        }
        val contentPendingIntent = PendingIntent.getActivity(
            context,
            1,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val acknowledgeIntent = Intent(context, AlarmAcknowledgeReceiver::class.java).apply {
            action = ACTION_ACKNOWLEDGE_ALARM
        }
        val acknowledgePendingIntent = PendingIntent.getBroadcast(
            context,
            2,
            acknowledgeIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, ALARM_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        return builder
            .setContentTitle(title)
            .setContentText(message)
            .setStyle(Notification.BigTextStyle().bigText(message))
            .setSmallIcon(com.wakemethere.app.R.drawable.ic_stat_wakemethere)
            .setCategory(Notification.CATEGORY_ALARM)
            .setPriority(Notification.PRIORITY_MAX)
            .setContentIntent(contentPendingIntent)
            .addAction(
                android.R.drawable.ic_media_pause,
                "I'm awake",
                acknowledgePendingIntent
            )
            .setOngoing(true)
            .build()
    }

    fun buildNotification(
        context: Context,
        destinationName: String = "Destination",
        distanceText: String = "Monitoring location..."
    ): Notification {
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
            data = android.net.Uri.parse("wakemethere://active/active-journey")
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }

        return builder
            .setContentTitle(destinationName)
            .setContentText(distanceText)
            .setSmallIcon(com.wakemethere.app.R.drawable.ic_stat_wakemethere)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }
}
