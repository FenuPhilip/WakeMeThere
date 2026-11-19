import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../domain/destination.dart';
import '../domain/place_search_provider.dart';
import 'sqflite_place_search_cache.dart';

class PhotonPlaceSearchProvider implements PlaceSearchProvider {
  PhotonPlaceSearchProvider({
    required http.Client client,
    required PlaceSearchCache cache,
    required this.baseUri,
    this.requestTimeout = const Duration(seconds: 8),
    this.resultLimit = 5,
  }) : _client = client,
       _cache = cache;

  final http.Client _client;
  final PlaceSearchCache _cache;
  final Uri baseUri;
  final Duration requestTimeout;
  final int resultLimit;
  DateTime? _rateLimitedUntil;

  @override
  Future<List<Destination>> search(String query, {LatLng? near}) async {
    final normalizedQuery = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalizedQuery.length < 3) return const [];

    final cacheKey = 'search:${normalizedQuery.toLowerCase()}';
    final cached = await _readCache(cacheKey);
    if (cached != null &&
        _isFresh(
          cached,
          cached.results.isEmpty
              ? const Duration(minutes: 10)
              : const Duration(hours: 24),
        )) {
      return cached.results;
    }

    final uri = _endpoint('api', {
      'q': normalizedQuery,
      'limit': resultLimit.clamp(1, 10).toString(),
    });
    // No location bias is sent. `near` remains available for a future explicit,
    // user-approved bias flow but is deliberately not transmitted by default.
    late final http.Response response;
    try {
      response = await _get(uri);
    } on PlaceSearchException {
      if (cached != null &&
          DateTime.now().difference(cached.cachedAt) <=
              const Duration(days: 7)) {
        return cached.results;
      }
      rethrow;
    }
    final results = _parseFeatureCollection(response.body);
    await _writeCache(cacheKey, results);
    return results;
  }

  @override
  Future<String?> reverseGeocode(LatLng coordinates) async {
    final lat = coordinates.latitude;
    final lon = coordinates.longitude;
    if (!lat.isFinite ||
        !lon.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lon < -180 ||
        lon > 180) {
      throw const PlaceSearchException(
        'The selected map coordinate is invalid.',
      );
    }
    final key = 'reverse:${lat.toStringAsFixed(5)}:${lon.toStringAsFixed(5)}';
    final cached = await _readCache(key);
    if (_isFresh(cached, const Duration(days: 30))) {
      final result = cached!.results;
      return result.isEmpty ? null : result.first.address;
    }

    late final http.Response response;
    try {
      response = await _get(
        _endpoint('reverse', {
          'lat': lat.toStringAsFixed(6),
          'lon': lon.toStringAsFixed(6),
          'limit': '1',
        }),
      );
    } on PlaceSearchException {
      if (cached != null &&
          DateTime.now().difference(cached.cachedAt) <=
              const Duration(days: 90) &&
          cached.results.isNotEmpty) {
        return cached.results.first.address;
      }
      rethrow;
    }
    final result = _parseFeatureCollection(response.body, limit: 1);
    await _writeCache(key, result);
    return result.isEmpty ? null : result.first.address ?? result.first.name;
  }

  Future<CachedPlaceSearch?> _readCache(String key) async {
    try {
      return await _cache.read(key);
    } on Object {
      // Cache failures must not prevent a network lookup.
      return null;
    }
  }

  Future<void> _writeCache(String key, List<Destination> results) async {
    try {
      await _cache.write(key, results);
    } on Object {
      // Search remains usable if local storage is temporarily unavailable.
    }
  }

  bool _isFresh(CachedPlaceSearch? cached, Duration maxAge) =>
      cached != null &&
      DateTime.now().difference(cached.cachedAt) <= maxAge &&
      !cached.cachedAt.isAfter(DateTime.now().add(const Duration(minutes: 5)));

  Uri _endpoint(String path, Map<String, String> parameters) {
    final prefix = baseUri.path.replaceFirst(RegExp(r'/$'), '');
    return baseUri.replace(path: '$prefix/$path', queryParameters: parameters);
  }

  Future<http.Response> _get(Uri uri) async {
    final cooldownRemaining = _rateLimitedUntil?.difference(DateTime.now());
    if (cooldownRemaining != null && !cooldownRemaining.isNegative) {
      throw PlaceSearchException(
        'Photon asked the app to slow down. Please retry shortly.',
        retryAfter: cooldownRemaining,
      );
    }
    try {
      final response = await _client
          .get(
            uri,
            headers: const {
              'Accept': 'application/geo+json, application/json',
              'User-Agent': 'WakeMeThere/1.0 (Android; OSM place search)',
            },
          )
          .timeout(requestTimeout);
      if (response.statusCode == 429) {
        final retrySeconds = int.tryParse(
          response.headers['retry-after'] ?? '',
        );
        final cooldown = Duration(seconds: (retrySeconds ?? 30).clamp(1, 300));
        _rateLimitedUntil = DateTime.now().add(cooldown);
        throw PlaceSearchException(
          'Photon is receiving too many requests. Please retry shortly.',
          retryAfter: cooldown,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw PlaceSearchException(
          response.statusCode >= 500
              ? 'Photon place search is temporarily unavailable.'
              : 'Photon could not complete this place search.',
        );
      }
      return response;
    } on PlaceSearchException {
      rethrow;
    } on TimeoutException {
      throw const PlaceSearchException(
        'Photon place search timed out. Check your connection and retry.',
      );
    } on http.ClientException {
      throw const PlaceSearchException(
        'Photon place search is unavailable. Check your internet connection.',
      );
    } on Object {
      throw const PlaceSearchException(
        'Photon place search is unavailable. Check your connection and retry.',
      );
    }
  }

  List<Destination> _parseFeatureCollection(String body, {int? limit}) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final features = decoded['features'] as List<dynamic>? ?? const [];
      return features
          .take(limit ?? resultLimit)
          .map((feature) {
            final item = feature as Map<String, dynamic>;
            final geometry = item['geometry'] as Map<String, dynamic>?;
            final coordinates = geometry?['coordinates'] as List<dynamic>?;
            if (coordinates == null || coordinates.length < 2) {
              throw const FormatException(
                'Photon response is missing coordinates.',
              );
            }
            final lon = (coordinates[0] as num).toDouble();
            final lat = (coordinates[1] as num).toDouble();
            if (!lat.isFinite ||
                !lon.isFinite ||
                lat < -90 ||
                lat > 90 ||
                lon < -180 ||
                lon > 180) {
              throw const FormatException(
                'Photon returned invalid coordinates.',
              );
            }
            final properties =
                item['properties'] as Map<String, dynamic>? ?? const {};
            final name = _firstText(properties, const [
              'name',
              'street',
              'locality',
              'district',
              'city',
              'county',
              'state',
              'country',
            ]);
            if (name == null) {
              throw const FormatException('Photon result has no display name.');
            }
            final address = _formatAddress(properties, name);
            return Destination(
              name: name,
              coordinates: LatLng(lat, lon),
              address: address,
              stationCode: 'OSM',
            );
          })
          .toList(growable: false);
    } on PlaceSearchException {
      rethrow;
    } on Object {
      throw const PlaceSearchException(
        'Photon returned place data that could not be read.',
      );
    }
  }

  String? _firstText(Map<String, dynamic> properties, List<String> keys) {
    for (final key in keys) {
      final value = properties[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  String? _formatAddress(Map<String, dynamic> properties, String name) {
    final parts = <String>[];
    for (final key in const [
      'housenumber',
      'street',
      'postcode',
      'city',
      'state',
      'country',
    ]) {
      final value = properties[key];
      if (value is String &&
          value.trim().isNotEmpty &&
          value != name &&
          !parts.contains(value)) {
        parts.add(value.trim());
      }
    }
    return parts.isEmpty ? name : parts.join(', ');
  }
}

final photonHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final placeSearchCacheProvider = Provider<PlaceSearchCache>(
  (ref) => const SqflitePlaceSearchCache(),
);

final placeSearchProvider = Provider<PlaceSearchProvider>((ref) {
  return PhotonPlaceSearchProvider(
    client: ref.watch(photonHttpClientProvider),
    cache: ref.watch(placeSearchCacheProvider),
    baseUri: Uri.parse('https://photon.komoot.io'),
  );
});
