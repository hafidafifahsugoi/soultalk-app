import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../providers/session_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('soultalk.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        time TEXT NOT NULL,
        duration TEXT NOT NULL,
        moodAbbr TEXT NOT NULL,
        primaryMood TEXT NOT NULL,
        emoji TEXT NOT NULL,
        accuracy TEXT NOT NULL,
        observations TEXT NOT NULL,
        messageCount INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE mood_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT UNIQUE NOT NULL,
        moodIndex INTEGER NOT NULL,
        emoji TEXT NOT NULL,
        label TEXT NOT NULL,
        note TEXT
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS mood_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT UNIQUE NOT NULL,
          moodIndex INTEGER NOT NULL,
          emoji TEXT NOT NULL,
          label TEXT NOT NULL,
          note TEXT
        )
      ''');
    }
  }

  Future<int> insertSession(SessionItem session) async {
    final db = await instance.database;
    final map = {
      'title': session.title,
      'time': session.time,
      'duration': session.duration,
      'moodAbbr': session.moodAbbr,
      'primaryMood': session.primaryMood,
      'emoji': session.emoji,
      'accuracy': session.accuracy,
      'observations': jsonEncode(session.observations),
      'messageCount': session.messageCount,
    };
    return await db.insert('sessions', map);
  }

  Future<List<SessionItem>> getAllSessions() async {
    final db = await instance.database;
    final result = await db.query('sessions', orderBy: 'id DESC');

    return result.map((json) {
      final obsRaw = json['observations'] as String;
      List<String> obsList = [];
      try {
        final decoded = jsonDecode(obsRaw);
        if (decoded is List) {
          obsList = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        obsList = [];
      }

      return SessionItem(
        title: json['title'] as String,
        time: json['time'] as String,
        duration: json['duration'] as String,
        moodAbbr: json['moodAbbr'] as String,
        primaryMood: json['primaryMood'] as String,
        emoji: json['emoji'] as String,
        accuracy: json['accuracy'] as String,
        observations: obsList,
        messageCount: json['messageCount'] as int,
      );
    }).toList();
  }

  Future<int> getSessionsCount() async {
    final db = await instance.database;
    final result = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM sessions'),
    );
    return result ?? 0;
  }

  Future<void> clearAll() async {
    final db = await instance.database;
    await db.delete('sessions');
  }

  Future<int> insertOrUpdateMoodRecord(int moodIndex, String emoji, String label, String? note) async {
    final db = await instance.database;
    final now = DateTime.now();
    final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    
    final map = {
      'date': dateStr,
      'moodIndex': moodIndex,
      'emoji': emoji,
      'label': label,
      'note': note,
    };
    
    return await db.insert(
      'mood_records',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getMoodRecords(int limit) async {
    final db = await instance.database;
    return await db.query(
      'mood_records',
      orderBy: 'date DESC',
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> getMoodRecordsByMonth(int year, int month) async {
    final db = await instance.database;
    final monthStr = month.toString().padLeft(2, '0');
    final prefix = "$year-$monthStr-%";
    return await db.query(
      'mood_records',
      where: 'date LIKE ?',
      whereArgs: [prefix],
      orderBy: 'date ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getAllMoodRecords() async {
    final db = await instance.database;
    return await db.query(
      'mood_records',
      orderBy: 'date ASC',
    );
  }

  Future<void> clearAllMoodRecords() async {
    final db = await instance.database;
    await db.delete('mood_records');
  }
}
