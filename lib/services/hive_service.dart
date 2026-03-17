import 'package:hive_flutter/hive_flutter.dart';
import 'package:bunkmate/models/schedule_entry.dart';

class HiveService {
  static const String _scheduleBoxName = 'classSchedule';

  static Future<void> init(String path) async {
    await Hive.initFlutter(path);
    // Register the adapter
    if (!Hive.isAdapterRegistered(ScheduleEntryAdapter().typeId)) {
      Hive.registerAdapter(ScheduleEntryAdapter());
    }
    // Open the box
    await Hive.openBox<ScheduleEntry>(_scheduleBoxName);
  }

  static Box<ScheduleEntry> getScheduleBox() {
    return Hive.box<ScheduleEntry>(_scheduleBoxName);
  }

  static Future<void> addEntry(ScheduleEntry entry) async {
    final box = getScheduleBox();
    await box.add(entry); // Use add for auto-incrementing key
  }
  
  static Future<void> updateEntry(dynamic key, ScheduleEntry entry) async {
    final box = getScheduleBox();
    await box.put(key, entry); // Use put to update at a specific key
  }

  static Future<void> deleteEntry(dynamic key) async {
    final box = getScheduleBox();
    await box.delete(key);
  }

  static List<ScheduleEntry> getSchedule() {
    final box = getScheduleBox();
    // Return sorted by day, then time
    var list = box.values.toList();
    list.sort((a, b) {
      int dayCompare = a.dayOfWeek.compareTo(b.dayOfWeek);
      if (dayCompare != 0) return dayCompare;
      return a.startTime.compareTo(b.startTime);
    });
    return list;
  }
}