import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../domain/entities/clip_item.dart';
import '../../domain/repositories/interfaces.dart';

/// [HistoryRepository] implementation on SQLite (via sqflite_ffi,
/// required on desktop instead of the mobile sqflite default).
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
    // Parameterized query - never string interpolation in SQL.
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
    final rows = await db.query(
      'clip_items',
      columns: const ['content', 'type'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    await db.delete('clip_items', where: 'id = ?', whereArgs: [id]);
    if (rows.isNotEmpty) _deleteImageFile(rows.first);
  }

  @override
  Future<void> clearAll({bool keepPinned = true}) async {
    final db = await _database;
    final rows = await db.query(
      'clip_items',
      columns: const ['content', 'type'],
      where: keepPinned ? 'isPinned = 0' : null,
    );
    if (keepPinned) {
      await db.delete('clip_items', where: 'isPinned = 0');
    } else {
      await db.delete('clip_items');
    }
    for (final row in rows) {
      _deleteImageFile(row);
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

    final toDelete = rows.skip(maxItems).toList();
    final batch = db.batch();
    for (final row in toDelete) {
      batch.delete('clip_items', where: 'id = ?', whereArgs: [row['id']]);
    }
    await batch.commit(noResult: true);
    for (final row in toDelete) {
      _deleteImageFile(row);
    }
  }

  @override
  Future<void> deleteOlderThan(Duration retention) async {
    final db = await _database;
    final cutoff = DateTime.now().subtract(retention).toIso8601String();
    final rows = await db.query(
      'clip_items',
      columns: const ['content', 'type'],
      where: 'isPinned = 0 AND copiedAt < ?',
      whereArgs: [cutoff],
    );
    await db.delete(
      'clip_items',
      where: 'isPinned = 0 AND copiedAt < ?',
      whereArgs: [cutoff],
    );
    for (final row in rows) {
      _deleteImageFile(row);
    }
  }

  /// Directory for clipboard image PNG files.
  Future<Directory> get _imagesDir async {
    final dir = await getApplicationSupportDirectory();
    final images = Directory(p.join(dir.path, 'images'));
    if (!await images.exists()) await images.create(recursive: true);
    return images;
  }

  @override
  Future<String> saveImage(String id, Uint8List bytes) async {
    final images = await _imagesDir;
    // Windows clipboard hands out BMP (huge, e.g. 38 MB for a 4K screen).
    // We convert to PNG and scale down to max 1920 px wide so history
    // does not eat the disk. Undecodable bytes are stored as-is.
    Uint8List out = bytes;
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        final resized =
            decoded.width > 1920 ? img.copyResize(decoded, width: 1920) : decoded;
        out = img.encodePng(resized);
      }
    } catch (_) {}
    final file = File(p.join(images.path, '$id.png'));
    await file.writeAsBytes(out, flush: true);
    return file.path;
  }

  @override
  Future<ClipItem?> findDuplicateImage(Uint8List bytes) async {
    final db = await _database;
    final rows = await db.query(
      'clip_items',
      where: 'type = ?',
      whereArgs: [ClipContentType.image.name],
    );
    for (final row in rows) {
      try {
        final file = File(row['content'] as String);
        if (!await file.exists()) continue;
        if (await file.length() != bytes.length) continue;
        final existing = await file.readAsBytes();
        if (_bytesEqual(existing, bytes)) {
          return ClipItem.fromMap(row);
        }
      } catch (_) {
        continue; // a corrupted file must not block saving a new image
      }
    }
    return null;
  }

  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Deletes the PNG file when the row represents one of our images.
  /// User files (file-type entries) are NEVER touched.
  void _deleteImageFile(Map<String, Object?> row) {
    if (row['type'] != ClipContentType.image.name) return;
    try {
      final file = File(row['content'] as String);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }
}
