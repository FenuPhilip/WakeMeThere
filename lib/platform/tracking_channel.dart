import 'package:flutter/services.dart';
import '../core/constants/app_constants.dart';
import '../core/errors/app_errors.dart';

/// Flutter side of the WakeMeThere platform channel.
/// Communicates with the Kotlin foreground LocationService.
class TrackingChannel {
  TrackingChannel._();

  static const _channel = MethodChannel(AppConstants.channelName);

  static Future<void> startTracking({
    required double destinationLat,
    required double destinationLon,
    required double earlyWarningMeters,
    required double wakeUpMeters,
    required double criticalMeters,
    required String destinationName,
    bool soundEnabled = true,
    bool voiceEnabled = true,
    bool vibrationEnabled = true,
    bool repeatUntilDismissed = true,
    double alarmVolume = 0.85,
  }) async {
    try {
      await _channel.invokeMethod('startTracking', {
        'destinationLat': destinationLat,
        'destinationLon': destinationLon,
        'earlyWarningMeters': earlyWarningMeters,
        'wakeUpMeters': wakeUpMeters,
        'criticalMeters': criticalMeters,
        'destinationName': destinationName,
        'soundEnabled': soundEnabled,
        'voiceEnabled': voiceEnabled,
        'vibrationEnabled': vibrationEnabled,
        'repeatUntilDismissed': repeatUntilDismissed,
        'alarmVolume': alarmVolume,
      });
    } on PlatformException catch (e) {
      throw PlatformChannelError('startTracking failed: ${e.message}');
    }
  }

  static Future<void> stopTracking() async {
    try {
      await _channel.invokeMethod('stopTracking');
    } on PlatformException catch (e) {
      throw PlatformChannelError('stopTracking failed: ${e.message}');
    }
  }

  static Future<Map<String, dynamic>> getTrackingStatus() async {
    try {
      final status = await _channel.invokeMapMethod<String, dynamic>(
        'getTrackingStatus',
      );
      return status ?? const {};
    } on PlatformException catch (e) {
      throw PlatformChannelError('getTrackingStatus failed: ${e.message}');
    }
  }

  static void setLocationUpdateHandler(
    void Function(Map<String, dynamic> location) handler, {
    void Function(String message)? onError,
    void Function()? onAlarmAcknowledged,
  }) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onLocationUpdate') {
        handler(Map<String, dynamic>.from(call.arguments as Map));
      } else if (call.method == 'onTrackingError') {
        onError?.call(
          call.arguments as String? ?? 'Location tracking stopped.',
        );
      } else if (call.method == 'onAlarmAcknowledged') {
        onAlarmAcknowledged?.call();
      }
    });
  }
}
