// import 'package:sqflite/sqflite.dart';
// import 'package:path/path.dart';

// // This is the model for our attendance records
// class AttendanceRecord {
//   final int? id;
//   final String subjectName;
//   final String date; // ISO 8601 String
//   final String status; // "attended", "skipped", "canceled"

//   AttendanceRecord({
//     this.id,
//     required this.subjectName,
//     required this.date,
//     required this.status,
//   });

//   Map<String, dynamic> toMap() {
//     return {
//       'id': id,
//       'subjectName': subjectName,
//       'date': date,
//       'status': status,
//     };
//   }
// }

// class DatabaseService {
//   // --- Singleton Pattern ---
//   DatabaseService._privateConstructor();
//   static final DatabaseService instance = DatabaseService._privateConstructor();
//   // ---

//   static Database? _database;
//   static const String _tableName = 'attendance';

//   Future<Database> get database async {
//     if (_database != null) return _database!;
//     _database = await _initDatabase();
//     return _database!;
//   }

//   // --- Initialize the database ---
//   Future<Database> _initDatabase() async {
//     final dbPath = await getDatabasesPath();
//     final path = join(dbPath, 'attendance_alchemist.db');

//     return await openDatabase(path, version: 1, onCreate: _onCreate);
//   }

//   // --- Create the table ---
//   Future<void> _onCreate(Database db, int version) async {
//     await db.execute('''
//       CREATE TABLE $_tableName (
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         subjectName TEXT NOT NULL,
//         date TEXT NOT NULL,
//         status TEXT NOT NULL
//       )
//     ''');
//   }

//   // --- Insert a new attendance record ---
//   Future<void> insertAttendance(String subjectName, String status) async {
//     final db = await instance.database;
//     await db.insert(
//       _tableName,
//       AttendanceRecord(
//         subjectName: subjectName,
//         date: DateTime.now().toIso8601String(),
//         status: status,
//       ).toMap(),
//       conflictAlgorithm: ConflictAlgorithm.replace,
//     );
//   }

//   // --- Get all attendance records ---
//   Future<List<Map<String, dynamic>>> getAllAttendance() async {
//     final db = await instance.database;
//     return await db.query(_tableName, orderBy: 'date DESC');
//   }

//   // --- Clear all data from the table ---
//   Future<void> clearAllData() async {
//     final db = await instance.database;
//     await db.delete(_tableName);
//   }
// }
