import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bunkmate/providers/attendance_provider.dart';

// --- RESULT DISPLAY HELPERS ---

Widget buildCustomCalcResult(
  BuildContext context,
  Map<String, dynamic> calcResult,
) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final isSafe = calcResult['isSafe'] ?? false;

  final Color baseColor = isSafe
      ? (isDark ? Colors.green.shade400 : Colors.green.shade600)
      : (isDark ? Colors.red.shade400 : Colors.red.shade600);

  final Color bgColor = isDark
      ? baseColor.withOpacity(0.1)
      : baseColor.withOpacity(0.05);

  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: baseColor.withOpacity(isDark ? 0.3 : 0.2),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: baseColor.withOpacity(isDark ? 0.1 : 0.05),
          blurRadius: 16,
          spreadRadius: 2,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: isSafe
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: baseColor, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Safe Strategy',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: baseColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              RichText(
                text: TextSpan(
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                    fontSize: 15,
                  ),
                  children: [
                    const TextSpan(text: 'If you attend the next '),
                    TextSpan(
                      text:
                          '${Provider.of<AttendanceProvider>(context, listen: false).plannerFutureClassesToAttend} classes',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const TextSpan(text: ', your buffer will grow to '),
                    TextSpan(
                      text: '${calcResult['skipsAllowed']} skips',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: baseColor,
                        fontSize: 16,
                      ),
                    ),
                    TextSpan(
                      text: ' (currently ${calcResult['originalSkips']}).',
                      style: TextStyle(
                        color: theme.hintColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, thickness: 1),
              ),

              // ✨ FIX: FittedBox ensures the bottom fraction never overflows horizontally
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Projected Attendance: ',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text:
                                '${(calcResult['projectedPercent'] as double).toStringAsFixed(2)}% ',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: baseColor,
                            ),
                          ),
                          TextSpan(
                            text:
                                '(${calcResult['projectedAttended']}/${calcResult['projectedConducted']})',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.hintColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
        : Row(
            children: [
              Icon(Icons.error_outline_rounded, color: baseColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  calcResult['message'],
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: baseColor,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
  );
}

Widget buildWhatIfResult(BuildContext context, Map<String, dynamic> simResult) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  final errorColor = isDark ? Colors.red.shade400 : Colors.red.shade700;

  if (simResult['error'] != null) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: errorColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_rounded, color: errorColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              simResult['error'],
              style: TextStyle(color: errorColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  final newOverall = simResult['newOverallPercent'] as double;
  final oldOverall = simResult['originalOverallPercent'] as double;
  final newSubject = simResult['newSubjectPercent'] as double;
  final oldSubject = simResult['originalSubjectPercent'] as double;
  final isAboveTarget = simResult['isAboveTarget'] as bool;

  final primaryColor = isAboveTarget
      ? (isDark ? Colors.green.shade400 : Colors.green.shade600)
      : (isDark ? Colors.red.shade400 : Colors.red.shade600);

  // ✨ FIX: Flexible + FittedBox ensures the Pill Badges scale perfectly without overflow
  Widget _buildComparisonRow(String label, double oldVal, double newVal) {
    final diff = newVal - oldVal;
    final isUp = diff >= 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              children: [
                Text(
                  '${oldVal.toStringAsFixed(2)}%',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  '${newVal.toStringAsFixed(2)}%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: (isUp ? Colors.blue : Colors.red).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${isUp ? '+' : ''}${diff.toStringAsFixed(2)}%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isUp
                          ? (isDark
                                ? Colors.blue.shade300
                                : Colors.blue.shade700)
                          : errorColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceVariant.withOpacity(isDark ? 0.2 : 0.4),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: primaryColor.withOpacity(0.3), width: 1.5),
      boxShadow: [
        BoxShadow(
          color: primaryColor.withOpacity(0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.analytics_rounded, color: primaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              'Simulation Result',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildComparisonRow('Subject Impact', oldSubject, newSubject),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(height: 1, thickness: 1),
        ),
        _buildComparisonRow('Overall Impact', oldOverall, newOverall),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isAboveTarget
                ? '✅ This action keeps you safely above your target.'
                : '🚨 WARNING: This action drops you below your target!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: primaryColor,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget buildHolidayResult(
  BuildContext context,
  Map<String, dynamic> impactResult,
) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  if (impactResult['error'] != null) {
    final errorColor = isDark ? Colors.red.shade400 : Colors.red.shade700;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: errorColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: errorColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              impactResult['error'],
              style: TextStyle(color: errorColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  final isSafe = impactResult['isSafe'] as bool;
  final percentageAfter = impactResult['percentageAfter'] as double;

  final primaryColor = isSafe
      ? (isDark ? Colors.tealAccent.shade400 : Colors.teal.shade600)
      : (isDark ? Colors.redAccent.shade400 : Colors.red.shade700);

  final int? remainingSkips = impactResult['remainingSkipsAfter'];
  final int? recoveryNeeded = impactResult['requiredRecovery'];

  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: primaryColor.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: primaryColor.withOpacity(0.3), width: 1.5),
      boxShadow: [
        BoxShadow(
          color: primaryColor.withOpacity(isDark ? 0.1 : 0.05),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  isSafe ? Icons.flight_land_rounded : Icons.warning_rounded,
                  color: primaryColor,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  isSafe ? 'Trip Approved ✈️' : 'Trip Denied ❌',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            Text(
              '${percentageAfter.toStringAsFixed(2)}%',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        RichText(
          text: TextSpan(
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            children: [
              const TextSpan(text: 'If you take '),
              TextSpan(
                text: '${impactResult['leaveDescription']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),

              if ((impactResult['attendBefore'] ?? 0) > 0) ...[
                const TextSpan(text: ' after attending '),
                TextSpan(
                  text: '${impactResult['attendBefore']} classes',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],

              const TextSpan(text: ', your final attendance will be '),
              TextSpan(
                text:
                    '${impactResult['attendedAfter']}/${impactResult['conductedAfter']}.',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        if (isSafe && remainingSkips != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.beach_access_rounded,
                  color: Colors.green,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Reward: You can still afford ~$remainingSkips more ${remainingSkips == 1 ? 'skip' : 'skips'} after this trip!',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

        if (!isSafe && recoveryNeeded != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.healing_rounded, color: Colors.red, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Recovery: Attend ~$recoveryNeeded consecutive ${recoveryNeeded == 1 ? 'class' : 'classes'} after you return to fix this.',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

Widget buildProjectionStatBox(
  BuildContext context,
  String label,
  String value,
  Color valueColor,
  IconData icon,
) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16), // Premium curve
      border: Border.all(
        color: valueColor.withOpacity(isDark ? 0.3 : 0.2), // Tinted border
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: valueColor.withOpacity(isDark ? 0.1 : 0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize:
          MainAxisSize.min, // ✨ FIX: Prevents infinite vertical expansion
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: valueColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: valueColor, size: 16),
            ),
          ],
        ),

        // ✨ FIX: Replaced Spacer() with a fixed height SizedBox
        const SizedBox(height: 16),

        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: valueColor,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.hintColor,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
          ),
        ),
      ],
    ),
  );
}
