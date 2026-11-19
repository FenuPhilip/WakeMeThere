package com.wakemethere.app.alarms

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.speech.tts.TextToSpeech
import java.util.Locale

object AlarmAudio {
    private var mediaPlayer: MediaPlayer? = null
    private var tts: TextToSpeech? = null
    private var ttsInitialized = false

    fun initTts(context: Context) {
        if (tts == null) {
            tts = TextToSpeech(context.applicationContext) { status ->
                if (status == TextToSpeech.SUCCESS) {
                    tts?.language = Locale.ENGLISH
                    ttsInitialized = true
                }
            }
        }
    }

    fun playAlarm(context: Context, volume: Float = 1.0f, looping: Boolean = true) {
        try {
            stopAlarm()
            val preferences = context.getSharedPreferences("alarm_preferences", Context.MODE_PRIVATE)
            val selectedUri = preferences.getString("ringtone_uri", null)?.let(Uri::parse)
            val defaultUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val candidates = listOfNotNull(selectedUri, defaultUri).distinct()
            var lastError: Exception? = null
            for (uri in candidates) {
                try {
                    mediaPlayer = MediaPlayer().apply {
                        setDataSource(context, uri)
                        setAudioAttributes(
                            AudioAttributes.Builder()
                                .setUsage(AudioAttributes.USAGE_ALARM)
                                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                .build()
                        )
                        isLooping = looping
                        setVolume(volume, volume)
                        prepare()
                        start()
                    }
                    return
                } catch (error: Exception) {
                    mediaPlayer?.release()
                    mediaPlayer = null
                    lastError = error
                }
            }
            throw lastError ?: IllegalStateException("No alarm sound is available")
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun stopAlarm() {
        try {
            tts?.stop()
            mediaPlayer?.stop()
            mediaPlayer?.release()
            mediaPlayer = null
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun speak(text: String) {
        if (ttsInitialized && tts != null) {
            tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "WakeMeThereTTS")
        }
    }

    fun vibrate(context: Context, pattern: LongArray = longArrayOf(0, 500, 200, 500)) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vibratorManager?.defaultVibrator?.vibrate(VibrationEffect.createWaveform(pattern, -1))
            } else {
                @Suppress("DEPRECATION")
                val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                @Suppress("DEPRECATION")
                vibrator?.vibrate(pattern, -1)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
