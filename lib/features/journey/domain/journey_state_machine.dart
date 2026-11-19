import 'journey_state.dart';

/// Enforces valid state transitions for the Journey lifecycle.
class JourneyStateMachine {
  JourneyStateMachine({JourneyState initial = JourneyState.idle})
    : _current = initial;

  JourneyState _current;

  JourneyState get current => _current;

  static const _validTransitions = <JourneyState, Set<JourneyState>>{
    JourneyState.idle: {JourneyState.preparing, JourneyState.cancelled},
    JourneyState.preparing: {JourneyState.tracking, JourneyState.cancelled},
    JourneyState.tracking: {
      JourneyState.approaching,
      JourneyState.wakeUpAlert,
      JourneyState.criticalAlert,
      JourneyState.destinationReached,
      JourneyState.cancelled,
    },
    JourneyState.approaching: {
      JourneyState.tracking,
      JourneyState.wakeUpAlert,
      JourneyState.criticalAlert,
      JourneyState.destinationReached,
      JourneyState.cancelled,
    },
    JourneyState.wakeUpAlert: {
      JourneyState.approaching,
      JourneyState.criticalAlert,
      JourneyState.destinationReached,
      JourneyState.cancelled,
    },
    JourneyState.criticalAlert: {
      JourneyState.wakeUpAlert,
      JourneyState.destinationReached,
      JourneyState.cancelled,
    },
    JourneyState.destinationReached: {JourneyState.completed},
    JourneyState.completed: {},
    JourneyState.cancelled: {},
  };

  /// Returns true and transitions to [next] if the transition is valid.
  bool transition(JourneyState next) {
    final allowed = _validTransitions[_current] ?? {};
    if (allowed.contains(next)) {
      _current = next;
      return true;
    }
    return false;
  }

  bool canTransitionTo(JourneyState next) {
    return (_validTransitions[_current] ?? {}).contains(next);
  }

  void restore(JourneyState state) => _current = state;

  void reset() => _current = JourneyState.idle;
}
