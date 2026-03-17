import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:bunkmate/providers/attendance_provider.dart'; // We need this for CalculationResult, etc.

/// Helper class to pass input data to the compute isolate
class ComputeInput {
  final String rawData;
  final int targetPercentage;
  final String? erpConfigJson;

  ComputeInput({
    required this.rawData,
    required this.targetPercentage,
    this.erpConfigJson,
  });
}

/// Helper class to return multiple values from the compute isolate
class CalculationOutput {
  final CalculationResult result;
  final String? errorMessage;
  final bool unrecognizedFormat;
  final String? fileName;

  CalculationOutput(
    this.result,
    this.errorMessage, {
    this.unrecognizedFormat = false,
    this.fileName,
  });
}

/// Top-level function to intelligently detect format and parse data.
/// Throws an Exception if parsing fails or format is unknown.
Map<String, SubjectStatsDetailed> parseDataTopLevel(
  String textData,
  String? erpConfigJson,
) {
  final lines = textData
      .split('\n')
      .map((line) => line.trim().replaceAll('\r', ''))
      .where((line) => line.isNotEmpty)
      .toList();
  final headerRowIndex = lines.indexWhere(
    (line) => line.toLowerCase().contains('subject'),
  );

  if (headerRowIndex == -1) {
    throw Exception("Could not find a header row containing 'Subject'.");
  }

  final relevantLines = lines.sublist(headerRowIndex);
  if (relevantLines.length < 2) {
    // Need header + at least one data row
    throw Exception(
      "Data must contain at least one data row below the identified header.",
    );
  }
  // Now, the header is guaranteed to be at index 0 within relevantLines
  final headerLine = relevantLines[0];
  final headerLower = headerLine.toLowerCase();

  final bool isRawLog =
      headerLower.contains('date') && headerLower.contains('marked');
  final bool isAggregated =
      headerLower.contains('present') && headerLower.contains('absent');

  Map<String, SubjectStatsDetailed>? parsedStats;

  if (isRawLog) {
    parsedStats = parseRawLogDataTopLevel(relevantLines, 0, erpConfigJson);
  } else if (isAggregated) {
    parsedStats = parseAggregatedDataTopLevel(relevantLines, 0, erpConfigJson);
  } else {
    if (headerLower.contains('subject')) {
      try {
        parsedStats = parseAggregatedDataTopLevel(
          relevantLines,
          0,
          erpConfigJson,
        );
      } catch (aggError) {
        debugPrint(
          "Top-Level: Aggregated parse failed ($aggError), attempting raw log parse as fallback.",
        );
        try {
          parsedStats = parseRawLogDataTopLevel(
            relevantLines,
            0,
            erpConfigJson,
          );
        } catch (rawError) {
          throw Exception(
            "Could not determine data format after attempting both parses. Aggregated Error: $aggError, Raw Error: $rawError",
          );
        }
      }
    } else {
      throw Exception(
        "Could not determine data format. No 'Subject' header found and specific keywords missing.",
      );
    }
  }

  // Check result after parsing attempts
  if (parsedStats == null || parsedStats.isEmpty) {
    throw Exception("Parsing completed but yielded no valid subject data.");
  }

  return parsedStats;
}

/// Top-level function to find header index. Returns -1 if not found.
int findHeaderIndexTopLevel(
  List<String> headers,
  List<String> primaryTerms, {
  List<String> secondaryTerms = const [],
  List<String> exclusionTerms = const [],
}) {
  // 1. Exact primary match (case-insensitive, trimmed)
  for (final term in primaryTerms) {
    final exactIndex = headers.indexWhere(
      (h) => h.trim().toLowerCase() == term.toLowerCase(),
    );
    if (exactIndex > -1) return exactIndex;
  }
  // 2. Partial match containing primary term (excluding exclusions)
  final potentialPrimaryMatches = <int>[];
  for (int i = 0; i < headers.length; i++) {
    final header = headers[i].trim().toLowerCase();
    final bool hasPrimary = primaryTerms.any(
      (pTerm) => header.contains(pTerm.toLowerCase()),
    );
    final bool hasExclusion = exclusionTerms.any(
      (term) => header.contains(term.toLowerCase()),
    );
    if (hasPrimary && !hasExclusion) potentialPrimaryMatches.add(i);
  }
  if (potentialPrimaryMatches.isNotEmpty) {
    potentialPrimaryMatches.sort(
      (a, b) => headers[a].length.compareTo(headers[b].length),
    );
    return potentialPrimaryMatches.first;
  }
  // 3. Fallback: Broad secondary term match (excluding exclusions)
  if (secondaryTerms.isNotEmpty) {
    for (int i = 0; i < headers.length; i++) {
      final header = headers[i].trim().toLowerCase();
      final bool hasSecondary = secondaryTerms.any(
        (term) => header.contains(term.toLowerCase()),
      );
      final bool hasExclusion = exclusionTerms.any(
        (term) => header.contains(term.toLowerCase()),
      );
      if (hasSecondary && !hasExclusion) return i;
    }
  }
  return -1;
}

