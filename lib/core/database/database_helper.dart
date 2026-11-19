import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'wakemethere.db');

    return await openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        // Destinations table
        await db.execute('''
          CREATE TABLE destinations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            address TEXT,
            station_code TEXT,
            created_at TEXT
          )
        ''');

        // Journeys table
        await db.execute('''
          CREATE TABLE journeys (
            id TEXT PRIMARY KEY,
            dest_name TEXT NOT NULL,
            dest_lat REAL NOT NULL,
            dest_lon REAL NOT NULL,
            dest_address TEXT,
            state TEXT NOT NULL,
            started_at TEXT NOT NULL,
            completed_at TEXT,
            early_warning_meters REAL NOT NULL,
            wake_up_meters REAL NOT NULL,
            critical_meters REAL NOT NULL,
            last_distance_meters REAL,
            sound_enabled INTEGER NOT NULL DEFAULT 1,
            voice_enabled INTEGER NOT NULL DEFAULT 1,
            vibration_enabled INTEGER NOT NULL DEFAULT 1,
            repeat_until_dismissed INTEGER NOT NULL DEFAULT 1,
            alarm_volume REAL NOT NULL DEFAULT 0.85
          )
        ''');
        await db.execute('''
          CREATE TABLE place_search_cache (
            cache_key TEXT PRIMARY KEY NOT NULL,
            result_json TEXT NOT NULL,
            cached_at INTEGER NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE journeys ADD COLUMN sound_enabled INTEGER NOT NULL DEFAULT 1',
          );
          await db.execute(
            'ALTER TABLE journeys ADD COLUMN voice_enabled INTEGER NOT NULL DEFAULT 1',
          );
          await db.execute(
            'ALTER TABLE journeys ADD COLUMN vibration_enabled INTEGER NOT NULL DEFAULT 1',
          );
          await db.execute(
            'ALTER TABLE journeys ADD COLUMN repeat_until_dismissed INTEGER NOT NULL DEFAULT 1',
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE journeys ADD COLUMN alarm_volume REAL NOT NULL DEFAULT 0.85',
          );
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE place_search_cache (
              cache_key TEXT PRIMARY KEY NOT NULL,
              result_json TEXT NOT NULL,
              cached_at INTEGER NOT NULL
            )
          ''');
        }
      },
    );
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('journeys');
      await txn.delete('destinations');
      await txn.delete('place_search_cache');
    });
  }
}
