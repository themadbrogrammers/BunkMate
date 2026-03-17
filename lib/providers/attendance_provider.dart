import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'dart:convert';
import 'package:bunkmate/services/attendance_calculator.dart';
import 'package:bunkmate/helpers/toast_helper.dart';
import 'package:bunkmate/services/remote_config_service.dart';

class SaveSlot {
  String name;
  String attendanceData;
  int targetPercent;
  String projectionMode;
  int projectionRemainingTime;
  int projectionClassesPerWeek;
  int projectionDaysPerWeek;
  DateTime timestamp;

  SaveSlot({
    required this.name,
    required this.attendanceData,
    required this.targetPercent,
    required this.projectionMode,
    required this.projectionRemainingTime,
    required this.projectionClassesPerWeek,
    required this.projectionDaysPerWeek,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'attendanceData': attendanceData,
    'targetPercent': targetPercent,
    'projectionMode': projectionMode,
    'projectionRemainingTime': projectionRemainingTime,
    'projectionClassesPerWeek': projectionClassesPerWeek,
    'projectionDaysPerWeek': projectionDaysPerWeek,
    'timestamp': timestamp.toIso8601String(),
  };

  factory SaveSlot.fromJson(Map<String, dynamic> json) => SaveSlot(
    name: json['name'] as String? ?? 'Unnamed Slot',
    attendanceData: json['attendanceData'] as String? ?? '',
    targetPercent: json['targetPercent'] as int? ?? 65,
    projectionMode: json['projectionMode'] as String? ?? 'weeks',
    projectionRemainingTime: json['projectionRemainingTime'] as int? ?? 5,
    projectionClassesPerWeek: json['projectionClassesPerWeek'] as int? ?? 35,
    projectionDaysPerWeek: json['projectionDaysPerWeek'] as int? ?? 6,
    timestamp:
        DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
  );
}

class SubjectStatsDetailed {
  final String name;
  double attended;
  double conducted;
  double present;
  double od;
  double makeup;
  double absent;
  List<AbsenceRecord> absences;

  SubjectStatsDetailed({
    required this.name,
    this.attended = 0.0,
    this.conducted = 0.0,
    this.present = 0.0,
    this.od = 0.0,
    this.makeup = 0.0,
    this.absent = 0.0,
    List<AbsenceRecord>? initialAbsences,
  }) : absences = initialAbsences ?? [];

  double get percentage => (conducted > 0) ? (attended / conducted) * 100 : 0.0;
}

class AbsenceRecord {
  final DateTime date;
  final double hours;
  AbsenceRecord({required this.date, required this.hours});
}

class CalculationResult {
  final double totalAttended;
  final double totalConducted;
  final double totalPresent;
  final double totalOD;
  final double totalMakeup;
  final double totalAbsent;
  final double currentPercentage;
  final int maxDroppableHours;
  final int requiredToAttend;
  final Map<String, SubjectStatsDetailed> subjectStats;
  final bool dataParsedSuccessfully;
  final int targetPercentage;
  final int projectionClassesPerWeek;
  final String? fileName;
  final DateTime? timestamp;

  CalculationResult({
    this.totalAttended = 0.0,
    this.totalConducted = 0.0,
    this.totalPresent = 0.0,
    this.totalOD = 0.0,
    this.totalMakeup = 0.0,
    this.totalAbsent = 0.0,
    this.currentPercentage = 0.0,
    this.maxDroppableHours = 0,
    this.requiredToAttend = 0,
    this.subjectStats = const {},
    this.dataParsedSuccessfully = false,
    this.targetPercentage = 0,
    this.projectionClassesPerWeek = 0,
    this.fileName,
    this.timestamp,
  });

  factory CalculationResult.empty() => CalculationResult();

