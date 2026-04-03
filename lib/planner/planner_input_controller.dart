import 'package:flutter/material.dart';
import 'package:bunkmate/providers/attendance_provider.dart';

class PlannerInputController {
  final customAttend = TextEditingController();
  final remainingTime = TextEditingController();
  final classesPerWeek = TextEditingController();
  final whatIfClasses = TextEditingController();
  final holidayAttendBefore = TextEditingController();
  final holidayDays = TextEditingController();
  final holidayTotalClasses = TextEditingController();

  void dispose() {
    customAttend.dispose();
    remainingTime.dispose();
    classesPerWeek.dispose();
    whatIfClasses.dispose();
    holidayAttendBefore.dispose();
    holidayDays.dispose();
    holidayTotalClasses.dispose();
  }
}
