import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Warm tungsten bar backdrop: deep charcoal with a pool of amber light
/// falling on the table, oxblood bleeding in from the edges.
class BarBackground extends StatelessWidget {
  const BarBackground({super.key, this.glow = 1.0});

  /// 0..1+ intensity of the central light (dims during anticipation).
  final double glow;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.15),
          radius: 1.1,
          colors: [
            Color.lerp(AppColors.charcoal, AppColors.amber,
                0.16 * glow.clamp(0, 1))!,
            AppColors.charcoal,
            AppColors.ink,
            const Color(0xFF050506),
          ],
          stops: const [0.0, 0.35, 0.72, 1.0],
        ),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0x22000000),
              Colors.transparent,
              Color(0x33000000),
            ],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Soft dark vignette around the edges for cinematic framing.
class Vignette extends StatelessWidget {
  const Vignette({super.key, this.strength = 0.85});
  final double strength;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 0.95,
            colors: [
              Colors.transparent,
              Colors.transparent,
              Colors.black.withValues(alpha: strength),
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Animated film grain drawn as scattered translucent specks.
class FilmGrain extends StatefulWidget {
  const FilmGrain({super.key, this.intensity = 0.05, this.density = 900});
  final double intensity;
  final int density;

  @override
  State<FilmGrain> createState() => _FilmGrainState();
}

class _FilmGrainState extends State<FilmGrain>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(
            size: Size.infinite,
            painter: _GrainPainter(
              seed: (_c.value * 1000).floor(),
              intensity: widget.intensity,
              density: widget.density,
            ),
          ),
        ),
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  _GrainPainter({
    required this.seed,
    required this.intensity,
    required this.density,
  });
  final int seed;
  final double intensity;
  final int density;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed);
    final paint = Paint();
    for (var i = 0; i < density; i++) {
      final dx = rnd.nextDouble() * size.width;
      final dy = rnd.nextDouble() * size.height;
      final a = rnd.nextDouble() * intensity;
      paint.color = (rnd.nextBool() ? Colors.white : Colors.black)
          .withValues(alpha: a);
      canvas.drawRect(Rect.fromLTWH(dx, dy, 1.2, 1.2), paint);
    }
  }

  @override
  bool shouldRepaint(_GrainPainter old) => old.seed != seed;
}

/// Slow-drifting smoke haze for depth.
class SmokeHaze extends StatefulWidget {
  const SmokeHaze({super.key, this.opacity = 0.10});
  final double opacity;

  @override
  State<SmokeHaze> createState() => _SmokeHazeState();
}

class _SmokeHazeState extends State<SmokeHaze>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          size: Size.infinite,
          painter: _SmokePainter(_c.value, widget.opacity),
        ),
      ),
    );
  }
}

class _SmokePainter extends CustomPainter {
  _SmokePainter(this.t, this.opacity);
  final double t;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 3; i++) {
      final phase = t * 2 * math.pi + i * 2.1;
      final cx = size.width * (0.3 + 0.4 * (0.5 + 0.5 * math.sin(phase)));
      final cy = size.height * (0.25 + 0.15 * math.cos(phase * 0.7)) +
          i * size.height * 0.2;
      final r = size.width * (0.35 + 0.1 * math.sin(phase * 1.3));
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.smoke.withValues(alpha: opacity),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r))
        ..blendMode = BlendMode.screen;
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }

  @override
  bool shouldRepaint(_SmokePainter old) => old.t != t;
}
