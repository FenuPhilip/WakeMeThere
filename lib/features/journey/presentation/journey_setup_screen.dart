import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../app/theme.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/utils/distance_utils.dart';
import '../../destination/domain/destination.dart';
import '../providers/journey_provider.dart';
import '../../settings/data/settings_repository.dart';
import '../../home/providers/home_provider.dart';
import '../../map/domain/map_tile_provider.dart';

class JourneySetupScreen extends ConsumerStatefulWidget {
  const JourneySetupScreen({super.key, this.destination});

  final Destination? destination;

  @override
  ConsumerState<JourneySetupScreen> createState() => _JourneySetupScreenState();
}

class _JourneySetupScreenState extends ConsumerState<JourneySetupScreen> {
  late Destination _destination;

  double _earlyWarningKm = 5.0;
  double _wakeUpKm = 2.0;
  double _criticalMeters = 500.0;

  bool _audibleAlarm = true;
  bool _voiceAnnouncement = true;
  bool _hapticVibration = true;
  bool _alertUntilDismissed = true;
  bool _starting = false;
  double _alarmVolume = 0.85;
  bool? _locationGranted;
  bool? _locationEnabled;
  bool? _notificationsGranted;
  bool? _batteryExemptionGranted;

  @override
  void initState() {
    super.initState();
    _wakeUpKm = ref.read(wakeBufferDistanceProvider);
    if (_wakeUpKm >= _earlyWarningKm) _earlyWarningKm = _wakeUpKm + 0.5;
    _destination =
        widget.destination ??
        const Destination(
          name: 'Select a destination',
          coordinates: LatLng(0, 0),
        );
    _loadPreferences();
    _checkReadiness();
  }

  Future<void> _checkReadiness() async {
    try {
      final locationPermission = await Geolocator.checkPermission();
      final locationAccuracy = await Geolocator.getLocationAccuracy();
      final locationEnabled = await Geolocator.isLocationServiceEnabled();
      final notifications = await Permission.notification.status;
      final battery = await Permission.ignoreBatteryOptimizations.status;
      if (!mounted) return;
      setState(() {
        _locationGranted =
            (locationPermission == LocationPermission.always ||
                locationPermission == LocationPermission.whileInUse) &&
            locationAccuracy == LocationAccuracyStatus.precise;
        _locationEnabled = locationEnabled;
        _notificationsGranted = notifications.isGranted;
        _batteryExemptionGranted = battery.isGranted;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationGranted ??= false;
        _locationEnabled ??= false;
        _notificationsGranted ??= false;
        _batteryExemptionGranted ??= false;
      });
    }
  }

  String _readinessText(bool? status) => status == null
      ? 'Checking…'
      : status
      ? 'Ready'
      : 'Needs attention';

  String _batteryReadinessText(bool? status) => status == null
      ? 'Checking…'
      : status
      ? 'Unrestricted'
      : 'Optimization enabled';

  Future<void> _loadPreferences() async {
    final repo = SettingsRepository();
    final volume = await repo.getVolume();
    final alerts = await repo.loadAlertConfig();
    final voice = await repo.getVoiceEnabled();
    final repeat = await repo.getRepeatUntilDismissed();
    if (!mounted) return;
    setState(() {
      _alarmVolume = volume / 100;
      _earlyWarningKm = alerts.earlyWarningMeters / 1000;
      _wakeUpKm = alerts.wakeUpMeters / 1000;
      _criticalMeters = alerts.criticalMeters;
      _audibleAlarm = alerts.soundOnAlert;
      _hapticVibration = alerts.vibrateOnAlert;
      _voiceAnnouncement = voice;
      _alertUntilDismissed = repeat;
    });
  }

  Future<void> _startJourney() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      await ref
          .read(journeyProvider.notifier)
          .startJourney(
            destination: _destination,
            earlyWarningMeters: _earlyWarningKm * 1000,
            wakeUpMeters: _wakeUpKm * 1000,
            criticalMeters: _criticalMeters,
            soundEnabled: _audibleAlarm,
            voiceEnabled: _voiceAnnouncement,
            vibrationEnabled: _hapticVibration,
            repeatUntilDismissed: _alertUntilDismissed,
            alarmVolume: _alarmVolume,
          );

      if (mounted) context.go('/active-journey');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = kPrimary;
    const surfaceColor = kAppBackground;
    const surfaceContainer = kSurfaceLowest;
    const surfaceContainerHigh = kSurfaceHigh;
    const surfaceContainerHighest = kSurfaceHighest;
    const onSurface = kOnSurface;
    const onSurfaceVariant = kOnSurfaceVariant;
    const outline = kOutline;
    const outlineVariant = kOutlineVariant;

