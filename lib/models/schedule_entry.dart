import 'package:hive/hive.dart';

part 'schedule_entry.g.dart'; // This file will be generated

@HiveType(typeId: 0) // Unique ID for this model
class ScheduleEntry extends HiveObject {
  @HiveField(0)
  late String subjectName;

  @HiveField(1)
  late int dayOfWeek; // 1 = Monday, 7 = Sunday (from DateTime)

  @HiveField(2)
  late String startTime; // Stored as "HH:mm" (24-hour)

  @HiveField(3, defaultValue: 1)
  int durationHours = 1;
}
