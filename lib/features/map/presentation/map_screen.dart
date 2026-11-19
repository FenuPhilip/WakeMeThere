import 'dart:async';
import 'dart:math' show Point;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../app/theme.dart';
import '../../../core/utils/distance_utils.dart';
import '../domain/map_tile_provider.dart';
import '../../destination/domain/destination.dart';
import '../../destination/domain/place_search_provider.dart';
import '../../destination/data/photon_place_search_provider.dart';
import '../../home/providers/home_provider.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  maplibre.MapLibreMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();

  LatLng? _currentPosition;
  bool _hasSelectedDestination = false;
  bool _searching = false;
  String? _searchError;
  List<Destination> _searchResults = const [];

  // Start with an unselected map center. A user must tap or search to choose.
  Destination _selectedDestination = const Destination(
    name: 'Tap the map or search for a place',
    coordinates: LatLng(10.5276, 76.2144),
    address: 'Select a destination to continue',
  );

  bool _showSuggestions = false;
  double _zoom = 11.0;
  bool _mapStyleLoaded = false;
  int _searchRequestId = 0;
  Timer? _searchDebounce;
  Timer? _reverseGeocodeDebounce;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCurrentPosition(requestPermission: false));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    _reverseGeocodeDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentPosition({required bool requestPermission}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (requestPermission && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Allow location access to recenter the map.'),
            ),
          );
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      setState(
        () => _currentPosition = LatLng(position.latitude, position.longitude),
      );
      if (_mapStyleLoaded) {
        await _showMapMarkers();
        if (requestPermission) _moveCamera(_currentPosition!, 14);
      }
    } catch (_) {
      if (requestPermission && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not get a current location fix.'),
          ),
        );
      }
    }
  }

  void _onMapCreated(maplibre.MapLibreMapController controller) {
    _mapController = controller;
  }

  Future<void> _onMapStyleLoaded() async {
    _mapStyleLoaded = true;
    await _showMapMarkers();
    if (_currentPosition != null) {
      _moveCamera(_currentPosition!, 14);
    }
  }

  Future<void> _showMapMarkers() async {
    final controller = _mapController;
    if (controller == null || !_mapStyleLoaded) return;
    await controller.clearCircles();
    final current = _currentPosition;
    if (current != null) {
      await controller.addCircle(
        maplibre.CircleOptions(
          geometry: maplibre.LatLng(current.latitude, current.longitude),
          circleRadius: 7,
          circleColor: '#4285F4',
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 2,
        ),
      );
    }
    if (_hasSelectedDestination) {
      await controller.addCircle(
        maplibre.CircleOptions(
          geometry: maplibre.LatLng(
            _selectedDestination.coordinates.latitude,
            _selectedDestination.coordinates.longitude,
          ),
          circleRadius: 10,
          circleColor: '#006856',
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 3,
        ),
      );
    }
  }

  void _moveCamera(LatLng position, double zoom) {
    _mapController?.animateCamera(
      maplibre.CameraUpdate.newLatLngZoom(
        maplibre.LatLng(position.latitude, position.longitude),
        zoom,
      ),
    );
  }

  Future<void> _searchPlaces() async {
    final query = _searchController.text.trim();
    if (query.length < 3) {
      setState(() => _searchError = 'Enter at least 3 characters to search.');
      return;
    }
    final requestId = ++_searchRequestId;
    setState(() {
      _searching = true;
      _searchError = null;
      _showSuggestions = true;
    });
    try {
      List<Destination> savedResults = const [];
      String? storageError;
      try {
        final destinations = await ref
            .read(destinationRepositoryProvider)
            .getAll();
        final normalizedQuery = query.toLowerCase();
        savedResults = destinations
            .where(
              (destination) =>
                  destination.name.toLowerCase().contains(normalizedQuery) ||
                  (destination.address?.toLowerCase().contains(
                        normalizedQuery,
                      ) ??
                      false),
            )
            .toList();
      } catch (_) {
        storageError = 'Saved destinations could not be loaded.';
      }
      if (!mounted || requestId != _searchRequestId) return;

      List<Destination> onlineResults = const [];
      String? onlineError;
      try {
        onlineResults = await ref.read(placeSearchProvider).search(query);
      } on PlaceSearchException catch (error) {
        onlineError = error.message;
      } catch (_) {
        onlineError = 'Online place search is temporarily unavailable.';
      }
      if (!mounted || requestId != _searchRequestId) return;

      final results = <Destination>[...savedResults];
      for (final result in onlineResults) {
        final duplicate = results.any(
          (existing) =>
              existing.name.toLowerCase() == result.name.toLowerCase() ||
              (existing.coordinates.latitude - result.coordinates.latitude)
                          .abs() <
                      0.0001 &&
                  (existing.coordinates.longitude -
                              result.coordinates.longitude)
                          .abs() <
                      0.0001,
        );
        if (!duplicate) results.add(result);
      }
      setState(() {
        _searchResults = results;
        if (onlineError != null) {
          _searchError = onlineError;
        } else if (storageError != null) {
          _searchError = storageError;
        } else if (results.isEmpty) {
          _searchError =
              'No places found. Try a broader name or tap a point on the map.';
        }
      });
    } finally {
      if (mounted && requestId == _searchRequestId) {
        setState(() => _searching = false);
      }
    }
  }

  void _onSearchChanged(String value) {
    _searchRequestId++;
    _searchDebounce?.cancel();
    setState(() {
      _showSuggestions = true;
      _searchError = null;
      _searching = false;
    });
    if (value.trim().length < 3) return;
    _searchDebounce = Timer(const Duration(milliseconds: 650), () {
      if (mounted) unawaited(_searchPlaces());
    });
  }

  void _onMapTapped(Point<double> _, maplibre.LatLng tappedPoint) {
    final point = LatLng(tappedPoint.latitude, tappedPoint.longitude);
    final dist = _currentPosition == null
        ? null
        : DistanceUtils.haversine(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            point.latitude,
            point.longitude,
          );

    setState(() {
      _selectedDestination = Destination(
        name: 'Selected map location',
        coordinates: point,
        address:
            '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}',
        stationCode: 'PIN',
        distanceMeters: dist,
      );
      _hasSelectedDestination = true;
      _showSuggestions = false;
    });
    unawaited(_showMapMarkers());
    _reverseGeocodeDebounce?.cancel();
    _reverseGeocodeDebounce = Timer(const Duration(milliseconds: 650), () {
      unawaited(_reverseGeocode(point));
    });
  }

  Future<void> _reverseGeocode(LatLng coordinates) async {
    try {
      final address = await ref
          .read(placeSearchProvider)
          .reverseGeocode(coordinates);
      if (!mounted || address == null || !_hasSelectedDestination) return;
      final selected = _selectedDestination;
      if (selected.coordinates.latitude != coordinates.latitude ||
          selected.coordinates.longitude != coordinates.longitude) {
        return;
      }
      final placeName = address.split(',').first.trim();
      setState(() {
        _selectedDestination = selected.copyWith(
          name: placeName.isEmpty ? selected.name : placeName,
          address: address,
        );
      });
    } on PlaceSearchException {
      // The selected coordinates remain valid when reverse geocoding is offline.
    }
  }

  void _selectSuggestion(Destination dest) {
    _searchDebounce?.cancel();
    _searchRequestId++;
    final selected = _currentPosition == null
        ? dest
        : dest.copyWith(
            distanceMeters: DistanceUtils.haversine(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              dest.coordinates.latitude,
              dest.coordinates.longitude,
            ),
          );
    setState(() {
      _selectedDestination = selected;
      _hasSelectedDestination = true;
      _showSuggestions = false;
    });
    _moveCamera(dest.coordinates, 12.5);
    unawaited(_showMapMarkers());
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = kPrimary;
    const surfaceColor = kAppBackground;
    const surfaceContainer = kSurfaceLowest;
    const surfaceContainerHigh = kSurfaceLow;
    const surfaceContainerHighest = kSurfaceHigh;
    const surfaceContainerLowest = kSurfaceLow;
    const onSurface = kOnSurface;
    const onSurfaceVariant = kOnSurfaceVariant;
    const outlineVariant = kOutlineVariant;

    final distanceUnit = ref.watch(distanceUnitProvider);
    final mapTiles = ref.watch(mapTileProvider);
    final distanceKm = _selectedDestination.distanceMeters == null
        ? '—'
        : DistanceUtils.formatDistance(
            _selectedDestination.distanceMeters!,
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
          'Map Selection',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: onSurface,
          ),
        ),
      ),
      body: Stack(
        children: [
          maplibre.MapLibreMap(
            initialCameraPosition: maplibre.CameraPosition(
              target: maplibre.LatLng(
                (_currentPosition ?? _selectedDestination.coordinates).latitude,
                (_currentPosition ?? _selectedDestination.coordinates)
                    .longitude,
              ),
              zoom: _zoom,
            ),
            styleString: mapTiles.styleUrl,
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _onMapStyleLoaded,
            onMapClick: _onMapTapped,
            attributionButtonMargins: const Point<double>(8, 285),
            compassEnabled: true,
          ),

          // Floating Top Search Bar Pill & Dropdown
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: surfaceContainer.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(kRadiusLg),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A0D3732),
                        blurRadius: 12,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: primaryColor, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          onChanged: _onSearchChanged,
                          onSubmitted: (_) {
                            _searchDebounce?.cancel();
                            _searchPlaces();
                          },
                          onTap: () => setState(() => _showSuggestions = true),
                          style: const TextStyle(
                            fontSize: 14,
                            color: onSurface,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Search places worldwide',
                            hintStyle: TextStyle(
                              color: onSurfaceVariant,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      if (_searching)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (_searchController.text.isNotEmpty)
                        IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                            setState(() => _showSuggestions = false);
                          },
                          icon: const Icon(Icons.close, size: 20),
                        ),
                    ],
                  ),
                ),
                if (_showSuggestions) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: surfaceContainer.withValues(alpha: 0.97),
                      borderRadius: BorderRadius.circular(kRadiusLg),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A0D3732),
                          blurRadius: 16,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            'Search terms and selected map coordinates are sent to Photon by Komoot. Recent results are cached on this device.',
                            style: TextStyle(
                              fontSize: 11,
                              color: onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (_searchError != null)
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              _searchError!,
                              style: const TextStyle(color: kError),
                            ),
                          ),
                        if (_searchResults.isEmpty && !_searching)
                          const Padding(
                            padding: EdgeInsets.all(8),
                            child: Text(
                              'Submit a search, or tap a point on the map.',
                              style: TextStyle(
                                fontSize: 12,
                                color: onSurfaceVariant,
                              ),
                            ),
                          ),
                        if (_searchResults.isNotEmpty) ...[
                          ..._searchResults.map(
                            (dest) => ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.place_outlined,
                                color: primaryColor,
                              ),
                              title: Text(
                                dest.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: onSurface),
                              ),
                              subtitle: Text(
                                dest.address ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: onSurfaceVariant),
                              ),
                              onTap: () => _selectSuggestion(dest),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.fromLTRB(8, 4, 8, 6),
                            child: Text(
                              'Place results: Photon by Komoot · Data: © OpenStreetMap contributors',
                              style: TextStyle(
                                fontSize: 10,
                                color: onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Floating Map Control Cluster (Recenter, Zoom In, Zoom Out)
          Positioned(
            right: 16,
            bottom: 250,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'recenter',
                  onPressed: () =>
                      _loadCurrentPosition(requestPermission: true),
                  backgroundColor: surfaceContainer.withValues(alpha: 0.95),
                  foregroundColor: primaryColor,
                  child: const Icon(Icons.my_location, size: 20),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: surfaceContainer.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: outlineVariant, width: 0.8),
                  ),
                  child: Column(
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() => _zoom++);
                          _mapController?.animateCamera(
                            maplibre.CameraUpdate.zoomTo(_zoom),
                          );
                        },
                        icon: const Icon(Icons.add, size: 18, color: onSurface),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() => _zoom--);
                          _mapController?.animateCamera(
                            maplibre.CameraUpdate.zoomTo(_zoom),
                          );
                        },
                        icon: const Icon(
                          Icons.remove,
                          size: 18,
                          color: onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Floating Bottom Sheet Card
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: BoxDecoration(
                color: surfaceContainer,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: const Border(
                  top: BorderSide(color: outlineVariant, width: 1),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A0D3732),
                    blurRadius: 24,
                    offset: Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tactile Drag Pull Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Header Meta & Station Code Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedDestination.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: onSurface,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _selectedDestination.address ?? '',
                              style: const TextStyle(
                                fontSize: 13,
                                color: onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _selectedDestination.stationCode ?? 'PIN',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: primaryColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Key Mobility Metrics (Distance & Arrival Window)
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.straighten,
                                    size: 14,
                                    color: onSurfaceVariant,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'RADIAL DISTANCE',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: onSurfaceVariant,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    distanceKm,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: onSurface,
                                    ),
                                  ),
                                ],
                              ),
                              const Text(
                                'Straight-line sensor vector',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.explore_outlined,
                                    size: 14,
                                    color: onSurfaceVariant,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'COORDINATES',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: onSurfaceVariant,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Lat ${_selectedDestination.coordinates.latitude.toStringAsFixed(4)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: onSurface,
                                ),
                              ),
                              Text(
                                'Long ${_selectedDestination.coordinates.longitude.toStringAsFixed(4)}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: onSurfaceVariant,
                                ),
                              ),
                              const Text(
                                'WGS-84 calibrated',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 100% Offline Peace-of-Mind Chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: primaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'GPS tracking works offline; maps and search need internet',
                              style: TextStyle(
                                fontSize: 11,
                                color: onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const Icon(
                          Icons.offline_bolt,
                          size: 16,
                          color: primaryColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Confirm Destination Primary CTA
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _hasSelectedDestination
                          ? () {
                              context.push(
                                '/journey-setup',
                                extra: _selectedDestination,
                              );
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: kOnPrimary,
                        shape: const StadiumBorder(),
                        elevation: 1,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Confirm Destination',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 20),
                        ],
                      ),
                    ),
                  ),
                  if (_hasSelectedDestination)
                    Center(
                      child: TextButton.icon(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await ref
                              .read(destinationRepositoryProvider)
                              .save(_selectedDestination);
                          ref.invalidate(savedDestinationsProvider);
                          if (mounted) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Destination saved on this device.',
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                        label: const Text('Save this destination'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
