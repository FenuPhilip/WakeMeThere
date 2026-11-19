import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/utils/distance_utils.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../destination/domain/destination.dart';
import '../../destination/domain/place_search_provider.dart';
import '../../destination/data/photon_place_search_provider.dart';
import '../../journey/domain/journey_state.dart';
import '../../journey/providers/journey_provider.dart';
import '../../settings/data/settings_repository.dart';
import '../../../platform/tracking_channel.dart';
import '../providers/home_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool? _nativeTrackingActive;
  Timer? _trackingStatusTimer;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<Destination> _searchResults = const [];
  bool _searching = false;
  bool _showSearchResults = false;
  String? _searchError;
  int _searchRequestId = 0;

  @override
  void initState() {
    super.initState();
    _refreshTrackingStatus();
    _trackingStatusTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refreshTrackingStatus(),
    );
    SettingsRepository().getDistanceUnit().then((unit) {
      if (mounted) ref.read(distanceUnitProvider.notifier).state = unit;
    });
  }

  @override
  void dispose() {
    _trackingStatusTimer?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onHomeSearchChanged(String query) {
    _searchDebounce?.cancel();
    // Invalidate any request already in flight when the user edits or clears
    // the field, so an older response cannot repopulate stale results.
    _searchRequestId++;
    setState(() {
      _showSearchResults = true;
      _searchError = null;
      if (query.trim().length < 3) {
        _searchResults = const [];
        _searching = false;
      }
    });
    if (query.trim().length < 3) return;
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      _searchHome(query);
    });
  }

  Future<void> _searchHome(String query) async {
    if (query.trim().length < 3) return;
    final requestId = ++_searchRequestId;
    if (mounted) setState(() => _searching = true);
    try {
      final saved = await ref.read(destinationRepositoryProvider).getAll();
      final normalized = query.trim().toLowerCase();
      final results = saved.where((destination) =>
        destination.name.toLowerCase().contains(normalized) ||
        (destination.address?.toLowerCase().contains(normalized) ?? false),
      ).toList();
      try {
        final online = await ref.read(placeSearchProvider).search(query);
        for (final destination in online) {
          final duplicate = results.any((existing) =>
            existing.name.toLowerCase() == destination.name.toLowerCase() ||
            ((existing.coordinates.latitude - destination.coordinates.latitude).abs() < 0.0001 &&
              (existing.coordinates.longitude - destination.coordinates.longitude).abs() < 0.0001),
          );
          if (!duplicate) results.add(destination);
        }
      } on PlaceSearchException catch (error) {
        if (results.isEmpty) _searchError = error.message;
      }
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _searchResults = results.take(6).toList();
        _searching = false;
      });
    } catch (_) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _searching = false;
        _searchError = 'Search is temporarily unavailable.';
      });
    }
  }

  void _openSearchResult(Destination destination) {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _showSearchResults = false;
      _searchResults = const [];
    });
    context.push('/journey-setup', extra: destination);
  }

  Future<void> _refreshTrackingStatus() async {
    try {
      final status = await TrackingChannel.getTrackingStatus();
      if (mounted) {
        setState(() => _nativeTrackingActive = status['active'] == true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _nativeTrackingActive = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final journey = ref.watch(journeyProvider);
    final unit = ref.watch(distanceUnitProvider);
    final destinations = ref.watch(savedDestinationsProvider);
    final trackingError = ref.watch(trackingErrorProvider);
    final isTracking =
        journey?.state.isActive == true && _nativeTrackingActive == true;

    return Scaffold(
      backgroundColor: kAppBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(kMargin, 12, kMargin, 24),
                children: [
                  _buildBrandHeader(context),
                  const SizedBox(height: 20),
                  if (trackingError != null) ...[
                    _InfoBanner(
                      icon: Icons.error_outline,
                      color: kError,
                      text: 'Tracking stopped: $trackingError',
                    ),
                    const SizedBox(height: 14),
                  ],
                  _buildLocationStatus(
                    hasJourney: journey != null,
                    isTracking: isTracking,
                    arrived: journey?.state == JourneyState.destinationReached,
                  ),
                  const SizedBox(height: 24),
                  _buildSearchEntry(context),
                  if (_showSearchResults) _buildHomeSearchResults(context),
                  const SizedBox(height: 10),
                  _buildMapEntry(context),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('JOURNEY TRACKER', style: _sectionLabel),
                      if (journey != null)
                        TextButton.icon(
                          onPressed: () => context.push('/active-journey'),
                          icon: const Icon(Icons.swap_horiz, size: 18),
                          label: const Text('View Active Journey'),
                          style: TextButton.styleFrom(
                            backgroundColor: kSurfaceLowest,
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  journey == null
                      ? _buildEmptyJourneyCard(context)
                      : _buildActiveJourneyCard(
                          context,
                          journey,
                          unit,
                          trackingActive: _nativeTrackingActive,
                        ),
                  const SizedBox(height: 28),
                  Text(
                    'Saved Destinations',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _sectionHeading,
                  ),
                  const SizedBox(height: 12),
                  destinations.when(
                    data: (items) => items.isEmpty
                        ? _buildNoDestinations(context)
                        : _buildDestinationsGrid(context, items),
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, __) => const _InfoBanner(
                      icon: Icons.info_outline,
                      color: kSecondary,
                      text: 'Saved destinations could not be loaded.',
                    ),
                  ),
                ],
              ),
            ),
            const AppBottomNav(currentIndex: 0),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandHeader(BuildContext context) => Row(
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
          color: kSurfaceLow,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.navigation, color: kPrimary, size: 21),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('WakeMeThere', style: _brandTitle),
            Text('Never miss your stop', style: _brandSubtitle),
          ],
        ),
      ),
      IconButton.filledTonal(
        onPressed: () => context.go('/settings'),
        icon: const Icon(Icons.tune),
        style: IconButton.styleFrom(
          backgroundColor: kSurfaceLowest,
          foregroundColor: kOnSurfaceVariant,
          fixedSize: const Size(48, 48),
        ),
      ),
    ],
  );

  Widget _buildLocationStatus({
    required bool hasJourney,
    required bool isTracking,
    required bool arrived,
  }) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: const BoxDecoration(
        color: kSurfaceLow,
        borderRadius: BorderRadius.all(Radius.circular(kRadiusFull)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle, size: 9, color: kPrimary),
          const SizedBox(width: 9),
          Flexible(
            child: Text(
              !hasJourney
                  ? 'Location checked when journey starts'
                  : arrived
                  ? 'Journey complete'
                  : _nativeTrackingActive == null
                  ? 'Checking tracking service…'
                  : isTracking
                  ? 'Monitoring active'
                  : 'Tracking service unavailable',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: kOnSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildSearchEntry(BuildContext context) => Material(
    color: kSurfaceLowest,
    borderRadius: BorderRadius.circular(kRadiusLg),
    elevation: 1,
    shadowColor: const Color(0x100D3732),
    child: SizedBox(
      height: 60,
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onChanged: _onHomeSearchChanged,
        onSubmitted: _searchHome,
        onTap: () => setState(() => _showSearchResults = true),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search, color: kSecondary),
          hintText: 'Where do you want to get off?',
          suffixIcon: _searching
              ? const Padding(
                  padding: EdgeInsets.all(18),
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _searchController.text.isNotEmpty
              ? IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchResults = const [];
                      _searchError = null;
                    });
                  },
                  icon: const Icon(Icons.close),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    ),
  );

  Widget _buildHomeSearchResults(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 8),
    decoration: kLayer1Decoration,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_searchResults.isEmpty && !_searching)
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              _searchError ?? (_searchController.text.trim().length < 3
                  ? 'Type at least 3 characters to search.'
                  : 'No matching places found.'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ..._searchResults.map(
          (destination) => ListTile(
            leading: const Icon(Icons.place_outlined, color: kPrimary),
            title: Text(destination.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: destination.address == null
                ? null
                : Text(destination.address!, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => _openSearchResult(destination),
          ),
        ),
      ],
    ),
  );

  Widget _buildMapEntry(BuildContext context) => Material(
    color: kSurfaceLow,
    borderRadius: BorderRadius.circular(kRadiusLg),
    child: InkWell(
      borderRadius: BorderRadius.circular(kRadiusLg),
      onTap: () => context.push('/map'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_on_outlined, color: kPrimary, size: 24),
            const SizedBox(width: 10),
            Text('Choose on Map', style: _cardTitle),
            const SizedBox(width: 12),
          ],
        ),
      ),
    ),
  );

  Widget _buildEmptyJourneyCard(BuildContext context) => Container(
    decoration: kLayer1Decoration,
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
    child: Column(
      children: [
        const CircleAvatar(
          radius: 30,
          backgroundColor: kSurfaceLow,
          child: Icon(Icons.nightlight_round, color: kPrimary, size: 30),
        ),
        const SizedBox(height: 16),
        Text(
          'Ready for your next journey?',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          "Choose a destination and we'll help you get ready before your stop.",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    ),
  );

  Widget _buildActiveJourneyCard(
    BuildContext context,
    dynamic journey,
    String unit, {
    required bool? trackingActive,
  }) {
    final isArrived = journey.state == JourneyState.destinationReached;
    final remaining = journey.currentDistanceMeters == null
        ? '—'
        : DistanceUtils.formatDistance(journey.currentDistanceMeters, unit);

    return Container(
      decoration: kLayer1Decoration,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.nightlight_round, color: kPrimary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  journey.destination.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _cardTitle,
                ),
              ),
              _Pill(
                label: isArrived
                    ? 'Arrived'
                    : trackingActive == true
                    ? 'Monitoring active'
                    : trackingActive == false
                    ? 'Service unavailable'
                    : 'Checking service',
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                remaining,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text(
                  'remaining',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Straight-line distance to your stop',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push('/active-journey'),
              icon: const Icon(Icons.swap_horiz),
              label: const Text('View Active Journey'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDestinations(BuildContext context) => Container(
    decoration: kLayer1Decoration,
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('No saved destinations yet', style: _cardTitle),
        const SizedBox(height: 4),
        Text(
          'Save a place from the map and it will appear here.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 14),
      ],
    ),
  );

  Widget _buildDestinationsGrid(
    BuildContext context,
    List<Destination> destinations,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: destinations.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.13,
      ),
      itemBuilder: (context, index) {
        final destination = destinations[index];
        return Material(
          color: kSurfaceLowest,
          borderRadius: BorderRadius.circular(kRadiusLg),
          elevation: 1,
          shadowColor: const Color(0x100D3732),
          child: InkWell(
            borderRadius: BorderRadius.circular(kRadiusLg),
            onTap: () => context.push('/journey-setup', extra: destination),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const CircleAvatar(
                        radius: 19,
                        backgroundColor: kSurfaceLow,
                        child: Icon(Icons.place_outlined, color: kPrimary),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    destination.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _cardTitle,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    destination.address ?? 'Saved Location',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.color,
    required this.text,
  });
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(kRadiusMd),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: TextStyle(color: color)),
        ),
      ],
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: const BoxDecoration(
      color: kSurfaceHigh,
      borderRadius: BorderRadius.all(Radius.circular(kRadiusFull)),
    ),
    child: Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.labelMedium?.copyWith(color: kOnSurfaceVariant),
    ),
  );
}

TextStyle get _sectionLabel => GoogleFonts.inter(
  color: kSecondary,
  fontSize: 13,
  fontWeight: FontWeight.w600,
  letterSpacing: 1.1,
);
TextStyle get _sectionHeading => GoogleFonts.plusJakartaSans(
  color: kOnSurface,
  fontSize: 22,
  fontWeight: FontWeight.w600,
);

TextStyle get _brandTitle => GoogleFonts.plusJakartaSans(
  color: kOnSurface,
  fontSize: 20,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.5,
);

TextStyle get _brandSubtitle => GoogleFonts.inter(
  color: kSecondary,
  fontSize: 12,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.4,
);

TextStyle get _cardTitle => GoogleFonts.plusJakartaSans(
  color: kOnSurface,
  fontSize: 16,
  fontWeight: FontWeight.w600,
  height: 1.25,
);
