import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../app/theme.dart';
import '../../../core/database/database_helper.dart';
import '../../../platform/alarm_channel.dart';
import '../../home/providers/home_provider.dart';
import '../../journey/providers/journey_provider.dart';
import '../../journey/domain/journey_state.dart';
import '../data/settings_repository.dart';
import '../../alerts/domain/alert_configuration.dart';
import '../../../platform/tracking_channel.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(),
);

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  String _distanceUnit = 'km';
  int _volume = 85;
  bool _isPlayingPreview = false;
  double _earlyWarningMeters = 5000;
  double _wakeUpMeters = 2000;
  double _criticalMeters = 500;
  bool _soundEnabled = true;
  bool _vibrateEnabled = true;
  bool _voiceEnabled = true;
  bool _repeatUntilDismissed = true;
  String _ringtoneName = 'Device default alarm';
  bool? _locationGranted;
  bool? _locationServicesEnabled;
  bool? _notificationsGranted;
  bool? _batteryExemptionGranted;
  bool? _nativeTrackingActive;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
    _refreshSystemStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshSystemStatus();
  }

  Future<void> _refreshSystemStatus() async {
    try {
      final locationPermission = await Geolocator.checkPermission();
      final locationAccuracy = await Geolocator.getLocationAccuracy();
      final locationEnabled = await Geolocator.isLocationServiceEnabled();
      final notificationStatus = await Permission.notification.status;
      final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
      final tracking = await TrackingChannel.getTrackingStatus();
      if (!mounted) return;
      setState(() {
        _locationGranted =
            (locationPermission == LocationPermission.always ||
                locationPermission == LocationPermission.whileInUse) &&
            locationAccuracy == LocationAccuracyStatus.precise;
        _locationServicesEnabled = locationEnabled;
        _notificationsGranted = notificationStatus.isGranted;
        _batteryExemptionGranted = batteryStatus.isGranted;
        _nativeTrackingActive = tracking['active'] == true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationGranted ??= false;
        _locationServicesEnabled ??= false;
        _notificationsGranted ??= false;
        _batteryExemptionGranted ??= false;
        _nativeTrackingActive ??= false;
      });
    }
  }

  String _statusText(bool? status) => status == null
      ? 'Checking…'
      : status
      ? 'Ready'
      : 'Needs attention';

  String _batteryStatusText(bool? status) => status == null
      ? 'Checking…'
      : status
      ? 'Unrestricted'
      : 'Battery optimization active';

  Future<void> _manageLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
    } else {
      var status = await Geolocator.checkPermission();
      if (status == LocationPermission.denied) {
        status = await Geolocator.requestPermission();
      }
      final accuracy = await Geolocator.getLocationAccuracy();
      if (status == LocationPermission.deniedForever ||
          accuracy == LocationAccuracyStatus.reduced) {
        await openAppSettings();
      }
    }
    await _refreshSystemStatus();
  }

  Future<void> _manageNotificationPermission() async {
    final status = await Permission.notification.request();
    if (status.isPermanentlyDenied || status.isRestricted) {
      await openAppSettings();
    }
    await _refreshSystemStatus();
  }

  Future<void> _manageBatteryRestrictions() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    if (!status.isGranted) {
      await openAppSettings();
    }
    await _refreshSystemStatus();
  }

  Future<void> _showDndExplanation() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Do Not Disturb'),
        content: const Text(
          'WakeMeThere does not change or bypass Android Do Not Disturb. Alarm delivery depends on your device’s alarm and DND configuration. Review Android sound settings and test an alarm before travelling.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.maybeOf(context);
              Navigator.pop(dialogContext);
              try {
                await AlarmChannel.openDoNotDisturbSettings();
              } catch (error) {
                if (messenger?.mounted == true) {
                  messenger!.showSnackBar(
                    SnackBar(content: Text(error.toString())),
                  );
                }
              }
            },
            child: const Text('Open Android settings'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSettings() async {
    final repo = ref.read(settingsRepositoryProvider);
    final unit = await repo.getDistanceUnit();
    final vol = await repo.getVolume();
    final alerts = await repo.loadAlertConfig();
    final voice = await repo.getVoiceEnabled();
    final repeat = await repo.getRepeatUntilDismissed();
    var ringtoneName = 'Device default alarm';
    try {
      ringtoneName = await AlarmChannel.getAlarmRingtoneName();
    } catch (_) {
      // Keep the rest of the settings available if the native channel fails.
    }
    if (mounted) {
      setState(() {
        _distanceUnit = unit;
        _volume = vol;
        _earlyWarningMeters = alerts.earlyWarningMeters;
        _wakeUpMeters = alerts.wakeUpMeters;
        _criticalMeters = alerts.criticalMeters;
        _soundEnabled = alerts.soundOnAlert;
        _vibrateEnabled = alerts.vibrateOnAlert;
        _voiceEnabled = voice;
        _repeatUntilDismissed = repeat;
        _ringtoneName = ringtoneName;
      });
      ref.read(distanceUnitProvider.notifier).state = unit;
    }
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _clearDestinations() async {
    if (!await _confirm(
      'Clear saved destinations?',
      'This removes saved places from this device.',
    )) {
      return;
    }
    await ref.read(destinationRepositoryProvider).clearAll();
    ref.invalidate(savedDestinationsProvider);
  }

  Future<void> _resetLocalData() async {
    if (!await _confirm(
      'Reset local data?',
      'This deletes saved places, journey history, and app preferences from this device.',
    )) {
      return;
    }
    if (ref.read(journeyProvider) != null) {
      await ref.read(journeyProvider.notifier).stopJourney();
    }
    await DatabaseHelper.instance.clearAllData();
    await ref.read(settingsRepositoryProvider).clear();
    try {
      await AlarmChannel.clearSelectedAlarmRingtone();
    } catch (_) {
      // Clearing other local data should still complete if native is absent.
    }
    ref.invalidate(savedDestinationsProvider);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Local data cleared.')));
    }
  }

  Future<void> _previewAlarm() async {
    if (_isPlayingPreview) {
      await AlarmChannel.stopAlarm();
      if (mounted) setState(() => _isPlayingPreview = false);
      return;
    }
    setState(() => _isPlayingPreview = true);
    try {
      await AlarmChannel.playAlarm(volume: _volume / 100);
      await Future<void>.delayed(const Duration(seconds: 3));
    } finally {
      await AlarmChannel.stopAlarm();
      if (mounted) setState(() => _isPlayingPreview = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentJourney = ref.watch(journeyProvider);
    final alarmPreviewAvailable =
        currentJourney == null ||
        (!currentJourney.state.isActive &&
            currentJourney.state != JourneyState.destinationReached);
    final trackingStatus = currentJourney?.state.isActive == true
        ? _statusText(_nativeTrackingActive)
        : 'Not running';
    const primaryColor = kPrimary;
    const surfaceColor = kAppBackground;
    const surfaceContainer = kSurfaceLowest;
    const surfaceContainerHigh = kSurfaceLow;
    const onSurface = kOnSurface;
    const onSurfaceVariant = kOnSurfaceVariant;
    const outline = kOutline;
    const outlineVariant = kOutlineVariant;

    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: onSurface,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: kMargin,
                  vertical: 8,
                ),
                children: [
                  // Guardian Active Banner
                  Container(
                    decoration: BoxDecoration(
                      color: surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: outlineVariant, width: 0.8),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 8,
                          backgroundColor: primaryColor.withValues(alpha: 0.2),
                          child: const CircleAvatar(
                            radius: 4,
                            backgroundColor: primaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'WakeMeThere Settings',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: onSurface,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(
                                  Icons.verified,
                                  size: 16,
                                  color: primaryColor,
                                ),
                              ],
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Review location and battery settings before each trip',
                              style: TextStyle(
                                fontSize: 11,
                                color: onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Section 1: General Experience
                  const Text(
                    'GENERAL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: outline,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: outlineVariant, width: 0.8),
                    ),
                    child: Column(
                      children: [
                        _buildSettingRow(
                          icon: Icons.palette_outlined,
                          title: 'Appearance',
                          subtitle: 'Dark theme is not available in this build',
                          trailing: const Text(
                            'Light only',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                          ),
                        ),
                        const Divider(height: 1, color: outlineVariant),
                        _buildSettingRow(
                          icon: Icons.straighten,
                          title: 'Distance Units',
                          trailing: Container(
                            decoration: BoxDecoration(
                              color: surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.all(2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _UnitButton(
                                  label: 'km',
                                  isSelected: _distanceUnit == 'km',
                                  onTap: () {
                                    setState(() => _distanceUnit = 'km');
                                    ref
                                            .read(distanceUnitProvider.notifier)
                                            .state =
                                        'km';
                                    ref
                                        .read(settingsRepositoryProvider)
                                        .setDistanceUnit('km');
                                  },
                                ),
                                _UnitButton(
                                  label: 'mi',
                                  isSelected: _distanceUnit == 'mi',
                                  onTap: () {
                                    setState(() => _distanceUnit = 'mi');
                                    ref
                                            .read(distanceUnitProvider.notifier)
                                            .state =
                                        'mi';
                                    ref
                                        .read(settingsRepositoryProvider)
                                        .setDistanceUnit('mi');
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 1, color: outlineVariant),
                        _buildSettingRow(
                          icon: Icons.layers_outlined,
                          title: 'Map style',
                          subtitle:
                              'MapLibre vector style; no alternate styles are available',
                          trailing: const Text(
                            'Fixed',
                            style: TextStyle(
                              fontSize: 12,
                              color: onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Section 2: Default Alert Perimeters
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'DEFAULT JOURNEY ALERTS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: outline,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        'Used in journey setup',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: outlineVariant, width: 0.8),
                    ),
                    child: Column(
                      children: [
                        _buildEditableThresholdRow(
                          icon: Icons.notifications_paused_outlined,
                          iconColor: kSecondary,
                          title: 'Early Warning',
                          subtitle: 'Voice and vibration when enabled',
                          value: _earlyWarningMeters,
                          badgeColor: kPrimary,
                          min: 1000,
                          max: 15000,
                          onChanged: (v) => _saveAlertConfig(early: v),
                        ),
                        const Divider(height: 1, color: outlineVariant),
                        _buildEditableThresholdRow(
                          icon: Icons.alarm,
                          iconColor: primaryColor,
                          title: 'Wake-Up Call',
                          subtitle: 'Sound, voice, and vibration when enabled',
                          value: _wakeUpMeters,
                          badgeColor: primaryColor,
                          min: 500,
                          max: 5000,
                          onChanged: (v) => _saveAlertConfig(wake: v),
                        ),
                        const Divider(height: 1, color: outlineVariant),
                        _buildEditableThresholdRow(
                          icon: Icons.emergency_outlined,
                          iconColor: kTertiary,
                          title: 'Critical Warning',
                          subtitle: 'Final proximity alert',
                          value: _criticalMeters,
                          badgeColor: kTertiary,
                          min: 200,
                          max: 1000,
                          onChanged: (v) => _saveAlertConfig(critical: v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Section 3: Audio & Wake Cues
                  const Text(
                    'SOUND & WAKE-UP',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: outline,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: outlineVariant, width: 0.8),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: const [
                                      Icon(
                                        Icons.volume_up,
                                        size: 18,
                                        color: onSurfaceVariant,
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        'Alarm Volume',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '$_volume%',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: primaryColor,
                                  inactiveTrackColor: surfaceContainerHigh,
                                  thumbColor: primaryColor,
                                  trackHeight: 3,
                                ),
                                child: Slider(
                                  value: _volume.toDouble(),
                                  min: 10,
                                  max: 100,
                                  onChanged: (val) {
                                    setState(() => _volume = val.toInt());
                                    ref
                                        .read(settingsRepositoryProvider)
                                        .setVolume(val.toInt());
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: outlineVariant),
                        _buildSettingRow(
                          icon: Icons.notifications_active_outlined,
                          title: 'Audible alarm',
                          trailing: Switch(
                            value: _soundEnabled,
                            onChanged: (value) {
                              setState(() => _soundEnabled = value);
                              _saveAlertConfig();
                            },
                          ),
                        ),
                        const Divider(height: 1, color: outlineVariant),
                        _buildSettingRow(
                          icon: Icons.vibration,
                          title: 'Vibration',
                          trailing: Switch(
                            value: _vibrateEnabled,
                            onChanged: (value) {
                              setState(() => _vibrateEnabled = value);
                              _saveAlertConfig();
                            },
                          ),
                        ),
                        const Divider(height: 1, color: outlineVariant),
                        _buildSettingRow(
                          icon: Icons.do_not_disturb_on_outlined,
                          title: 'Do Not Disturb',
                          subtitle:
                              'Android may silence alarms under DND; WakeMeThere cannot override it',
                          onTap: _showDndExplanation,
                          trailing: const Text(
                            'Device controlled',
                            style: TextStyle(
                              fontSize: 11,
                              color: onSurfaceVariant,
                            ),
                          ),
                        ),
                        const Divider(height: 1, color: outlineVariant),
                        _buildSettingRow(
                          icon: Icons.music_note_outlined,
                          title: 'Ringtone',
                          subtitle: _ringtoneName,
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                tooltip: _isPlayingPreview
                                    ? 'Stop preview'
                                    : 'Preview alarm',
                                onPressed: alarmPreviewAvailable
                                    ? _previewAlarm
                                    : null,
                                icon: Icon(
                                  _isPlayingPreview
                                      ? Icons.stop
                                      : Icons.play_arrow,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Choose alarm sound',
                                onPressed: () async {
                                  try {
                                    final selectedName =
                                        await AlarmChannel.pickAlarmRingtone();
                                    if (selectedName != null && mounted) {
                                      setState(
                                        () => _ringtoneName = selectedName,
                                      );
                                    }
                                  } catch (error) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(error.toString())),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.library_music_outlined),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: outlineVariant),
                        _buildSettingRow(
                          icon: Icons.record_voice_over,
                          title: 'Voice Announcement',
                          subtitle: 'Device text-to-speech during a journey',
                          trailing: Switch(
                            value: _voiceEnabled,
                            onChanged: (value) async {
                              setState(() => _voiceEnabled = value);
                              await ref
                                  .read(settingsRepositoryProvider)
                                  .setVoiceEnabled(value);
                            },
                          ),
                        ),
                        const Divider(height: 1, color: outlineVariant),
                        _buildSettingRow(
                          icon: Icons.touch_app_outlined,
                          title: 'Repeat until dismissed',
                          subtitle:
                              'Keep the alarm sounding until acknowledged',
                          trailing: Switch(
                            value: _repeatUntilDismissed,
                            onChanged: (value) async {
                              setState(() => _repeatUntilDismissed = value);
                              await ref
                                  .read(settingsRepositoryProvider)
                                  .setRepeatUntilDismissed(value);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Section 4: Permissions & System Health
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'PERMISSIONS & RELIABILITY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: outline,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 3,
                            backgroundColor: primaryColor,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Review before travel',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: outlineVariant, width: 0.8),
                    ),
                    child: Column(
                      children: [
                        _buildHealthRow(
                          title: 'Location permission',
                          subtitle: _statusText(_locationGranted),
                          onTap: _manageLocationPermission,
                        ),
                        const Divider(height: 1, color: outlineVariant),
                        _buildHealthRow(
                          title: 'Location services',
                          subtitle: _statusText(_locationServicesEnabled),
                          onTap: () async {
                            await Geolocator.openLocationSettings();
                            await _refreshSystemStatus();
                          },
                        ),
                        const Divider(height: 1, color: outlineVariant),
                        _buildHealthRow(
                          title: 'Notifications',
                          subtitle: _statusText(_notificationsGranted),
                          onTap: _manageNotificationPermission,
                        ),
                        const Divider(height: 1, color: outlineVariant),
                        _buildHealthRow(
                          title: 'Background tracking',
                          subtitle: trackingStatus,
                          onTap: _refreshSystemStatus,
                        ),
                        const Divider(height: 1, color: outlineVariant),
                        _buildHealthRow(
                          title: 'Battery restrictions',
                          subtitle: _batteryStatusText(
                            _batteryExemptionGranted,
                          ),
                          onTap: _manageBatteryRestrictions,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Section 5: Privacy & Local Data
                  const Text(
                    'PRIVACY & LOCAL DATA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: outline,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: outlineVariant, width: 0.8),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Icon(
                                Icons.lock_person,
                                size: 20,
                                color: primaryColor,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Location stored on this device',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: onSurface,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'GPS fixes, journey history, and saved places stay local. Search terms are sent to Photon by Komoot, and selected map coordinates are sent only for reverse geocoding. Current GPS is not sent as search bias. Recent geocoding results are cached on this device.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: outlineVariant),
                        ListTile(
                          title: const Text(
                            'Clear Saved Destinations',
                            style: TextStyle(fontSize: 13, color: onSurface),
                          ),
                          trailing: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: outline,
                          ),
                          onTap: _clearDestinations,
                        ),
                        const Divider(height: 1, color: outlineVariant),
                        ListTile(
                          title: const Text(
                            'Reset All Local Data',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: kError,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: kError,
                          ),
                          onTap: _resetLocalData,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // About Footer
                  Center(
                    child: Column(
                      children: const [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: surfaceContainer,
                          child: Icon(
                            Icons.explore,
                            size: 20,
                            color: primaryColor,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'WakeMeThere',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: onSurface,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Version 2.4.0 (Build 128)',
                          style: TextStyle(fontSize: 11, color: outline),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'OpenStreetMap & MapLibre GL Attributions',
                          style: TextStyle(fontSize: 10, color: outlineVariant),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '"Rest well. Wake precisely at your platform."',
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            const AppBottomNav(currentIndex: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    const onSurface = kOnSurface;
    const onSurfaceVariant = kOnSurfaceVariant;
    const outline = kOutline;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: onSurface,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: outline),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveAlertConfig({
    double? early,
    double? wake,
    double? critical,
  }) async {
    var nextEarly = early ?? _earlyWarningMeters;
    var nextWake = wake ?? _wakeUpMeters;
    var nextCritical = critical ?? _criticalMeters;
    if (nextWake <= nextCritical) {
      nextWake = (nextCritical + 200).clamp(500, 5000).toDouble();
      if (nextWake <= nextCritical) {
        nextCritical = (nextWake - 200).clamp(200, 1000).toDouble();
      }
    }
    if (nextEarly <= nextWake) {
      nextEarly = (nextWake + 500).clamp(1000, 15000).toDouble();
      if (nextEarly <= nextWake) {
        nextWake = (nextEarly - 500).clamp(500, 5000).toDouble();
      }
    }
    setState(() {
      _earlyWarningMeters = nextEarly;
      _wakeUpMeters = nextWake;
      _criticalMeters = nextCritical;
    });
    await ref
        .read(settingsRepositoryProvider)
        .saveAlertConfig(
          AlertConfiguration(
            earlyWarningMeters: nextEarly,
            wakeUpMeters: nextWake,
            criticalMeters: nextCritical,
            soundOnAlert: _soundEnabled,
            vibrateOnAlert: _vibrateEnabled,
          ),
        );
  }

  Widget _buildEditableThresholdRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required Color badgeColor,
    required ValueChanged<double> onChanged,
  }) {
    final display = value >= 1000
        ? '${(value / 1000).toStringAsFixed(1)} km'
        : '${value.toInt()} m';
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: kOnSurface,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: kSurfaceHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  display,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: kOutline)),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: ((max - min) / 100).round(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildHealthRow({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    const onSurface = kOnSurface;
    const outline = kOutline;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kRadiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: outline),
                  ),
                ],
              ),
            ),
            Icon(
              subtitle == 'Ready' ? Icons.check_circle : Icons.chevron_right,
              size: 18,
              color: subtitle == 'Ready' ? kPrimary : kTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitButton extends StatelessWidget {
  const _UnitButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const primaryColor = kPrimary;
    const onSurfaceVariant = kOnSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? kOnPrimary : onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
