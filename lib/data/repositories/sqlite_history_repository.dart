import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../domain/entities/clip_item.dart';
import '../../domain/repositories/interfaces.dart';

/// Implementacja [HistoryRepository] na bazie SQLite (przez sqflite_ffi,
/// wymagane na desktopie zamiast domyślnego sqflite mobilnego).
class SqliteHistoryRepository implements HistoryRepository {
  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'clipboard_history.db');

    _db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE clip_items (
              id TEXT PRIMARY KEY,
              content TEXT NOT NULL,
              type TEXT NOT NULL,
              copiedAt TEXT NOT NULL,
              lastUsedAt TEXT,
              useCount INTEGER NOT NULL DEFAULT 0,
              isPinned INTEGER NOT NULL DEFAULT 0,
              isSecret INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.execute(
              'CREATE INDEX idx_copiedAt ON clip_items(copiedAt)');
        },
      ),
    );
    return _db!;
  }

  @override
  Future<void> add(ClipItem item) async {
    final db = await _database;
    // Parametryzowane zapytanie - nigdy interpolacja stringów w SQL.
    await db.insert('clip_items', item.toMap());
  }

  @override
  Future<void> update(ClipItem item) async {
    final db = await _database;
    await db.update(
      'clip_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  @override
  Future<void> delete(String id) async {
    final db = await _database;
    await db.delete('clip_items', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> clearAll({bool keepPinned = true}) async {
    final db = await _database;
    if (keepPinned) {
      await db.delete('clip_items', where: 'isPinned = 0');
    } else {
      await db.delete('clip_items');
    }
  }

  @override
  Future<ClipItem?> findDuplicate(String content) async {
    final db = await _database;
    final rows = await db.query(
      'clip_items',
      where: 'content = ?',
      whereArgs: [content],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ClipItem.fromMap(rows.first);
  }

  @override
  Future<List<ClipItem>> getAll({
    String? searchQuery,
    ClipContentType? filterType,
  }) async {
    final db = await _database;
    final whereClauses = <String>[];
    final whereArgs = <Object?>[];

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClauses.add('content LIKE ?');
      whereArgs.add('%$searchQuery%');
    }
    if (filterType != null) {
      whereClauses.add('type = ?');
      whereArgs.add(filterType.name);
    }

    final rows = await db.query(
      'clip_items',
      where: whereClauses.isEmpty ? null : whereClauses.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'isPinned DESC, copiedAt DESC',
    );
    return rows.map(ClipItem.fromMap).toList();
  }

  @override
  Future<void> enforceLimit(int? maxItems) async {
    if (maxItems == null) return; // brak limitu
    final db = await _database;
    final rows = await db.query(
      'clip_items',
      where: 'isPinned = 0',
      orderBy: 'copiedAt DESC',
    );
    if (rows.length <= maxItems) return;

    final toDelete = rows.skip(maxItems).map((r) => r['id'] as String);
    final batch = db.batch();
    for (final id in toDelete) {
      batch.delete('clip_items', where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> deleteOlderThan(Duration retention) async {
    final db = await _database;
    final cutoff = DateTime.now().subtract(retention).toIso8601String();
    await db.delete(
      'clip_items',
      where: 'isPinned = 0 AND copiedAt < ?',
      whereArgs: [cutoff],
    );
  }
}
