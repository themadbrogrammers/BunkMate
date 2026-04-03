import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:bunkmate/providers/gpa_provider.dart';
import 'package:bunkmate/models/gpa_models.dart';
import 'package:bunkmate/helpers/toast_helper.dart';

class GpaPdfParser {
  static const Map<String, double> gradePoints = {
    "A++": 10,
    "A+": 9,
    "A": 8.5,
    "B+": 8,
    "B": 7.5,
    "C+": 7,
    "C": 6.5,
    "D+": 6,
    "D": 5.5,
    "E+": 5,
    "E": 4,
    "F": 0,
  };

  static const Map<String, double> courseCreditMap = {
    '3CDS1-02': 2,
    '3CDS2-01': 3,
    '3CDS3-04': 3,
    '3CDS4-05': 3,
    '3CDS4-06': 3,
    '3CDS4-07': 3,
    '3CDS4-21': 1.5,
    '3CDS4-22': 1.5,
    '3CDS4-23': 1.5,
    '3CDS4-24': 1.5,
    '3CDS7-30': 1,
    'FEC09': 0.5,
    '2FY1-05': 2,
    '2FY1-23': 1,
    '2FY2-01': 4,
    '2FY2-03': 3,
    '2FY2-21': 1.5,
    '2FY3-07': 3,
    '2FY3-09': 3,
    '2FY3-25': 1.5,
    '2FY3-27': 1.5,
    '2FY3-29': 1.5,
    'FEC02': 0.5,
    '1FY1-04': 2,
    '1FY1-22': 1,
    '1FY2-01': 4,
    '1FY2-02': 4,
    '1FY2-20': 1,
    '1FY3-06': 2,
    '1FY3-08': 2,
    '1FY3-24': 1.5,
    '1FY3-26': 1,
    '1FY3-28': 1.5,
    'FEC01': 0.5,
    '4CDS1-03': 2,
    '4CDS2-01': 3,
    '4CDS3-04': 3,
    '4CDS4-05': 3,
    '4CDS4-06': 3,
    '4CDS4-07': 3,
    '4CDS4-21': 1,
    '4CDS4-22': 1.5,
    '4CDS4-23': 1.5,
    '4CDS4-24': 1,
    '4CDS4-25': 1,
    'FEC24': 0.5,
    '5CDS-01': 2,
    '5CDS-02': 3,
    '5CDS-03': 3,
    '5CDS-04': 3,
    '5CDS-05': 3,
    '5CDS-11': 2,
    '5CDS-21': 1,
    '5CDS-22': 1,
    '5CDS-23': 1,
    '5CDS-24': 1,
    '5CDS-30': 2.5,
    'FEC16': 0.5,
  };