/// Top-level function to parse Raw Log Data. Throws Exception on critical errors.
Map<String, SubjectStatsDetailed> parseRawLogDataTopLevel(
  List<String> lines,
  int headerRowIndex,
  String? erpConfigJson,
) {
  final splitter = RegExp(r'\t| {2,}|,(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)');
  final headers = lines[headerRowIndex]
      .split(splitter)
      .map((h) => h.trim().replaceAll('"', ''))
      .toList();

  // ✨ DETECT COMPLETE SPACE CORRUPTION ✨
  final bool isCorrupted = headers.length <= 4;

  final subjectIndex = findHeaderIndexTopLevel(
    headers,
    ['subject name', 'subject'],
    secondaryTerms: ['subject'],
    exclusionTerms: ['code'],
  );
  final dateIndex = findHeaderIndexTopLevel(
    headers,
    ['date'],
    secondaryTerms: ['date'],
  );
  final hoursIndex = findHeaderIndexTopLevel(
    headers,
    ['number of hours', 'hours'],
    secondaryTerms: ['hour'],
  );
  final markedIndex = findHeaderIndexTopLevel(
    headers,
    ['marked'],
    secondaryTerms: ['marked', 'status'],
  );

  if (!isCorrupted &&
      [subjectIndex, dateIndex, hoursIndex, markedIndex].contains(-1)) {
    throw Exception("Raw Log Parse Error: Could not find required columns.");
  }

  // --- DYNAMIC ERP CONFIGURATION ---
  double attPres = 1.0, attOd = 1.0, attMak = 1.0, attAbs = 0.0;
  double conPres = 1.0, conOd = 0.0, conMak = 0.0, conAbs = 1.0;

  if (erpConfigJson != null && erpConfigJson.isNotEmpty) {
    try {
      final config = jsonDecode(erpConfigJson);
      final att = config['attended'];
      final con = config['conducted'];

      attPres = (att['present'] as num).toDouble();
      attOd = (att['od'] as num).toDouble();
      attMak = (att['makeup'] as num).toDouble();
      attAbs = (att['absent'] as num).toDouble();

      conPres = (con['present'] as num).toDouble();
      conOd = (con['od'] as num).toDouble();
      conMak = (con['makeup'] as num).toDouble();
      conAbs = (con['absent'] as num).toDouble();
    } catch (_) {
      debugPrint("Failed to parse ERP config for raw logs, using defaults.");
    }
  }

  final subjectStats = <String, SubjectStatsDetailed>{};
  final dataLines = lines.sublist(headerRowIndex + 1);
  final dateFormats = [
    DateFormat("dd-MM-yyyy"),
    DateFormat("d-M-yyyy"),
    DateFormat("MM/dd/yyyy"),
    DateFormat("M/d/yyyy"),
    DateFormat("yyyy-MM-dd"),
  ];

  for (final line in dataLines) {
    var values = line
        .split(splitter)
        .map((v) => v.trim().replaceAll('"', ''))
        .toList();

    // ✨ CORRUPTION RESCUE BLOCK ✨
    if (isCorrupted || values.length <= 4) {
      final parts = line
          .split(RegExp(r'\s+'))
          .where((p) => p.isNotEmpty)
          .toList();
      if (parts.length < 8) continue;

      String marked = parts.last.toUpperCase();
      if (marked == 'DUTY' &&
          parts.length > 1 &&
          parts[parts.length - 2].toUpperCase() == 'ON')
        marked = 'OD';

      double hours = 0.0;
      for (int i = parts.length - 1; i >= 0; i--) {
        if ([
          'P',
          'A',
          'OD',
          'DUTY',
          'ON',
          'PRESENT',
          'ABSENT',
        ].contains(parts[i].toUpperCase()))
          continue;
        if (parts[i].length <= 2) {
          double? parsed = double.tryParse(parts[i]);
          if (parsed != null) {
            hours = parsed;
            break;
          }
        }
      }

      DateTime? absenceDate;
      final dateRegex = RegExp(r'\d{2,4}[-/]\d{1,2}[-/]\d{2,4}');
      for (int i = parts.length - 1; i >= 0; i--) {
        if (dateRegex.hasMatch(parts[i])) {
          String dateString = parts[i];
          for (final format in dateFormats) {
            try {
              final cleanedDateString = dateString.replaceAll(
                RegExp(r'[./]'),
                '-',
              );
              if (cleanedDateString.isNotEmpty) {
                absenceDate = format.parseStrict(cleanedDateString);
                break;
              }
            } catch (_) {}
          }
          break;
        }
      }

      int subjectStartIndex = 1;
      if (int.tryParse(parts[0]) != null && parts.length > 2) {
        if (RegExp(r'[0-9-]').hasMatch(parts[1])) subjectStartIndex = 2;
      }

      final knownTypes = [
        'lecture',
        'lab',
        'tutorial',
        'practical',
        'theory',
        'seminar',
        'workshop',
      ];
      int typeIdx = -1;
      for (int i = subjectStartIndex; i < parts.length; i++) {
        if (knownTypes.contains(parts[i].toLowerCase())) {
          typeIdx = i;
          break;
        }
      }

      if (typeIdx == -1 || typeIdx <= subjectStartIndex) continue;

      bool isMakeup = false;
      int subjectEnd = typeIdx - 1;
      if (subjectEnd >= subjectStartIndex &&
          parts[subjectEnd].toUpperCase() == 'MAKEUP') {
        isMakeup = true;
        subjectEnd--;
      }

      if (subjectEnd < subjectStartIndex) continue;

      final subject = parts
          .sublist(subjectStartIndex, subjectEnd + 1)
          .join(" ");
      final stats = subjectStats.putIfAbsent(
        subject,
        () => SubjectStatsDetailed(name: subject),
      );

      if (isMakeup) {
        if (marked == 'P' || marked == 'PRESENT') stats.makeup += hours;
      } else if (marked == 'P' || marked == 'PRESENT') {
        stats.present += hours;
      } else if (marked == 'OD' || marked == 'ON DUTY') {
        stats.od += hours;
      } else if (marked == 'A' || marked == 'ABSENT') {
        stats.absent += hours;
        if (absenceDate != null)
          stats.absences.add(AbsenceRecord(date: absenceDate, hours: hours));
      }
      continue;
    }

    // --- Original Standard Tab Parsing ---
    bool isMakeup = false;
    int makeupIdx = values.indexWhere((v) => v.toUpperCase() == 'MAKEUP');
    if (makeupIdx != -1) {
      isMakeup = true;
      values.removeAt(makeupIdx);
    }

    final maxIndex = [
      subjectIndex,
      dateIndex,
      hoursIndex,
      markedIndex,
    ].reduce((a, b) => a > b ? a : b);
    if (values.length <= maxIndex) continue;

    final subject = values[subjectIndex];
    if (subject.isEmpty ||
        subject.toLowerCase() == 'subject' ||
        subject.toLowerCase() == 'subject name')
      continue;

    final stats = subjectStats.putIfAbsent(
      subject,
      () => SubjectStatsDetailed(name: subject),
    );
    final hours = double.tryParse(values[hoursIndex]) ?? 0.0;
    if (hours < 0) continue;

    final marked = values[markedIndex].toUpperCase();
    final dateString = values[dateIndex].split(' ')[0];
    DateTime? absenceDate;
    for (final format in dateFormats) {
      try {
        final cleanedDateString = dateString.replaceAll(RegExp(r'[./]'), '-');
        if (cleanedDateString.isNotEmpty) {
          absenceDate = format.parseStrict(cleanedDateString);
          break;
        }
      } catch (_) {}
    }

    if (isMakeup) {
      if (marked == 'P' || marked == 'PRESENT') stats.makeup += hours;
    } else if (marked == 'P' || marked == 'PRESENT') {
      stats.present += hours;
    } else if (marked == 'OD' || marked == 'ON DUTY') {
      stats.od += hours;
    } else if (marked == 'A' || marked == 'ABSENT') {
      stats.absent += hours;
      if (absenceDate != null)
        stats.absences.add(AbsenceRecord(date: absenceDate, hours: hours));
    }
  }

  for (final stats in subjectStats.values) {
    stats.attended =
        (stats.present * attPres) +
        (stats.od * attOd) +
        (stats.makeup * attMak) +
        (stats.absent * attAbs);
    stats.conducted =
        (stats.present * conPres) +
        (stats.od * conOd) +
        (stats.makeup * conMak) +
        (stats.absent * conAbs);
  }

  if (subjectStats.isEmpty)
    throw Exception("Raw Log Parse Error: No valid subject data rows found.");
  return subjectStats;
}

