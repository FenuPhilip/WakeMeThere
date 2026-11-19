package com.wakemethere.app.bridge

import android.content.Context
import android.content.Intent
import android.app.Activity
import android.Manifest
import android.os.Build
import android.content.pm.PackageManager
import android.media.RingtoneManager
import android.net.Uri
import android.provider.Settings
import com.wakemethere.app.alarms.AlarmAudio
import com.wakemethere.app.tracking.LocationService
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

object WakeMeThereChannel : MethodChannel.MethodCallHandler {
    private const val TRACKING_CHANNEL = "com.wakemethere.app/tracking"
    private const val ALARM_CHANNEL = "com.wakemethere.app/alarm"

    private var trackingChannel: MethodChannel? = null
    private var alarmChannel: MethodChannel? = null
    private var appContext: Context? = null
    private var activity: Activity? = null
    private var ringtonePickerResult: MethodChannel.Result? = null
    private const val RINGTONE_PICKER_REQUEST = 4312

    fun register(context: Context, messenger: BinaryMessenger) {
        appContext = context.applicationContext
        activity = context as? Activity
        trackingChannel = MethodChannel(messenger, TRACKING_CHANNEL).apply {
            setMethodCallHandler(this@WakeMeThereChannel)
        }
        alarmChannel = MethodChannel(messenger, ALARM_CHANNEL).apply {
            setMethodCallHandler(this@WakeMeThereChannel)
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != RINGTONE_PICKER_REQUEST) return
        val result = ringtonePickerResult ?: return
        ringtonePickerResult = null
        if (resultCode != Activity.RESULT_OK) {
            result.success(null)
            return
        }
        val context = appContext ?: return result.error("NO_CONTEXT", "App context is null", null)
        val uri = data?.getParcelableExtra<Uri>(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
        context.getSharedPreferences("alarm_preferences", Context.MODE_PRIVATE)
            .edit().putString("ringtone_uri", uri?.toString()).apply()
        val title = uri?.let { RingtoneManager.getRingtone(context, it)?.getTitle(context) }
            ?: "Device default alarm"
        result.success(mapOf("title" to title))
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val context = appContext ?: return result.error("NO_CONTEXT", "App context is null", null)

        when (call.method) {
            "startTracking" -> {
                val destLat = call.argument<Double>("destinationLat")
                val destLon = call.argument<Double>("destinationLon")
                if (destLat == null || destLon == null || !destLat.isFinite() || !destLon.isFinite() ||
                    destLat !in -90.0..90.0 || destLon !in -180.0..180.0
                ) return result.error("INVALID_DESTINATION", "Valid destination coordinates are required", null)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
                    context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED
                ) return result.error("LOCATION_PERMISSION", "Precise location permission is required", null)
                val earlyWarning = call.argument<Double>("earlyWarningMeters") ?: 5000.0
                val wakeUp = call.argument<Double>("wakeUpMeters") ?: 2000.0
                val critical = call.argument<Double>("criticalMeters") ?: 500.0

                val serviceIntent = Intent(context, LocationService::class.java).apply {
                    action = LocationService.ACTION_START
                    putExtra("destinationLat", destLat)
                    putExtra("destinationLon", destLon)
                    putExtra("earlyWarningMeters", earlyWarning)
                    putExtra("wakeUpMeters", wakeUp)
                    putExtra("criticalMeters", critical)
                    putExtra("soundEnabled", call.argument<Boolean>("soundEnabled") ?: true)
                    putExtra("voiceEnabled", call.argument<Boolean>("voiceEnabled") ?: true)
                    putExtra("vibrationEnabled", call.argument<Boolean>("vibrationEnabled") ?: true)
                    putExtra("repeatUntilDismissed", call.argument<Boolean>("repeatUntilDismissed") ?: true)
                    putExtra("alarmVolume", (call.argument<Double>("alarmVolume") ?: 0.85).coerceIn(0.0, 1.0))
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
                result.success(true)
            }

            "stopTracking" -> {
                val serviceIntent = Intent(context, LocationService::class.java).apply {
                    action = LocationService.ACTION_STOP
                }
                context.startService(serviceIntent)
                result.success(true)
            }

            "getTrackingStatus" -> {
                val saved = context.getSharedPreferences("active_journey", Context.MODE_PRIVATE)
                result.success(
                    mapOf(
                        "active" to (saved.getBoolean("active", false) && LocationService.isRunning),
                        "destinationReached" to saved.getBoolean("destinationReached", false),
                        "alarmAcknowledged" to saved.getBoolean("alarmAcknowledged", false),
                        "alertStage" to saved.getString("alertStage", ""),
                        "error" to saved.getString("lastError", "")
                    )
                )
            }

            "playAlarm" -> {
                val volume = (call.argument<Double>("volume") ?: 1.0).toFloat()
                AlarmAudio.playAlarm(context, volume)
                result.success(true)
            }

            "pickAlarmRingtone" -> {
                val currentActivity = activity
                    ?: return result.error("NO_ACTIVITY", "Ringtone selection needs an open activity", null)
                if (ringtonePickerResult != null) {
                    return result.error("PICKER_OPEN", "The ringtone picker is already open", null)
                }
                val savedUri = context.getSharedPreferences("alarm_preferences", Context.MODE_PRIVATE)
                    .getString("ringtone_uri", null)?.let(Uri::parse)
                val pickerIntent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
                    putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_ALARM)
                    putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, "Choose alarm sound")
                    putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
                    putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
                    putExtra(
                        RingtoneManager.EXTRA_RINGTONE_EXISTING_URI,
                        savedUri ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                    )
                }
                ringtonePickerResult = result
                try {
                    currentActivity.startActivityForResult(pickerIntent, RINGTONE_PICKER_REQUEST)
                } catch (error: Exception) {
                    ringtonePickerResult = null
                    result.error("PICKER_UNAVAILABLE", error.message, null)
                }
            }

