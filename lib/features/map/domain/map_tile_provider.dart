import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class MapTileProvider {
  String get styleUrl;

  String get attribution;

  OfflineMapLimits? get offlineMapLimits;
}

class OfflineMapLimits {
  const OfflineMapLimits({
    required this.maxTilesPerDownload,
    required this.maxBytesPerDownload,
    required this.maxConcurrentRequests,
    required this.requiresIdentifyingUserAgent,
  });

  final int maxTilesPerDownload;
  final int maxBytesPerDownload;
  final int maxConcurrentRequests;
  final bool requiresIdentifyingUserAgent;
}

class OpenFreeMapTileProvider implements MapTileProvider {
  const OpenFreeMapTileProvider();

  @override
  String get styleUrl => 'https://tiles.openfreemap.org/styles/liberty';

  @override
  String get attribution => '© OpenFreeMap · © OpenMapTiles · © OpenStreetMap';

  @override
  OfflineMapLimits? get offlineMapLimits => const OfflineMapLimits(
    maxTilesPerDownload: 3000,
    maxBytesPerDownload: 50 * 1024 * 1024,
    maxConcurrentRequests: 4,
    requiresIdentifyingUserAgent: true,
  );
}

final mapTileProvider = Provider<MapTileProvider>(
  (ref) => const OpenFreeMapTileProvider(),
);
