import '../../../core/database/database_helper.dart';
import '../domain/destination.dart';

abstract class DestinationRepository {
  Future<List<Destination>> getAll();
  Future<Destination> save(Destination destination);
  Future<void> delete(int id);
  Future<void> clearAll();
}

class SqfliteDestinationRepository implements DestinationRepository {
  const SqfliteDestinationRepository();

  @override
  Future<List<Destination>> getAll() async {
    final db = await DatabaseHelper.instance.database;
    final records = await db.query('destinations', orderBy: 'id DESC');
    return records.map(Destination.fromMap).toList();
  }

  @override
  Future<Destination> save(Destination destination) async {
    final db = await DatabaseHelper.instance.database;
    final id = await db.insert('destinations', destination.toMap());
    return destination.copyWith(id: id);
  }

  @override
  Future<void> delete(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('destinations', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> clearAll() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('destinations');
  }
}
