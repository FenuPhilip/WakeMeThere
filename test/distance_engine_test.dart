import 'package:flutter_test/flutter_test.dart';
import 'package:wake_me_there/core/utils/distance_utils.dart';
import 'package:wake_me_there/features/journey/domain/distance_engine.dart';
import 'package:wake_me_there/features/journey/domain/location_filter.dart';

void main() {
  group('DistanceUtils (Haversine)', () {
    test('Zero distance for same coordinates', () {
      final d = DistanceUtils.haversine(10.5276, 76.2144, 10.5276, 76.2144);
      expect(d, closeTo(0.0, 0.01));
    });

    test('Known distance between Thrissur and Ernakulam (~60-75 km)', () {
      // Thrissur: 10.5276° N, 76.2144° E
      // Ernakulam: 9.9816° N, 76.2999° E
      final d = DistanceUtils.haversine(10.5276, 76.2144, 9.9816, 76.2999);
      expect(d, greaterThan(60000));
      expect(d, lessThan(75000));
    });
  });

  group('DistanceEngine hysteresis', () {
    test('Requires configured consecutive readings under threshold', () {
      final engine = DistanceEngine(hysteresisRequired: 3);
      expect(engine.isStablyBelow(2100, 2000), isFalse);
      expect(engine.isStablyBelow(1950, 2000), isFalse); // 1st reading
      expect(engine.isStablyBelow(1900, 2000), isFalse); // 2nd reading
      expect(engine.isStablyBelow(1850, 2000), isTrue);  // 3rd reading!
    });

    test('Resets when distance goes above threshold', () {
      final engine = DistanceEngine(hysteresisRequired: 3);
      engine.isStablyBelow(1900, 2000);
      engine.isStablyBelow(1900, 2000);
      expect(engine.isStablyBelow(2050, 2000), isFalse); // Jitter above
      expect(engine.isStablyBelow(1900, 2000), isFalse); // Back below (needs 3 again)
    });
  });

  group('LocationFilter', () {
    final filter = LocationFilter(maxAccuracyMeters: 50, maxAgeSeconds: 30);

    test('Rejects inaccurate GPS samples', () {
      final valid = filter.isValid(
        latitude: 10.0,
        longitude: 76.0,
        accuracyMeters: 65,
        timestamp: DateTime.now(),
      );
      expect(valid, isFalse);
    });

    test('Rejects stale GPS samples', () {
      final valid = filter.isValid(
        latitude: 10.0,
        longitude: 76.0,
        accuracyMeters: 10,
        timestamp: DateTime.now().subtract(const Duration(seconds: 45)),
      );
      expect(valid, isFalse);
    });

    test('Accepts valid fresh and accurate samples', () {
      final valid = filter.isValid(
        latitude: 10.0,
        longitude: 76.0,
        accuracyMeters: 12,
        timestamp: DateTime.now(),
      );
      expect(valid, isTrue);
    });
  });
}
