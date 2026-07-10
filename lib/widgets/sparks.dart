import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class _Spark {
  _Spark(this.angle, this.speed, this.size, this.life);
  final double angle;
  final double speed;
  final double size;
  final double life; // 0..1 fraction of total that this spark lives
}

/// A one-shot brass spark burst, driven by an external [progress] 0→1.
/// Draw it over the coin's landing point.
class Sparks extends StatelessWidget {
  Sparks({super.key, required this.progress, this.count = 26, int seed = 0})
      : _sparks = _build(count, seed);

  final double progress;
  final int count;
  final List<_Spark> _sparks;

  static List<_Spark> _build(int count, int seed) {
    final r = math.Random(seed);
    return List.generate(count, (_) {
      final a = -math.pi / 2 + (r.nextDouble() - 0.5) * math.pi * 1.1;
      return _Spark(
        a,
        60 + r.nextDouble() * 180,
        1.4 + r.nextDouble() * 2.6,
        0.55 + r.nextDouble() * 0.45,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (progress <= 0 || progress >= 1) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _SparkPainter(_sparks, progress),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.sparks, this.t);
  final List<_Spark> sparks;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.56);
    final paint = Paint()..blendMode = BlendMode.plus;
    for (final s in sparks) {
      final lt = (t / s.life).clamp(0.0, 1.0);
      if (lt >= 1) continue;
      final dist = s.speed * lt;
      final gravity = 90 * lt * lt; // arc downward
      final pos = origin +
          Offset(math.cos(s.angle) * dist, math.sin(s.angle) * dist + gravity);
      final fade = (1 - lt);
      paint.color = Color.lerp(AppColors.brassLight, AppColors.amber, lt)!
          .withValues(alpha: fade);
      // streak in the direction of travel
      final tail = Offset(math.cos(s.angle), math.sin(s.angle)) * s.size * 3;
      canvas.drawLine(
        pos - tail * fade,
        pos,
        paint
          ..strokeWidth = s.size * fade
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.t != t;
}
