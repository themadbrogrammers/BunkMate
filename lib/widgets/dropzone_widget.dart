import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io'; // Keep for non-web path reading if needed later
import 'dart:convert'; // For utf8 decoding
import 'dart:typed_data'; // Import for Uint8List
import 'package:excel/excel.dart' as excel; // Import excel with prefix
import 'package:bunkmate/providers/attendance_provider.dart';
// import 'package:intl/intl.dart'; // Uncomment if you format DateTime from Excel
import 'package:bunkmate/helpers/toast_helper.dart';

class DropzoneWidget extends StatelessWidget {
  const DropzoneWidget({super.key});

  Future<void> _pickFile(BuildContext context) async {
    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    String rawContent = ''; // Declare here to be accessible later

    try {
      // --- Use FileType.any for broader compatibility ---
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any, // Allow selecting any file type initially
        // allowedExtensions: null, // Don't filter here if FileType.any is used
      );

      if (result != null && result.files.isNotEmpty) {
        PlatformFile file = result.files.first;
        String? filePath = file.path;
        String fileName = file.name;
        // --- Validate extension AFTER picking ---
        String fileExtension = file.extension?.toLowerCase() ?? '';
        if (!['csv', 'txt', 'log', 'xlsx'].contains(fileExtension)) {
          showTopToast(
            '⚠️ Unsupported file type: .$fileExtension. Please select CSV, TXT, LOG, or XLSX.',
            backgroundColor: Colors.orange.shade700,
            textColor: Colors.white,
          );
          return; // Stop if extension is not supported
        }

        String? parsedCsvContent;

        // --- Read File Content ---
        Uint8List? fileBytes = file.bytes;

        if (fileBytes == null && filePath != null) {
          try {
            fileBytes = await File(filePath).readAsBytes();
          } catch (e) {
            showTopToast(
              '❌ Error reading file from path: $e',
              backgroundColor: Colors.red.shade700,
            );
            return;
          }
        }

        if (fileBytes == null) {
          showTopToast(
            '⚠️ Could not read file data (bytes or path).',
            backgroundColor: Colors.orange.shade700,
          );
          return;
        }

        // --- Parse Based on Extension ---
        if (['csv', 'txt', 'log'].contains(fileExtension)) {
          try {
            rawContent = utf8.decode(fileBytes, allowMalformed: true);
            if (rawContent.startsWith('\uFEFF')) {
              rawContent = rawContent.substring(1);
            }
            parsedCsvContent = rawContent;
            print("CSV/TXT/LOG Content read successfully.");
          } catch (e) {
            showTopToast(
              '❌ Error decoding text file: $e',
              backgroundColor: Colors.red.shade700,
            );
            return;
          }
        } else if (fileExtension == 'xlsx') {
          try {
            debugPrint(
              "Attempting to parse XLSX file: ${fileName}, Bytes length: ${fileBytes.length}",
            );
            var excelFile = excel.Excel.decodeBytes(fileBytes);
            if (excelFile.tables.isEmpty) {
              throw Exception("Excel file contains no sheets.");
            }
            var sheetName = excelFile.tables.keys.first;
            var sheet = excelFile.tables[sheetName];
            if (sheet == null) {
              throw Exception(
                "Could not access the first sheet ('$sheetName').",
              );
            }

            List<String> csvRows = [];
            for (var row in sheet.rows) {
              List<String?> stringRow = row.map((cellData) {
                dynamic value = (cellData as excel.Data?)?.value;
                if (value == null) return '';
                if (value is double && value == value.truncateToDouble()) {
                  return value.toInt().toString();
                }
                // Add more type handling if needed (e.g., DateTime)
                return value.toString();
              }).toList();
              csvRows.add(
                stringRow
                    .map((cell) => '"${(cell ?? '').replaceAll('"', '""')}"')
                    .join(','),
              );
            }
            parsedCsvContent = csvRows.join('\n');
            print("XLSX Content parsed to CSV successfully.");
          } catch (e) {
            showTopToast(
              '❌ Error parsing XLSX file: $e',
              backgroundColor: Colors.red.shade700,
            );
            return;
          }
        }
        // No else needed here because we validated the extension earlier

        // --- Update Provider with Parsed Content ---
        if (parsedCsvContent != null && parsedCsvContent.trim().isNotEmpty) {
          print("Updating provider with parsed data:\n$parsedCsvContent");
          provider.setRawData(parsedCsvContent, newFileName: fileName);
          showTopToast(
            '📄 File "$fileName" loaded & calculating...',
            backgroundColor: Colors.green.shade600.withOpacity(0.9),
          );
        } else if (parsedCsvContent != null) {
          showTopToast(
            '⚠️ File loaded, but it appears to be empty or could not be parsed meaningfully.',
            backgroundColor: Colors.orange.shade700,
          );
        } else {
          showTopToast(
            '❌ Failed to parse file content after reading.',
            backgroundColor: Colors.red.shade700,
          );
        }
      } else {
        showTopToast(
          '📁 File selection cancelled.',
          backgroundColor: Colors.grey.shade800.withOpacity(0.8),
        );
      }
    } catch (e) {
      showTopToast('Your file is being processed.\n(～￣▽￣)～');
      // showTopToast(
      //   '❌ Error during file picking/processing: $e',
      //   backgroundColor: Colors.red.shade700,
      // );
    }
  }

  // --- build method remains the same ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () => _pickFile(context),
      borderRadius: BorderRadius.circular(12.0), // Match decoration radius
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.0), // Consistent radius
          border: Border.all(
            // Use Flutter's Border class
            color: theme.colorScheme.primary.withOpacity(
              0.4,
            ), // Use primary color accent
            width: 1.5,
          ),
          gradient: LinearGradient(
            // Subtle background gradient
            colors: [
              theme.colorScheme.surface.withOpacity(isDarkMode ? 0.3 : 0.5),
              theme.colorScheme.surface.withOpacity(isDarkMode ? 0.1 : 0.2),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_upload_outlined,
              size: 48.0,
              color: theme.colorScheme.primary,
            ), // Icon themed
            const SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Click to Upload File', // Clearer action text
                  style: TextStyle(
                    color: theme.colorScheme.primary, // Themed text color
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4.0),
            Text(
              'CSV, TXT, LOG, XLSX supported', // Updated list
              style: TextStyle(
                color: theme.hintColor,
                fontSize: 12,
              ), // Use hint color
            ),
          ],
        ),
      ),
    );
  }
}
