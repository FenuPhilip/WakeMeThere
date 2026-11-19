import '../../../core/constants/app_constants.dart';

/// Validates GPS samples for accuracy, freshness, and plausibility.
class LocationFilter {
  LocationFilter({
    double maxAccuracyMeters = AppConstants.gpsMaxAccuracyMeters,
    int maxAgeSeconds = AppConstants.gpsMaxAgeSeconds,
  }) : _maxAccuracyMeters = maxAccuracyMeters,
       _maxAgeSeconds = maxAgeSeconds;

  final double _maxAccuracyMeters;
  final int _maxAgeSeconds;

  double? _lastLat;
  double? _lastLon;

  /// Returns true when the GPS sample passes all validation checks.
  bool isValid({
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required DateTime timestamp,
  }) {
    if (!_isAccurate(accuracyMeters)) return false;
    if (!_isFresh(timestamp)) return false;
    if (!_isPlausible(latitude, longitude)) return false;

    _lastLat = latitude;
    _lastLon = longitude;
    return true;
  }

  bool _isAccurate(double accuracy) => accuracy <= _maxAccuracyMeters;

  bool _isFresh(DateTime timestamp) {
    final age = DateTime.now().difference(timestamp).inSeconds.abs();
    return age <= _maxAgeSeconds;
  }

  bool _isPlausible(double lat, double lon) {
    // Basic bounds check
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return false;
    // If we have a previous fix, check for teleportation (> 500m/s implausible)
    if (_lastLat != null && _lastLon != null) {
      // Rough check: 1 degree ≈ 111 km; more than 0.1 deg per sample is suspicious
      final latDiff = (lat - _lastLat!).abs();
      final lonDiff = (lon - _lastLon!).abs();
      if (latDiff > 0.5 || lonDiff > 0.5) return false;
    }
    return true;
  }

  void reset() {
    _lastLat = null;
    _lastLon = null;
  }
}
