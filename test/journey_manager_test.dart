import 'package:flutter_test/flutter_test.dart';
import 'package:wake_me_there/features/journey/domain/journey_state.dart';
import 'package:wake_me_there/features/journey/domain/journey_state_machine.dart';

void main() {
  group('JourneyStateMachine', () {
    test('Default initial state is idle', () {
      final sm = JourneyStateMachine();
      expect(sm.current, equals(JourneyState.idle));
    });

    test('Valid transition from idle to preparing to tracking', () {
      final sm = JourneyStateMachine();
      expect(sm.transition(JourneyState.preparing), isTrue);
      expect(sm.current, equals(JourneyState.preparing));
      expect(sm.transition(JourneyState.tracking), isTrue);
      expect(sm.current, equals(JourneyState.tracking));
    });

    test('Invalid direct transition from idle to tracking is rejected', () {
      final sm = JourneyStateMachine();
      expect(sm.transition(JourneyState.tracking), isFalse);
      expect(sm.current, equals(JourneyState.idle));
    });

    test('Tracking to approaching to wakeUpAlert to criticalAlert to destinationReached', () {
      final sm = JourneyStateMachine(initial: JourneyState.tracking);
      expect(sm.transition(JourneyState.approaching), isTrue);
      expect(sm.transition(JourneyState.wakeUpAlert), isTrue);
      expect(sm.transition(JourneyState.criticalAlert), isTrue);
      expect(sm.transition(JourneyState.destinationReached), isTrue);
      expect(sm.transition(JourneyState.completed), isTrue);
      expect(sm.current, equals(JourneyState.completed));
    });

    test('Cancellation from active state is allowed', () {
      final sm = JourneyStateMachine(initial: JourneyState.tracking);
      expect(sm.transition(JourneyState.cancelled), isTrue);
      expect(sm.current, equals(JourneyState.cancelled));
    });
  });
}
