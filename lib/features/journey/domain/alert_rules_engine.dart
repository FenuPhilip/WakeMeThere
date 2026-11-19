import 'journey_state.dart';
import '../../../core/constants/app_constants.dart';

/// Determines the appropriate alert level based on distance to destination.
class AlertRulesEngine {
  const AlertRulesEngine({
    double earlyWarningMeters = AppConstants.defaultEarlyWarningMeters,
    double wakeUpMeters = AppConstants.defaultWakeUpMeters,
    double criticalMeters = AppConstants.defaultCriticalMeters,
    double arrivalMeters = AppConstants.defaultArrivalRadiusMeters,
  }) : _earlyWarningMeters = earlyWarningMeters,
       _wakeUpMeters = wakeUpMeters,
       _criticalMeters = criticalMeters,
       _arrivalMeters = arrivalMeters;

  final double _earlyWarningMeters;
  final double _wakeUpMeters;
  final double _criticalMeters;
  final double _arrivalMeters;

  /// Returns the target [JourneyState] for a given distance.
  JourneyState evaluate(double distanceMeters) {
    if (distanceMeters <= _arrivalMeters) {
      return JourneyState.destinationReached;
    } else if (distanceMeters <= _criticalMeters) {
      return JourneyState.criticalAlert;
    } else if (distanceMeters <= _wakeUpMeters) {
      return JourneyState.wakeUpAlert;
    } else if (distanceMeters <= _earlyWarningMeters) {
      return JourneyState.approaching;
    } else {
      return JourneyState.tracking;
    }
  }
}