  CalculationResult copyWith({
    double? totalAttended,
    double? totalConducted,
    double? totalPresent,
    double? totalOD,
    double? totalMakeup,
    double? totalAbsent,
    double? currentPercentage,
    int? maxDroppableHours,
    int? requiredToAttend,
    Map<String, SubjectStatsDetailed>? subjectStats,
    bool? dataParsedSuccessfully,
    int? targetPercentage,
    int? projectionClassesPerWeek,
    String? fileName,
    DateTime? timestamp,
  }) {
    return CalculationResult(
      totalAttended: totalAttended ?? this.totalAttended,
      totalConducted: totalConducted ?? this.totalConducted,
      totalPresent: totalPresent ?? this.totalPresent,
      totalOD: totalOD ?? this.totalOD,
      totalMakeup: totalMakeup ?? this.totalMakeup,
      totalAbsent: totalAbsent ?? this.totalAbsent,
      currentPercentage: currentPercentage ?? this.currentPercentage,
      maxDroppableHours: maxDroppableHours ?? this.maxDroppableHours,
      requiredToAttend: requiredToAttend ?? this.requiredToAttend,
      subjectStats: subjectStats ?? this.subjectStats,
      dataParsedSuccessfully:
          dataParsedSuccessfully ?? this.dataParsedSuccessfully,
      targetPercentage: targetPercentage ?? this.targetPercentage,
      projectionClassesPerWeek:
          projectionClassesPerWeek ?? this.projectionClassesPerWeek,
      fileName: fileName ?? this.fileName,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

class AttendanceProvider extends ChangeNotifier {
  // --- Core State ---
  String _rawData = "";
  String get rawData => _rawData;

  bool _overlayShownThisSession = false;
  bool get overlayShownThisSession => _overlayShownThisSession;
  bool get isOverlayEligible =>
      !_overlayShownThisSession &&
      result.dataParsedSuccessfully &&
      result.totalConducted > 0;

  int _targetPercentage = 65;
  int get targetPercentage => _targetPercentage;

  CalculationResult _result = CalculationResult.empty();
  CalculationResult get result => _result;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isUnrecognizedFormat = false;
  bool get isUnrecognizedFormat => _isUnrecognizedFormat;

  String? _rawInputSnapshot;
  String? get rawInputSnapshot => _rawInputSnapshot;

  String? _fileName;
  String? get fileName => _fileName;

  // --- Planner State ---
  int _plannerFutureClassesToAttend = 0;
  int get plannerFutureClassesToAttend => _plannerFutureClassesToAttend;

  String _projectionMode = 'weeks';
  String get projectionMode => _projectionMode;

  int _projectionRemainingTime = 5;
  int get projectionRemainingTime => _projectionRemainingTime;

  int _projectionClassesPerWeek = 35;
  int get projectionClassesPerWeek => _projectionClassesPerWeek;

  int _projectionDaysPerWeek = 6;
  int get projectionDaysPerWeek => _projectionDaysPerWeek;

  String? _whatIfSelectedSubject;
  String? get whatIfSelectedSubject => _whatIfSelectedSubject;

  String _whatIfAction = 'attend';
  String get whatIfAction => _whatIfAction;

  int _whatIfNumClasses = 1;
  int get whatIfNumClasses => _whatIfNumClasses;

  Map<String, dynamic>? _whatIfResult;
  Map<String, dynamic>? get whatIfResult => _whatIfResult;

  int _holidayAttendBefore = 0;
  int get holidayAttendBefore => _holidayAttendBefore;

  String _holidayInputMode = 'days';
  String get holidayInputMode => _holidayInputMode;

  int _holidayDays = 1;
  int get holidayDays => _holidayDays;

  int _holidayTotalClassesToMiss = 10;
  int get holidayTotalClassesToMiss => _holidayTotalClassesToMiss;

  Map<String, dynamic>? _holidayImpactResult;
  Map<String, dynamic>? get holidayImpactResult => _holidayImpactResult;

  static const String _savesKey = 'attendanceAppSaves';
  static const int _maxSaves = 2;
  int get maxSaves => _maxSaves;

  SharedPreferences? _prefs;

  AttendanceProvider() {
    // _initAndLoad();
    _ensurePrefs();
    loadSavedTargetOnly();
  }

  // --- Initialization & Persistence Helpers ---

  // Future<void> _initAndLoad() async {
  //   await _ensurePrefs();
  //   await loadSavedData();
  // }

  Future<void> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Future<void> loadSavedTargetOnly() async {
  //   await _ensurePrefs();
  //   final savedTarget = _prefs!.getInt('lastTargetPercentage');

  //   if (savedTarget != null && savedTarget >= 0 && savedTarget <= 100) {
  //     _targetPercentage = savedTarget;
  //     notifyListeners(); // UI slider updates
  //   }
  // }

  Future<void> loadSavedTargetOnly() async {
    await _ensurePrefs();

    // 1. Try to load the target they were specifically using last session
    final savedSessionTarget = _prefs!.getInt('lastTargetPercentage');
    // 2. If it's a fresh start, grab their global default setting (fallback to 75)
    final globalDefaultTarget = _prefs!.getInt('defaultTarget') ?? 75;

    // ✨ FIX: Use the session target if it exists, otherwise use their global default
    final finalTargetToUse = savedSessionTarget ?? globalDefaultTarget;

    if (finalTargetToUse >= 0 && finalTargetToUse <= 100) {
      _targetPercentage = finalTargetToUse;
      notifyListeners();
    }
  }

  // --- Core Lifecycle Methods ---

  void markOverlayAsShown() => _overlayShownThisSession = true;
  void resetOverlayFlag() => _overlayShownThisSession = false;

  Future<void> updateSlotName(String slotId, String newName) async {
    await _ensurePrefs();
    final currentSaves = await getAllSaves();
    final savedSlot = currentSaves[slotId];

    if (savedSlot != null) {
      final trimmedName = newName.trim();
      if (trimmedName.isNotEmpty && savedSlot.name != trimmedName) {
        savedSlot.name = trimmedName;
        currentSaves[slotId] = savedSlot;

        try {
          final String savesJson = jsonEncode(
            currentSaves.map((k, v) => MapEntry(k, v.toJson())),
          );
          await _prefs!.setString(_savesKey, savesJson);
          showTopToast("✅ Slot renamed to '$trimmedName'");
        } catch (e) {
          debugPrint("Error renaming slot: $e");
          showTopToast("❌ Failed to rename slot");
        }
      }
    } else {
      showTopToast("⚠️ Slot not found");
    }
  }

  Future<Map<String, SaveSlot>> getAllSaves() async {
    await _ensurePrefs();
    final String? savesJson = _prefs?.getString(_savesKey);
    if (savesJson == null || savesJson.isEmpty) return {};

    try {
      final Map<String, dynamic> decodedMap = jsonDecode(savesJson);
      final Map<String, SaveSlot> validSaves = {};
      decodedMap.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          try {
            validSaves[key] = SaveSlot.fromJson(value);
          } catch (e) {
            debugPrint("Corrupt SaveSlot at $key: $e");
          }
        }
      });
      return validSaves;
    } catch (e) {
      debugPrint("Error decoding saves: $e");
      return {};
    }
  }

  Future<void> saveToSlot(String slotId, String slotName) async {
    await _ensurePrefs();
    if (_rawData.trim().isEmpty) return;

    final currentSaves = await getAllSaves();
    currentSaves[slotId] = SaveSlot(
      name: slotName.trim().isNotEmpty
          ? slotName.trim()
          : slotId.replaceFirst('slot', 'Save Slot '),
      attendanceData: _rawData,
      targetPercent: _targetPercentage,
      projectionMode: _projectionMode,
      projectionRemainingTime: _projectionRemainingTime,
      projectionClassesPerWeek: _projectionClassesPerWeek,
      projectionDaysPerWeek: _projectionDaysPerWeek,
      timestamp: DateTime.now(),
    );

    try {
      final String savesJson = jsonEncode(
        currentSaves.map((k, v) => MapEntry(k, v.toJson())),
      );
      await _prefs!.setString(_savesKey, savesJson);
      notifyListeners();
    } catch (e) {
      debugPrint("Error saving slot: $e");
    }
  }

  Future<bool> loadFromSlot(String slotId) async {
    await _ensurePrefs();
    final currentSaves = await getAllSaves();
    final savedSlot = currentSaves[slotId];

    if (savedSlot != null) {
      _targetPercentage = savedSlot.targetPercent;
      _projectionMode = savedSlot.projectionMode;
      _projectionRemainingTime = savedSlot.projectionRemainingTime;
      _projectionClassesPerWeek = savedSlot.projectionClassesPerWeek;
      _projectionDaysPerWeek = savedSlot.projectionDaysPerWeek;
      _clearValidationState();

      setRawData(savedSlot.attendanceData, newFileName: savedSlot.name);
      return true;
    }
    return false;
  }

  Future<void> deleteSlot(String slotId) async {
    await _ensurePrefs();
    final currentSaves = await getAllSaves();
    if (currentSaves.containsKey(slotId)) {
      currentSaves.remove(slotId);
      try {
        final String savesJson = jsonEncode(
          currentSaves.map((k, v) => MapEntry(k, v.toJson())),
        );
        await _prefs!.setString(_savesKey, savesJson);
        notifyListeners();
      } catch (e) {
        debugPrint("Error deleting slot: $e");
      }
    }
  }

  // --- Planner Getters ---

  int get projectionTotalRemainingClasses {
    if (_projectionMode == 'weeks') {
      return _projectionRemainingTime * _projectionClassesPerWeek;
    }
    if (_projectionDaysPerWeek > 0) {
      final avg = _projectionClassesPerWeek / _projectionDaysPerWeek;
      return (_projectionRemainingTime * avg).round().clamp(0, 99999);
    }
    return 0;
  }

  int get projectionRequiredAttendance {
    if (!result.dataParsedSuccessfully || result.totalConducted <= 0) return 0;
    final double targetDecimal = _targetPercentage / 100.0;
    if (targetDecimal <= 0 || targetDecimal >= 1)
      return projectionTotalRemainingClasses;

    final totalFutureConducted =
        result.totalConducted + projectionTotalRemainingClasses;
    final totalRequiredOverall = (totalFutureConducted * targetDecimal)
        .ceilToDouble();
    final needed = totalRequiredOverall - result.totalAttended;

    return needed
        .clamp(0.0, projectionTotalRemainingClasses.toDouble())
        .toInt();
  }

  int get projectionAllowedSkips {
    final remaining = projectionTotalRemainingClasses;
    final required = projectionRequiredAttendance;
    return (remaining - required).clamp(0, remaining);
  }

  double get projectionFinalPercentage {
    if (!result.dataParsedSuccessfully || result.totalConducted <= 0)
      return 0.0;
    final finalConducted =
        result.totalConducted + projectionTotalRemainingClasses;
    if (finalConducted <= 0) return result.currentPercentage;
    final finalAttended = result.totalAttended + projectionRequiredAttendance;
    return (finalAttended / finalConducted * 100).clamp(0.0, 100.0);
  }

  double get calculatedAvgClassesPerDay {
    return (_projectionDaysPerWeek > 0)
        ? _projectionClassesPerWeek / _projectionDaysPerWeek
        : 0.0;
  }

  // --- Input & Calculation Logic ---

  void updateRawDataWithoutCalc(String data) {
    if (_rawData != data) {
      _rawData = data;
    }
  }

  void setRawData(String data, {String? newFileName}) {
    _rawData = data.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
    _fileName =
        (newFileName != null &&
            newFileName != 'Pasted from clipboard' &&
            _rawData.isNotEmpty)
        ? newFileName
        : null;

    _clearValidationState();

    if (_rawData.isNotEmpty) {
      calculateHours();
    } else {
      _result = CalculationResult.empty();
      notifyListeners();
    }
  }

  void _clearValidationState() {
    _errorMessage = null;
    _isUnrecognizedFormat = false;
    _rawInputSnapshot = null;
    _whatIfResult = null;
    _holidayImpactResult = null;
  }

  void setTargetPercentage(int newTarget) {
    if (newTarget >= 0 && newTarget <= 100 && newTarget != _targetPercentage) {
      _targetPercentage = newTarget;
      _whatIfResult = null;
      _holidayImpactResult = null;
      saveData();
      if (_rawData.isNotEmpty && result.dataParsedSuccessfully) {
        calculateHours();
      } else {
        notifyListeners();
      }
    }
  }

  // Planner Setters with redundant notify avoidance
  void setPlannerFutureClasses(int value) {
    final val = value.clamp(0, 9999);
    if (_plannerFutureClassesToAttend != val) {
      _plannerFutureClassesToAttend = val;
      notifyListeners();
    }
  }

  void setProjectionMode(String mode) {
    if ((mode == 'weeks' || mode == 'days') && _projectionMode != mode) {
      _projectionMode = mode;
      notifyListeners();
    }
  }

  void setProjectionRemainingTime(int value) {
    final val = value.clamp(1, 999);
    if (_projectionRemainingTime != val) {
      _projectionRemainingTime = val;
      notifyListeners();
    }
  }

  void setProjectionClassesPerWeek(int value) {
    final val = value.clamp(1, 999);
    if (_projectionClassesPerWeek != val) {
      _projectionClassesPerWeek = val;
      if (_projectionMode == 'days' && _projectionDaysPerWeek > val) {
        _projectionDaysPerWeek = val.clamp(1, 7);
      }
      notifyListeners();
    }
  }

  void setProjectionDaysPerWeek(int value) {
    final val = value.clamp(1, 7).clamp(1, _projectionClassesPerWeek);
    if (_projectionDaysPerWeek != val) {
      _projectionDaysPerWeek = val;
      notifyListeners();
    }
  }

  void setWhatIfSubject(String? subjectName) {
    if (_whatIfSelectedSubject != subjectName) {
      _whatIfSelectedSubject = subjectName;
      _whatIfResult = null;
      notifyListeners();
    }
  }

  void setWhatIfAction(String action) {
    if ((action == 'attend' || action == 'miss') && _whatIfAction != action) {
      _whatIfAction = action;
      _whatIfResult = null;
      notifyListeners();
    }
  }

  void setWhatIfNumClasses(int value) {
    final val = value.clamp(1, 999);
    if (_whatIfNumClasses != val) {
      _whatIfNumClasses = val;
      _whatIfResult = null;
      notifyListeners();
    }
  }

  void setHolidayAttendBefore(int value) {
    final val = value.clamp(0, 9999);
    if (_holidayAttendBefore != val) {
      _holidayAttendBefore = val;
      _holidayImpactResult = null;
      notifyListeners();
    }
  }

  void setHolidayInputMode(String mode) {
    if ((mode == 'days' || mode == 'classes') && _holidayInputMode != mode) {
      _holidayInputMode = mode;
      _holidayImpactResult = null;
      notifyListeners();
    }
  }

  void setHolidayDays(int value) {
    final val = value.clamp(1, 365);
    if (_holidayDays != val) {
      _holidayDays = val;
      _holidayImpactResult = null;
      notifyListeners();
    }
  }

  void setHolidayTotalClassesToMiss(int value) {
    final val = value.clamp(1, 9999);
    if (_holidayTotalClassesToMiss != val) {
      _holidayTotalClassesToMiss = val;
      _holidayImpactResult = null;
      notifyListeners();
    }
  }

  // --- Async Isolate Calculation ---

  Future<void> calculateHours() async {
    if (_rawData.trim().isEmpty) {
      if (_result.dataParsedSuccessfully || _errorMessage != null) {
        _result = CalculationResult.empty();
        _errorMessage = null;
        notifyListeners();
      }
      return;
    }

    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final erpLogicString = RemoteConfigService.instance.erpAttendanceLogic;

    final input = ComputeInput(
      rawData: _rawData,
      targetPercentage: _targetPercentage,
      erpConfigJson: erpLogicString,
    );

    try {
      final calcOutput = await compute(performCalculation, input);

      // Race condition protection: Check if inputs mutated during isolate execution
      if (_rawData != input.rawData ||
          _targetPercentage != input.targetPercentage) {
        debugPrint("Stale isolate result discarded.");
        _isLoading = false;
        // Logic intentionally returns without notifying; if state changed,
        // another calculateHours() call is already queued or active.
        return;
      }

      _isLoading = false;
      _isUnrecognizedFormat = calcOutput.unrecognizedFormat;

      if (_isUnrecognizedFormat) {
        _result = CalculationResult.empty();
        _errorMessage = null;
        _rawInputSnapshot = _rawData;
        _whatIfResult = null;
        _holidayImpactResult = null;
      } else {
        _result = calcOutput.result.copyWith(
          targetPercentage: _targetPercentage,
          projectionClassesPerWeek: _projectionClassesPerWeek,
          fileName: _fileName,
          timestamp: DateTime.now(),
        );
        _errorMessage = calcOutput.errorMessage;
      }

      if (_errorMessage != null) {
        _whatIfResult = null;
        _holidayImpactResult = null;
      } else {
        await saveData();
      }
      notifyListeners();
    } catch (error) {
      _isLoading = false;
      _result = CalculationResult.empty();
      _errorMessage = "Unexpected isolate error: ${error.toString()}";
      _whatIfResult = null;
      _holidayImpactResult = null;
      debugPrint("Compute Isolate Error: $error");
      notifyListeners();
    }
  }

  // --- Persistence Methods ---

  Future<void> saveData() async {
    await _ensurePrefs();
    await _prefs!.setString('lastRawData', _rawData);
    await _prefs!.setInt('lastTargetPercentage', _targetPercentage);

    if (_result.dataParsedSuccessfully) {
      await _prefs!.setInt('cached_max_droppable', _result.maxDroppableHours);
      await _prefs!.setInt('cached_required_attend', _result.requiredToAttend);
    } //notification

    debugPrint("Persistent Save: Data and Target Cached.");
  }

  Future<bool> loadSavedData() async {
    await _ensurePrefs();
    final savedData = _prefs!.getString('lastRawData');
    final savedTarget = _prefs!.getInt('lastTargetPercentage');

    if (savedData != null || savedTarget != null) {
      if (savedData != null) _rawData = savedData;
      if (savedTarget != null) _targetPercentage = savedTarget;
      _fileName = "Resumed Session";

      if (_rawData.isNotEmpty) {
        calculateHours();
      } else {
        notifyListeners();
      }
      return true;
    }
    return false;
  }

  // Future<void> clearData() async {
  //   _rawData = "";
  //   _fileName = null;
  //   _errorMessage = null;
  //   _result = CalculationResult.empty();
  //   _whatIfResult = null;
  //   _holidayImpactResult = null;
  //   _plannerFutureClassesToAttend = 0;
  //   _isUnrecognizedFormat = false;
  //   _rawInputSnapshot = null;

  //   await _ensurePrefs();
  //   await _prefs?.remove('lastRawData');
  //   await _prefs?.remove('lastTargetPercentage');

  //   notifyListeners();
  // }

  Future<void> clearData() async {
    await _ensurePrefs();

    // ✨ FIX: When they clear data, reset the slider back to their global default setting!
    final globalDefaultTarget = _prefs!.getInt('defaultTarget') ?? 75;

    _rawData = "";
    _fileName = null;
    _errorMessage = null;
    _result = CalculationResult.empty();
    _whatIfResult = null;
    _holidayImpactResult = null;
    _plannerFutureClassesToAttend = 0;
    _isUnrecognizedFormat = false;
    _rawInputSnapshot = null;

    // Set the target to their preferred default
    _targetPercentage = globalDefaultTarget;

    await _prefs?.remove('lastRawData');
    await _prefs?.remove('lastTargetPercentage');

    notifyListeners();
  }

  // --- Main Thread Planner Simulations ---

  Map<String, dynamic> calculateCustomMissable() {
    if (!result.dataParsedSuccessfully ||
        result.totalConducted <= 0 ||
        _plannerFutureClassesToAttend <= 0) {
      return {'canCalculate': false};
    }
    final double targetDecimal = _targetPercentage / 100.0;
    final tempAttended = result.totalAttended + _plannerFutureClassesToAttend;
    final tempConducted = result.totalConducted + _plannerFutureClassesToAttend;

    if (targetDecimal <= 0 || targetDecimal >= 1 || tempConducted <= 0) {
      return {'canCalculate': false, 'error': 'Invalid target or data.'};
    }

    final numerator = tempAttended - (targetDecimal * tempConducted);
    final maxSkips = (numerator / targetDecimal).floor();

    if (maxSkips < 0) {
      final finalPercent = (tempAttended / tempConducted * 100);
      return {
        'canCalculate': true,
        'isSafe': false,
        'message':
            '⚠️ Even after attending $_plannerFutureClassesToAttend more class(es) (${finalPercent.toStringAsFixed(1)}%), you still cannot reach the $_targetPercentage% target.',
      };
    } else {
      final projectedConducted = tempConducted + maxSkips;
      final projectedPercent = (tempAttended / projectedConducted) * 100;
      return {
        'canCalculate': true,
        'isSafe': true,
        'skipsAllowed': maxSkips,
        'originalSkips': result.maxDroppableHours,
        'projectedAttended': tempAttended.round(),
        'projectedConducted': projectedConducted.round(),
        'projectedPercent': projectedPercent,
      };
    }
  }

  void runWhatIfSimulation() {
    _whatIfResult = null;
    if (!result.dataParsedSuccessfully ||
        result.totalConducted <= 0 ||
        result.subjectStats.isEmpty ||
        _whatIfSelectedSubject == null ||
        _whatIfNumClasses <= 0) {
      _whatIfResult = {
        'error': 'Select a subject and enter a valid number of classes (> 0).',
      };
      notifyListeners();
      return;
    }

    final originalSubject = result.subjectStats[_whatIfSelectedSubject!];
    if (originalSubject == null || originalSubject.conducted <= 0) {
      _whatIfResult = {'error': 'Selected subject has invalid data.'};
      notifyListeners();
      return;
    }

    double simAttended = result.totalAttended;
    double simConducted = result.totalConducted;
    double simSubAttended = originalSubject.attended;
    double simSubConducted = originalSubject.conducted;

    if (_whatIfAction == 'attend') {
      simAttended += _whatIfNumClasses;
      simConducted += _whatIfNumClasses;
      simSubAttended += _whatIfNumClasses;
      simSubConducted += _whatIfNumClasses;
    } else {
      simConducted += _whatIfNumClasses;
      simSubConducted += _whatIfNumClasses;
    }

    final newSubPercent = (simSubAttended / simSubConducted * 100);
    final newOverallPercent = (simAttended / simConducted * 100);

    _whatIfResult = {
      'subjectName': _whatIfSelectedSubject,
      'action': _whatIfAction,
      'numClasses': _whatIfNumClasses,
      'originalSubjectPercent': originalSubject.percentage,
      'newSubjectPercent': newSubPercent,
      'originalOverallPercent': result.currentPercentage,
      'newOverallPercent': newOverallPercent,
      'isAboveTarget': newOverallPercent >= _targetPercentage,
    };
    notifyListeners();
  }

  void calculateHolidayImpact() {
    _holidayImpactResult = null;
    if (!result.dataParsedSuccessfully || result.totalConducted <= 0) {
      _holidayImpactResult = {'error': 'Calculate current attendance first.'};
      notifyListeners();
      return;
    }

    int totalMissed = 0;
    String desc = "";
    double avg = calculatedAvgClassesPerDay;

    if (_holidayInputMode == 'days') {
      if (_holidayDays <= 0 || avg <= 0) {
        _holidayImpactResult = {
          'error': 'Enter valid positive numbers for days and classes/day.',
        };
        notifyListeners();
        return;
      }
      totalMissed = (_holidayDays * avg).round();
      desc =
          "$_holidayDays-day leave (~$totalMissed classes @ ${avg.toStringAsFixed(1)}/day)";
    } else {
      if (_holidayTotalClassesToMiss <= 0) {
        _holidayImpactResult = {
          'error': 'Enter a valid positive number for total classes to miss.',
        };
        notifyListeners();
        return;
      }
      totalMissed = _holidayTotalClassesToMiss;
      desc = "a leave missing $totalMissed classes";
    }

    final attAfter = result.totalAttended + _holidayAttendBefore;
    final condAfterLeave =
        result.totalConducted + _holidayAttendBefore + totalMissed;
    final double pctAfter = (attAfter / condAfterLeave * 100);
    final bool isSafe = pctAfter >= _targetPercentage;
    int recovery = 0;

    if (!isSafe) {
      final double targetDecimal = _targetPercentage / 100.0;
      if (targetDecimal < 1.0) {
        final deficit = (targetDecimal * condAfterLeave) - attAfter;
        recovery = (deficit / (1 - targetDecimal)).ceil().clamp(0, 99999);
      } else {
        recovery = 99999;
      }
    }

    int remainingSkipsAfter = 0;

    if (isSafe) {
      final double targetDecimal = _targetPercentage / 100.0;

      if (targetDecimal > 0 && targetDecimal < 1) {
        final surplus = attAfter - (targetDecimal * condAfterLeave);
        remainingSkipsAfter = (surplus / targetDecimal).floor().clamp(0, 99999);
      }
    }

    _holidayImpactResult = {
      'attendBefore': _holidayAttendBefore,
      'leaveDescription': desc,
      'attendedAfter': attAfter.round(),
      'conductedAfter': condAfterLeave.round(),
      'percentageAfter': pctAfter,
      'isSafe': isSafe,
      'requiredRecovery': recovery,
      'remainingSkipsAfter': remainingSkipsAfter,
    };
    notifyListeners();
  }
}
