import 'package:latlong2/latlong.dart';

import 'destination.dart';

/// Replaceable network boundary for online place search and reverse geocoding.
/// Implementations should cache successful responses and identify their client
/// according to the provider's usage policy.
abstract interface class PlaceSearchProvider {
  Future<List<Destination>> search(String query, {LatLng? near});

  Future<String?> reverseGeocode(LatLng coordinates);
}

class PlaceSearchException implements Exception {
  const PlaceSearchException(this.message, {this.retryAfter});

  final String message;
  final Duration? retryAfter;

  @override
  String toString() => message;
}

class CachedPlaceSearch {
  const CachedPlaceSearch({required this.results, required this.cachedAt});

  final List<Destination> results;
  final DateTime cachedAt;
}

abstract interface class PlaceSearchCache {
  Future<CachedPlaceSearch?> read(String key);

  Future<void> write(String key, List<Destination> results);
}
