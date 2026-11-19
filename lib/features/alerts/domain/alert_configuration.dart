import '../../../core/constants/app_constants.dart';

/// User-configurable alert thresholds for a journey.
class AlertConfiguration {
  const AlertConfiguration({
    this.earlyWarningMeters = AppConstants.defaultEarlyWarningMeters,
    this.wakeUpMeters = AppConstants.defaultWakeUpMeters,
    this.criticalMeters = AppConstants.defaultCriticalMeters,
    this.arrivalRadiusMeters = AppConstants.defaultArrivalRadiusMeters,
    this.vibrateOnAlert = true,
    this.soundOnAlert = true,
  });

  final double earlyWarningMeters;
  final double wakeUpMeters;
  final double criticalMeters;
  final double arrivalRadiusMeters;
  final bool vibrateOnAlert;
  final bool soundOnAlert;

  AlertConfiguration copyWith({
    double? earlyWarningMeters,
    double? wakeUpMeters,
    double? criticalMeters,
    double? arrivalRadiusMeters,
    bool? vibrateOnAlert,
    bool? soundOnAlert,
  }) {
    return AlertConfiguration(
      earlyWarningMeters: earlyWarningMeters ?? this.earlyWarningMeters,
      wakeUpMeters: wakeUpMeters ?? this.wakeUpMeters,
      criticalMeters: criticalMeters ?? this.criticalMeters,
      arrivalRadiusMeters: arrivalRadiusMeters ?? this.arrivalRadiusMeters,
      vibrateOnAlert: vibrateOnAlert ?? this.vibrateOnAlert,
      soundOnAlert: soundOnAlert ?? this.soundOnAlert,
    );
  }

  Map<String, dynamic> toMap() => {
    'early_warning_meters': earlyWarningMeters,
    'wake_up_meters': wakeUpMeters,
    'critical_meters': criticalMeters,
    'arrival_radius_meters': arrivalRadiusMeters,
    'vibrate_on_alert': vibrateOnAlert ? 1 : 0,
    'sound_on_alert': soundOnAlert ? 1 : 0,
  };

  factory AlertConfiguration.fromMap(Map<String, dynamic> map) =>
      AlertConfiguration(
        earlyWarningMeters:
            (map['early_warning_meters'] as num?)?.toDouble() ??
            AppConstants.defaultEarlyWarningMeters,
        wakeUpMeters:
            (map['wake_up_meters'] as num?)?.toDouble() ??
            AppConstants.defaultWakeUpMeters,
        criticalMeters:
            (map['critical_meters'] as num?)?.toDouble() ??
            AppConstants.defaultCriticalMeters,
        arrivalRadiusMeters:
            (map['arrival_radius_meters'] as num?)?.toDouble() ??
            AppConstants.defaultArrivalRadiusMeters,
        vibrateOnAlert: (map['vibrate_on_alert'] as int?) == 1,
        soundOnAlert: (map['sound_on_alert'] as int?) == 1,
      );
}
