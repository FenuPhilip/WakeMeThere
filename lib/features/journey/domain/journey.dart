import 'journey_state.dart';
import '../../destination/domain/destination.dart';
import '../../../core/constants/app_constants.dart';

/// Represents an active or completed journey.
class Journey {
  const Journey({
    required this.id,
    required this.destination,
    required this.state,
    required this.startedAt,
    this.completedAt,
    this.earlyWarningMeters = AppConstants.defaultEarlyWarningMeters,
    this.wakeUpMeters = AppConstants.defaultWakeUpMeters,
    this.criticalMeters = AppConstants.defaultCriticalMeters,
    this.currentDistanceMeters,
    this.speedKmh,
    this.locationAccuracyMeters,
    this.locationUpdatedAt,
    this.etaMinutes,
    this.progressPercent = 0.0,
    this.originName = 'Origin Station',
    this.isAlertSilenced = false,
    this.soundEnabled = true,
    this.voiceEnabled = true,
    this.vibrationEnabled = true,
    this.repeatUntilDismissed = true,
    this.alarmVolume = 0.85,
  });

  final String id;
  final Destination destination;
  final JourneyState state;
  final DateTime startedAt;
  final DateTime? completedAt;
  final double earlyWarningMeters;
  final double wakeUpMeters;
  final double criticalMeters;
  final double? currentDistanceMeters;
  final double? speedKmh;
  final double? locationAccuracyMeters;
  final DateTime? locationUpdatedAt;
  final int? etaMinutes;
  final double progressPercent;
  final String originName;
  final bool isAlertSilenced;
  final bool soundEnabled;
  final bool voiceEnabled;
  final bool vibrationEnabled;
  final bool repeatUntilDismissed;
  final double alarmVolume;

  Journey copyWith({
    String? id,
    Destination? destination,
    JourneyState? state,
    DateTime? startedAt,
    DateTime? completedAt,
    double? earlyWarningMeters,
    double? wakeUpMeters,
    double? criticalMeters,
    double? currentDistanceMeters,
    double? speedKmh,
    double? locationAccuracyMeters,
    DateTime? locationUpdatedAt,
    int? etaMinutes,
    double? progressPercent,
    String? originName,
    bool? isAlertSilenced,
    bool? soundEnabled,
    bool? voiceEnabled,
    bool? vibrationEnabled,
    bool? repeatUntilDismissed,
    double? alarmVolume,
  }) {
    return Journey(
      id: id ?? this.id,
      destination: destination ?? this.destination,
      state: state ?? this.state,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      earlyWarningMeters: earlyWarningMeters ?? this.earlyWarningMeters,
      wakeUpMeters: wakeUpMeters ?? this.wakeUpMeters,
      criticalMeters: criticalMeters ?? this.criticalMeters,
      currentDistanceMeters:
          currentDistanceMeters ?? this.currentDistanceMeters,
      speedKmh: speedKmh ?? this.speedKmh,
      locationAccuracyMeters:
          locationAccuracyMeters ?? this.locationAccuracyMeters,
      locationUpdatedAt: locationUpdatedAt ?? this.locationUpdatedAt,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      progressPercent: progressPercent ?? this.progressPercent,
      originName: originName ?? this.originName,
      isAlertSilenced: isAlertSilenced ?? this.isAlertSilenced,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      voiceEnabled: voiceEnabled ?? this.voiceEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      repeatUntilDismissed: repeatUntilDismissed ?? this.repeatUntilDismissed,
      alarmVolume: alarmVolume ?? this.alarmVolume,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'dest_name': destination.name,
    'dest_lat': destination.coordinates.latitude,
    'dest_lon': destination.coordinates.longitude,
    'dest_address': destination.address,
    'state': state.name,
    'started_at': startedAt.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
    'early_warning_meters': earlyWarningMeters,
    'wake_up_meters': wakeUpMeters,
    'critical_meters': criticalMeters,
    'last_distance_meters': currentDistanceMeters,
    'sound_enabled': soundEnabled ? 1 : 0,
    'voice_enabled': voiceEnabled ? 1 : 0,
    'vibration_enabled': vibrationEnabled ? 1 : 0,
    'repeat_until_dismissed': repeatUntilDismissed ? 1 : 0,
    'alarm_volume': alarmVolume,
  };
}
