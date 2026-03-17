import 'package:flutter/material.dart';

class WhatsNewList extends StatelessWidget {
  final List<Map<String, dynamic>> items;

  const WhatsNewList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        IconData icon;
        Color color;
        String label;

        switch (item['type']) {
          case 'fix':
            icon = Icons.bug_report_rounded;
            color = isDark ? Colors.redAccent.shade200 : Colors.red.shade700;
            label = "FIX";
            break;
          case 'feature':
            icon = Icons.auto_awesome_rounded;
            color = isDark
                ? Colors.purpleAccent.shade200
                : Colors.purple.shade700;
            label = "NEW";
            break;
          case 'data':
            icon = Icons.school_rounded;
            color = isDark ? Colors.blueAccent.shade200 : Colors.blue.shade700;
            label = "DATA";
            break;
          default:
            icon = Icons.info_outline_rounded;
            color = Colors.grey;
            label = "INFO";
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(isDark ? 0.1 : 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['text'] ?? '',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
