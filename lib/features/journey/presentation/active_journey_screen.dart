import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../../../app/theme.dart';
import '../../../core/utils/distance_utils.dart';
import '../../map/domain/map_tile_provider.dart';
import '../../home/providers/home_provider.dart';
import '../domain/journey_state.dart';
import '../providers/journey_provider.dart';
import '../../../platform/tracking_channel.dart';

class ActiveJourneyScreen extends ConsumerStatefulWidget {
  const ActiveJourneyScreen({super.key});

  @override
  ConsumerState<ActiveJourneyScreen> createState() =>
      _ActiveJourneyScreenState();
}

class _ActiveJourneyScreenState extends ConsumerState<ActiveJourneyScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  maplibre.MapLibreMapController? insetMapController;
  bool _isConfirmingAbort = false;
  bool? _nativeTrackingActive;
  String? _trackingServiceError;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _refreshTrackingStatus();
    _statusTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refreshTrackingStatus(),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshTrackingStatus() async {
    try {
      final status = await TrackingChannel.getTrackingStatus();
      if (mounted) {
        setState(() {
          _nativeTrackingActive = status['active'] == true;
          final message = status['error'] as String?;
          _trackingServiceError = message == null || message.isEmpty
              ? null
              : message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _nativeTrackingActive = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final journey = ref.watch(journeyProvider);
    final distanceUnit = ref.watch(distanceUnitProvider);
    final mapTiles = ref.watch(mapTileProvider);

    if (journey == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('No Active Journey')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Start a journey to see live distance and alerts.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Go home'),
              ),
            ],
          ),
        ),
      );
    }

    const primaryColor = kPrimary;
    const surfaceColor = kAppBackground;
    const surfaceContainer = kSurfaceLowest;
    const surfaceContainerHigh = kSurfaceLow;
    const surfaceContainerHighest = kSurfaceHighest;
    const onSurface = kOnSurface;
    const onSurfaceVariant = kOnSurfaceVariant;
    const outline = kOutline;
    const outlineVariant = kOutlineVariant;

    final locationAge = journey.locationUpdatedAt == null
        ? null
        : DateTime.now().difference(journey.locationUpdatedAt!);
    final safeLocationAge = locationAge != null && locationAge.isNegative
        ? Duration.zero
        : locationAge;
    final isLocationStale =
        safeLocationAge != null &&
        safeLocationAge > const Duration(seconds: 30);
    final distanceKm = journey.currentDistanceMeters == null
        ? 'Waiting for GPS'
        : isLocationStale
        ? 'Updating location'
        : DistanceUtils.formatDistance(
            journey.currentDistanceMeters!,
            distanceUnit,
          );
    final destName = journey.destination.name;
    final isSilenced = journey.isAlertSilenced;
    final isAlertActive =
        journey.state == JourneyState.wakeUpAlert ||
        journey.state == JourneyState.criticalAlert ||
        journey.state == JourneyState.destinationReached;

    final destCoords = journey.destination.coordinates;

    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: onSurface,
          ),
          onPressed: () => context.go('/'),
        ),
        title: const Text(
          'Active Journey',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: onSurface,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: kMargin,
            vertical: 12,
          ),
          children: [
            // Live Telemetry Status Pill
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _nativeTrackingActive == true
                                ? kColorSafe
                                : kTertiary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _nativeTrackingActive == null
                                ? 'Checking tracking service…'
                                : journey.state ==
                                      JourneyState.destinationReached
                                ? 'Arrival alert · journey complete'
                                : !_nativeTrackingActive!
                                ? 'Tracking service unavailable'
                                : journey.currentDistanceMeters == null
                                ? 'Tracking active · Waiting for GPS'
                                : isLocationStale
                                ? 'Tracking active · Location update is stale'
                                : 'Tracking active · Location updates received',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Row(
                  children: [
                    Icon(Icons.satellite_alt, size: 16, color: primaryColor),
                    SizedBox(width: 4),
                    Text(
                      'GPS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: surfaceContainer,
                borderRadius: BorderRadius.circular(kRadiusLg),
              ),
              child: Row(
                children: [
                  Icon(
                    isLocationStale ? Icons.gps_off : Icons.gps_fixed,
                    color: isLocationStale ? kTertiary : kPrimary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          journey.locationAccuracyMeters == null
                              ? 'GPS accuracy unavailable'
                              : 'Accuracy ±${journey.locationAccuracyMeters!.round()} m',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          safeLocationAge == null
                              ? 'Waiting for the first location update'
                              : isLocationStale
                              ? 'Last update ${safeLocationAge.inSeconds} seconds ago'
                              : safeLocationAge.inSeconds < 2
                              ? 'Updated just now'
                              : 'Updated ${safeLocationAge.inSeconds} seconds ago',
                          style: const TextStyle(
                            fontSize: 13,
                            color: kOnSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (journey.speedKmh != null && !isLocationStale)
                    Text(
                      '${(distanceUnit == 'mi' ? journey.speedKmh! / 1.609344 : journey.speedKmh!).toStringAsFixed(0)} ${distanceUnit == 'mi' ? 'mi/h' : 'km/h'}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Primary Journey Vector Header
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DESTINATION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: outline,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        destName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                        textWidthBasis: TextWidthBasis.parent,
                        // Long place names share the available width with the marker.
                        //
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.place, size: 20, color: primaryColor),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Hero Remaining Distance Card
            Container(
              decoration: BoxDecoration(
                color: surfaceContainer,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: outlineVariant, width: 0.8),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      distanceKm,
                      style: const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        color: onSurface,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  const Text(
                    'Approximate straight-line distance to destination',
                    style: TextStyle(fontSize: 12, color: onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: kSurfaceLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.alarm_outlined, color: kPrimary),
                        const SizedBox(width: 10),
                        const Expanded(child: Text('Wake-up threshold')),
                        Text(
                          DistanceUtils.formatDistance(
                            journey.wakeUpMeters,
                            distanceUnit,
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: kPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Alert milestone card. A percentage would imply route progress,
            // but this product only knows straight-line proximity.
            Container(
              decoration: BoxDecoration(
                color: surfaceContainer,
                borderRadius: BorderRadius.circular(kRadiusLg),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x140D3732),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Alert milestones',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _MilestoneRow(
                    label: 'Early warning',
                    meters: journey.earlyWarningMeters,
                    currentMeters: journey.currentDistanceMeters,
                    unit: distanceUnit,
                  ),
                  _MilestoneRow(
                    label: 'Wake-up call',
                    meters: journey.wakeUpMeters,
                    currentMeters: journey.currentDistanceMeters,
                    unit: distanceUnit,
                    emphasized: true,
                  ),
                  _MilestoneRow(
                    label: 'Critical warning',
                    meters: journey.criticalMeters,
                    currentMeters: journey.currentDistanceMeters,
                    unit: distanceUnit,
                  ),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Straight-line proximity only • No route timetable',
                      style: TextStyle(fontSize: 11, color: onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Active Wake-Up Operational Alert Card
            if (!isAlertActive)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceContainer,
                  borderRadius: BorderRadius.circular(kRadiusLg),
                ),
                child: Row(
                  children: [
                    Icon(
                      _nativeTrackingActive == true
                          ? Icons.sensors
                          : Icons.warning_amber,
                      color: _nativeTrackingActive == true
                          ? primaryColor
                          : kTertiary,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _nativeTrackingActive == null
                            ? 'Checking whether background tracking is active.'
                            : _nativeTrackingActive == true
                            ? 'No proximity alert is active. Background monitoring is running.'
                            : _trackingServiceError ??
                                  'The journey is saved, but background tracking is not running.',
                        style: TextStyle(color: onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            if (!isAlertActive) const SizedBox(height: 14),
            if (isAlertActive)
              Container(
                decoration: BoxDecoration(
                  color: journey.state == JourneyState.criticalAlert
                      ? kErrorContainer
                      : kTertiaryFixed.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(kRadiusLg),
                  boxShadow: [
                    if (isAlertActive && !isSilenced)
                      BoxShadow(
                        color: kTertiary.withValues(alpha: 0.12),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: primaryColor.withValues(alpha: 0.15),
                          child: const Icon(
                            Icons.alarm_on,
                            color: primaryColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    journey.state ==
                                            JourneyState.destinationReached
                                        ? 'ARRIVAL'
                                        : journey.state ==
                                              JourneyState.criticalAlert
                                        ? 'CRITICAL ALERT'
                                        : 'WAKE-UP ALERT',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: kOnPrimary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  journey.state.displayName,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${journey.state.displayName} alert',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: onSurface,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You are approximately ${(journey.currentDistanceMeters ?? 0).round()} m from ${journey.destination.name}. Acknowledge when you are awake.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/alarm'),
                        icon: const Icon(Icons.open_in_full),
                        label: const Text('Open full alert'),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Acknowledge Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          ref.read(journeyProvider.notifier).acknowledgeAlert();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSilenced
                              ? surfaceContainerHighest
                              : primaryColor,
                          foregroundColor: isSilenced ? onSurface : kOnPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isSilenced ? Icons.task_alt : Icons.check_circle,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isSilenced
                                  ? 'Alarm Silenced • Tracking Continues'
                                  : "I'm Awake (Acknowledge Alert)",
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),

            // Destination map inset
            Container(
              decoration: BoxDecoration(
                color: surfaceContainer,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: outlineVariant, width: 0.8),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Row(
                        children: [
                          Icon(Icons.near_me, size: 16, color: primaryColor),
                          SizedBox(width: 6),
                          Text(
                            'Destination map',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: onSurface,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Online map tiles',
                        style: TextStyle(fontSize: 11, color: onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 150,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: maplibre.MapLibreMap(
                        initialCameraPosition: maplibre.CameraPosition(
                          target: maplibre.LatLng(
                            destCoords.latitude,
                            destCoords.longitude,
                          ),
                          zoom: 13,
                        ),
                        styleString: mapTiles.styleUrl,
                        compassEnabled: false,
                        scrollGesturesEnabled: false,
                        zoomGesturesEnabled: false,
                        rotateGesturesEnabled: false,
                        tiltGesturesEnabled: false,
                        onStyleLoadedCallback: () async {
                          final controller = insetMapController;
                          if (controller != null) {
                            await controller.addCircle(
                              maplibre.CircleOptions(
                                geometry: maplibre.LatLng(
                                  destCoords.latitude,
                                  destCoords.longitude,
                                ),
                                circleRadius: 9,
                                circleColor: '#006856',
                                circleStrokeColor: '#FFFFFF',
                                circleStrokeWidth: 2,
                              ),
                            );
                          }
                        },
                        onMapCreated: (controller) =>
                            insetMapController = controller,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Guarded Trip Termination CTA
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  if (!_isConfirmingAbort) {
                    setState(() => _isConfirmingAbort = true);
                    Future.delayed(const Duration(seconds: 4), () {
                      if (mounted) {
                        setState(() => _isConfirmingAbort = false);
                      }
                    });
                  } else {
                    ref.read(journeyProvider.notifier).stopJourney();
                    context.go('/');
                  }
                },
                icon: Icon(
                  _isConfirmingAbort ? Icons.warning : Icons.power_settings_new,
                  size: 18,
                  color: kError,
                ),
                label: Text(
                  _isConfirmingAbort
                      ? 'Tap Again to Confirm Disarm'
                      : 'End Tracking & Disarm Alarms',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: kError,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: _isConfirmingAbort
                      ? kErrorContainer
                      : surfaceContainerHighest,
                  side: const BorderSide(color: kError),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({
    required this.label,
    required this.meters,
    required this.currentMeters,
    required this.unit,
    this.emphasized = false,
  });
  final String label;
  final double meters;
  final double? currentMeters;
  final String unit;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final reached = currentMeters != null && currentMeters! <= meters;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            reached ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: reached ? kPrimary : kOutline,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
                color: kOnSurface,
              ),
            ),
          ),
          Text(
            DistanceUtils.formatDistance(meters, unit),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: emphasized ? kPrimary : kOnSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
