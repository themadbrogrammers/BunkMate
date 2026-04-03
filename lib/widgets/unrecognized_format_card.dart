import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class UnrecognizedFormatCard extends StatelessWidget {
  final String? rawData;

  const UnrecognizedFormatCard({super.key, required this.rawData});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Colors.deepPurple.shade900.withOpacity(0.45),
                  Colors.indigo.shade900.withOpacity(0.25),
                ]
              : [
                  Colors.deepPurple.shade100.withOpacity(0.75),
                  Colors.indigo.shade50.withOpacity(0.45),
                ],
        ),
        border: Border.all(
          color: theme.colorScheme.secondary.withOpacity(0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.secondary.withOpacity(
              isDark ? 0.35 : 0.25,
            ),
            blurRadius: 27,
            spreadRadius: -7,
            offset: const Offset(0, 16),
          ),
        ],
      ),

      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.secondary.withOpacity(0.18),
                  ),
                  child: Icon(
                    Icons.help_outline_rounded,
                    size: 28,
                    color: theme.colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "We couldn’t understand this attendance format",
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "This one’s new — but we can learn it.",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // --- Explanation ---
            Text(
              "Nothing’s wrong on your end.\n\n"
              "Attendance formats vary wildly between colleges, "
              "and this one doesn’t match any structure we currently support.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 20),

            // --- Callout ---
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withOpacity(
                  isDark ? 0.22 : 0.12,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.secondary.withOpacity(0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 20,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Share this once & BunkMate will remember it.\n"
                      "Next Update (for you), everything just works 😎",
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- Actions ---
            // Row(
            //   children: [
            //     Expanded(
            //       child: SizedBox(
            //         height: 48,
            //         child: OutlinedButton.icon(
            //           icon: const Icon(Icons.copy_rounded, size: 18),
            //           label: const Text("Copy raw data"),
            //           onPressed: rawData == null || rawData!.isEmpty
            //               ? null
            //               : () {
            //                   Clipboard.setData(ClipboardData(text: rawData!));
            //                   HapticFeedback.lightImpact();
            //                   ScaffoldMessenger.of(context).showSnackBar(
            //                     const SnackBar(
            //                       content: Text("Attendance data copied ✨"),
            //                       duration: Duration(seconds: 2),
            //                     ),
            //                   );
            //                 },
            //           style: OutlinedButton.styleFrom(
            //             foregroundColor: theme.colorScheme.secondary,
            //             side: BorderSide(
            //               color: theme.colorScheme.secondary.withOpacity(0.6),
            //             ),
            //             padding: const EdgeInsets.symmetric(vertical: 12),
            //             shape: RoundedRectangleBorder(
            //               borderRadius: BorderRadius.circular(12),
            //             ),
            //           ),
            //         ),
            //       ),
            //     ),
            //     const SizedBox(width: 12),
            //     Expanded(
            //       child: SizedBox(
            //         height: 48,
            //         child: ElevatedButton.icon(
            //           icon: const Icon(Icons.mail_outline_rounded, size: 18),
            //           label: const Text(
            //             "Send for support",
            //             style: TextStyle(fontWeight: FontWeight.w600),
            //           ),

            //           onPressed: () {
            //             HapticFeedback.mediumImpact();
            //             _launchSupportEmail(context);
            //           },
            //           style: ElevatedButton.styleFrom(
            //             elevation: 0,
            //             backgroundColor: theme.colorScheme.secondary,
            //             foregroundColor: theme.colorScheme.onSecondary,
            //             padding: const EdgeInsets.symmetric(vertical: 12),
            //             shape: RoundedRectangleBorder(
            //               borderRadius: BorderRadius.circular(12),
            //             ),
            //           ),
            //         ),
            //       ),
            //     ),
            //   ],
            // ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text("Copy raw data"),
                    onPressed: rawData == null || rawData!.isEmpty
                        ? null
                        : () {
                            Clipboard.setData(ClipboardData(text: rawData!));
                            HapticFeedback.lightImpact();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Attendance data copied ✨"),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.secondary,
                      side: BorderSide(
                        color: theme.colorScheme.secondary.withOpacity(0.6),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.mail_outline_rounded, size: 18),
                    label: const Text(
                      // "Send for support",
                      "Mail Us 🗿",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      _launchSupportEmail(context);
                    },
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: theme.colorScheme.secondary,
                      foregroundColor: theme.colorScheme.onSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // --- Footer ---
            // Text(
            //   "Tip: Don’t edit the data before sending. "
            //   "The original format helps us support your college accurately.",
            //   style: theme.textTheme.bodySmall?.copyWith(
            //     color: theme.hintColor.withOpacity(0.80),
            //     fontStyle: FontStyle.italic,
            //   ),
            // ),
            Text(
              "Tip: Don’t edit the data before sending. "
              "The original format helps us support your college accurately.",
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                height: 1.35,
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurface.withOpacity(0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _launchSupportEmail(BuildContext context) async {
    const email = "themadbrogrammers@gmail.com";
    const subject = "Unsupported attendance format – BunkMate";

    final body = Uri.encodeComponent(
      "Hi BunkMate Team,\n\n"
      "My college’s attendance format isn’t currently supported.\n\n"
      "Here is the data exactly as provided:\n\n"
      "----------------------------------------\n"
      "${rawData ?? ''}\n"
      "----------------------------------------\n\n"
      "Thanks!",
    );

    final uri = Uri.parse(
      "mailto:$email?subject=${Uri.encodeComponent(subject)}&body=$body",
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Unable to open mail app")));
    }
  }
}
