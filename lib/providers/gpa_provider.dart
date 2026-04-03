import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:bunkmate/models/gpa_models.dart';

class GpaProvider extends ChangeNotifier {
  static const Map<String, double> gradePoints = {
    "A++": 10.0,
    "A+": 9.0,
    "A": 8.5,
    "B+": 8.0,
    "B": 7.5,
    "C+": 7.0,
    "C": 6.5,
    "D+": 6.0,
    "D": 5.5,
    "E+": 5.0,
    "E": 4.0,
    "F": 0.0,
  };

  static const List<String> gradesList = [
    "A++",
    "A+",
    "A",
    "B+",
    "B",
    "C+",
    "C",
    "D+",
    "D",
    "E+",
    "E",
    "F",
  ];

  List<Semester> _semesters = [];
  List<Semester> get semesters => _semesters;

  // Planner State
  double _targetCgpa = 8.5;
  double get targetCgpa => _targetCgpa;

  double _projectedSgpa = 7.5;
  double get projectedSgpa => _projectedSgpa;

  List<double> _futureSemesterCredits = [25.0];
  List<double> get futureSemesterCredits => _futureSemesterCredits;

  Box<Semester>? _box;

  GpaProvider() {
    _init();
  }

  Future<void> _init() async {
    _box = await Hive.openBox<Semester>('gpa_semesters');
    _semesters = _box!.values.toList();

    if (_semesters.isEmpty) {
      addSemester(name: "Semester 1");
    }
    notifyListeners();
  }

  // --- CORE MATH ---

  double get cgpa {
    double totalCredits = 0;
    double totalWeightedSgpa = 0;

    for (var sem in _semesters) {
      double semCredits = sem.courses.fold(0.0, (sum, c) => sum + c.credits);
      if (semCredits > 0) {
        totalCredits += semCredits;
        totalWeightedSgpa += sem.sgpa * semCredits;
      }
    }
    return totalCredits > 0 ? (totalWeightedSgpa / totalCredits) : 0.0;
  }

  double calculateSgpa(List<Course> courses) {
    double totalCredits = 0;
    double totalPoints = 0;

    for (var c in courses) {
      if (c.credits > 0 && gradePoints.containsKey(c.grade)) {
        totalCredits += c.credits;
        totalPoints += c.credits * gradePoints[c.grade]!;
      }
    }
    return totalCredits > 0 ? (totalPoints / totalCredits) : 0.0;
  }

  // --- CRUD OPERATIONS ---

  void addParsedSemester(Semester newSem) {
    _semesters.add(newSem);
    _saveToHive();
  }

  void addSemester({String? name}) {
    final semName = name ?? "Semester ${_semesters.length + 1}";
    final newSem = Semester(
      id: "sem-${DateTime.now().millisecondsSinceEpoch}",
      name: semName,
      courses: [
        Course(
          id: "course-${DateTime.now().millisecondsSinceEpoch}",
          name: "",
          credits: 0.0,
          grade: gradesList.first,
        ),
      ],
      sgpa: 0.0,
    );
    _semesters.add(newSem);
    _saveToHive();
  }

  void removeSemester(String semId) {
    _semesters.removeWhere((s) => s.id == semId);
    _saveToHive();
  }

  void updateSemesterName(String semId, String newName) {
    final sem = _semesters.firstWhere((s) => s.id == semId);
    sem.name = newName;
    _saveToHive();
  }

  void addCourse(String semId) {
    final sem = _semesters.firstWhere((s) => s.id == semId);
    sem.courses.add(
      Course(
        id: "course-${DateTime.now().millisecondsSinceEpoch}",
        name: "",
        credits: 0.0,
        grade: gradesList.first,
      ),
    );
    sem.isCollapsed = false;
    _saveToHive();
  }