            "getAlarmRingtoneName" -> {
                val savedUri = context.getSharedPreferences("alarm_preferences", Context.MODE_PRIVATE)
                    .getString("ringtone_uri", null)?.let(Uri::parse)
                val title = savedUri?.let { RingtoneManager.getRingtone(context, it)?.getTitle(context) }
                    ?: "Device default alarm"
                result.success(title)
            }

            "clearAlarmRingtone" -> {
                context.getSharedPreferences("alarm_preferences", Context.MODE_PRIVATE)
                    .edit().remove("ringtone_uri").apply()
                result.success(true)
            }

            "openDoNotDisturbSettings" -> {
                try {
                    context.startActivity(
                        Intent(Settings.ACTION_ZEN_MODE_PRIORITY_SETTINGS)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                    result.success(true)
                } catch (error: Exception) {
                    result.error("SETTINGS_UNAVAILABLE", error.message, null)
                }
            }

            "stopAlarm", "dismissAlerts" -> {
                AlarmAudio.stopAlarm()
                result.success(true)
            }

            "acknowledgeAlarm" -> {
                AlarmAudio.stopAlarm()
                context.getSharedPreferences("active_journey", Context.MODE_PRIVATE)
                    .edit().putBoolean("alarmAcknowledged", true).apply()
                (context.getSystemService(Context.NOTIFICATION_SERVICE) as? android.app.NotificationManager)
                    ?.cancel(com.wakemethere.app.tracking.TrackingNotification.ALARM_NOTIFICATION_ID)
                result.success(true)
            }

            "triggerWakeUpAlert" -> {
                AlarmAudio.playAlarm(context, 0.9f)
                AlarmAudio.vibrate(context, longArrayOf(0, 500, 200, 500))
                val destName = call.argument<String>("destinationName") ?: "your destination"
                AlarmAudio.speak("Wake up. Approaching $destName.")
                result.success(true)
            }

            "triggerCriticalAlert" -> {
                AlarmAudio.playAlarm(context, 1.0f)
                AlarmAudio.vibrate(context, longArrayOf(0, 800, 300, 800))
                val destName = call.argument<String>("destinationName") ?: "your destination"
                AlarmAudio.speak("Critical alert: arriving at $destName now.")
                result.success(true)
            }

            else -> result.notImplemented()
        }
    }

    fun sendLocationUpdate(
        latitude: Double,
        longitude: Double,
        accuracy: Double,
        speed: Double?,
        distanceMeters: Double,
        timestampMs: Long = System.currentTimeMillis()
    ) {
        val payload = mapOf(
            "latitude" to latitude,
            "longitude" to longitude,
            "accuracy" to accuracy,
            "speed" to speed,
            "distanceMeters" to distanceMeters,
            "timestampMs" to timestampMs
        )
        trackingChannel?.invokeMethod("onLocationUpdate", payload)
    }

    fun sendTrackingError(message: String) {
        trackingChannel?.invokeMethod("onTrackingError", message)
    }

    fun sendAlarmAcknowledged() {
        trackingChannel?.invokeMethod("onAlarmAcknowledged", null)
    }
}
