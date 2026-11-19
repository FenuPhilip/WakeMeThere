import 'package:flutter_test/flutter_test.dart';
import 'package:wake_me_there/features/journey/domain/alert_rules_engine.dart';
import 'package:wake_me_there/features/journey/domain/journey_state.dart';

void main() {
  group('AlertRulesEngine', () {
    const engine = AlertRulesEngine(
      earlyWarningMeters: 5000,
      wakeUpMeters: 2000,
      criticalMeters: 500,
      arrivalMeters: 150,
    );

    test('Tracking state when beyond early warning', () {
      expect(engine.evaluate(6000), equals(JourneyState.tracking));
    });

    test('Approaching state between early warning and wake-up', () {
      expect(engine.evaluate(4500), equals(JourneyState.approaching));
      expect(engine.evaluate(2001), equals(JourneyState.approaching));
    });

    test('WakeUpAlert state between wake-up and critical', () {
      expect(engine.evaluate(2000), equals(JourneyState.wakeUpAlert));
      expect(engine.evaluate(501), equals(JourneyState.wakeUpAlert));
    });

    test('CriticalAlert state between critical and arrival', () {
      expect(engine.evaluate(500), equals(JourneyState.criticalAlert));
      expect(engine.evaluate(151), equals(JourneyState.criticalAlert));
    });

    test('DestinationReached when inside arrival radius', () {
      expect(engine.evaluate(150), equals(JourneyState.destinationReached));
      expect(engine.evaluate(20), equals(JourneyState.destinationReached));
    });
  });
}
