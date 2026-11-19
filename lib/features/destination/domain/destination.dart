import 'package:latlong2/latlong.dart';

/// Represents a destination for transit alerts.
class Destination {
  const Destination({
    this.id,
    required this.name,
    required this.coordinates,
    this.address,
    this.stationCode,
    this.createdAt,
    this.distanceMeters,
    this.etaMinutes,
    this.iconName,
  });

  final int? id;
  final String name;
  final LatLng coordinates;
  final String? address;
  final String? stationCode;
  final DateTime? createdAt;
  final double? distanceMeters;
  final int? etaMinutes;
  final String? iconName;

  Destination copyWith({
    int? id,
    String? name,
    LatLng? coordinates,
    String? address,
    String? stationCode,
    DateTime? createdAt,
    double? distanceMeters,
    int? etaMinutes,
    String? iconName,
  }) {
    return Destination(
      id: id ?? this.id,
      name: name ?? this.name,
      coordinates: coordinates ?? this.coordinates,
      address: address ?? this.address,
      stationCode: stationCode ?? this.stationCode,
      createdAt: createdAt ?? this.createdAt,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      iconName: iconName ?? this.iconName,
    );
  }

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'latitude': coordinates.latitude,
    'longitude': coordinates.longitude,
    'address': address,
    'station_code': stationCode,
    'created_at':
        createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
  };

  factory Destination.fromMap(Map<String, dynamic> map) => Destination(
    id: map['id'] as int?,
    name: map['name'] as String,
    coordinates: LatLng(
      (map['latitude'] as num).toDouble(),
      (map['longitude'] as num).toDouble(),
    ),
    address: map['address'] as String?,
    stationCode: map['station_code'] as String?,
    createdAt: map['created_at'] != null
        ? DateTime.tryParse(map['created_at'] as String)
        : null,
  );
}
