import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/utils/distance_utils.dart';
import '../../home/providers/home_provider.dart';
import '../domain/journey_state.dart';
import '../providers/journey_provider.dart';

class AlarmScreen extends ConsumerWidget {
  const AlarmScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journey = ref.watch(journeyProvider);
    final unit = ref.watch(distanceUnitProvider);
    if (journey == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Back to WakeMeThere'),
            ),
          ),
        ),
      );
    }

    final title = switch (journey.state) {
      JourneyState.criticalAlert => 'Your stop is very close',
      JourneyState.destinationReached => 'You have arrived',
      JourneyState.wakeUpAlert => 'Your stop is approaching',
      _ => 'Get ready to leave',
    };
    final locationAge = journey.locationUpdatedAt == null
        ? null
        : DateTime.now().difference(journey.locationUpdatedAt!).abs();
    final distance =
        journey.currentDistanceMeters == null ||
            locationAge == null ||
            locationAge > const Duration(seconds: 30)
        ? null
        : DistanceUtils.formatDistance(journey.currentDistanceMeters!, unit);

    return Scaffold(
      backgroundColor: kAppBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(kMargin),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: kTertiaryFixed.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.alarm, size: 48, color: kTertiary),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  journey.destination.name,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (distance != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    distance,
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  Text(
                    'Approximate straight-line distance',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Get ready to leave the vehicle. Acknowledge this alert when you are awake.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: () async {
                      await ref
                          .read(journeyProvider.notifier)
                          .acknowledgeAlert();
                      if (context.mounted) context.go('/active-journey');
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text("I'm awake"),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/active-journey'),
                  child: const Text('View active journey'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