  // ✨ ADD THIS METHOD for Drag-and-Drop Reordering
  void reorderSemesters(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1; // Adjust for the item being removed before insertion
    }
    final Semester item = _semesters.removeAt(oldIndex);
    _semesters.insert(newIndex, item);
    _saveToHive();
  }

  void updateCourse(
    String semId,
    String courseId, {
    String? name,
    double? credits,
    String? grade,
  }) {
    final sem = _semesters.firstWhere((s) => s.id == semId);
    final course = sem.courses.firstWhere((c) => c.id == courseId);

    if (name != null) course.name = name;
    if (credits != null) course.credits = credits;
    if (grade != null) course.grade = grade;

    sem.sgpa = calculateSgpa(sem.courses);
    _saveToHive();
  }

  void removeCourse(String semId, String courseId) {
    final sem = _semesters.firstWhere((s) => s.id == semId);
    sem.courses.removeWhere((c) => c.id == courseId);
    sem.sgpa = calculateSgpa(sem.courses);
    _saveToHive();
  }

  void toggleCollapse(String semId) {
    final sem = _semesters.firstWhere((s) => s.id == semId);
    sem.isCollapsed = !sem.isCollapsed;
    _saveToHive();
  }

  void clearAllData() {
    _box?.clear();
    _semesters.clear();
    addSemester(name: "Semester 1");
  }

  void _saveToHive() {
    _box?.clear().then((_) {
      _box?.addAll(_semesters);
      notifyListeners();
    });
  }

  // --- PLANNER LOGIC ---

  void setTargetCgpa(double target) {
    _targetCgpa = target;
    notifyListeners();
  }

  void setProjectedSgpa(double sgpa) {
    _projectedSgpa = sgpa;
    notifyListeners();
  }

  void addFutureSemester() {
    _futureSemesterCredits.add(25.0); // Default 25 credits
    notifyListeners();
  }

  void removeFutureSemester(int index) {
    _futureSemesterCredits.removeAt(index);
    notifyListeners();
  }

  void updateFutureCredits(int index, double credits) {
    _futureSemesterCredits[index] = credits;
    notifyListeners();
  }

  double getRequiredSgpa() {
    double futureTotalCredits = _futureSemesterCredits.fold(
      0.0,
      (sum, val) => sum + val,
    );

    if (_targetCgpa == 0 || futureTotalCredits == 0) return 0.0;

    double currentTotalCredits = 0;
    double currentTotalPoints = 0;

    for (var sem in _semesters) {
      double semCredits = sem.courses.fold(0.0, (sum, c) => sum + c.credits);
      currentTotalCredits += semCredits;
      currentTotalPoints += sem.sgpa * semCredits;
    }

    double targetTotalPoints =
        _targetCgpa * (currentTotalCredits + futureTotalCredits);
    double requiredFuturePoints = targetTotalPoints - currentTotalPoints;

    return requiredFuturePoints / futureTotalCredits;
  }

  double getResultingCgpa() {
    double futureTotalCredits = _futureSemesterCredits.fold(
      0.0,
      (sum, val) => sum + val,
    );

    double currentTotalCredits = 0;
    double currentTotalPoints = 0;

    for (var sem in _semesters) {
      double semCredits = sem.courses.fold(0.0, (sum, c) => sum + c.credits);
      currentTotalCredits += semCredits;
      currentTotalPoints += sem.sgpa * semCredits;
    }

    if (futureTotalCredits == 0) {
      return currentTotalCredits > 0
          ? (currentTotalPoints / currentTotalCredits)
          : 0.0;
    }

    double futureTotalPoints = _projectedSgpa * futureTotalCredits;
    return (currentTotalPoints + futureTotalPoints) /
        (currentTotalCredits + futureTotalCredits);
  }

  // --- IMPORT / EXPORT LOGIC ---

  String exportToJson() {
    final data = _semesters.map((s) => s.toJson()).toList();
    return jsonEncode({'semesters': data});
  }

  bool importFromJson(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded != null && decoded['semesters'] is List) {
        final List sems = decoded['semesters'];
        _semesters.clear();
        _semesters.addAll(sems.map((s) => Semester.fromJson(s)).toList());
        _saveToHive();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Import Error: $e");
      return false;
    }
  }
}
