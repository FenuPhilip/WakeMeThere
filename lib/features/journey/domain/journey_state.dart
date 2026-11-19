/// All possible states of a Journey lifecycle.
/// idle→preparing→tracking→approaching→wakeUpAlert→criticalAlert→destinationReached→completed/cancelled
enum JourneyState {
  idle,
  preparing,
  tracking,
  approaching,
  wakeUpAlert,
  criticalAlert,
  destinationReached,
  completed,
  cancelled,
}

extension JourneyStateX on JourneyState {
  bool get isActive => switch (this) {
    JourneyState.tracking ||
    JourneyState.approaching ||
    JourneyState.wakeUpAlert ||
    JourneyState.criticalAlert => true,
    _ => false,
  };

  bool get isTerminal => switch (this) {
    JourneyState.completed ||
    JourneyState.cancelled ||
    JourneyState.destinationReached => true,
    _ => false,
  };

  String get displayName => switch (this) {
    JourneyState.idle => 'Idle',
    JourneyState.preparing => 'Preparing',
    JourneyState.tracking => 'Tracking',
    JourneyState.approaching => 'Approaching',
    JourneyState.wakeUpAlert => 'Wake Up!',
    JourneyState.criticalAlert => 'Almost There!',
    JourneyState.destinationReached => 'Arrived!',
    JourneyState.completed => 'Completed',
    JourneyState.cancelled => 'Cancelled',
  };
}
