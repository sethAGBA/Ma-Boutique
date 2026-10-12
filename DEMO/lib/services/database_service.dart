import 'dart:io';
import 'package:path/path.dart';
import 'package:school_manager/models/class.dart';
import 'package:school_manager/models/course.dart';
import 'package:school_manager/models/payment.dart';
import 'package:school_manager/models/staff.dart';
import 'package:school_manager/models/student.dart';
import 'package:school_manager/models/grade.dart';
import 'package:sqflite/sqflite.dart';


class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'ecole_manager.db');
    print('[DatabaseService] Ouverture de la base à : $path');
    final db = await openDatabase(
      path,
      version: 6, // Increment version for users permissions
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE classes(
            name TEXT PRIMARY KEY,
            academicYear TEXT NOT NULL,
            titulaire TEXT,
            fraisEcole REAL,
            fraisCotisationParallele REAL
          )
        ''');
        await db.execute('''
          CREATE TABLE students(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            dateOfBirth TEXT NOT NULL,
            address TEXT NOT NULL,
            gender TEXT NOT NULL,
            contactNumber TEXT NOT NULL,
            email TEXT NOT NULL,
            emergencyContact TEXT NOT NULL,
            guardianName TEXT NOT NULL,
            guardianContact TEXT NOT NULL,
            className TEXT NOT NULL,
            enrollmentDate TEXT NOT NULL, -- New field
            medicalInfo TEXT,
            photoPath TEXT,
            FOREIGN KEY (className) REFERENCES classes(name)
          )
        ''');
        await db.execute('''
          CREATE TABLE payments(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            studentId TEXT NOT NULL,
            className TEXT NOT NULL,
            amount REAL NOT NULL,
            date TEXT NOT NULL,
            comment TEXT,
            isCancelled INTEGER DEFAULT 0,
            cancelledAt TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE staff(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            role TEXT NOT NULL,
            department TEXT NOT NULL,
            phone TEXT NOT NULL,
            email TEXT NOT NULL,
            qualifications TEXT,
            courses TEXT,
            classes TEXT,
            status TEXT NOT NULL,
            hireDate TEXT NOT NULL,
            typeRole TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE courses(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE grades(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            studentId TEXT NOT NULL,
            className TEXT NOT NULL,
            academicYear TEXT NOT NULL,
            subject TEXT NOT NULL,
            term TEXT NOT NULL,
            value REAL NOT NULL,
            label TEXT,
            maxValue REAL DEFAULT 20,
            coefficient REAL DEFAULT 1,
            type TEXT DEFAULT 'Devoir',
            subjectId TEXT,
            FOREIGN KEY (studentId) REFERENCES students(id),
            FOREIGN KEY (className) REFERENCES classes(name)
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS grades_archive(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            studentId TEXT NOT NULL,
            className TEXT NOT NULL,
            academicYear TEXT NOT NULL,
            subject TEXT NOT NULL,
            term TEXT NOT NULL,
            value REAL NOT NULL,
            label TEXT,
            maxValue REAL DEFAULT 20,
            coefficient REAL DEFAULT 1,
            type TEXT DEFAULT 'Devoir',
            subjectId TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE subject_appreciation(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            studentId TEXT NOT NULL,
            className TEXT NOT NULL,
            academicYear TEXT NOT NULL,
            subject TEXT NOT NULL,
            term TEXT NOT NULL,
            professeur TEXT,
            appreciation TEXT,
            moyenne_classe TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE class_courses(
            className TEXT NOT NULL,
            courseId TEXT NOT NULL,
            PRIMARY KEY (className, courseId),
            FOREIGN KEY (className) REFERENCES classes(name),
            FOREIGN KEY (courseId) REFERENCES courses(id)
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS report_cards(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            studentId TEXT NOT NULL,
            className TEXT NOT NULL,
            academicYear TEXT NOT NULL,
            term TEXT NOT NULL,
            appreciation_generale TEXT,
            decision TEXT,
            fait_a TEXT,
            le_date TEXT,
            moyenne_generale REAL,
            rang INTEGER,
            nb_eleves INTEGER,
            mention TEXT,
            moyennes_par_periode TEXT, -- JSON encodé
            all_terms TEXT, -- JSON encodé
            moyenne_generale_classe REAL,
            moyenne_la_plus_forte REAL,
            moyenne_la_plus_faible REAL,
            moyenne_annuelle REAL,
            sanctions TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS subject_appreciation_archive(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            report_card_id INTEGER NOT NULL,
            subject TEXT NOT NULL,
            professeur TEXT,
            appreciation TEXT,
            moyenne_classe TEXT,
            academicYear TEXT NOT NULL,
            FOREIGN KEY (report_card_id) REFERENCES report_cards_archive(id)
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS report_cards_archive(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            studentId TEXT NOT NULL,
            className TEXT NOT NULL,
            academicYear TEXT NOT NULL,
            term TEXT NOT NULL,
            appreciation_generale TEXT,
            decision TEXT,
            fait_a TEXT,
            le_date TEXT,
            moyenne_generale REAL,
            rang INTEGER,
            nb_eleves INTEGER,
            mention TEXT,
            moyennes_par_periode TEXT, -- JSON encodé
            all_terms TEXT, -- JSON encodé
            moyenne_generale_classe REAL,
            moyenne_la_plus_forte REAL,
            moyenne_la_plus_faible REAL,
            moyenne_annuelle REAL,
            sanctions TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS users(
            username TEXT PRIMARY KEY,
            displayName TEXT,
            role TEXT,
            passwordHash TEXT NOT NULL,
            salt TEXT NOT NULL,
            isTwoFactorEnabled INTEGER DEFAULT 0,
            totpSecret TEXT,
            isActive INTEGER DEFAULT 1,
            createdAt TEXT,
            lastLoginAt TEXT,
            permissions TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add enrollmentDate to students table
          final columns = await db.rawQuery("PRAGMA table_info(students)");
          final hasEnrollmentDate = columns.any((col) => col['name'] == 'enrollmentDate');
          if (!hasEnrollmentDate) {
            await db.execute("ALTER TABLE students ADD COLUMN enrollmentDate TEXT");
            // Populate enrollmentDate with dateOfBirth for existing students
            await db.execute("UPDATE students SET enrollmentDate = dateOfBirth WHERE enrollmentDate IS NULL OR enrollmentDate = ''");
            // Fallback for any remaining nulls or empty strings to current date
            await db.execute("UPDATE students SET enrollmentDate = ? WHERE enrollmentDate IS NULL OR enrollmentDate = ''", [DateTime.now().toIso8601String()]);
          }
        }
        // Ensure new tables exist for upgraded databases
        await db.execute('''
          CREATE TABLE IF NOT EXISTS grades_archive(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            studentId TEXT NOT NULL,
            className TEXT NOT NULL,
            academicYear TEXT NOT NULL,
            subject TEXT NOT NULL,
            term TEXT NOT NULL,
            value REAL NOT NULL,
            label TEXT,
            maxValue REAL DEFAULT 20,
            coefficient REAL DEFAULT 1,
            type TEXT DEFAULT 'Devoir',
            subjectId TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS subject_appreciation(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            studentId TEXT NOT NULL,
            className TEXT NOT NULL,
            academicYear TEXT NOT NULL,
            subject TEXT NOT NULL,
            term TEXT NOT NULL,
            professeur TEXT,
            appreciation TEXT,
            moyenne_classe TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS report_cards(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            studentId TEXT NOT NULL,
            className TEXT NOT NULL,
            academicYear TEXT NOT NULL,
            term TEXT NOT NULL,
            appreciation_generale TEXT,
            decision TEXT,
            fait_a TEXT,
            le_date TEXT,
            moyenne_generale REAL,
            rang INTEGER,
            nb_eleves INTEGER,
            mention TEXT,
            moyennes_par_periode TEXT,
            all_terms TEXT,
            moyenne_generale_classe REAL,
            moyenne_la_plus_forte REAL,
            moyenne_la_plus_faible REAL,
            moyenne_annuelle REAL,
            sanctions TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS report_cards_archive(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            studentId TEXT NOT NULL,
            className TEXT NOT NULL,
            academicYear TEXT NOT NULL,
            term TEXT NOT NULL,
            appreciation_generale TEXT,
            decision TEXT,
            fait_a TEXT,
            le_date TEXT,
            moyenne_generale REAL,
            rang INTEGER,
            nb_eleves INTEGER,
            mention TEXT,
            moyennes_par_periode TEXT,
            all_terms TEXT,
            moyenne_generale_classe REAL,
            moyenne_la_plus_forte REAL,
            moyenne_la_plus_faible REAL,
            moyenne_annuelle REAL,
            sanctions TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS subject_appreciation_archive(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            report_card_id INTEGER NOT NULL,
            subject TEXT NOT NULL,
            professeur TEXT,
            appreciation TEXT,
            moyenne_classe TEXT,
            academicYear TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS users(
            username TEXT PRIMARY KEY,
            displayName TEXT,
            role TEXT,
            passwordHash TEXT NOT NULL,
            salt TEXT NOT NULL,
            isTwoFactorEnabled INTEGER DEFAULT 0,
            totpSecret TEXT,
            isActive INTEGER DEFAULT 1,
            createdAt TEXT,
            lastLoginAt TEXT,
            permissions TEXT
          )
        ''');
        // Ensure 'permissions' column exists when upgrading from older versions
        final cols = await db.rawQuery("PRAGMA table_info(users)");
        final hasPermissions = cols.any((c) => c['name'] == 'permissions');
        if (!hasPermissions) {
          await db.execute('ALTER TABLE users ADD COLUMN permissions TEXT');
        }
      },
    );
    await _migrateGradesSubjectId(db);
    await _migrateReportCardsExtraFields(db);
    return db;
  }

  Future<void> _migrateReportCardsExtraFields(Database db) async {
    // Helper to add column if missing
    Future<void> addColumnIfMissing(String table, String column, String type) async {
      final cols = await db.rawQuery("PRAGMA table_info($table)");
      final has = cols.any((c) => c['name'] == column);
      if (!has) {
        await db.execute('ALTER TABLE ' + table + ' ADD COLUMN ' + column + ' ' + type);
      }
    }
    // report_cards
    await addColumnIfMissing('report_cards', 'recommandations', 'TEXT');
    await addColumnIfMissing('report_cards', 'forces', 'TEXT');
    await addColumnIfMissing('report_cards', 'points_a_developper', 'TEXT');
    await addColumnIfMissing('report_cards', 'attendance_justifiee', 'INTEGER');
    await addColumnIfMissing('report_cards', 'attendance_injustifiee', 'INTEGER');
    await addColumnIfMissing('report_cards', 'retards', 'INTEGER');
    await addColumnIfMissing('report_cards', 'presence_percent', 'REAL');
    await addColumnIfMissing('report_cards', 'conduite', 'TEXT');
    // report_cards_archive
    await addColumnIfMissing('report_cards_archive', 'recommandations', 'TEXT');
    await addColumnIfMissing('report_cards_archive', 'forces', 'TEXT');
    await addColumnIfMissing('report_cards_archive', 'points_a_developper', 'TEXT');
    await addColumnIfMissing('report_cards_archive', 'attendance_justifiee', 'INTEGER');
    await addColumnIfMissing('report_cards_archive', 'attendance_injustifiee', 'INTEGER');
    await addColumnIfMissing('report_cards_archive', 'retards', 'INTEGER');
    await addColumnIfMissing('report_cards_archive', 'presence_percent', 'REAL');
    await addColumnIfMissing('report_cards_archive', 'conduite', 'TEXT');
  }

  Future<void> _migrateStudentsEnrollmentDate(Database db) async {
    final columns = await db.rawQuery("PRAGMA table_info(students)");
    final hasEnrollmentDate = columns.any((col) => col['name'] == 'enrollmentDate');
    if (!hasEnrollmentDate) {
      await db.execute("ALTER TABLE students ADD COLUMN enrollmentDate TEXT DEFAULT ''");
      // Optionally, populate with a default value like current date or dateOfBirth if appropriate
      await db.execute("UPDATE students SET enrollmentDate = dateOfBirth WHERE enrollmentDate = ''");
    }
  }

  Future<void> _migrateGradesSubjectId(Database db) async {
    await db.transaction((txn) async {
      final columns = await txn.rawQuery("PRAGMA table_info(grades)");
      final hasSubjectId = columns.any((col) => col['name'] == 'subjectId');
      if (!hasSubjectId) {
        await txn.execute("ALTER TABLE grades ADD COLUMN subjectId TEXT");
      }
      final grades = await txn.query('grades');
      for (final grade in grades) {
        final currentSubjectId = grade['subjectId'] as Object?;
        if (currentSubjectId == null || (currentSubjectId is String && currentSubjectId.isEmpty)) {
          final subjectName = grade['subject'] as String?;
          if (subjectName != null && subjectName.isNotEmpty) {
            final course = await txn.query('courses', where: 'name = ?', whereArgs: [subjectName]);
            if (course.isNotEmpty) {
              final courseId = course.first['id'] as String;
              await txn.update('grades', {'subjectId': courseId}, where: 'id = ?', whereArgs: [grade['id']]);
            }
          }
        }
      }
    });
  }

  // Class operations
  Future<void> insertClass(Class cls) async {
    final db = await database;
    await db.insert('classes', cls.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Class>> getClasses() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('classes');
    return List.generate(maps.length, (i) => Class.fromMap(maps[i]));
  }

  Future<Class?> getClassByName(String name) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'classes',
      where: 'name = ?',
      whereArgs: [name],
    );
    if (maps.isNotEmpty) {
      return Class.fromMap(maps.first);
    }
    return null;
  }

  Future<void> updateClass(String oldName, Class updatedClass) async {
    final db = await database;
    await db.update(
      'classes',
      updatedClass.toMap(),
      where: 'name = ?',
      whereArgs: [oldName],
    );
    if (oldName != updatedClass.name) {
      await db.update(
        'students',
        {'className': updatedClass.name},
        where: 'className = ?',
        whereArgs: [oldName],
      );
      await db.update(
        'payments',
        {'className': updatedClass.name},
        where: 'className = ?',
        whereArgs: [oldName],
      );
      await updateClassNameInStaff(oldName, updatedClass.name);
    }
  }

  // Student operations
  Future<void> insertStudent(Student student) async {
    final db = await database;
    await db.insert('students', student.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Student>> getStudents() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('students');
    return List.generate(maps.length, (i) => Student.fromMap(maps[i]));
  }

  Future<void> updateStudent(String oldId, Student updatedStudent) async {
    final db = await database;
    await db.update(
      'students',
      updatedStudent.toMap(),
      where: 'id = ?',
      whereArgs: [oldId],
    );
  }

  Future<void> deleteStudent(String id) async {
    final db = await database;
    await db.delete('students', where: 'id = ?', whereArgs: [id]);
  }

  // Aggregate data for charts and table
  Future<Map<String, int>> getClassDistribution() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT className, COUNT(*) as count
      FROM students
      GROUP BY className
    ''');
    return {for (var item in result) item['className']: item['count']};
  }

  Future<Map<String, int>> getGenderDistribution(String className) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT gender, COUNT(*) as count
      FROM students
      WHERE className = ?
      GROUP BY gender
    ''', [className]);
    return {for (var item in result) item['gender']: item['count']};
  }

  Future<Map<String, int>> getAcademicYearDistribution() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT c.academicYear, COUNT(s.id) as count
      FROM students s
      JOIN classes c ON s.className = c.name
      GROUP BY c.academicYear
    ''');
    return {for (var item in result) item['academicYear']: item['count']};
  }

  Future<void> insertPayment(Payment payment) async {
    final db = await database;
    await db.insert('payments', payment.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> cancelPayment(int id) async {
    final db = await database;
    await db.update(
      'payments',
      {
        'isCancelled': 1,
        'cancelledAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Payment>> getPaymentsForStudent(String studentId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'payments',
      where: 'studentId = ? AND (isCancelled IS NULL OR isCancelled = 0)',
      whereArgs: [studentId],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => Payment.fromMap(maps[i]));
  }

  Future<double> getTotalPaidForStudent(String studentId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM payments WHERE studentId = ? AND (isCancelled IS NULL OR isCancelled = 0)',
      [studentId],
    );
    if (result.isNotEmpty && result.first['total'] != null) {
      return (result.first['total'] as num).toDouble();
    }
    return 0.0;
  }

  Future<void> deletePayment(int id) async {
    final db = await database;
    await db.delete('payments', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Payment>> getAllPayments() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'payments',
      where: 'isCancelled IS NULL OR isCancelled = 0',
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => Payment.fromMap(maps[i]));
  }

  Future<Student?> getStudentById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'students',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Student.fromMap(maps.first);
    }
    return null;
  }

  // Staff operations
  Future<void> insertStaff(Staff staff) async {
    final db = await database;
    await db.insert('staff', staff.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Staff>> getStaff() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('staff');
    return List.generate(maps.length, (i) => Staff.fromMap(maps[i]));
  }

  Future<void> updateStaff(String id, Staff updatedStaff) async {
    final db = await database;
    await db.update(
      'staff',
      updatedStaff.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteStaff(String id) async {
    final db = await database;
    await db.delete('staff', where: 'id = ?', whereArgs: [id]);
  }

  // Course operations
  Future<void> insertCourse(Course course) async {
    final db = await database;
    await db.insert('courses', course.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Course>> getCourses() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('courses');
    return List.generate(maps.length, (i) => Course.fromMap(maps[i]));
  }

  Future<void> updateCourse(String id, Course updatedCourse) async {
    final db = await database;
    await db.update(
      'courses',
      updatedCourse.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteCourse(String id) async {
    final db = await database;
    await db.delete('courses', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  // Met à jour le nom d'une classe dans tous les membres du personnel
  Future<void> updateClassNameInStaff(String oldName, String newName) async {
    final db = await database;
    final List<Map<String, dynamic>> staffList = await db.query('staff');
    for (final staff in staffList) {
      final classesStr = staff['classes'] as String?;
      if (classesStr != null && classesStr.isNotEmpty) {
        final classes = classesStr.split(',');
        final updatedClasses = classes.map((c) => c == oldName ? newName : c).toList();
        await db.update(
          'staff',
          {'classes': updatedClasses.join(',')},
          where: 'id = ?',
          whereArgs: [staff['id']],
        );
      }
    }
  }

  // Grade operations
  Future<void> insertGrade(Grade grade) async {
    final db = await database;
    await db.insert('grades', grade.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateGrade(Grade grade) async {
    final db = await database;
    await db.update(
      'grades',
      grade.toMap(),
      where: 'id = ?',
      whereArgs: [grade.id],
    );
  }

  Future<void> deleteGrade(int id) async {
    final db = await database;
    await db.delete('grades', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Grade>> getGradesForSelection({
    required String className,
    required String academicYear,
    required String subject,
    required String term,
  }) async {
    final db = await database;
    // On cherche d'abord par subjectId si possible
    final course = await db.query('courses', where: 'name = ?', whereArgs: [subject]);
    String? subjectId = course.isNotEmpty ? course.first['id'] as String : null;
    final List<Map<String, dynamic>> maps = await db.query(
      'grades',
      where: subjectId != null
        ? 'className = ? AND academicYear = ? AND (subject = ? OR subjectId = ?) AND term = ?'
        : 'className = ? AND academicYear = ? AND subject = ? AND term = ?',
      whereArgs: subjectId != null
        ? [className, academicYear, subject, subjectId, term]
        : [className, academicYear, subject, term],
    );
    return List.generate(maps.length, (i) => Grade.fromMap(maps[i]));
  }

  Future<Grade?> getGradeForStudent({
    required String studentId,
    required String className,
    required String academicYear,
    required String subject,
    required String term,
  }) async {
    final db = await database;
    final course = await db.query('courses', where: 'name = ?', whereArgs: [subject]);
    String? subjectId = course.isNotEmpty ? course.first['id'] as String : null;
    final List<Map<String, dynamic>> maps = await db.query(
      'grades',
      where: subjectId != null
        ? 'studentId = ? AND className = ? AND academicYear = ? AND (subject = ? OR subjectId = ?) AND term = ?'
        : 'studentId = ? AND className = ? AND academicYear = ? AND subject = ? AND term = ?',
      whereArgs: subjectId != null
        ? [studentId, className, academicYear, subject, subjectId, term]
        : [studentId, className, academicYear, subject, term],
    );
    if (maps.isNotEmpty) {
      return Grade.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Grade>> getAllGradesForPeriod({
    required String className,
    required String academicYear,
    required String term,
  }) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'grades',
      where: 'className = ? AND academicYear = ? AND term = ?',
      whereArgs: [className, academicYear, term],
    );
    return List.generate(maps.length, (i) => Grade.fromMap(maps[i]));
  }

  // Appreciation/professeur par matière
  Future<void> insertOrUpdateSubjectAppreciation({
    required String studentId,
    required String className,
    required String academicYear,
    required String subject,
    required String term,
    String? professeur,
    String? appreciation,
    String? moyenneClasse,
  }) async {
    final db = await database;
    final existing = await db.query(
      'subject_appreciation',
      where: 'studentId = ? AND className = ? AND academicYear = ? AND subject = ? AND term = ?',
      whereArgs: [studentId, className, academicYear, subject, term],
    );
    final data = {
      'studentId': studentId,
      'className': className,
      'academicYear': academicYear,
      'subject': subject,
      'term': term,
      'professeur': professeur,
      'appreciation': appreciation,
      'moyenne_classe': moyenneClasse,
    };
    if (existing.isEmpty) {
      await db.insert('subject_appreciation', data);
    } else {
      await db.update(
        'subject_appreciation',
        data,
        where: 'studentId = ? AND className = ? AND academicYear = ? AND subject = ? AND term = ?',
        whereArgs: [studentId, className, academicYear, subject, term],
      );
    }
  }

  Future<List<Map<String, dynamic>>> getSubjectAppreciations({
    required String studentId,
    required String className,
    required String academicYear,
    required String term,
  }) async {
    final db = await database;
    return await db.query(
      'subject_appreciation',
      where: 'studentId = ? AND className = ? AND academicYear = ? AND term = ?',
      whereArgs: [studentId, className, academicYear, term],
    );
  }

  Future<Map<String, dynamic>?> getSubjectAppreciation({
    required String studentId,
    required String className,
    required String academicYear,
    required String subject,
    required String term,
  }) async {
    final db = await database;
    final res = await db.query(
      'subject_appreciation',
      where: 'studentId = ? AND className = ? AND academicYear = ? AND subject = ? AND term = ?',
      whereArgs: [studentId, className, academicYear, subject, term],
    );
    if (res.isNotEmpty) return res.first;
    return null;
  }

  // Association Classe <-> Matière
  Future<void> addCourseToClass(String className, String courseId) async {
    final db = await database;
    await db.insert('class_courses', {
      'className': className,
      'courseId': courseId,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> removeCourseFromClass(String className, String courseId) async {
    final db = await database;
    await db.delete('class_courses', where: 'className = ? AND courseId = ?', whereArgs: [className, courseId]);
  }

  Future<List<Course>> getCoursesForClass(String className) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT c.* FROM courses c
      INNER JOIN class_courses cc ON cc.courseId = c.id
      WHERE cc.className = ?
    ''', [className]);
    return List.generate(maps.length, (i) => Course.fromMap(maps[i]));
  }

  Future<List<String>> getClassesForCourse(String courseId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'class_courses',
      columns: ['className'],
      where: 'courseId = ?',
      whereArgs: [courseId],
    );
    return maps.map((m) => m['className'] as String).toList();
  }

  Future<void> archiveGradesForYear(String year) async {
    final db = await database;
    // Copier toutes les notes de l'année dans grades_archive
    await db.execute('''
      INSERT INTO grades_archive (studentId, className, academicYear, subject, term, value, label, maxValue, coefficient, type, subjectId)
      SELECT studentId, className, academicYear, subject, term, value, label, maxValue, coefficient, type, subjectId
      FROM grades WHERE academicYear = ?
    ''', [year]);
  }

  Future<List<Grade>> getArchivedGrades({
    required String academicYear,
    String? className,
    String? studentId,
  }) async {
    final db = await database;
    String where = 'academicYear = ?';
    List<dynamic> whereArgs = [academicYear];
    if (className != null && className.isNotEmpty) {
      where += ' AND className = ?';
      whereArgs.add(className);
    }
    if (studentId != null && studentId != 'all' && studentId.isNotEmpty) {
      where += ' AND studentId = ?';
      whereArgs.add(studentId);
    }
    final List<Map<String, dynamic>> maps = await db.query('grades_archive', where: where, whereArgs: whereArgs);
    return List.generate(maps.length, (i) => Grade.fromMap(maps[i]));
  }

  /// Archive tous les bulletins d'une année académique (notes, appréciations, synthèse)
  Future<void> archiveReportCardsForYear(String academicYear) async {
    final db = await database;
    // Supprimer les anciennes archives pour cette année
    await db.delete('subject_appreciation_archive', where: 'report_card_id IN (SELECT id FROM report_cards_archive WHERE academicYear = ?)', whereArgs: [academicYear]);
    await db.delete('report_cards_archive', where: 'academicYear = ?', whereArgs: [academicYear]);
    await db.delete('grades_archive', where: 'academicYear = ?', whereArgs: [academicYear]);
    // Archiver toutes les notes de l'année dans grades_archive
    await archiveGradesForYear(academicYear);
    // Récupérer tous les élèves de l'année
    final classes = await db.query('classes', where: 'academicYear = ?', whereArgs: [academicYear]);
    for (final classRow in classes) {
      final className = classRow['name'] as String;
      final students = await db.query('students', where: 'className = ?', whereArgs: [className]);
      for (final student in students) {
        final studentId = student['id'] as String;
        // On récupère tous les termes utilisés pour cette classe/année
        final grades = await db.query('grades', where: 'studentId = ? AND className = ? AND academicYear = ?', whereArgs: [studentId, className, academicYear]);
        final terms = grades.map((g) => g['term'] as String).toSet();
        for (final term in terms) {
          // Récupérer toutes les notes de ce bulletin
          final gradesForTerm = grades.where((g) => g['term'] == term).toList();
          if (gradesForTerm.isEmpty) continue;
          // Récupérer toutes les appréciations par matière
          final subjectAppreciations = await db.query('subject_appreciation', where: 'studentId = ? AND className = ? AND academicYear = ? AND term = ?', whereArgs: [studentId, className, academicYear, term]);
          // Récupérer la synthèse du bulletin (report_cards)
          final reportCard = await db.query('report_cards', where: 'studentId = ? AND className = ? AND academicYear = ? AND term = ?', whereArgs: [studentId, className, academicYear, term]);
          Map<String, dynamic> synthese;
          if (reportCard.isNotEmpty) {
            synthese = reportCard.first;
          } else {
            // Calculer la synthèse automatiquement si elle n'existe pas
            // Moyenne générale pondérée
            double sommeNotes = 0.0;
            double sommeCoefficients = 0.0;
            for (final g in gradesForTerm) {
              final value = g['value'] is int ? (g['value'] as int).toDouble() : (g['value'] as num? ?? 0.0);
              final maxValue = g['maxValue'] is int ? (g['maxValue'] as int).toDouble() : (g['maxValue'] as num? ?? 20.0);
              final coeff = g['coefficient'] is int ? (g['coefficient'] as int).toDouble() : (g['coefficient'] as num? ?? 1.0);
              if (maxValue > 0 && coeff > 0) {
                sommeNotes += ((value / maxValue) * 20) * coeff;
                sommeCoefficients += coeff;
              }
            }
            final moyenneGenerale = (sommeCoefficients > 0) ? (sommeNotes / sommeCoefficients) : 0.0;
            // Calcul du rang
            final classStudentIds = (await db.query('students', where: 'className = ?', whereArgs: [className])).map((s) => s['id'] as String).toList();
            final List<double> allMoyennes = [];
            for (final sid in classStudentIds) {
              final sg = await db.query('grades', where: 'studentId = ? AND className = ? AND academicYear = ? AND term = ?', whereArgs: [sid, className, academicYear, term]);
              double sNotes = 0.0;
              double sCoeffs = 0.0;
              for (final g in sg) {
                final value = g['value'] is int ? (g['value'] as int).toDouble() : (g['value'] as num? ?? 0.0);
                final maxValue = g['maxValue'] is int ? (g['maxValue'] as int).toDouble() : (g['maxValue'] as num? ?? 20.0);
                final coeff = g['coefficient'] is int ? (g['coefficient'] as int).toDouble() : (g['coefficient'] as num? ?? 1.0);
                if (maxValue > 0 && coeff > 0) {
                  sNotes += ((value / maxValue) * 20) * coeff;
                  sCoeffs += coeff;
                }
              }
              allMoyennes.add((sCoeffs > 0) ? (sNotes / sCoeffs) : 0.0);
            }
            allMoyennes.sort((a, b) => b.compareTo(a));
            final rang = allMoyennes.indexWhere((m) => (m - moyenneGenerale).abs() < 0.001) + 1;
            final nbEleves = classStudentIds.length;

            final double? moyenneGeneraleDeLaClasse = allMoyennes.isNotEmpty
                ? allMoyennes.reduce((a, b) => a + b) / allMoyennes.length
                : null;
            final double? moyenneLaPlusForte = allMoyennes.isNotEmpty
                ? allMoyennes.reduce((a, b) => a > b ? a : b)
                : null;
            final double? moyenneLaPlusFaible = allMoyennes.isNotEmpty
                ? allMoyennes.reduce((a, b) => a < b ? a : b)
                : null;

            // Calcul de la moyenne annuelle
            double? moyenneAnnuelle;
            final allGradesForYear = (await db.query('grades', where: 'studentId = ? AND className = ? AND academicYear = ?', whereArgs: [studentId, className, academicYear]))
                .where((g) => (g['type'] == 'Devoir' || g['type'] == 'Composition') && g['value'] != null && g['value'] != 0)
                .toList();

            if (allGradesForYear.isNotEmpty) {
              double totalAnnualNotes = 0.0;
              double totalAnnualCoeffs = 0.0;
              for (final g in allGradesForYear) {
                final value = g['value'] is int ? (g['value'] as int).toDouble() : (g['value'] as num? ?? 0.0);
                final maxValue = g['maxValue'] is int ? (g['maxValue'] as int).toDouble() : (g['maxValue'] as num? ?? 20.0);
                final coeff = g['coefficient'] is int ? (g['coefficient'] as int).toDouble() : (g['coefficient'] as num? ?? 1.0);
                if (maxValue > 0 && coeff > 0) {
                  totalAnnualNotes += ((value / maxValue) * 20) * coeff;
                  totalAnnualCoeffs += coeff;
                }
              }
              moyenneAnnuelle = totalAnnualCoeffs > 0 ? totalAnnualNotes / totalAnnualCoeffs : null;
            }

            // Déterminer le mode (Trimestre / Semestre) et calculer les moyennes par période
            final allTermsForStudent = (await db.query('grades', where: 'studentId = ? AND className = ? AND academicYear = ?', whereArgs: [studentId, className, academicYear]))
                .map((g) => g['term'] as String)
                .toSet();
            List<String> orderedTerms;
            if (allTermsForStudent.any((t) => t.toLowerCase().contains('semestre'))) {
              orderedTerms = ['Semestre 1', 'Semestre 2'];
            } else {
              orderedTerms = ['Trimestre 1', 'Trimestre 2', 'Trimestre 3'];
            }
            // Restreindre aux termes effectivement utilisés
            orderedTerms = orderedTerms.where((t) => allTermsForStudent.contains(t)).toList();
            final List<double?> moyennesParPeriode = [];
            for (final t in orderedTerms) {
              final termGrades = await db.query('grades', where: 'studentId = ? AND className = ? AND academicYear = ? AND term = ?', whereArgs: [studentId, className, academicYear, t]);
              double sNotes = 0.0;
              double sCoeffs = 0.0;
              for (final g in termGrades) {
                final value = g['value'] is int ? (g['value'] as int).toDouble() : (g['value'] as num? ?? 0.0);
                final maxValue = g['maxValue'] is int ? (g['maxValue'] as int).toDouble() : (g['maxValue'] as num? ?? 20.0);
                final coeff = g['coefficient'] is int ? (g['coefficient'] as int).toDouble() : (g['coefficient'] as num? ?? 1.0);
                if (maxValue > 0 && coeff > 0) {
                  sNotes += ((value / maxValue) * 20) * coeff;
                  sCoeffs += coeff;
                }
              }
              moyennesParPeriode.add(sCoeffs > 0 ? sNotes / sCoeffs : null);
            }

            // Mention
            String mention;
            if (moyenneGenerale >= 18) {
              mention = 'EXCELLENT';
            } else if (moyenneGenerale >= 16) {
              mention = 'TRÈS BIEN';
            } else if (moyenneGenerale >= 14) {
              mention = 'BIEN';
            } else if (moyenneGenerale >= 12) {
              mention = 'ASSEZ BIEN';
            } else if (moyenneGenerale >= 10) {
              mention = 'PASSABLE';
            } else {
              mention = 'INSUFFISANT';
            }
            synthese = {
              'studentId': studentId,
              'className': className,
              'academicYear': academicYear,
              'term': term,
              'appreciation_generale': '',
              'decision': '',
              'fait_a': '',
              'le_date': '',
              'moyenne_generale': moyenneGenerale,
              'rang': rang,
              'nb_eleves': nbEleves,
              'mention': mention,
              'moyennes_par_periode': moyennesParPeriode.toString(),
              'all_terms': orderedTerms.toString(),
              'moyenne_generale_classe': moyenneGeneraleDeLaClasse,
              'moyenne_la_plus_forte': moyenneLaPlusForte,
              'moyenne_la_plus_faible': moyenneLaPlusFaible,
              'moyenne_annuelle': moyenneAnnuelle,
              'sanctions': '',
              'recommandations': '',
              'forces': '',
              'points_a_developper': '',
              'attendance_justifiee': 0,
              'attendance_injustifiee': 0,
              'retards': 0,
              'presence_percent': 0.0,
              'conduite': '',
            };
            await db.insert('report_cards', synthese);
          }
          final reportCardId = await db.insert('report_cards_archive', {
            'studentId': studentId,
            'className': className,
            'academicYear': academicYear,
            'term': term,
            'appreciation_generale': synthese['appreciation_generale'] ?? '',
            'decision': synthese['decision'] ?? '',
            'recommandations': synthese['recommandations'] ?? '',
            'forces': synthese['forces'] ?? '',
            'points_a_developper': synthese['points_a_developper'] ?? '',
            'fait_a': synthese['fait_a'] ?? '',
            'le_date': synthese['le_date'] ?? '',
            'moyenne_generale': synthese['moyenne_generale'] ?? 0.0,
            'rang': synthese['rang'] ?? 0,
            'nb_eleves': synthese['nb_eleves'] ?? students.length,
            'mention': synthese['mention'] ?? '',
            'moyennes_par_periode': synthese['moyennes_par_periode'] ?? '[]',
            'all_terms': synthese['all_terms'] ?? '[]',
            'moyenne_generale_classe': synthese['moyenne_generale_classe'] ?? 0.0,
            'moyenne_la_plus_forte': synthese['moyenne_la_plus_forte'] ?? 0.0,
            'moyenne_la_plus_faible': synthese['moyenne_la_plus_faible'] ?? 0.0,
            'moyenne_annuelle': synthese['moyenne_annuelle'] ?? 0.0,
            'sanctions': synthese['sanctions'] ?? '',
            'attendance_justifiee': synthese['attendance_justifiee'] ?? 0,
            'attendance_injustifiee': synthese['attendance_injustifiee'] ?? 0,
            'retards': synthese['retards'] ?? 0,
            'presence_percent': synthese['presence_percent'] ?? 0.0,
            'conduite': synthese['conduite'] ?? '',
          });
          // Archiver les appréciations par matière
          for (final app in subjectAppreciations) {
            await db.insert('subject_appreciation_archive', {
              'report_card_id': reportCardId,
              'subject': app['subject'],
              'professeur': app['professeur'],
              'appreciation': app['appreciation'],
              'moyenne_classe': app['moyenne_classe'],
              'academicYear': academicYear,
            });
          }
        }
      }
    }
  }

  Future<void> archiveSingleReportCard({
    required String studentId,
    required String className,
    required String academicYear,
    required String term,
    required List<Grade> grades,
    required Map<String, String> professeurs,
    required Map<String, String> appreciations,
    required Map<String, String> moyennesClasse,
    required Map<String, dynamic> synthese,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      // 1. Supprimer l'ancienne archive pour ce bulletin spécifique
      final existingArchives = await txn.query('report_cards_archive', 
        where: 'studentId = ? AND className = ? AND academicYear = ? AND term = ?',
        whereArgs: [studentId, className, academicYear, term]);

      for (final archive in existingArchives) {
        final reportCardId = archive['id'];
        await txn.delete('subject_appreciation_archive', where: 'report_card_id = ?', whereArgs: [reportCardId]);
      }
      await txn.delete('report_cards_archive', 
        where: 'studentId = ? AND className = ? AND academicYear = ? AND term = ?',
        whereArgs: [studentId, className, academicYear, term]);

      // 2. Archiver les notes
      for (final grade in grades) {
        await txn.insert('grades_archive', grade.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // 3. Archiver la synthèse du bulletin
      final reportCardId = await txn.insert('report_cards_archive', {
        'studentId': studentId,
        'className': className,
        'academicYear': academicYear,
        'term': term,
        'appreciation_generale': synthese['appreciation_generale'] ?? '',
        'decision': synthese['decision'] ?? '',
        'recommandations': synthese['recommandations'] ?? '',
        'forces': synthese['forces'] ?? '',
        'points_a_developper': synthese['points_a_developper'] ?? '',
        'fait_a': synthese['fait_a'] ?? '',
        'le_date': synthese['le_date'] ?? '',
        'moyenne_generale': synthese['moyenne_generale'] ?? 0.0,
        'rang': synthese['rang'] ?? 0,
        'nb_eleves': synthese['nb_eleves'] ?? 0,
        'mention': synthese['mention'] ?? '',
        'moyennes_par_periode': synthese['moyennes_par_periode'] ?? '[]',
        'all_terms': synthese['all_terms'] ?? '[]',
        'moyenne_generale_classe': synthese['moyenne_generale_classe'] ?? 0.0,
        'moyenne_la_plus_forte': synthese['moyenne_la_plus_forte'] ?? 0.0,
        'moyenne_la_plus_faible': synthese['moyenne_la_plus_faible'] ?? 0.0,
        'moyenne_annuelle': synthese['moyenne_annuelle'] ?? 0.0,
        'sanctions': synthese['sanctions'] ?? '',
        'attendance_justifiee': synthese['attendance_justifiee'] ?? 0,
        'attendance_injustifiee': synthese['attendance_injustifiee'] ?? 0,
        'retards': synthese['retards'] ?? 0,
        'presence_percent': synthese['presence_percent'] ?? 0.0,
        'conduite': synthese['conduite'] ?? '',
      });

      // 4. Archiver les appréciations par matière
      for (final subject in appreciations.keys) {
        await txn.insert('subject_appreciation_archive', {
          'report_card_id': reportCardId,
          'subject': subject,
          'professeur': professeurs[subject] ?? '-',
          'appreciation': appreciations[subject] ?? '-',
          'moyenne_classe': moyennesClasse[subject] ?? '-',
          'academicYear': academicYear,
        });
      }
    });
  }

  /// Récupère les bulletins archivés pour une classe et une année, groupés par élève
  Future<List<Map<String, dynamic>>> getArchivedReportCardsByClassAndYear({
    required String academicYear,
    required String className,
  }) async {
    final db = await database;
    final List<Map<String, dynamic>> rows = await db.query(
      'report_cards_archive',
      where: 'academicYear = ? AND className = ?',
      whereArgs: [academicYear, className],
    );
    return rows;
  }

  Future<List<Map<String, dynamic>>> getAllArchivedReportCards() async {
    final db = await database;
    final List<Map<String, dynamic>> rows = await db.query('report_cards_archive');
    return rows;
  }

  // ===================== Users (Authentication) =====================
  Future<void> upsertUser(Map<String, dynamic> userData) async {
    final db = await database;
    await db.insert('users', userData, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getUserRowByUsername(String username) async {
    final db = await database;
    final rows = await db.query('users', where: 'username = ?', whereArgs: [username]);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<List<Map<String, dynamic>>> getAllUserRows() async {
    final db = await database;
    return await db.query('users', orderBy: 'username ASC');
  }

  Future<void> deleteUserByUsername(String username) async {
    final db = await database;
    await db.delete('users', where: 'username = ?', whereArgs: [username]);
  }

  Future<void> updateUserLastLoginAt(String username) async {
    final db = await database;
    await db.update('users', {
      'lastLoginAt': DateTime.now().toIso8601String(),
    }, where: 'username = ?', whereArgs: [username]);
  }

  /// Récupère la synthèse du bulletin pour un élève/classe/année/période
  Future<Map<String, dynamic>?> getReportCard({
    required String studentId,
    required String className,
    required String academicYear,
    required String term,
  }) async {
    final db = await database;
    final res = await db.query(
      'report_cards',
      where: 'studentId = ? AND className = ? AND academicYear = ? AND term = ?',
      whereArgs: [studentId, className, academicYear, term],
    );
    if (res.isEmpty) return null;
    return res.first;
  }

  /// Insère ou met à jour un bulletin complet (infos synthèse)
  Future<void> insertOrUpdateReportCard({
    required String studentId,
    required String className,
    required String academicYear,
    required String term,
    String? appreciationGenerale,
    String? decision,
    String? faitA,
    String? leDate,
    double? moyenneGenerale,
    int? rang,
    int? nbEleves,
    String? mention,
    String? moyennesParPeriode,
    String? allTerms,
    double? moyenneGeneraleDeLaClasse,
    double? moyenneLaPlusForte,
    double? moyenneLaPlusFaible,
    double? moyenneAnnuelle,
    String? sanctions,
    String? recommandations,
    String? forces,
    String? pointsADevelopper,
    int? attendanceJustifiee,
    int? attendanceInjustifiee,
    int? retards,
    double? presencePercent,
    String? conduite,
  }) async {
    final db = await database;
    final existing = await db.query(
      'report_cards',
      where: 'studentId = ? AND className = ? AND academicYear = ? AND term = ?',
      whereArgs: [studentId, className, academicYear, term],
    );
    final data = {
      'studentId': studentId,
      'className': className,
      'academicYear': academicYear,
      'term': term,
      'appreciation_generale': appreciationGenerale,
      'decision': decision,
      'fait_a': faitA,
      'le_date': leDate,
      'moyenne_generale': moyenneGenerale,
      'rang': rang,
      'nb_eleves': nbEleves,
      'mention': mention,
      'moyennes_par_periode': moyennesParPeriode,
      'all_terms': allTerms,
      'moyenne_generale_classe': moyenneGeneraleDeLaClasse,
      'moyenne_la_plus_forte': moyenneLaPlusForte,
      'moyenne_la_plus_faible': moyenneLaPlusFaible,
      'moyenne_annuelle': moyenneAnnuelle,
      'sanctions': sanctions,
      'recommandations': recommandations,
      'forces': forces,
      'points_a_developper': pointsADevelopper,
      'attendance_justifiee': attendanceJustifiee,
      'attendance_injustifiee': attendanceInjustifiee,
      'retards': retards,
      'presence_percent': presencePercent,
      'conduite': conduite,
    };
    if (existing.isEmpty) {
      await db.insert('report_cards', data);
    } else {
      await db.update(
        'report_cards',
        data,
        where: 'studentId = ? AND className = ? AND academicYear = ? AND term = ?',
        whereArgs: [studentId, className, academicYear, term],
      );
    }
  }

  Future<List<Payment>> getRecentPayments(int limit) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'payments',
      orderBy: 'date DESC',
      limit: limit,
    );
    return List.generate(maps.length, (i) => Payment.fromMap(maps[i]));
  }

  Future<List<Staff>> getRecentStaff(int limit) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'staff',
      orderBy: 'hireDate DESC',
      limit: limit,
    );
    return List.generate(maps.length, (i) => Staff.fromMap(maps[i]));
  }

  Future<List<Student>> getRecentStudents(int limit) async {
    final db = await database;
    // Assuming students are ordered by their ID or a creation timestamp if available
    // For now, we'll just order by ID as there's no explicit creation date.
    final List<Map<String, dynamic>> maps = await db.query(
      'students',
      orderBy: 'enrollmentDate DESC',
      limit: limit,
    );
    return List.generate(maps.length, (i) => Student.fromMap(maps[i]));
  }

  // For the chart, we need to get monthly enrollment data.
  // This requires a 'createdAt' or 'enrollmentDate' column in the students table.
  // For now, we'll return dummy data or an empty list.
  Future<List<Map<String, dynamic>>> getMonthlyEnrollmentData() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT strftime('%Y-%m', enrollmentDate) as month, COUNT(*) as count
      FROM students
      GROUP BY month
      ORDER BY month
    ''');
    return result;
  }

  Future<List<Map<String, dynamic>>> getArchivedReportCardsForStudent(String studentId) async {
    final db = await database;
    return await db.query(
      'report_cards_archive',
      where: 'studentId = ?',
      whereArgs: [studentId],
      orderBy: 'academicYear DESC, term DESC',
    );
  }
}