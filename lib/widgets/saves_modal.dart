import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:bunkmate/providers/attendance_provider.dart';
import 'package:bunkmate/providers/premium_provider.dart';
import 'package:bunkmate/helpers/toast_helper.dart';

// Import your gorgeous new premium sheet!
import 'package:bunkmate/widgets/premium_sheet.dart';

class SavesModal extends StatefulWidget {
  const SavesModal({super.key});

  @override
  State<SavesModal> createState() => _SavesModalState();
}

class _SavesModalState extends State<SavesModal> {
  late Future<Map<String, SaveSlot>> _savesFuture;
  Map<String, TextEditingController> _nameControllers = {};
  final Map<String, FocusNode> _focusNodes = {};

  // Hardcode to 5 total slots (2 Free + 3 Pro)
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

      // Create controllers for all 5 potential slots
      for (var i = 1; i <= totalSlots; i++) {
        final slotId = 'slot$i';
        final initialName = saves[slotId]?.name ?? 'Save Slot $i';
        _nameControllers[slotId] = TextEditingController(text: initialName);
        _focusNodes[slotId] = FocusNode();

        // --- Add listener to save name on focus loss ---
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
    final premium = context.watch<PremiumProvider>(); // Watch Premium Status!
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        top: 20,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '🗂️ Manage Saves',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
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
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading saves: ${snapshot.error}'),
                  );
                }

                final saves = snapshot.data ?? {};

                // Build list of all 5 save slots
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

                    final String lastSaved = hasDataInSlot
                        ? DateFormat.yMd().add_jm().format(
                            savedSlot.timestamp.toLocal(),
                          )
                        : 'Empty';

                    // ✨ The Upsell Logic: Lock slots 3, 4, and 5 if not premium!
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

                    // Standard Unlocked Slot UI
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
                            // Name and Timestamp
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextField(
                                    controller: nameController,
                                    focusNode: focusNode,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      hintText: 'Slot Name',
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  Text(
                                    'Last Saved: $lastSaved',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.hintColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Action Buttons
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Save Button
                                IconButton(
                                  icon: const Icon(Icons.save_alt_rounded),
                                  tooltip: 'Save Current Data Here',
                                  color: theme.colorScheme.primary,
                                  iconSize: 20,
                                  visualDensity: VisualDensity.compact,
                                  onPressed: provider.rawData.trim().isEmpty
                                      ? null
                                      : () async {
                                          HapticFeedback.lightImpact();
                                          final currentName =
                                              nameController.text;
                                          await provider.saveToSlot(
                                            slotId,
                                            currentName,
                                          );
                                          showTopToast(
                                            '💾 Saved to "$currentName"',
                                            backgroundColor: Colors
                                                .green
                                                .shade600
                                                .withOpacity(0.9),
                                          );
                                          _refreshSavesList();
                                        },
                                ),
                                // Load Button
                                IconButton(
                                  icon: const Icon(Icons.download_rounded),
                                  tooltip: 'Load Data From Here',
                                  color: hasDataInSlot
                                      ? Colors.green.shade600
                                      : theme.disabledColor,
                                  iconSize: 20,
                                  visualDensity: VisualDensity.compact,
                                  onPressed: !hasDataInSlot
                                      ? null
                                      : () async {
                                          HapticFeedback.lightImpact();
                                          bool loaded = await provider
                                              .loadFromSlot(slotId);
                                          if (mounted) Navigator.pop(context);
                                          if (loaded) {
                                            showTopToast(
                                              '📂 Loaded "${savedSlot?.name ?? slotId}"',
                                              backgroundColor: Colors
                                                  .green
                                                  .shade600
                                                  .withOpacity(0.9),
                                            );
                                          } else {
                                            showTopToast(
                                              '❌ Failed to load data.',
                                              backgroundColor:
                                                  Colors.red.shade700,
                                            );
                                          }
                                        },
                                ),
                                // Delete Button
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                  ),
                                  tooltip: 'Delete This Save',
                                  color: hasDataInSlot
                                      ? Colors.red.shade400
                                      : theme.disabledColor,
                                  iconSize: 20,
                                  visualDensity: VisualDensity.compact,
                                  onPressed: !hasDataInSlot
                                      ? null
                                      : () async {
                                          HapticFeedback.lightImpact();
                                          bool?
                                          confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text(
                                                'Confirm Delete',
                                              ),
                                              content: Text(
                                                'Delete save slot "${nameController.text}"?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, false),
                                                  child: const Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, true),
                                                  child: const Text(
                                                    'Delete',
                                                    style: TextStyle(
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            await provider.deleteSlot(slotId);
                                            showTopToast(
                                              '🗑️ Deleted "${nameController.text}"',
                                              backgroundColor: Colors
                                                  .red
                                                  .shade600
                                                  .withOpacity(0.9),
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

  // ✨ UI for Locked Premium Slots (Purple Theme)
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
