import 'dart:math' as math;

/// Haversine distance calculation utilities.
/// All distances in metres.
class DistanceUtils {
  DistanceUtils._();

  static const double _earthRadiusMeters = 6371000.0;

  /// Calculates the Haversine distance between two geographic coordinates.
  /// Returns distance in metres.
  static double haversine(double lat1, double lon1, double lat2, double lon2) {
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusMeters * c;
  }

  static String formatDistance(double meters, String unit) {
    if (unit == 'mi') {
      final miles = meters / 1609.344;
      return miles < 0.1
          ? '${(meters / 0.3048).round()} ft'
          : '${miles.toStringAsFixed(1)} mi';
    }
    return meters < 1000
        ? '${meters.round()} m'
        : '${(meters / 1000).toStringAsFixed(1)} km';
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;
}
