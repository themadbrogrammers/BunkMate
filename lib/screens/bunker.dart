import 'dart:ui' as dart_ui;
import 'package:flutter/material.dart';

/// About BunkMate Bottom Sheet – A fully frosted, premium glassmorphic easter egg.
class AboutBunkMateSheet extends StatefulWidget {
  const AboutBunkMateSheet({super.key});

  @override
  State<AboutBunkMateSheet> createState() => _AboutBunkMateSheetState();
}

class _AboutBunkMateSheetState extends State<AboutBunkMateSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    // Exquisite slow-breathing animation for the background aura
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.2, end: 0.6).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // ✨ FIX: ConstrainedBox + Flexible.
    // This allows the sheet to hug its content perfectly, scroll ONLY if the
    // screen is too small, and instantly close when you swipe down!
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.79,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        child: BackdropFilter(
          filter: dart_ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor.withOpacity(
                isDark ? 0.75 : 0.9,
              ),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(isDark ? 0.1 : 0.5),
                  width: 1.5,
                ),
              ),
            ),
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // --- The Ambient Glowing Core (Stays fixed in background) ---
                Positioned(
                  top: -60,
                  child: AnimatedBuilder(
                    animation: _glowAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepPurpleAccent.withOpacity(
                                isDark
                                    ? _glowAnimation.value
                                    : _glowAnimation.value * 0.4,
                              ),
                              blurRadius: 120,
                              spreadRadius: 30,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // --- UI Content ---
                SafeArea(
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min, // ✨ FIX: Hugs content perfectly
                    children: [
                      // ─── PINNED DRAG HANDLE ───────────────────────────
                      Center(
                        child: Container(
                          width: 48,
                          height: 5,
                          margin: const EdgeInsets.only(top: 16, bottom: 16),
                          decoration: BoxDecoration(
                            color: theme.dividerColor.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),

                      // ─── FLEXIBLE SCROLLABLE CONTENT ───────────────────
                      Flexible(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ─── HERO ORB ────────────────────────
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDark
                                        ? Colors.white.withOpacity(0.03)
                                        : Colors.black.withOpacity(0.02),
                                    border: Border.all(
                                      color: Colors.deepPurpleAccent
                                          .withOpacity(isDark ? 0.3 : 0.15),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.deepPurpleAccent
                                            .withOpacity(isDark ? 0.15 : 0.05),
                                        blurRadius: 30,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons
                                        .diamond_outlined, // Diamond fits the "exquisite" theme perfectly
                                    size: 48,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.deepPurple.shade700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // ─── TITLE (Gradient Text) ────────────────────────
                              Center(
                                child: ShaderMask(
                                  shaderCallback: (bounds) => LinearGradient(
                                    colors: [
                                      theme.colorScheme.primary,
                                      Colors.deepPurpleAccent,
                                      isDark
                                          ? Colors.cyanAccent
                                          : Colors.blueAccent,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ).createShader(bounds),
                                  child: Text(
                                    'BunkMate',
                                    style: theme.textTheme.displaySmall?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1.0,
                                      color: Colors
                                          .white, // Required for ShaderMask to render
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Attendance. But smarter.',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.hintColor,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: 32),

                              // ─── CORE CARD ────────────────────────
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  color: theme.colorScheme.surfaceVariant
                                      .withOpacity(isDark ? 0.3 : 0.5),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(
                                      isDark ? 0.05 : 0.4,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'Figure out exactly when you can skip — '
                                  'and when you really shouldn’t.\n'
                                  'No guesswork. No panic. '
                                  'Just clean calculations and full control over your academic life.',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    height: 1.6,
                                    fontWeight: FontWeight.w300,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),

                              const SizedBox(height: 24),

                              // ─── PHILOSOPHY ───────────────────────
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  gradient: LinearGradient(
                                    colors: isDark
                                        ? [
                                            Colors.deepPurpleAccent.withOpacity(
                                              0.15,
                                            ),
                                            Colors.blueAccent.withOpacity(0.05),
                                          ]
                                        : [
                                            Colors.deepPurpleAccent.withOpacity(
                                              0.08,
                                            ),
                                            Colors.blueAccent.withOpacity(0.02),
                                          ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  border: Border.all(
                                    color: Colors.deepPurpleAccent.withOpacity(
                                      isDark ? 0.2 : 0.1,
                                    ),
                                  ),
                                ),
                                child: const Column(
                                  children: [
                                    _PhilosophyLine('Think before you bunk.'),
                                    SizedBox(height: 12),
                                    _PhilosophyLine('Know your margin.'),
                                    SizedBox(height: 12),
                                    _PhilosophyLine('Stay in control.'),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 40),

                              // ─── FOOTER BADGE ───────────────────────────
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.black38
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(
                                      color: theme.dividerColor.withOpacity(
                                        isDark ? 0.2 : 0.1,
                                      ),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Built with 🖤 by ',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme.hintColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      Text(
                                        'TheMadBrogrammers',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black,
                                              letterSpacing: 0.2,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Philosophy line with a styled checkmark orb
class _PhilosophyLine extends StatelessWidget {
  final String text;

  const _PhilosophyLine(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_rounded,
            size: 14,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}
