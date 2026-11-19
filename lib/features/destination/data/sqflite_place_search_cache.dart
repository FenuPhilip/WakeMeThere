import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../domain/destination.dart';
import '../domain/place_search_provider.dart';

class SqflitePlaceSearchCache implements PlaceSearchCache {
  const SqflitePlaceSearchCache();

  @override
  Future<CachedPlaceSearch?> read(String key) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'place_search_cache',
      columns: ['result_json', 'cached_at'],
      where: 'cache_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final row = rows.single;
    try {
      final decoded = jsonDecode(row['result_json'] as String) as List<dynamic>;
      return CachedPlaceSearch(
        results: decoded
            .map((value) => Destination.fromMap(value as Map<String, dynamic>))
            .toList(growable: false),
        cachedAt: DateTime.fromMillisecondsSinceEpoch(row['cached_at'] as int),
      );
    } on Object {
      await db.delete(
        'place_search_cache',
        where: 'cache_key = ?',
        whereArgs: [key],
      );
      return null;
    }
  }

  @override
  Future<void> write(String key, List<Destination> results) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('place_search_cache', {
      'cache_key': key,
      'result_json': jsonEncode(results.map((item) => item.toMap()).toList()),
      'cached_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.execute('''
      DELETE FROM place_search_cache
      WHERE cache_key NOT IN (
        SELECT cache_key FROM place_search_cache
        ORDER BY cached_at DESC LIMIT 100
      )
    ''');
  }
}
