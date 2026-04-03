import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:bunkmate/providers/attendance_provider.dart';
import 'package:bunkmate/providers/premium_provider.dart';
import 'package:bunkmate/providers/gpa_provider.dart';
import 'package:bunkmate/helpers/toast_helper.dart';

import 'package:bunkmate/widgets/premium_sheet.dart';

class SavesModal extends StatefulWidget {
  final bool isGpaMode;

  const SavesModal({super.key, this.isGpaMode = false});

  @override
  State<SavesModal> createState() => _SavesModalState();
}

class _SavesModalState extends State<SavesModal> {
  late Future<Map<String, SaveSlot>> _savesFuture;
  Map<String, TextEditingController> _nameControllers = {};
  final Map<String, FocusNode> _focusNodes = {};

  static const int totalSlots = 5;

  @override
  void initState() {
    super.initState();
    _loadSaves();
  }

  void _loadSaves() {
    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    _savesFuture = provider.getAllSaves().then((saves) {
      _nameControllers.values.forEach((controller) => controller.dispose());
      _focusNodes.values.forEach((node) => node.dispose());
      _nameControllers.clear();
      _focusNodes.clear();

      for (var i = 1; i <= totalSlots; i++) {
        final slotId = 'slot$i';
        final initialName = saves[slotId]?.name ?? 'Save Slot $i';
        _nameControllers[slotId] = TextEditingController(text: initialName);
        _focusNodes[slotId] = FocusNode();

        _focusNodes[slotId]?.addListener(() {
          final node = _focusNodes[slotId];
          final controller = _nameControllers[slotId];
          if (node != null && !node.hasFocus && controller != null) {
            provider.updateSlotName(slotId, controller.text);
          }
        });
      }
      return saves;
    });
  }

  @override
  void dispose() {
    _nameControllers.values.forEach((controller) => controller.dispose());
    _focusNodes.values.forEach((node) => node.dispose());
    super.dispose();
  }

