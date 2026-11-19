import 'package:flutter/services.dart';
import '../core/constants/app_constants.dart';
import '../core/errors/app_errors.dart';

/// Alarm/notification channel for triggering wake-up alerts.
class AlarmChannel {
  AlarmChannel._();

  static const _channel = MethodChannel(AppConstants.alarmChannelName);

  static Future<void> playAlarm({
    String soundId = 'default',
    double volume = 1.0,
  }) async {
    try {
      await _channel.invokeMethod('playAlarm', {
        'soundId': soundId,
        'volume': volume,
      });
    } catch (_) {}
  }

  static Future<void> stopAlarm() async {
    try {
      await _channel.invokeMethod('stopAlarm');
    } catch (_) {}
  }

  static Future<void> acknowledgeAlarm() async {
    try {
      await _channel.invokeMethod('acknowledgeAlarm');
    } catch (_) {}
  }

  static Future<String?> pickAlarmRingtone() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'pickAlarmRingtone',
      );
      return result?['title'] as String?;
    } on PlatformException catch (e) {
      throw PlatformChannelError('Ringtone selection failed: ${e.message}');
    }
  }

  static Future<String> getAlarmRingtoneName() async {
    try {
      return await _channel.invokeMethod<String>('getAlarmRingtoneName') ??
          'Device default alarm';
    } on PlatformException catch (e) {
      throw PlatformChannelError('Could not read alarm sound: ${e.message}');
    }
  }

  static Future<void> clearSelectedAlarmRingtone() async {
    try {
      await _channel.invokeMethod('clearAlarmRingtone');
    } on PlatformException catch (e) {
      throw PlatformChannelError('Could not reset alarm sound: ${e.message}');
    }
  }

  static Future<void> openDoNotDisturbSettings() async {
    try {
      await _channel.invokeMethod('openDoNotDisturbSettings');
    } on PlatformException catch (e) {
      throw PlatformChannelError(
        'Could not open Do Not Disturb settings: ${e.message}',
      );
    }
  }

  static Future<void> triggerWakeUpAlert({
    required String destinationName,
    required double distanceMeters,
  }) async {
    try {
      await _channel.invokeMethod('triggerWakeUpAlert', {
        'destinationName': destinationName,
        'distanceMeters': distanceMeters,
      });
    } on PlatformException catch (e) {
      throw PlatformChannelError('triggerWakeUpAlert failed: ${e.message}');
    } catch (_) {}
  }

  static Future<void> triggerCriticalAlert({
    required String destinationName,
    required double distanceMeters,
  }) async {
    try {
      await _channel.invokeMethod('triggerCriticalAlert', {
        'destinationName': destinationName,
        'distanceMeters': distanceMeters,
      });
    } on PlatformException catch (e) {
      throw PlatformChannelError('triggerCriticalAlert failed: ${e.message}');
    } catch (_) {}
  }

  static Future<void> dismissAlerts() async {
    try {
      await _channel.invokeMethod('dismissAlerts');
    } on PlatformException catch (e) {
      throw PlatformChannelError('dismissAlerts failed: ${e.message}');
    } catch (_) {}
  }
}
