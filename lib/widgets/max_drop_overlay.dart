import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:bunkmate/providers/attendance_provider.dart';

class MaxDropOverlay extends StatefulWidget {
  final CalculationResult result;
  const MaxDropOverlay({super.key, required this.result});

  @override
  State<MaxDropOverlay> createState() => _MaxDropOverlayState();
}

class _MaxDropOverlayState extends State<MaxDropOverlay> {
  StreamSubscription<AccelerometerEvent>? _subscription;
  Timer? _idleTimer;

  double _tiltX = 0.0;
  double _tiltY = 0.0;

  static const double _maxTiltDeg = 16.0;
  static const double _sensitivity = 2.5;
  static const double _perspective = 0.0045;

  @override
  void initState() {
    super.initState();
    _startSensors();
  }

  void _startSensors() {
    _subscription =
        accelerometerEventStream(
          samplingPeriod: SensorInterval.uiInterval,
        ).listen((event) {
          final tx = (-(event.y / 9.8) * _maxTiltDeg * _sensitivity).clamp(
            -_maxTiltDeg,
            _maxTiltDeg,
          );
          final ty = ((event.x / 9.8) * _maxTiltDeg * _sensitivity).clamp(
            -_maxTiltDeg,
            _maxTiltDeg,
          );

          setState(() {
            _tiltX = lerpDouble(_tiltX, tx * pi / 180, 0.35)!;
            _tiltY = lerpDouble(_tiltY, ty * pi / 180, 0.35)!;
          });
        });

    _idleTimer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      final intensity = (_tiltX.abs() + _tiltY.abs()).clamp(0, 1);
      final idleFactor = 1 - intensity;

      setState(() {
        _tiltX = _tiltX.clamp(-0.35, 0.35);
        _tiltY = _tiltY.clamp(-0.35, 0.35);
        _tiltX +=
            sin(DateTime.now().millisecondsSinceEpoch * 0.002) *
            0.002 *
            idleFactor;
        _tiltY +=
            cos(DateTime.now().millisecondsSinceEpoch * 0.002) *
            0.002 *
            idleFactor;
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _idleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final maxDrop = widget.result.maxDroppableHours;
    final required = widget.result.requiredToAttend;

    late final String title;
    late final String message;
    late final String lottie;
    late final Color glow;
    late final Gradient gradient;
    late final String badge;

    if (required > 0) {
      title = 'No More Skips';
      message =
          'Attend the next <strong>$required</strong> classes consecutively to recover.';
      lottie = 'assets/doomd.json';
      glow = Colors.red;
      badge = 'DANGER';
      gradient = LinearGradient(
        colors: [Colors.red.shade400, Colors.pink.shade600],
      );
    } else if (maxDrop < 5) {
      title = 'Heads Up';
      message = 'Only <strong>$maxDrop</strong> skips left. Plan wisely.';
      lottie = 'assets/warn.json';
      glow = Colors.orange;
      badge = 'WARNING';
      gradient = LinearGradient(
        colors: [Colors.orange.shade400, Colors.amber.shade600],
      );
    } else {
      title = 'You’re Safe';
      message = 'You can skip <strong>$maxDrop</strong> classes.';
      lottie = 'assets/success.json';
      glow = Colors.green;
      badge = 'SAFE';
      gradient = LinearGradient(
        colors: [Colors.green.shade400, Colors.teal.shade600],
      );
    }

    final blurStrength = lerpDouble(
      4,
      5.5,
      (_tiltX.abs() + _tiltY.abs()).clamp(0, 1),
    )!;

    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Stack(
        children: [
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: blurStrength,
                sigmaY: blurStrength,
              ),
              child: Container(
                color: isDark
                    ? Colors.black.withOpacity(0.25)
                    : Colors.black.withOpacity(0.12),
              ),
            ),
          ),
          Center(
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, _perspective)
                ..rotateX(_tiltX)
                ..rotateY(_tiltY),
              child: Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  color: theme.cardColor,
                  boxShadow: [
                    BoxShadow(
                      color: glow.withOpacity(0.31),
                      blurRadius: 27,
                      spreadRadius: 1.6,
                      offset: Offset(_tiltY * 20, _tiltX * 20),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: glow.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        badge,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Halo + Lottie
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [glow.withOpacity(0.4), Colors.transparent],
                        ),
                      ),
                      child: SizedBox(
                        width: 90,
                        height: 90,
                        child: Lottie.asset(lottie, repeat: true),
                      ),
                    ),

                    const SizedBox(height: 16),

                    ShaderMask(
                      shaderCallback: (b) => gradient.createShader(b),
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
                        children: _parseBold(message, theme),
                      ),
                    ),

                    const SizedBox(height: 24),

                    ElevatedButton.icon(
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Got it'),
                      style: ElevatedButton.styleFrom(
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<TextSpan> _parseBold(String text, ThemeData theme) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'<strong>(.*?)<\/strong>');
    int last = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: theme.colorScheme.primary,
          ),
        ),
      );
      last = match.end;
    }

    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }
    return spans;
  }
}