  static Future<void> pickAndParsePdf(BuildContext context) async {
    try {
      // 1. Pick the PDF File
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.single.path == null) return;

      showTopToast('📄 Reading PDF...', backgroundColor: Colors.blueAccent);

      // 2. Load PDF Document
      final File file = File(result.files.single.path!);
      final List<int> bytes = await file.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      final PdfTextExtractor extractor = PdfTextExtractor(document);

      // Extract raw text just for finding the semester name easily
      String rawTextForRegex = extractor.extractText();

      // Extract coordinates! Get all text lines and their individual words/bounds
      List<TextLine> textLines = extractor.extractTextLines();
      document.dispose();

      showTopToast(
        '🔍 Analyzing grades...',
        backgroundColor: Colors.purpleAccent,
      );

      // 3. Group words by physical Y-coordinate to build perfect rows
      List<TextWord> allWords = [];
      for (var line in textLines) {
        allWords.addAll(line.wordCollection);
      }

      // Sort all words top-to-bottom first
      allWords.sort((a, b) => a.bounds.bottom.compareTo(b.bounds.bottom));

      // ✨ THE FIX: Correctly group words into visual rows
      List<List<TextWord>> rows = [];
      for (var word in allWords) {
        bool addedToExistingRow = false;

        for (var row in rows) {
          // If the word's Y-coordinate is within 4 pixels of an existing row, it belongs to that row
          if ((row.first.bounds.bottom - word.bounds.bottom).abs() <= 4.0) {
            row.add(word);
            addedToExistingRow = true;
            break;
          }
        }

        if (!addedToExistingRow) {
          rows.add([word]);
        }
      }

      // 4. Parse the Text Rows
      List<Course> extractedCourses = [];
      final courseCodeRegex = RegExp(
        r'\b(\d?[A-Z]{2,}\d?-\d{2,}|[A-Z]+\d{2,})\b',
      );

      for (var row in rows) {
        // Sort words in this specific row from left-to-right (X-coordinate)
        row.sort((a, b) => a.bounds.left.compareTo(b.bounds.left));

        // Reconstruct the line string perfectly ordered
        String cleanLine = row
            .map((w) => w.text)
            .join(' ')
            .replaceAll('"', ' ')
            .replaceAll(',', ' ')
            .trim();

        if (cleanLine.length < 5) continue;

        List<String> parts = cleanLine.split(RegExp(r'\s+'));
        if (parts.length < 3) continue;

        // Find Grade (scanning from right to left)
        String grade = '';
        int gradeIndex = -1;
        for (int i = parts.length - 1; i >= 0; i--) {
          if (gradePoints.containsKey(parts[i])) {
            grade = parts[i];
            gradeIndex = i;
            break;
          }
        }

        // Find Course Code (scanning from left to right)
        String courseCode = '';
        int codeIndex = -1;
        List<String> searchParts = (gradeIndex != -1)
            ? parts.sublist(0, gradeIndex)
            : parts;

        for (int i = 0; i < searchParts.length; i++) {
          if (courseCodeRegex.hasMatch(searchParts[i])) {
            courseCode = searchParts[i];
            codeIndex = i;
            break;
          }
        }

        // Build Course object if valid
        if (grade.isNotEmpty && courseCode.isNotEmpty && codeIndex != -1) {
          String courseName = parts.sublist(0, codeIndex).join(' ');

          if (courseName.length > 2) {
            double credits = courseCreditMap[courseCode] ?? 0.0;
            extractedCourses.add(
              Course(
                id: "course-${DateTime.now().microsecondsSinceEpoch}-${extractedCourses.length}",
                name: courseName.trim(),
                credits: credits,
                grade: grade,
              ),
            );
          }
        }
      }

      if (extractedCourses.isEmpty) {
        showErrorToast('Could not find valid course data in the PDF.');
        return;
      }

      // 5. Save to GpaProvider
      final gpaProvider = Provider.of<GpaProvider>(context, listen: false);

      // Find semester number from the raw text
      RegExp semRegex = RegExp(r'B\.\s*Tech\s+(I{1,3}V?)\s+SEM');
      var match = semRegex.firstMatch(rawTextForRegex);
      String semName = match != null
          ? 'Semester ${match.group(1)}'
          : 'Uploaded Result ${DateTime.now().hour}:${DateTime.now().minute}';

      final newSem = Semester(
        id: "sem-${DateTime.now().millisecondsSinceEpoch}",
        name: semName,
        courses: extractedCourses,
      );

      newSem.sgpa = gpaProvider.calculateSgpa(extractedCourses);

      gpaProvider.addParsedSemester(newSem);

      HapticFeedback.heavyImpact();

      // ✨ NEW: Warn them if credits are missing so they know to fill them in manually!
      final missingCredits = extractedCourses
          .where((c) => c.credits == 0.0)
          .length;
      if (missingCredits > 0) {
        showTopToast(
          '✅ Found ${extractedCourses.length} courses! Please set credits for $missingCredits courses.',
          backgroundColor: Colors.orange.shade700,
        );
      } else {
        showTopToast(
          '✅ Success! Found ${extractedCourses.length} courses.',
          backgroundColor: Colors.green,
        );
      }
    } catch (e) {
      showErrorToast('Error parsing PDF: ${e.toString()}');
    }
  }
}
