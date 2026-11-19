import '../../../core/utils/distance_utils.dart';
import '../../../core/constants/app_constants.dart';

/// Computes distance to destination and applies hysteresis debouncing.
class DistanceEngine {
  DistanceEngine({
    int hysteresisRequired = AppConstants.hysteresisReadingsRequired,
  }) : _hysteresisRequired = hysteresisRequired;

  final int _hysteresisRequired;
  final List<double> _recentReadings = [];

  /// Returns distance in metres from current position to destination.
  double computeDistance({
    required double currentLat,
    required double currentLon,
    required double destLat,
    required double destLon,
  }) {
    return DistanceUtils.haversine(currentLat, currentLon, destLat, destLon);
  }

  /// Returns true only when [_hysteresisRequired] consecutive readings
  /// are all below [thresholdMeters] — prevents false threshold crossings.
  bool isStablyBelow(double distanceMeters, double thresholdMeters) {
    _recentReadings.add(distanceMeters);
    if (_recentReadings.length > _hysteresisRequired) {
      _recentReadings.removeAt(0);
    }
    if (_recentReadings.length < _hysteresisRequired) return false;
    return _recentReadings.every((d) => d < thresholdMeters);
  }

  void reset() => _recentReadings.clear();
}
