package com.wakemethere.app.tracking

import android.annotation.SuppressLint
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.os.SystemClock
import com.wakemethere.app.alarms.AlarmAudio
import com.wakemethere.app.bridge.WakeMeThereChannel
import kotlin.math.*

class LocationService : Service(), LocationListener {

    companion object {
        const val ACTION_START = "com.wakemethere.app.ACTION_START"
        const val ACTION_STOP = "com.wakemethere.app.ACTION_STOP"

        var isRunning = false
            private set
    }

    private var locationManager: LocationManager? = null
    private var destinationLat: Double = 0.0
    private var destinationLon: Double = 0.0
    private var earlyWarningMeters: Double = 5000.0
    private var wakeUpMeters: Double = 2000.0
    private var criticalMeters: Double = 500.0

    private var hasFiredEarly = false
    private var hasFiredWake = false
    private var hasFiredCritical = false
    private var insideCriticalCount = 0
    private var insideWakeCount = 0
    private var insideEarlyCount = 0
    private var arrivalCount = 0
    private var lastEvaluatedLocationTime = Long.MIN_VALUE
    private var currentIntervalMs = 60_000L
    private var soundEnabled = true
    private var voiceEnabled = true
    private var vibrationEnabled = true
    private var repeatUntilDismissed = true
    private var alarmVolume = 0.85f
    private var destinationName = "your destination"

    override fun onCreate() {
        super.onCreate()
        TrackingNotification.createNotificationChannel(this)
        AlarmAudio.initTts(this)
        locationManager = getSystemService(Context.LOCATION_SERVICE) as? LocationManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: ACTION_START

        if (action == ACTION_STOP) {
            stopTracking()
            AlarmAudio.stopAlarm()
            (getSystemService(Context.NOTIFICATION_SERVICE) as? android.app.NotificationManager)
                ?.cancel(TrackingNotification.ALARM_NOTIFICATION_ID)
            getSharedPreferences("active_journey", Context.MODE_PRIVATE)
                .edit().putBoolean("active", false).apply()
            stopSelf()
            return START_NOT_STICKY
        }

        val saved = getSharedPreferences("active_journey", Context.MODE_PRIVATE)
        saved.edit().putBoolean("active", false).apply()
        if (intent?.hasExtra("destinationLat") == true && intent.hasExtra("destinationLon")) {
            destinationLat = intent.getDoubleExtra("destinationLat", Double.NaN)
            destinationLon = intent.getDoubleExtra("destinationLon", Double.NaN)
            earlyWarningMeters = intent.getDoubleExtra("earlyWarningMeters", 5000.0)
            wakeUpMeters = intent.getDoubleExtra("wakeUpMeters", 2000.0)
            criticalMeters = intent.getDoubleExtra("criticalMeters", 500.0)
            destinationName = intent.getStringExtra("destinationName")?.takeIf { it.isNotBlank() }
                ?: "your destination"
            soundEnabled = intent.getBooleanExtra("soundEnabled", true)
            voiceEnabled = intent.getBooleanExtra("voiceEnabled", true)
            vibrationEnabled = intent.getBooleanExtra("vibrationEnabled", true)
            repeatUntilDismissed = intent.getBooleanExtra("repeatUntilDismissed", true)
            alarmVolume = intent.getDoubleExtra("alarmVolume", 0.85).toFloat().coerceIn(0f, 1f)
            saved.edit()
                .putBoolean("active", false)
                .putBoolean("destinationReached", false)
                .putString("lastError", "")
                .putString("destinationLat", destinationLat.toString())
                .putString("destinationLon", destinationLon.toString())
                .putString("earlyWarningMeters", earlyWarningMeters.toString())
                .putString("wakeUpMeters", wakeUpMeters.toString())
                .putString("criticalMeters", criticalMeters.toString())
                .putString("destinationName", destinationName)
                .putBoolean("soundEnabled", soundEnabled)
                .putBoolean("voiceEnabled", voiceEnabled)
                .putBoolean("vibrationEnabled", vibrationEnabled)
                .putBoolean("repeatUntilDismissed", repeatUntilDismissed)
                .putFloat("alarmVolume", alarmVolume)
                .putBoolean("firedEarly", false)
                .putBoolean("firedWake", false)
                .putBoolean("firedCritical", false)
                .putBoolean("alarmAcknowledged", false)
                .putString("alertStage", "")
                .apply()
            hasFiredEarly = false
            hasFiredWake = false
            hasFiredCritical = false
        } else if (saved.getBoolean("active", false)) {
            destinationLat = saved.getString("destinationLat", null)?.toDoubleOrNull() ?: Double.NaN
            destinationLon = saved.getString("destinationLon", null)?.toDoubleOrNull() ?: Double.NaN
            earlyWarningMeters = saved.getString("earlyWarningMeters", null)?.toDoubleOrNull() ?: 5000.0
            wakeUpMeters = saved.getString("wakeUpMeters", null)?.toDoubleOrNull() ?: 2000.0
            criticalMeters = saved.getString("criticalMeters", null)?.toDoubleOrNull() ?: 500.0
            destinationName = saved.getString("destinationName", null) ?: "your destination"
            soundEnabled = saved.getBoolean("soundEnabled", true)
            voiceEnabled = saved.getBoolean("voiceEnabled", true)
            vibrationEnabled = saved.getBoolean("vibrationEnabled", true)
            repeatUntilDismissed = saved.getBoolean("repeatUntilDismissed", true)
            alarmVolume = saved.getFloat("alarmVolume", 0.85f).coerceIn(0f, 1f)
            hasFiredEarly = saved.getBoolean("firedEarly", false)
            hasFiredWake = saved.getBoolean("firedWake", false)
            hasFiredCritical = saved.getBoolean("firedCritical", false)
        } else {
            stopSelf()
            return START_NOT_STICKY
        }

        if (!destinationLat.isFinite() || destinationLat !in -90.0..90.0 ||
            !destinationLon.isFinite() || destinationLon !in -180.0..180.0 ||
            criticalMeters <= 0 || wakeUpMeters <= criticalMeters || earlyWarningMeters <= wakeUpMeters
        ) {
            stopSelf()
            return START_NOT_STICKY
        }

        insideCriticalCount = 0
        insideWakeCount = 0
        insideEarlyCount = 0
        arrivalCount = 0

        startForegroundServiceInternal()
        if (!requestLocationUpdatesInternal()) return START_NOT_STICKY
        saved.edit().putBoolean("active", true).apply()
        isRunning = true

        return START_STICKY
    }

