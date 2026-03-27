import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

class LocalDBService {
  static final LocalDBService instance = LocalDBService._internal();
  LocalDBService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'bettergym_local.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE workout_sessions (
            id TEXT PRIMARY KEY,
            user_id INTEGER NOT NULL,
            routine_id TEXT,
            status TEXT NOT NULL,
            global_score INTEGER NOT NULL,
            duration_seconds INTEGER NOT NULL,
            sync_status INTEGER DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        ''');

        await db.execute('''
          CREATE TABLE exercise_telemetry (
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL,
            exercise_name TEXT NOT NULL,
            good_reps INTEGER DEFAULT 0,
            bad_reps INTEGER DEFAULT 0,
            exercise_score INTEGER NOT NULL,
            rep_scores_array TEXT NOT NULL,
            FOREIGN KEY (session_id) REFERENCES workout_sessions(id) ON DELETE CASCADE
          )
        ''');
      },
    );
  }

  // --- SAVE WORKOUT TO PHONE ---
  Future<void> saveWorkoutOffline(Map<String, dynamic> sessionData, List<Map<String, dynamic>> exercisesData) async {
    final db = await database;
    
    await db.transaction((txn) async {
      await txn.insert('workout_sessions', sessionData);
      for (var ex in exercisesData) {
        ex['rep_scores_array'] = jsonEncode(ex['rep_scores_array']);
        await txn.insert('exercise_telemetry', ex);
      }
    });
  }

  // --- GRAB TRAPPED DATA ---
  Future<List<Map<String, dynamic>>> getUnsyncedSessions() async {
    final db = await database;
    final sessions = await db.query('workout_sessions', where: 'sync_status = ?', whereArgs: [0]);
    List<Map<String, dynamic>> payload = [];
    
    for (var session in sessions) {
      final sessionMap = Map<String, dynamic>.from(session);
      final telemetry = await db.query('exercise_telemetry', where: 'session_id = ?', whereArgs: [session['id']]);
      
      List<Map<String, dynamic>> decodedTelemetry = telemetry.map((t) {
        var mutableT = Map<String, dynamic>.from(t);
        mutableT['rep_scores'] = jsonDecode(mutableT['rep_scores_array']);
        mutableT.remove('rep_scores_array');
        return mutableT;
      }).toList();

      sessionMap['exercises'] = decodedTelemetry;
      payload.add(sessionMap);
    }
    return payload;
  }

  Future<void> markSessionAsSynced(String sessionId) async {
    final db = await database;
    await db.update('workout_sessions', {'sync_status': 1}, where: 'id = ?', whereArgs: [sessionId]);
  }
  // --- FETCH DASHBOARD DATA ---
  Future<List<Map<String, dynamic>>> getCompletedSessions() async {
    final db = await database;
    // We order by 'created_at ASC' so the oldest workout is on the left of the chart, newest on the right
    return await db.query(
      'workout_sessions',
      where: 'status = ?',
      whereArgs: ['COMPLETED'],
      orderBy: 'created_at ASC', 
    );
  }
  
  // --- INJECT DOWNLOADED HISTORY ---
  Future<void> saveDownloadedHistory(List<dynamic> serverSessions) async {
    final db = await database;
    
    // We run this as a massive batch transaction for speed
    await db.transaction((txn) async {
      for (var session in serverSessions) {
        // Prepare the session row
        final Map<String, dynamic> sessionData = {
          'id': session['id'],
          'user_id': session['user_id'],
          'routine_id': session['routine_id'],
          'status': session['status'],
          'global_score': session['global_score'],
          'duration_seconds': session['duration_seconds'],
          'sync_status': 1, // ALREADY SYNCED
          'created_at': session['created_at'],
        };

        // ConflictAlgorithm.replace prevents crashes if the data already exists locally
        await txn.insert('workout_sessions', sessionData, conflictAlgorithm: ConflictAlgorithm.replace);

        // Prepare the child telemetry rows
        List<dynamic> exercises = session['exercises'] ?? [];
        for (var ex in exercises) {
          final Map<String, dynamic> exData = {
            'id': ex['id'],
            'session_id': ex['session_id'],
            'exercise_name': ex['exercise_name'],
            'good_reps': ex['good_reps'],
            'bad_reps': ex['bad_reps'],
            'exercise_score': ex['exercise_score'],
            'rep_scores_array': jsonEncode(ex['rep_scores']), // Re-stringify for SQLite
          };
          await txn.insert('exercise_telemetry', exData, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }
}