/// Top-level function to parse Aggregated Data. Throws Exception on critical errors.
Map<String, SubjectStatsDetailed> parseAggregatedDataTopLevel(
  List<String> lines,
  int headerRowIndex,
  String? erpConfigJson,
) {
  final splitter = RegExp(r'\t| {2,}|,(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)');
  final headers = lines[headerRowIndex]
      .split(splitter)
      .map((h) => h.trim().replaceAll('"', ''))
      .toList();

  // ✨ DETECT COMPLETE SPACE CORRUPTION ✨
  final bool isCorrupted = headers.length <= 4;
  final headerLower = lines[headerRowIndex].toLowerCase();

  final subjectIndex = findHeaderIndexTopLevel(
    headers,
    ['subject name', 'subject'],
    secondaryTerms: ['subject'],
    exclusionTerms: ['code'],
  );
  final presentIndex = findHeaderIndexTopLevel(
    headers,
    ['present'],
    secondaryTerms: ['present'],
  );
  final odIndex = findHeaderIndexTopLevel(
    headers,
    ['od', 'on duty'],
    secondaryTerms: ['od', 'on duty'],
  );
  final makeupIndex = findHeaderIndexTopLevel(
    headers,
    ['makeup'],
    secondaryTerms: ['makeup', 'extra'],
  );
  final absentIndex = findHeaderIndexTopLevel(
    headers,
    ['absent'],
    secondaryTerms: ['absent'],
  );

  if (!isCorrupted &&
      (subjectIndex == -1 || presentIndex == -1 || absentIndex == -1)) {
    throw Exception("Aggregated Parse Error: Could not find required columns.");
  }

  // Dynamically map which columns exist so we can read them backwards correctly
  bool hasPercent =
      headerLower.contains('percent') || headerLower.contains('%');
  bool hasAbsent = headerLower.contains('absent');
  bool hasMakeup =
      headerLower.contains('makeup') || headerLower.contains('extra');
  bool hasOD = headerLower.contains('od') || headerLower.contains('duty');
  bool hasPresent = headerLower.contains('present');

  double attPres = 1.0, attOd = 1.0, attMak = 1.0, attAbs = 0.0;
  double conPres = 1.0, conOd = 0.0, conMak = 0.0, conAbs = 1.0;

  if (erpConfigJson != null && erpConfigJson.isNotEmpty) {
    try {
      final config = jsonDecode(erpConfigJson);
      final att = config['attended'];
      final con = config['conducted'];

      attPres = (att['present'] as num).toDouble();
      attOd = (att['od'] as num).toDouble();
      attMak = (att['makeup'] as num).toDouble();
      attAbs = (att['absent'] as num).toDouble();

      conPres = (con['present'] as num).toDouble();
      conOd = (con['od'] as num).toDouble();
      conMak = (con['makeup'] as num).toDouble();
      conAbs = (con['absent'] as num).toDouble();
    } catch (e) {
      debugPrint(
        "Failed to parse dynamic ERP config, falling back to defaults.",
      );
    }
  }

  final subjectStats = <String, SubjectStatsDetailed>{};
  final dataLines = lines.sublist(headerRowIndex + 1);

  for (final line in dataLines) {
    final values = line
        .split(splitter)
        .map((v) => v.trim().replaceAll('"', ''))
        .toList();

    // ✨ CORRUPTION RESCUE BLOCK ✨
    if (isCorrupted || values.length <= 4) {
      final parts = line
          .split(RegExp(r'\s+'))
          .where((p) => p.isNotEmpty)
          .toList();
      if (parts.length < 5) continue;

      if (double.tryParse(parts.last) == null) continue;

      int offset = 1;
      if (hasPercent) offset++; // skip percentage

      double absentRescue = 0;
      if (hasAbsent)
        absentRescue = double.tryParse(parts[parts.length - offset++]) ?? 0.0;

      double makeupRescue = 0;
      if (hasMakeup)
        makeupRescue = double.tryParse(parts[parts.length - offset++]) ?? 0.0;

      double odRescue = 0;
      if (hasOD)
        odRescue = double.tryParse(parts[parts.length - offset++]) ?? 0.0;

      double presentRescue = 0;
      if (hasPresent)
        presentRescue = double.tryParse(parts[parts.length - offset++]) ?? 0.0;

      int subjectEndIndex = parts.length - offset;
      while (subjectEndIndex >= 0) {
        final potType = parts[subjectEndIndex].toLowerCase();
        if ([
          'lecture',
          'lab',
          'tutorial',
          'practical',
          'theory',
          'workshop',
          'seminar',
          'project',
        ].contains(potType)) {
          subjectEndIndex--;
        } else {
          break;
        }
      }

      int subjectStartIndex = 0;
      if (int.tryParse(parts[0]) != null) {
        subjectStartIndex = 1;
        if (parts.length > 1 && RegExp(r'[0-9-]').hasMatch(parts[1]))
          subjectStartIndex = 2;
      }

      if (subjectEndIndex < subjectStartIndex) continue;
      final subject = parts
          .sublist(subjectStartIndex, subjectEndIndex + 1)
          .join(" ");

      final stats = subjectStats.putIfAbsent(
        subject,
        () => SubjectStatsDetailed(name: subject),
      );

      stats.present += presentRescue;
      stats.od += odRescue;
      stats.makeup += makeupRescue;
      stats.absent += absentRescue;

      stats.attended +=
          (presentRescue * attPres) +
          (odRescue * attOd) +
          (makeupRescue * attMak) +
          (absentRescue * attAbs);
      stats.conducted +=
          (presentRescue * conPres) +
          (odRescue * conOd) +
          (makeupRescue * conMak) +
          (absentRescue * conAbs);

      continue;
    }

    // --- Original Standard Tab Parsing ---
    final requiredIndices = [subjectIndex, presentIndex, absentIndex];
    if (odIndex != -1) requiredIndices.add(odIndex);
    if (makeupIndex != -1) requiredIndices.add(makeupIndex);
    final validIndices = requiredIndices.where((i) => i != -1).toList();
    if (validIndices.isEmpty) continue;
    final maxIndex = validIndices.reduce((a, b) => a > b ? a : b);

    if (values.length <= maxIndex) continue;

    final subject = values[subjectIndex];
    if (subject.isEmpty ||
        subject.toLowerCase() == 'subject' ||
        subject.toLowerCase() == 'subject name')
      continue;

    final stats = subjectStats.putIfAbsent(
      subject,
      () => SubjectStatsDetailed(name: subject),
    );

    final presentVal = double.tryParse(values[presentIndex]) ?? 0.0;
    final odVal = odIndex != -1
        ? (double.tryParse(values[odIndex]) ?? 0.0)
        : 0.0;
    final makeupVal = makeupIndex != -1
        ? (double.tryParse(values[makeupIndex]) ?? 0.0)
        : 0.0;
    final absentVal = double.tryParse(values[absentIndex]) ?? 0.0;

    if (presentVal < 0 || odVal < 0 || makeupVal < 0 || absentVal < 0) continue;

    stats.present += presentVal;
    stats.od += odVal;
    stats.makeup += makeupVal;
    stats.absent += absentVal;

    stats.attended +=
        (presentVal * attPres) +
        (odVal * attOd) +
        (makeupVal * attMak) +
        (absentVal * attAbs);
    stats.conducted +=
        (presentVal * conPres) +
        (odVal * conOd) +
        (makeupVal * conMak) +
        (absentVal * conAbs);
  }

  if (subjectStats.isEmpty)
    throw Exception(
      "Aggregated Parse Error: No valid subject data rows found.",
    );
  return subjectStats;
}

