import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/utils/distance_utils.dart';
import '../../destination/domain/destination.dart';
import '../data/journey_repository.dart';
import '../domain/alert_rules_engine.dart';
import '../domain/journey.dart';
import '../domain/journey_state.dart';
import '../domain/journey_state_machine.dart';
import '../domain/location_filter.dart';
import '../../../platform/tracking_channel.dart';
import '../../../platform/alarm_channel.dart';

final journeyRepositoryProvider = Provider<JourneyRepository>(
  (ref) => const SqfliteJourneyRepository(),
);

class JourneyNotifier extends StateNotifier<Journey?> {
  JourneyNotifier(this._repository) : super(null) {
    _initialization = _init();
  }

  final JourneyRepository _repository;
  final _stateMachine = JourneyStateMachine();
  final _locationFilter = LocationFilter();
  late final Future<void> _initialization;
  late AlertRulesEngine _alertEngine;
  DateTime? _lastPersistedAt;
  int _arrivalConfirmations = 0;
  String? _trackingError;
  String? get trackingError => _trackingError;

  Future<void> _init() async {
    final active = await _repository.getActiveJourney();
    if (active != null) {
      state = active;
      final nativeStatus = await TrackingChannel.getTrackingStatus();
      final destinationReached = nativeStatus['destinationReached'] == true;
      final nativeActive = nativeStatus['active'] == true;
      final nativeAlertState = switch (nativeStatus['alertStage']) {
        'early' => JourneyState.approaching,
        'wake' => JourneyState.wakeUpAlert,
        'critical' => JourneyState.criticalAlert,
        'arrived' => JourneyState.destinationReached,
        _ => active.state,
      };
      if (destinationReached) {
        await _repository.updateState(
          active.id,
          JourneyState.destinationReached.name,
        );
        state = active.copyWith(
          state: JourneyState.destinationReached,
          isAlertSilenced: nativeStatus['alarmAcknowledged'] == true,
        );
      } else if (!nativeActive) {
        await _repository.updateState(active.id, JourneyState.cancelled.name);
        state = null;
        _trackingError = (nativeStatus['error'] as String?)?.isNotEmpty == true
            ? nativeStatus['error'] as String
            : 'The Android tracking service is not running. Start a new journey.';
      } else {
        if (nativeAlertState != active.state) {
          await _repository.updateState(active.id, nativeAlertState.name);
        }
        state = active.copyWith(
          state: nativeAlertState,
          isAlertSilenced: nativeStatus['alarmAcknowledged'] == true,
        );
        _lastPersistedAt = DateTime.now();
        _alertEngine = AlertRulesEngine(
          earlyWarningMeters: active.earlyWarningMeters,
          wakeUpMeters: active.wakeUpMeters,
          criticalMeters: active.criticalMeters,
        );
        _stateMachine.restore(nativeAlertState);
      }
    }

    // Listen to native platform channel location updates
    TrackingChannel.setLocationUpdateHandler(
      (data) {
        final lat = (data['latitude'] as num?)?.toDouble();
        final lon = (data['longitude'] as num?)?.toDouble();
        final accuracy = (data['accuracy'] as num?)?.toDouble();
        final speed = (data['speed'] as num?)?.toDouble();
        final timestampMs = (data['timestampMs'] as num?)?.toInt();

        if (lat != null && lon != null && accuracy != null) {
          unawaited(
            onLocationReceived(
              lat: lat,
              lon: lon,
              accuracy: accuracy,
              speedKmh: speed != null ? speed * 3.6 : null,
              timestamp: timestampMs == null
                  ? DateTime.now()
                  : DateTime.fromMillisecondsSinceEpoch(timestampMs),
            ),
          );
        }
      },
      onError: (message) => unawaited(_handleTrackingError(message)),
      onAlarmAcknowledged: () {
        if (state != null) state = state!.copyWith(isAlertSilenced: true);
      },
    );
  }

  Future<void> _handleTrackingError(String message) async {
    final journey = state;
    if (journey == null) return;
    _trackingError = message;
    await _repository.updateState(journey.id, 'cancelled');
    _stateMachine.reset();
    state = null;
  }