  void _refreshSavesList() {
    setState(() {
      _loadSaves();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final premium = context.watch<PremiumProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bool canSaveCurrentState = widget.isGpaMode
        ? context.watch<GpaProvider>().semesters.isNotEmpty
        : provider.rawData.trim().isNotEmpty;

    // ✨ Solid background with rounded corners
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✨ Slick drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: theme.hintColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.isGpaMode ? '🗂️ GPA Saves' : '🗂️ Attendance Saves',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            FutureBuilder<Map<String, SaveSlot>>(
              future: _savesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final saves = snapshot.data ?? {};

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: totalSlots,
                  itemBuilder: (context, index) {
                    final slotId = 'slot${index + 1}';
                    final savedSlot = saves[slotId];
                    final nameController = _nameControllers[slotId];
                    final focusNode = _focusNodes[slotId];
                    final bool hasDataInSlot = savedSlot != null;

                    final bool isGpaSlot = savedSlot?.type == 'gpa';
                    final String typeLabel = isGpaSlot ? 'GPA' : 'Attendance';

                    // ✨ Determine if the slot type matches the current app context
                    final bool isMatchingMode = isGpaSlot == widget.isGpaMode;

                    final String lastSaved = hasDataInSlot
                        ? '$typeLabel • ${DateFormat.yMd().add_jm().format(savedSlot.timestamp.toLocal())}'
                        : 'Empty Slot';

                    final bool isLocked = !premium.isPremium && index >= 2;
                    if (isLocked) {
                      return _buildLockedSlot(
                        context,
                        theme,
                        isDark,
                        index + 1,
                      );
                    }
                    if (nameController == null || focusNode == null) {
                      return const SizedBox.shrink();
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6.0),
                      elevation: hasDataInSlot ? 2 : 0.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: hasDataInSlot
                              ? theme.colorScheme.primary.withOpacity(0.3)
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            if (hasDataInSlot) ...[
                              Icon(
                                // ✨ Backpack icon for attendance!
                                isGpaSlot
                                    ? Icons.science_rounded
                                    : Icons.backpack_rounded,
                                color: isGpaSlot
                                    ? Colors.purpleAccent
                                    : theme.colorScheme.primary,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                            ],

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextField(
                                    controller: nameController,
                                    focusNode: focusNode,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: (!hasDataInSlot || isMatchingMode)
                                          ? (isDark
                                                ? Colors.white
                                                : Colors.black87)
                                          : theme
                                                .hintColor, // Dim text if wrong mode
                                    ),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      hintText: 'Slot Name',
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  Text(
                                    lastSaved,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.hintColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // ✨ DYNAMIC SAVE BUTTON
                                IconButton(
                                  icon: const Icon(Icons.save_alt_rounded),
                                  tooltip: 'Save Current Data Here',
                                  color: theme.colorScheme.primary,
                                  iconSize: 20,
                                  visualDensity: VisualDensity.compact,
                                  onPressed: !canSaveCurrentState
                                      ? null
                                      : () async {
                                          HapticFeedback.lightImpact();
                                          final currentName =
                                              nameController.text;

                                          // ✨ CHECK FOR MISMATCHED OVERWRITE
                                          if (hasDataInSlot &&
                                              !isMatchingMode) {
                                            bool? confirm =
                                                await _showOverwriteWarning(
                                                  context,
                                                  isGpaSlot,
                                                  premium.isPremium,
                                                );
                                            if (confirm != true)
                                              return; // User canceled
                                          }

                                          if (widget.isGpaMode) {
                                            final gpaProvider = context
                                                .read<GpaProvider>();
                                            await provider.saveGpaToSlot(
                                              slotId,
                                              currentName,
                                              gpaProvider.exportToJson(),
                                            );
                                          } else {
                                            await provider.saveToSlot(
                                              slotId,
                                              currentName,
                                            );
                                          }

                                          showTopToast(
                                            '💾 Saved to "$currentName"',
                                            backgroundColor:
                                                Colors.green.shade600,
                                          );
                                          _refreshSavesList();
                                        },
                                ),
                                // ✨ DYNAMIC LOAD BUTTON
                                IconButton(
                                  icon: const Icon(Icons.download_rounded),
                                  tooltip: (!hasDataInSlot || isMatchingMode)
                                      ? 'Load Data From Here'
                                      : 'Cannot load $typeLabel data here',
                                  // Grey out if empty OR if it's the wrong mode
                                  color: (hasDataInSlot && isMatchingMode)
                                      ? Colors.green.shade600
                                      : theme.disabledColor.withOpacity(0.3),
                                  iconSize: 20,
                                  visualDensity: VisualDensity.compact,
                                  // ✨ Disable if empty OR wrong mode
                                  onPressed: (!hasDataInSlot || !isMatchingMode)
                                      ? null
                                      : () async {
                                          HapticFeedback.lightImpact();
                                          if (mounted) Navigator.pop(context);

                                          if (isGpaSlot) {
                                            final gpaProvider = context
                                                .read<GpaProvider>();
                                            bool success = gpaProvider
                                                .importFromJson(
                                                  savedSlot.gpaData,
                                                );
                                            if (success) {
                                              showTopToast(
                                                '📂 GPA Data Loaded!',
                                                backgroundColor:
                                                    Colors.green.shade600,
                                              );
                                            } else {
                                              showErrorToast(
                                                'Failed to load GPA data.',
                                              );
                                            }
                                          } else {
                                            bool loaded = await provider
                                                .loadFromSlot(slotId);
                                            if (loaded) {
                                              showTopToast(
                                                '📂 Attendance Loaded! (Check Home Tab)',
                                                backgroundColor:
                                                    Colors.green.shade600,
                                              );
                                            } else {
                                              showErrorToast(
                                                'Failed to load Attendance data.',
                                              );
                                            }
                                          }
                                        },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                  ),
                                  tooltip: 'Delete This Save',
                                  color: hasDataInSlot
                                      ? Colors.red.shade400
                                      : theme.disabledColor.withOpacity(0.3),
                                  iconSize: 20,
                                  visualDensity: VisualDensity.compact,
                                  onPressed: !hasDataInSlot
                                      ? null
                                      : () async {
                                          HapticFeedback.lightImpact();
                                          bool?
                                          confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => Dialog(
                                              backgroundColor: isDark
                                                  ? const Color(0xFF2A1C1C)
                                                  : Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(24),
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  24.0,
                                                ),
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    // 🔥 Icon
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            16,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.redAccent
                                                            .withOpacity(0.15),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(
                                                        Icons
                                                            .delete_outline_rounded,
                                                        color: Colors.redAccent,
                                                        size: 36,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 20),

                                                    // 🔥 Title
                                                    Text(
                                                      'Delete Save?',
                                                      style: theme
                                                          .textTheme
                                                          .titleLarge
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),

                                                    const SizedBox(height: 12),

                                                    // 🔥 Content
                                                    Text(
                                                      'This will permanently delete "${nameController.text}".\n\nYou can’t undo this.',
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: theme
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.copyWith(
                                                            color:
                                                                theme.hintColor,
                                                          ),
                                                    ),

                                                    const SizedBox(height: 24),

                                                    // 🔥 Buttons
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: OutlinedButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  ctx,
                                                                  false,
                                                                ),
                                                            style: OutlinedButton.styleFrom(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    vertical:
                                                                        14,
                                                                  ),
                                                              side: BorderSide(
                                                                color: theme
                                                                    .hintColor
                                                                    .withOpacity(
                                                                      0.4,
                                                                    ),
                                                              ),
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      16,
                                                                    ),
                                                              ),
                                                            ),
                                                            child: Text(
                                                              'Cancel',
                                                              style: TextStyle(
                                                                color: theme
                                                                    .hintColor,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 12,
                                                        ),
                                                        Expanded(
                                                          child: ElevatedButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  ctx,
                                                                  true,
                                                                ),
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor:
                                                                  Colors
                                                                      .redAccent,
                                                              foregroundColor:
                                                                  Colors.white,
                                                              elevation: 0,
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    vertical:
                                                                        14,
                                                                  ),
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      16,
                                                                    ),
                                                              ),
                                                            ),
                                                            child: const Text(
                                                              'Delete',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                          if (confirm == true) {
                                            await provider.deleteSlot(slotId);
                                            showTopToast(
                                              '🗑️ Deleted "${nameController.text}"',
                                              backgroundColor:
                                                  Colors.red.shade600,
                                            );
                                            _refreshSavesList();
                                          }
                                        },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ✨ GORGEOUS OVERWRITE WARNING DIALOG
  Future<bool?> _showOverwriteWarning(
    BuildContext context,
    bool overwritingGpa,
    bool isPremium,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final overwrittenType = overwritingGpa ? 'GPA' : 'Attendance';
    final currentType = widget.isGpaMode ? 'GPA' : 'Attendance';

    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✨ Glowing Warning Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),

              // ✨ Title
              Text(
                'Overwrite Save?',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // ✨ Content
              Text(
                'This slot currently holds $overwrittenType data. '
                'Saving now will permanently replace it with your current $currentType data.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.hintColor,
                ),
              ),
              const SizedBox(height: 24),

              // ✨ MASSIVE PREMIUM UPSELL FOR FREE USERS
              if (!isPremium) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx, false); // Close dialog
                      showPremiumPaywall(context); // Open premium sheet
                    },
                    icon: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    label: const Text(
                      'Unlock More Slots with Pro',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurpleAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],

              // ✨ ACTION BUTTONS
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: theme.hintColor.withOpacity(0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: theme.hintColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Overwrite',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLockedSlot(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    int slotNumber,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      elevation: 0,
      color: isDark
          ? Colors.white.withOpacity(0.03)
          : Colors.black.withOpacity(0.02),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.deepPurpleAccent.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.mediumImpact();
          showPremiumPaywall(context);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepPurpleAccent.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  color: Colors.deepPurpleAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pro Save Slot $slotNumber',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.hintColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Unlock with Premium',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? Colors.purpleAccent
                            : Colors.deepPurpleAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.deepPurpleAccent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