/// Static function designed to be run in a separate isolate via compute.
CalculationOutput performCalculation(ComputeInput input) {
  String? errorMessage;
  CalculationResult result =
      CalculationResult.empty(); // Start with empty result
  Map<String, SubjectStatsDetailed>? parsedStats;

  if (input.rawData.trim().isEmpty) {
    return CalculationOutput(
      CalculationResult.empty(),
      "Please provide attendance data to begin.",
    );
  }

  try {
    // Call the top-level parsing function
    parsedStats = parseDataTopLevel(input.rawData, input.erpConfigJson);
    // parseDataTopLevel will throw if parsing fails or returns empty/null

    // --- Calculate Totals ---
    double totalAttended = 0.0,
        totalConducted = 0.0,
        totalPresent = 0.0,
        totalOD = 0.0,
        totalMakeup = 0.0,
        totalAbsent = 0.0;
    parsedStats.forEach((key, stats) {
      totalAttended += stats.attended;
      totalConducted += stats.conducted;
      totalPresent += stats.present;
      totalOD += stats.od;
      totalMakeup += stats.makeup;
      totalAbsent += stats.absent;
    });

    if (totalConducted <= 0) {
      throw Exception(
        "Total conducted hours must be positive after parsing. Check data.",
      );
    }

    // --- Calculate Percentage and Max Drop ---
    final double targetDecimal =
        input.targetPercentage / 100.0; // Use target from input
    if (targetDecimal <= 0 || targetDecimal >= 1)
      throw Exception("Target % must be between 1 and 99.");

    final double currentPercentage = (totalAttended / totalConducted) * 100;
    final numerator = totalAttended - (targetDecimal * totalConducted);
    int maxDrop = (numerator / targetDecimal).floor();
    int requiredClasses = 0;

    if (maxDrop < 0) {
      final deficit = (targetDecimal * totalConducted) - totalAttended;
      if (1 - targetDecimal > 0) {
        requiredClasses = (deficit / (1 - targetDecimal)).ceil();
      } else {
        requiredClasses =
            99999; // Indicate practically unreachable if target is 100%
      }
      maxDrop = 0;
    }

    // --- Create Result ---
    result = CalculationResult(
      totalAttended: totalAttended,
      totalConducted: totalConducted,
      totalPresent: totalPresent,
      totalOD: totalOD,
      totalMakeup: totalMakeup,
      totalAbsent: totalAbsent,
      currentPercentage: currentPercentage.isNaN ? 0.0 : currentPercentage,
      maxDroppableHours: maxDrop,
      requiredToAttend: requiredClasses,
      subjectStats: parsedStats, // Use the successfully parsed stats
      dataParsedSuccessfully: true, // Mark as successful
    );
    errorMessage = null; // Clear error on success
  } catch (e) {
    final message = e.toString();

    // 👇 Heuristic: parsing/format-related failures
    final bool looksLikeFormatIssue =
        message.contains('header') ||
        message.contains('Subject') ||
        message.contains('columns') ||
        message.contains('format') ||
        message.contains('No valid subject data') ||
        message.contains('Could not determine');

    if (looksLikeFormatIssue) {
      debugPrint("Unrecognized attendance format detected.");

      return CalculationOutput(
        CalculationResult.empty(),
        null, // ❌ NO error message
        unrecognizedFormat: true,
      );
    }

    // ❌ Genuine error (calculation bug / invalid target etc.)
    errorMessage = message.replaceFirst('Exception: ', '');
    result = CalculationResult.empty();
    debugPrint("Static Calculation Error: $errorMessage");
  }

  return CalculationOutput(result, errorMessage);
}
