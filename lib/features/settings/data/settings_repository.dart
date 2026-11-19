import 'package:shared_preferences/shared_preferences.dart';
import '../../alerts/domain/alert_configuration.dart';

/// Persists user settings via shared_preferences.
class SettingsRepository {
  static const _keyEarlyWarning = 'early_warning_meters';
  static const _keyWakeUp = 'wake_up_meters';
  static const _keyCritical = 'critical_meters';
  static const _keyVibrate = 'vibrate_enabled';
  static const _keySound = 'sound_enabled';
  static const _keyVoice = 'voice_enabled';
  static const _keyUnit = 'distance_unit';
  static const _keyVolume = 'alarm_volume';
  static const _keyDnd = 'dnd_override';
  static const _keyRepeat = 'repeat_until_dismissed';

  Future<AlertConfiguration> loadAlertConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return AlertConfiguration(
      earlyWarningMeters: prefs.getDouble(_keyEarlyWarning) ?? 5000.0,
      wakeUpMeters: prefs.getDouble(_keyWakeUp) ?? 2000.0,
      criticalMeters: prefs.getDouble(_keyCritical) ?? 500.0,
      vibrateOnAlert: prefs.getBool(_keyVibrate) ?? true,
      soundOnAlert: prefs.getBool(_keySound) ?? true,
    );
  }

  Future<void> saveAlertConfig(AlertConfiguration config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyEarlyWarning, config.earlyWarningMeters);
    await prefs.setDouble(_keyWakeUp, config.wakeUpMeters);
    await prefs.setDouble(_keyCritical, config.criticalMeters);
    await prefs.setBool(_keyVibrate, config.vibrateOnAlert);
    await prefs.setBool(_keySound, config.soundOnAlert);
  }

  Future<String> getDistanceUnit() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUnit) ?? 'km';
  }

  Future<void> setDistanceUnit(String unit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUnit, unit);
  }

  Future<int> getVolume() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyVolume) ?? 85;
  }

  Future<void> setVolume(int volume) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyVolume, volume);
  }

  Future<bool> getDndOverride() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDnd) ?? true;
  }

  Future<void> setDndOverride(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDnd, enabled);
  }

  Future<bool> getVoiceEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyVoice) ?? true;
  }

  Future<void> setVoiceEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyVoice, enabled);
  }

  Future<bool> getRepeatUntilDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyRepeat) ?? true;
  }

  Future<void> setRepeatUntilDismissed(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRepeat, enabled);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