    final distanceUnit = ref.watch(distanceUnitProvider);
    final mapTiles = ref.watch(mapTileProvider);
    final distanceDisplay = _destination.distanceMeters == null
        ? 'Distance starts after GPS fix'
        : DistanceUtils.formatDistance(
            _destination.distanceMeters!,
            distanceUnit,
          );

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
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Journey Setup',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: onSurface,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: kMargin,
                  vertical: 8,
                ),
                children: [
                  // Destination Summary Card
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Live Pin Badge
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 3,
                                    backgroundColor: primaryColor,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Destination Locked',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: surfaceContainerHigh,
                              child: const Icon(
                                Icons.train,
                                color: primaryColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _destination.name,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: onSurface,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _destination.address ?? 'Destination',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: onSurfaceVariant,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          distanceDisplay,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: primaryColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Flexible(
                                        child: Text(
                                          'Straight-line estimate • no route ETA',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () => context.pop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: onSurface,
                                side: const BorderSide(color: outlineVariant),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                minimumSize: Size.zero,
                              ),
                              child: const Text('Edit'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(kRadiusMd),
                          child: SizedBox(
                            height: 96,
                            child: Stack(
                              children: [
                                maplibre.MapLibreMap(
                                  initialCameraPosition:
                                      maplibre.CameraPosition(
                                        target: maplibre.LatLng(
                                          _destination.coordinates.latitude,
                                          _destination.coordinates.longitude,
                                        ),
                                        zoom: 11,
                                      ),
                                  styleString: mapTiles.styleUrl,
                                  compassEnabled: false,
                                  scrollGesturesEnabled: false,
                                  zoomGesturesEnabled: false,
                                  rotateGesturesEnabled: false,
                                  tiltGesturesEnabled: false,
                                ),
                                const Center(
                                  child: Icon(
                                    Icons.location_pin,
                                    color: kPrimary,
                                    size: 28,
                                  ),
                                ),
                                Positioned(
                                  left: 8,
                                  bottom: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: const BoxDecoration(
                                      color: kSurfaceLowest,
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(kRadiusFull),
                                      ),
                                    ),
                                    child: const Text(
                                      'Geo-fence perimeter active',
                                      style: TextStyle(
                                        color: kPrimary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Section 1: Wake-Up Milestones (3-Tier Guard)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'WAKE-UP MILESTONES',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: outline,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        '3-Tier Guard',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 1. Early Warning Card
                  _buildMilestoneCard(
                    icon: Icons.backpack_outlined,
                    iconColor: onSurfaceVariant,
                    title: 'Early Warning',
                    subtitle: 'Gentle reminder to pack belongings',
                    valueText: '${_earlyWarningKm.toStringAsFixed(1)} km',
                    minText: '1 km',
                    maxText: '15 km',
                    sliderValue: _earlyWarningKm,
                    min: 1.0,
                    max: 15.0,
                    divisions: 28,
                    onChanged: (val) => setState(
                      () => _earlyWarningKm = val < _wakeUpKm + 0.5
                          ? _wakeUpKm + 0.5
                          : val,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 2. Wake-Up Call Card
                  _buildMilestoneCard(
                    icon: Icons.alarm,
                    iconColor: primaryColor,
                    title: 'Wake-Up Call',
                    subtitle: 'Main alarm to wake up and get ready',
                    valueText: '${_wakeUpKm.toStringAsFixed(1)} km',
                    minText: '0.5 km',
                    maxText: '5.0 km',
                    sliderValue: _wakeUpKm,
                    min: 0.5,
                    max: 5.0,
                    divisions: 45,
                    highlightValue: true,
                    onChanged: (val) => setState(() {
                      _wakeUpKm = val;
                      if (_wakeUpKm >= _earlyWarningKm) {
                        _earlyWarningKm = _wakeUpKm + 0.5;
                      }
                      if (_wakeUpKm * 1000 <= _criticalMeters + 100) {
                        _criticalMeters = _wakeUpKm * 1000 - 200;
                      }
                    }),
                  ),
                  const SizedBox(height: 10),

                  // 3. Critical Warning Card
                  _buildMilestoneCard(
                    icon: Icons.notification_important_outlined,
                    iconColor: kColorCritical,
                    title: 'Critical Warning',
                    subtitle: 'Final reminder before your stop',
                    valueText: '${_criticalMeters.toInt()} m',
                    minText: '200m',
                    maxText: '1 km',
                    sliderValue: _criticalMeters,
                    min: 200.0,
                    max: 1000.0,
                    divisions: 16,
                    onChanged: (val) => setState(
                      () => _criticalMeters = val >= _wakeUpKm * 1000 - 100
                          ? _wakeUpKm * 1000 - 200
                          : val,
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Section 2: How We Alert You
                  const Text(
                    'HOW WE ALERT YOU',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: outline,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
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
                    child: Column(
                      children: [
                        _buildSwitchTile(
                          icon: Icons.volume_up,
                          iconColor: primaryColor,
                          title: 'Audible Alarm',
                          subtitle: 'Uses the device alarm audio stream',
                          value: _audibleAlarm,
                          onChanged: (v) => setState(() => _audibleAlarm = v),
                        ),
                        const Divider(height: 1, color: outlineVariant),
                        _buildSwitchTile(
                          icon: Icons.record_voice_over,
                          iconColor: kTertiary,
                          title: 'Voice Announcement',
                          subtitle: '“Your destination is approaching”',
                          value: _voiceAnnouncement,
                          onChanged: (v) =>
                              setState(() => _voiceAnnouncement = v),
                        ),
                        const Divider(height: 1, color: outlineVariant),
                        _buildSwitchTile(
                          icon: Icons.vibration,
                          iconColor: kColorAdvisory,
                          title: 'Haptic Vibration',
                          subtitle: 'Strong pulse pattern',
                          value: _hapticVibration,
                          onChanged: (v) =>
                              setState(() => _hapticVibration = v),
                        ),
                        const Divider(height: 1, color: outlineVariant),
                        _buildSwitchTile(
                          icon: Icons.sync,
                          iconColor: primaryColor,
                          title: 'Alert Until Dismissed',
                          subtitle: 'Looping alarm requiring action',
                          value: _alertUntilDismissed,
                          onChanged: (v) =>
                              setState(() => _alertUntilDismissed = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Section 3: Readiness Checklist
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'SYSTEM READINESS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: outline,
                          letterSpacing: 0.8,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _checkReadiness,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Refresh checks'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
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
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        _ReadinessItem(
                          title: 'Location access',
                          status: _readinessText(_locationGranted),
                        ),
                        const SizedBox(height: 10),
                        _ReadinessItem(
                          title: 'Location services',
                          status: _readinessText(_locationEnabled),
                        ),
                        const SizedBox(height: 10),
                        _ReadinessItem(
                          title: 'Notifications',
                          status: _readinessText(_notificationsGranted),
                        ),
                        const SizedBox(height: 10),
                        _ReadinessItem(
                          title: 'Battery optimization',
                          status: _batteryReadinessText(
                            _batteryExemptionGranted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Bottom Fixed Action Area
            Container(
              padding: const EdgeInsets.fromLTRB(kMargin, 12, kMargin, 10),
              decoration: const BoxDecoration(
                color: kSurfaceLowest,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x140D3732),
                    blurRadius: 12,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _starting ? null : _startJourney,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: kOnPrimary,
                        shape: const StadiumBorder(),
                        elevation: 1,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_starting)
                            SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            const Icon(Icons.near_me, size: 20),
                          SizedBox(width: 8),
                          Text(
                            _starting ? 'Starting…' : 'Start Journey',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline, size: 14, color: outline),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Tracking runs in an Android foreground service. GPS and battery settings affect reliability.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMilestoneCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String valueText,
    required String minText,
    required String maxText,
    required double sliderValue,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    bool highlightValue = false,
  }) {
    const surfaceContainerHigh = kSurfaceHigh;
    const primaryColor = kPrimary;
    const onSurface = kOnSurface;
    const onSurfaceVariant = kOnSurfaceVariant;
    const outline = kOutline;

    return Container(
      decoration: kLayer1Decoration,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: surfaceContainerHigh,
                      child: Icon(icon, size: 16, color: iconColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: onSurface,
                            ),
                          ),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: highlightValue
                      ? primaryColor.withValues(alpha: 0.15)
                      : surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  valueText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: highlightValue ? primaryColor : onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                minText,
                style: const TextStyle(fontSize: 11, color: outline),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: primaryColor,
                    inactiveTrackColor: surfaceContainerHigh,
                    thumbColor: primaryColor,
                    overlayColor: primaryColor.withValues(alpha: 0.2),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: sliderValue,
                    min: min,
                    max: max,
                    divisions: divisions,
                    onChanged: onChanged,
                  ),
                ),
              ),
              Text(
                maxText,
                style: const TextStyle(fontSize: 11, color: outline),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    const surfaceContainerHigh = kSurfaceHigh;
    const primaryColor = kPrimary;
    const onSurface = kOnSurface;
    const onSurfaceVariant = kOnSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: surfaceContainerHigh,
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: onSurface,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: primaryColor,
            activeTrackColor: primaryColor.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}

class _ReadinessItem extends StatelessWidget {
  const _ReadinessItem({required this.title, required this.status});

  final String title;
  final String status;

  @override
  Widget build(BuildContext context) {
    const onSurface = kOnSurface;
    final ready = status == 'Ready';
    final statusColor = ready ? kPrimary : kTertiary;

    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              CircleAvatar(
                radius: 9,
                backgroundColor: statusColor.withValues(alpha: 0.16),
                child: Icon(Icons.info_outline, size: 12, color: statusColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: onSurface),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ),
      ],
    );
  }
}
