import 'dart:math' as math;

import 'package:flutter/material.dart';

/// New-device sync splash: makes the first cross-device recovery obvious
/// instead of silent.
///
/// The centerpiece is the "recovery ring": one tick per sync stage (8
/// backup + 9 restore stages) that lights up as each domain lands, orbited
/// by two counter-rotating dashed arcs. Progress is driven by
/// `AuthProvider.syncProgress`/`syncStageLabel`; the orbiting arcs keep
/// moving on their own so a stalled network stage still reads as alive.
class SyncSplashScreen extends StatefulWidget {
  final int completedStages;
  final int totalStages;
  final String stageLabel;
  final VoidCallback onSkip;

  const SyncSplashScreen({
    super.key,
    required this.completedStages,
    required this.totalStages,
    required this.stageLabel,
    required this.onSkip,
  });

  @override
  State<SyncSplashScreen> createState() => _SyncSplashScreenState();
}

class _SyncSplashScreenState extends State<SyncSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _orbit;

  @override
  void initState() {
    super.initState();
    _orbit = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fraction = widget.totalStages == 0
        ? 0.0
        : (widget.completedStages / widget.totalStages).clamp(0.0, 1.0);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Image.asset('assets/icon/logo.png', width: 56, height: 56),
              const SizedBox(height: 28),
              AnimatedBuilder(
                animation: _orbit,
                builder: (context, _) => CustomPaint(
                  size: const Size(220, 220),
                  painter: _RecoveryRingPainter(
                    completedStages: widget.completedStages,
                    totalStages: widget.totalStages,
                    orbitTurns: _orbit.value,
                    primary: cs.primary,
                    track: cs.outline.withValues(alpha: 0.25),
                  ),
                  child: Center(
                    child: Text(
                      '${(fraction * 100).round()}%',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                        fontFeatures: const [
                          FontFeature.tabularFigures()
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Recovering your library',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.stageLabel,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.64),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your notes, bookmarks, answers, and settings are moving to this device.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.48),
                ),
              ),
              const Spacer(flex: 2),
              TextButton(
                onPressed: widget.onSkip,
                child: const Text('Continue offline'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// One tick per sync stage around a circle, lit as stages complete, with
/// two counter-rotating dashed orbit arcs outside them.
class _RecoveryRingPainter extends CustomPainter {
  final int completedStages;
  final int totalStages;
  final double orbitTurns;
  final Color primary;
  final Color track;

  const _RecoveryRingPainter({
    required this.completedStages,
    required this.totalStages,
    required this.orbitTurns,
    required this.primary,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final ringRadius = size.shortestSide / 2 - 34;
    final total = math.max(totalStages, 1);

    // Stage ticks.
    for (var i = 0; i < total; i++) {
      final angle = -math.pi / 2 + (i * 2 * math.pi / total);
      final done = i < completedStages;
      final isCurrent = i == completedStages;
      final paint = Paint()
        ..color = done
            ? primary
            : isCurrent
                ? primary.withValues(alpha: 0.55)
                : track
        ..strokeWidth = done || isCurrent ? 5 : 3
        ..strokeCap = StrokeCap.round;
      final inner = ringRadius - (done || isCurrent ? 9 : 6);
      final p1 = center +
          Offset(math.cos(angle), math.sin(angle)) * inner;
      final p2 = center +
          Offset(math.cos(angle), math.sin(angle)) * (ringRadius + 2);
      canvas.drawLine(p1, p2, paint);
    }

    // Counter-rotating dashed orbit arcs.
    _orbitArcs(
      canvas,
      center,
      ringRadius + 16,
      orbitTurns * 2 * math.pi,
      primary.withValues(alpha: 0.7),
    );
    _orbitArcs(
      canvas,
      center,
      ringRadius + 26,
      -orbitTurns * 2 * math.pi + math.pi / 3,
      track,
    );
  }

  void _orbitArcs(
      Canvas canvas, Offset center, double radius, double rotation, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    const sweep = math.pi * 2 / 5;
    for (var k = 0; k < 3; k++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        rotation + k * (2 * math.pi / 3),
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RecoveryRingPainter old) {
    return old.completedStages != completedStages ||
        old.totalStages != totalStages ||
        old.orbitTurns != orbitTurns ||
        old.primary != primary ||
        old.track != track;
  }
}