    private fun startForegroundServiceInternal() {
        val notification = TrackingNotification.buildNotification(
            this,
            "Journey in progress",
            "On the way to $destinationName"
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                TrackingNotification.NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
            )
        } else {
            startForeground(TrackingNotification.NOTIFICATION_ID, notification)
        }
    }

    @SuppressLint("MissingPermission")
    private fun requestLocationUpdatesInternal(): Boolean {
        try {
            val minDistanceM = 5f
            var registered = false

            if (locationManager?.isProviderEnabled(LocationManager.GPS_PROVIDER) == true) {
                locationManager?.requestLocationUpdates(
                    LocationManager.GPS_PROVIDER,
                    currentIntervalMs,
                    minDistanceM,
                    this
                )
                registered = true
            }

            if (locationManager?.isProviderEnabled(LocationManager.NETWORK_PROVIDER) == true) {
                locationManager?.requestLocationUpdates(
                    LocationManager.NETWORK_PROVIDER,
                    currentIntervalMs,
                    minDistanceM,
                    this
                )
                registered = true
            }
            if (!registered) throw IllegalStateException("No location provider is available. Turn on Location Services and try again.")
            return true
        } catch (e: Exception) {
            val message = e.message ?: "Location updates could not be started. Check location permission and device settings."
            isRunning = false
            getSharedPreferences("active_journey", Context.MODE_PRIVATE)
                .edit().putBoolean("active", false).putBoolean("destinationReached", false)
                .putString("lastError", message).apply()
            try {
                locationManager?.removeUpdates(this)
            } catch (_: Exception) {
                // Continue stopping the service even if Android has already removed the listener.
            }
            TrackingNotification.buildNotification(this, "Tracking stopped", message).also { notification ->
                val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? android.app.NotificationManager
                manager?.notify(TrackingNotification.NOTIFICATION_ID, notification)
            }
            WakeMeThereChannel.sendTrackingError(message)
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return false
        }
    }

    override fun onLocationChanged(location: Location) {
        val ageMs = (SystemClock.elapsedRealtimeNanos() - location.elapsedRealtimeNanos) / 1_000_000
        if (!location.latitude.isFinite() || !location.longitude.isFinite() ||
            location.latitude !in -90.0..90.0 || location.longitude !in -180.0..180.0 ||
            !location.accuracy.isFinite() || location.accuracy > 100f || ageMs !in 0..30_000
        ) return
        if (location.time <= lastEvaluatedLocationTime) return
        lastEvaluatedLocationTime = location.time

        val distance = computeHaversineMeters(
            location.latitude,
            location.longitude,
            destinationLat,
            destinationLon
        )
        updateLocationFrequency(distance)

        insideEarlyCount = if (distance <= earlyWarningMeters) insideEarlyCount + 1 else 0
        insideWakeCount = if (distance <= wakeUpMeters) insideWakeCount + 1 else 0
        insideCriticalCount = if (distance <= criticalMeters) insideCriticalCount + 1 else 0
        arrivalCount = if (distance <= 100.0 && location.accuracy <= 35f) arrivalCount + 1 else 0

        // Require two trustworthy fixes before any stage can sound.
        if (arrivalCount >= 2) {
            WakeMeThereChannel.sendLocationUpdate(
                latitude = location.latitude,
                longitude = location.longitude,
                accuracy = location.accuracy.toDouble(),
                speed = if (location.hasSpeed()) location.speed.toDouble() else null,
                distanceMeters = distance,
                timestampMs = location.time
            )
            stopTracking()
            getSharedPreferences("active_journey", Context.MODE_PRIVATE)
                .edit().putBoolean("active", false).putBoolean("destinationReached", true)
                .putString("alertStage", "arrived").putBoolean("alarmAcknowledged", false).apply()
            stopSelf()
            if (soundEnabled) AlarmAudio.playAlarm(this, alarmVolume, repeatUntilDismissed)
            if (vibrationEnabled) AlarmAudio.vibrate(this, longArrayOf(0, 800, 300, 800, 300, 800))
            if (voiceEnabled) AlarmAudio.speak("You have arrived at your destination.")
            postAlarmNotification("You have arrived", "Acknowledge when you are ready to continue.")
            return
        } else if (insideCriticalCount >= 2 && !hasFiredCritical) {
            hasFiredCritical = true
            getSharedPreferences("active_journey", Context.MODE_PRIVATE)
                .edit().putBoolean("firedCritical", true).putString("alertStage", "critical").apply()
            if (soundEnabled) AlarmAudio.playAlarm(this, alarmVolume, repeatUntilDismissed)
            if (vibrationEnabled) AlarmAudio.vibrate(this, longArrayOf(0, 800, 300, 800, 300, 800))
            if (voiceEnabled) AlarmAudio.speak("Critical alert: your destination stop is approaching now.")
            postAlarmNotification("Your stop is very close", "You're approaching $destinationName.")
        } else if (insideWakeCount >= 2 && !hasFiredWake) {
            hasFiredWake = true
            getSharedPreferences("active_journey", Context.MODE_PRIVATE)
                .edit().putBoolean("firedWake", true).putString("alertStage", "wake").apply()
            if (soundEnabled) AlarmAudio.playAlarm(this, alarmVolume, repeatUntilDismissed)
            if (vibrationEnabled) AlarmAudio.vibrate(this, longArrayOf(0, 500, 200, 500))
            if (voiceEnabled) AlarmAudio.speak("Wake up. You are approaching your destination.")
            postAlarmNotification("Your stop is approaching", "You're getting closer to $destinationName.")
        } else if (insideEarlyCount >= 2 && !hasFiredEarly) {
            hasFiredEarly = true
            getSharedPreferences("active_journey", Context.MODE_PRIVATE)
                .edit().putBoolean("firedEarly", true).putString("alertStage", "early").apply()
            if (vibrationEnabled) AlarmAudio.vibrate(this, longArrayOf(0, 300, 200, 300))
            if (voiceEnabled) AlarmAudio.speak("Early warning: prepare your belongings.")
            postAlarmNotification("Get ready to leave", "$destinationName is coming up.")
        }

        // Update notification text
        val kmText = String.format("%.1f km to %s", distance / 1000.0, destinationName)
        val notification = TrackingNotification.buildNotification(this, "Journey in progress", kmText)
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? android.app.NotificationManager
        manager?.notify(TrackingNotification.NOTIFICATION_ID, notification)

        // Send location update to Flutter
        WakeMeThereChannel.sendLocationUpdate(
            latitude = location.latitude,
            longitude = location.longitude,
            accuracy = location.accuracy.toDouble(),
            speed = if (location.hasSpeed()) location.speed.toDouble() else null,
            distanceMeters = distance,
            timestampMs = location.time
        )
    }

    private fun computeHaversineMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val r = 6371000.0
        val dLat = Math.toRadians(lat2 - lat1)
        val dLon = Math.toRadians(lon2 - lon1)
        val a = sin(dLat / 2).pow(2) + cos(Math.toRadians(lat1)) * cos(Math.toRadians(lat2)) * sin(dLon / 2).pow(2)
        val c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return r * c
    }

    @SuppressLint("MissingPermission")
    private fun updateLocationFrequency(distanceMeters: Double) {
        val nextInterval = when {
            distanceMeters <= 5000 -> 5_000L
            distanceMeters <= 15000 -> 20_000L
            else -> 60_000L
        }
        if (nextInterval == currentIntervalMs) return
        currentIntervalMs = nextInterval
        try {
            locationManager?.removeUpdates(this)
            if (!requestLocationUpdatesInternal()) return
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun stopTracking() {
        isRunning = false
        try {
            locationManager?.removeUpdates(this)
        } catch (e: Exception) {
            e.printStackTrace()
        }
        stopForeground(STOP_FOREGROUND_REMOVE)
    }

    private fun postAlarmNotification(title: String, message: String) {
        getSharedPreferences("active_journey", Context.MODE_PRIVATE)
            .edit().putBoolean("alarmAcknowledged", false).apply()
        val notification = TrackingNotification.buildAlarmNotification(this, title, message)
        (getSystemService(Context.NOTIFICATION_SERVICE) as? android.app.NotificationManager)
            ?.notify(TrackingNotification.ALARM_NOTIFICATION_ID, notification)
    }

    override fun onDestroy() {
        stopTracking()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
    override fun onProviderEnabled(provider: String) {}
    override fun onProviderDisabled(provider: String) {}
}
