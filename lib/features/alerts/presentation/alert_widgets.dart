import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../journey/domain/journey_state.dart';

/// Returns the semantic alert color for the given [JourneyState].
Color alertColorForState(JourneyState state) => switch (state) {
  JourneyState.tracking => kColorSafe,
  JourneyState.approaching => kColorAdvisory,
  JourneyState.wakeUpAlert => kColorWake,
  JourneyState.criticalAlert => kColorCritical,
  JourneyState.destinationReached => kColorSafe,
  _ => kOutline,
};

/// Animated pulsing alert banner shown during active journey states.
class AlertBanner extends StatelessWidget {
  const AlertBanner({
    super.key,
    required this.state,
    required this.distanceMeters,
  });

  final JourneyState state;
  final double distanceMeters;

  @override
  Widget build(BuildContext context) {
    final color = alertColorForState(state);
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: kSpaceMd,
        vertical: kSpaceSm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border(bottom: BorderSide(color: color, width: 2)),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on, color: color, size: 20),
          const SizedBox(width: kSpaceSm),
          Text(
            state.displayName,
            style: theme.textTheme.labelLarge?.copyWith(color: color),
          ),
          const Spacer(),
          Text(
            _formatDistance(distanceMeters),
            style: theme.textTheme.bodyMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.round()} m';
  }
}