  Future<void> startJourney({
    required Destination destination,
    double earlyWarningMeters = 5000,
    double wakeUpMeters = 2000,
    double criticalMeters = 500,
    bool soundEnabled = true,
    bool voiceEnabled = true,
    bool vibrationEnabled = true,
    bool repeatUntilDismissed = true,
    double alarmVolume = 0.85,
  }) async {
    // Wait for any persisted journey to be restored before deciding whether a
    // new one can start. This prevents initialization and start from racing.
    await _initialization;
    if (state?.state.isActive == true) {
      throw StateError('End the current journey before starting another one.');
    }
    if (!earlyWarningMeters.isFinite ||
        !wakeUpMeters.isFinite ||
        !criticalMeters.isFinite ||
        criticalMeters <= 100 ||
        wakeUpMeters <= criticalMeters ||
        earlyWarningMeters <= wakeUpMeters) {
      throw StateError(
        'Alert distances must be ordered: early warning, wake-up, then critical.',
      );
    }
    _alertEngine = AlertRulesEngine(
      earlyWarningMeters: earlyWarningMeters,
      wakeUpMeters: wakeUpMeters,
      criticalMeters: criticalMeters,
    );
    _trackingError = null;

    _stateMachine.reset();
    _stateMachine.transition(JourneyState.preparing);
    _stateMachine.transition(JourneyState.tracking);

    // A place's catalogue distance is not the traveller's current distance.
    // Start with an unknown distance until the native service provides a fix.
    final newJourney = Journey(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      destination: destination,
      state: JourneyState.tracking,
      startedAt: DateTime.now(),
      earlyWarningMeters: earlyWarningMeters,
      wakeUpMeters: wakeUpMeters,
      criticalMeters: criticalMeters,
      currentDistanceMeters: null,
      speedKmh: null,
      etaMinutes: null,
      progressPercent: 0,
      soundEnabled: soundEnabled,
      voiceEnabled: voiceEnabled,
      vibrationEnabled: vibrationEnabled,
      repeatUntilDismissed: repeatUntilDismissed,
      alarmVolume: alarmVolume,
    );

    state = newJourney;
    _arrivalConfirmations = 0;
    await _repository.save(newJourney);
    _lastPersistedAt = DateTime.now();

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw StateError('Turn on Location Services to start a journey.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError(
          'Precise location permission is required to track this journey.',
        );
      }
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }

      await TrackingChannel.startTracking(
        destinationLat: destination.coordinates.latitude,
        destinationLon: destination.coordinates.longitude,
        earlyWarningMeters: earlyWarningMeters,
        wakeUpMeters: wakeUpMeters,
        criticalMeters: criticalMeters,
        destinationName: destination.name,
        soundEnabled: soundEnabled,
        voiceEnabled: voiceEnabled,
        vibrationEnabled: vibrationEnabled,
        repeatUntilDismissed: repeatUntilDismissed,
        alarmVolume: alarmVolume,
      );
      final deadline = DateTime.now().add(const Duration(seconds: 6));
      var confirmed = false;
      while (DateTime.now().isBefore(deadline)) {
        final status = await TrackingChannel.getTrackingStatus();
        if (status['active'] == true) {
          confirmed = true;
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      if (!confirmed) {
        throw StateError(
          'Android could not confirm that journey tracking started. Check location and notification settings, then try again.',
        );
      }
    } catch (_) {
      await _repository.updateState(newJourney.id, 'cancelled');
      state = null;
      _stateMachine.reset();
      rethrow;
    }
  }

  Future<void> onLocationReceived({
    required double lat,
    required double lon,
    required double accuracy,
    required DateTime timestamp,
    double? speedKmh,
  }) async {
    if (state == null) return;

    final isValid = _locationFilter.isValid(
      latitude: lat,
      longitude: lon,
      accuracyMeters: accuracy,
      timestamp: timestamp,
    );

    if (!isValid) return;

    final dest = state!.destination.coordinates;
    final dist = DistanceUtils.haversine(
      lat,
      lon,
      dest.latitude,
      dest.longitude,
    );

    if (dist <= 100 && accuracy <= 35) {
      _arrivalConfirmations += 1;
    } else {
      _arrivalConfirmations = 0;
    }
    final previousState = state!.state;
    final evaluatedState = _alertEngine.evaluate(dist);
    final nextState =
        evaluatedState == JourneyState.destinationReached &&
            _arrivalConfirmations < 2
        ? JourneyState.criticalAlert
        : evaluatedState;
    if (nextState != previousState) {
      _stateMachine.transition(nextState);
    }

    final speed = speedKmh ?? state!.speedKmh;
    final eta = speed != null && speed > 1
        ? (dist / (speed * 1000 / 60)).round().clamp(1, 1440)
        : null;

    state = state!.copyWith(
      currentDistanceMeters: dist,
      speedKmh: speed,
      etaMinutes: eta,
      locationAccuracyMeters: accuracy,
      locationUpdatedAt: timestamp,
      state: nextState,
      isAlertSilenced: nextState == previousState
          ? state!.isAlertSilenced
          : false,
    );
    if (nextState != previousState ||
        _lastPersistedAt == null ||
        DateTime.now().difference(_lastPersistedAt!) >=
            const Duration(seconds: 30)) {
      try {
        await _repository.save(state!);
        _lastPersistedAt = DateTime.now();
      } catch (_) {
        // Keep the foreground tracker working if local persistence is temporarily unavailable.
      }
    }
  }

  Future<void> acknowledgeAlert() async {
    if (state == null) return;
    await AlarmChannel.acknowledgeAlarm();
    state = state!.copyWith(isAlertSilenced: true);
  }

  Future<void> stopJourney() async {
    if (state != null) {
      final terminalState = state!.state == JourneyState.destinationReached
          ? 'completed'
          : 'cancelled';
      await _repository.updateState(state!.id, terminalState);
    }
    await TrackingChannel.stopTracking();
    await AlarmChannel.stopAlarm();
    _stateMachine.reset();
    _arrivalConfirmations = 0;
    state = null;
  }
}

final journeyProvider = StateNotifierProvider<JourneyNotifier, Journey?>(
  (ref) => JourneyNotifier(ref.watch(journeyRepositoryProvider)),
);

final journeyStateProvider = Provider<JourneyState>((ref) {
  final journey = ref.watch(journeyProvider);
  return journey?.state ?? JourneyState.idle;
});

final currentDistanceProvider = Provider<double?>((ref) {
  return ref.watch(journeyProvider)?.currentDistanceMeters;
});

final trackingErrorProvider = Provider<String?>((ref) {
  ref.watch(journeyProvider);
  return ref.read(journeyProvider.notifier).trackingError;
});
