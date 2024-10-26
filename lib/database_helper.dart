import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'media.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE taslak (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        media_id TEXT,
        media_url TEXT,
        media_type TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE video_attribute (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        baslangic INTEGER,
        bitis INTEGER,
        taslak_id INTEGER,
        FOREIGN KEY (taslak_id) REFERENCES taslak (id)
      )
    ''');
  }
  Future<void> insertTaslak(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('taslak', data);
  }

  Future<List<Map<String, dynamic>>> queryAllTaslak() async {
    final db = await database;
    return await db.query('taslak');
  }
// Veri ekleme ve diğer işlemler için gerekli metodları buraya ekleyebilirsiniz.
}
