import 'package:latlong2/latlong.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../../destination/domain/destination.dart';
import '../domain/journey.dart';
import '../domain/journey_state.dart';

abstract class JourneyRepository {
  Future<Journey?> getActiveJourney();
  Future<Journey> save(Journey journey);
  Future<void> updateState(String id, String state);
  Future<List<Journey>> getHistory();
  Future<void> clearHistory();
}

class SqfliteJourneyRepository implements JourneyRepository {
  const SqfliteJourneyRepository();

  @override
  Future<Journey?> getActiveJourney() async {
    final db = await DatabaseHelper.instance.database;
    final results = await db.query(
      'journeys',
      where: 'state NOT IN (?, ?)',
      whereArgs: ['completed', 'cancelled'],
      orderBy: 'started_at DESC',
      limit: 1,
    );

    if (results.isEmpty) return null;
    final row = results.first;

    final dest = Destination(
      name: row['dest_name'] as String,
      coordinates: LatLng(
        (row['dest_lat'] as num).toDouble(),
        (row['dest_lon'] as num).toDouble(),
      ),
      address: row['dest_address'] as String?,
    );

    final stateName = row['state'] as String;
    final state = JourneyState.values.firstWhere(
      (s) => s.name == stateName,
      orElse: () => JourneyState.tracking,
    );

    return Journey(
      id: row['id'] as String,
      destination: dest,
      state: state,
      startedAt: DateTime.parse(row['started_at'] as String),
      completedAt: row['completed_at'] != null
          ? DateTime.tryParse(row['completed_at'] as String)
          : null,
      earlyWarningMeters: (row['early_warning_meters'] as num).toDouble(),
      wakeUpMeters: (row['wake_up_meters'] as num).toDouble(),
      criticalMeters: (row['critical_meters'] as num).toDouble(),
      currentDistanceMeters: (row['last_distance_meters'] as num?)?.toDouble(),
      soundEnabled: (row['sound_enabled'] as int? ?? 1) == 1,
      voiceEnabled: (row['voice_enabled'] as int? ?? 1) == 1,
      vibrationEnabled: (row['vibration_enabled'] as int? ?? 1) == 1,
      repeatUntilDismissed: (row['repeat_until_dismissed'] as int? ?? 1) == 1,
      alarmVolume: (row['alarm_volume'] as num?)?.toDouble() ?? 0.85,
    );
  }

  @override
  Future<Journey> save(Journey journey) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'journeys',
      journey.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return journey;
  }

  @override
  Future<void> updateState(String id, String state) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'journeys',
      {
        'state': state,
        if (state == 'completed' || state == 'cancelled')
          'completed_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<Journey>> getHistory() async {
    final db = await DatabaseHelper.instance.database;
    final results = await db.query('journeys', orderBy: 'started_at DESC');
    return results.map((row) {
      final dest = Destination(
        name: row['dest_name'] as String,
        coordinates: LatLng(
          (row['dest_lat'] as num).toDouble(),
          (row['dest_lon'] as num).toDouble(),
        ),
        address: row['dest_address'] as String?,
      );
      final stateName = row['state'] as String;
      final state = JourneyState.values.firstWhere(
        (s) => s.name == stateName,
        orElse: () => JourneyState.completed,
      );
      return Journey(
        id: row['id'] as String,
        destination: dest,
        state: state,
        startedAt: DateTime.parse(row['started_at'] as String),
        completedAt: row['completed_at'] != null
            ? DateTime.tryParse(row['completed_at'] as String)
            : null,
        earlyWarningMeters: (row['early_warning_meters'] as num).toDouble(),
        wakeUpMeters: (row['wake_up_meters'] as num).toDouble(),
        criticalMeters: (row['critical_meters'] as num).toDouble(),
        currentDistanceMeters: (row['last_distance_meters'] as num?)
            ?.toDouble(),
        soundEnabled: (row['sound_enabled'] as int? ?? 1) == 1,
        voiceEnabled: (row['voice_enabled'] as int? ?? 1) == 1,
        vibrationEnabled: (row['vibration_enabled'] as int? ?? 1) == 1,
        repeatUntilDismissed: (row['repeat_until_dismissed'] as int? ?? 1) == 1,
        alarmVolume: (row['alarm_volume'] as num?)?.toDouble() ?? 0.85,
      );
    }).toList();
  }

  @override
  Future<void> clearHistory() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('journeys');
  }
}
