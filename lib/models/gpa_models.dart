import 'package:hive/hive.dart';

part 'gpa_models.g.dart';

@HiveType(
  typeId: 1,
) // Make sure typeId doesn't conflict with ScheduleEntry (which is 0)
class Course extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  double credits;

  @HiveField(3)
  String grade;

  Course({
    required this.id,
    required this.name,
    required this.credits,
    required this.grade,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'credits': credits,
    'grade': grade,
  };

  factory Course.fromJson(Map<String, dynamic> json) => Course(
    id: json['id'] ?? "course-${DateTime.now().microsecondsSinceEpoch}",
    name: json['name'] ?? '',
    credits: (json['credits'] ?? 0).toDouble(),
    grade: json['grade'] ?? 'A++',
  );
}

@HiveType(typeId: 2)
class Semester extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  List<Course> courses;

  @HiveField(3)
  double sgpa;

  @HiveField(4)
  bool isCollapsed;

  Semester({
    required this.id,
    required this.name,
    required this.courses,
    this.sgpa = 0.0,
    this.isCollapsed = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'sgpa': sgpa,
    'isCollapsed': isCollapsed,
    'courses': courses.map((c) => c.toJson()).toList(),
  };

  factory Semester.fromJson(Map<String, dynamic> json) => Semester(
    id: json['id'] ?? "sem-${DateTime.now().millisecondsSinceEpoch}",
    name: json['name'] ?? 'Imported Semester',
    sgpa: (json['sgpa'] ?? 0).toDouble(),
    isCollapsed: json['isCollapsed'] ?? false,
    courses:
        (json['courses'] as List?)?.map((c) => Course.fromJson(c)).toList() ??
        [],
  );
}
