import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The lived-in 1920s bar: rain-streaked sash window, back-bar bottles, oak
/// table, and two silhouetted men settling a dispute — a standing witness
/// smoking (left) and a seated challenger hunched over the table (right).
/// The player is the third man: the tosser. Everything idles — breathing,
/// rain, ember drags — off an internal loop so the room never feels frozen.
class BarSet extends StatefulWidget {
  const BarSet({
    super.key,
    this.emberFlare = 0.0,
    this.lightning = 0.0,
    this.dim = 1.0,
  });

  /// Extra cigarette-ember flare 0..1 (scripted during the "faces" shot).
  final double emberFlare;

  /// Lightning brightness 0..1 — floods the window and rims the figures.
  final double lightning;

  /// Room light multiplier (the scene dims during the wager).
  final double dim;

  @override
  State<BarSet> createState() => _BarSetState();
}

class _BarSetState extends State<BarSet> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 12))
      ..repeat();
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
            painter: _BarSetPainter(
              t: _c.value,
              emberFlare: widget.emberFlare,
              lightning: widget.lightning,
              dim: widget.dim,
            ),
          ),
        ),
      ),
    );
  }
}

class _BarSetPainter extends CustomPainter {
  _BarSetPainter({
    required this.t,
    required this.emberFlare,
    required this.lightning,
    required this.dim,
  });

  final double t;
  final double emberFlare;
  final double lightning;
  final double dim;

  static const _silhouette = Color(0xFF060607);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    _window(canvas, w, h);
    _backBar(canvas, w, h);
    _table(canvas, w, h);
    _witness(canvas, w, h);
    _challenger(canvas, w, h);
  }

  // ---- Sash window, upper right: cold street light, rain, lightning. ----
  void _window(Canvas canvas, double w, double h) {
    final rect = Rect.fromLTRB(w * 0.66, h * 0.05, w * 0.94, h * 0.33);
    final glow = (0.16 + 0.84 * lightning).clamp(0.0, 1.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.inflate(w * 0.012), Radius.circular(w * 0.01)),
      Paint()..color = const Color(0xFF0A0A0C),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(const Color(0xFF16222E), const Color(0xFFBFD3E8), glow)!,
            Color.lerp(const Color(0xFF0C1218), const Color(0xFF5F7A96), glow)!,
          ],
        ).createShader(rect),
    );

    // Rain streaks sliding down the glass.
    final rnd = math.Random(41);
    final rain = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.1;
    for (var i = 0; i < 26; i++) {
      final x = rect.left + rnd.nextDouble() * rect.width;
      final speed = 0.6 + rnd.nextDouble() * 0.8;
      final len = rect.height * (0.10 + rnd.nextDouble() * 0.12);
      final phase = rnd.nextDouble();
      final y = rect.top +
          ((t * 6 * speed + phase) % 1.0) * (rect.height + len) -
          len;
      final top = math.max(y, rect.top);
      final bottom = math.min(y + len, rect.bottom);
      if (bottom <= top) continue;
      rain.color = const Color(0xFF9FB6CF)
          .withValues(alpha: (0.10 + 0.35 * lightning) * (0.5 + 0.5 * speed));
      canvas.drawLine(
          Offset(x + 1.5, top), Offset(x, bottom), rain);
    }

    // Muntin bars.
    final bars = Paint()
      ..color = const Color(0xFF08080A)
      ..strokeWidth = w * 0.012;
    canvas.drawLine(Offset(rect.center.dx, rect.top),
        Offset(rect.center.dx, rect.bottom), bars);
    canvas.drawLine(Offset(rect.left, rect.center.dy),
        Offset(rect.right, rect.center.dy), bars);

    // Cold spill from the window onto the room.
    canvas.drawRect(
      Rect.fromLTRB(rect.left - w * 0.08, rect.top, rect.right + w * 0.04,
          rect.bottom + h * 0.14),
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: [
            const Color(0xFF3D586F)
                .withValues(alpha: (0.05 + 0.30 * lightning) * dim.clamp(0, 1)),
            Colors.transparent,
          ],
        ).createShader(rect.inflate(w * 0.1))
        ..blendMode = BlendMode.plus,
    );
  }

  // ---- Back-bar shelf with bottle silhouettes, upper left. ----
  void _backBar(Canvas canvas, double w, double h) {
    final shelfY = h * 0.255;
    canvas.drawRect(
      Rect.fromLTWH(w * 0.03, shelfY, w * 0.30, h * 0.008),
      Paint()..color = const Color(0xFF0D0C0B),
    );
    final rnd = math.Random(9);
    final rim = 0.10 * dim + 0.18 * lightning;
    for (var i = 0; i < 6; i++) {
      final bx = w * (0.055 + i * 0.046) + rnd.nextDouble() * w * 0.008;
      final bh = h * (0.055 + rnd.nextDouble() * 0.035);
      final bw = w * (0.020 + rnd.nextDouble() * 0.008);
      final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(bx, shelfY - bh, bw, bh),
        Radius.circular(bw * 0.3),
      );
      canvas.drawRRect(body, Paint()..color = const Color(0xFF0A0908));
      // neck
      canvas.drawRect(
        Rect.fromLTWH(bx + bw * 0.35, shelfY - bh - h * 0.018, bw * 0.3,
            h * 0.02),
        Paint()..color = const Color(0xFF0A0908),
      );
      // amber rim light on the lamp side
      canvas.drawLine(
        Offset(bx + bw, shelfY - bh * 0.85),
        Offset(bx + bw, shelfY - bh * 0.1),
        Paint()
          ..color = AppColors.amber.withValues(alpha: rim)
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  // ---- Oak table catching the lamp pool. ----
  void _table(Canvas canvas, double w, double h) {
    final surfaceY = h * 0.72;
    // Surface plane, lit warm in the middle and falling to black.
    final surface = Rect.fromLTRB(-w * 0.1, surfaceY, w * 1.1, h * 0.86);
    canvas.drawRect(
      surface,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.6),
          radius: 1.0,
          colors: [
            Color.lerp(const Color(0xFF1A120A), const Color(0xFF3A2812),
                dim.clamp(0, 1))!,
            const Color(0xFF120C07),
            const Color(0xFF080604),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(surface),
    );
    // Warm elliptical lamp pool on the wood.
    final pool = Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.755), width: w * 0.72, height: h * 0.10);
    canvas.drawOval(
      pool,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.amber.withValues(alpha: 0.16 * dim),
            Colors.transparent,
          ],
        ).createShader(pool)
        ..blendMode = BlendMode.plus,
    );
    // Table front edge into darkness.
    canvas.drawRect(
      Rect.fromLTRB(-w * 0.1, h * 0.86, w * 1.1, h * 1.02),
      Paint()..color = const Color(0xFF050403),
    );
  }

  // ---- The witness: standing left, long coat, flat cap, smoking. ----
  void _witness(Canvas canvas, double w, double h) {
    final breathe = math.sin(t * 2 * math.pi * 3) * h * 0.0015;
    final cx = w * 0.155;
    final headY = h * 0.365 + breathe;
    final headR = h * 0.026;

    final p = Path()
      // long coat: hem to shoulders
      ..moveTo(cx - w * 0.115, h * 0.86)
      ..lineTo(cx - w * 0.075, headY + headR * 1.6)
      ..quadraticBezierTo(
          cx - w * 0.06, headY + headR * 0.9, cx - headR * 0.9, headY + headR)
      // head + flat cap silhouette
      ..lineTo(cx - headR, headY)
      ..quadraticBezierTo(cx - headR * 1.25, headY - headR * 0.9, cx,
          headY - headR * 1.25)
      // cap brim points toward the table (right)
      ..lineTo(cx + headR * 1.7, headY - headR * 0.55)
      ..lineTo(cx + headR * 0.95, headY - headR * 0.2)
      ..quadraticBezierTo(
          cx + headR * 1.05, headY + headR * 0.7, cx + headR * 0.7, headY + headR)
      // raised smoking arm toward the face
      ..quadraticBezierTo(cx + w * 0.055, headY + headR * 1.4, cx + w * 0.065,
          headY + headR * 2.6)
      ..quadraticBezierTo(
          cx + w * 0.075, headY + headR * 3.4, cx + w * 0.055, headY + headR * 4)
      // shoulder down the coat to the hem
      ..quadraticBezierTo(cx + w * 0.085, h * 0.55, cx + w * 0.10, h * 0.86)
      ..close();

    canvas.drawPath(p, Paint()..color = _silhouette);

    // Amber rim light on the lamp side of cap and shoulder.
    final rim = Paint()
      ..color = AppColors.amber
          .withValues(alpha: (0.10 * dim + 0.22 * lightning).clamp(0.0, 0.4))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    final rimPath = Path()
      ..moveTo(cx + headR * 1.7, headY - headR * 0.55)
      ..lineTo(cx + headR * 0.95, headY - headR * 0.2)
      ..quadraticBezierTo(
          cx + headR * 1.05, headY + headR * 0.7, cx + headR * 0.7, headY + headR)
      ..quadraticBezierTo(
          cx + w * 0.055, headY + headR * 1.4, cx + w * 0.065, headY + headR * 2.6);
    canvas.drawPath(rimPath, rim);

    // Cigarette: a drag flares the ember every few seconds.
    final drag = math.pow(
        math.max(0.0, math.sin(t * 2 * math.pi * 2 + 1.2)), 6) as double;
    final ember = (0.35 + 0.65 * drag + emberFlare).clamp(0.0, 1.0);
    final tip = Offset(cx + headR * 2.1, headY + headR * 0.35);
    canvas.drawLine(
      Offset(cx + headR * 1.2, headY + headR * 0.45),
      tip,
      Paint()
        ..color = const Color(0xFFD8D2C5).withValues(alpha: 0.5)
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      tip,
      2.2 + 1.6 * ember,
      Paint()
        ..color = const Color(0xFFFF5A22).withValues(alpha: 0.85 * ember)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    // Face catches the ember light during the drag.
    canvas.drawCircle(
      Offset(cx + headR * 0.8, headY + headR * 0.25),
      headR * 0.9,
      Paint()
        ..color = const Color(0xFFB4531F).withValues(alpha: 0.28 * ember)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Smoke wisp rising off the cigarette.
    for (var i = 0; i < 5; i++) {
      final lt = ((t * 3 + i / 5) % 1.0);
      final sway = math.sin(lt * math.pi * 3 + i) * w * 0.02;
      canvas.drawCircle(
        tip + Offset(sway + w * 0.01, -lt * h * 0.12),
        3 + lt * 9,
        Paint()
          ..color = AppColors.smoke.withValues(alpha: 0.10 * (1 - lt) * dim)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
  }

  // ---- The challenger: seated right, hunched over the table. ----
  void _challenger(Canvas canvas, double w, double h) {
    final breathe = math.sin(t * 2 * math.pi * 3 + 2.1) * h * 0.0018;
    final cx = w * 0.83;
    final headY = h * 0.52 + breathe;
    final headR = h * 0.028;

    final p = Path()
      // rounded hunched back rising from the bench
      ..moveTo(cx + w * 0.115, h * 0.80)
      ..quadraticBezierTo(cx + w * 0.125, h * 0.62, cx + w * 0.055,
          headY + headR * 2.0)
      // shoulder up to the nape — a clear notch so the head reads
      ..quadraticBezierTo(cx + w * 0.02, headY + headR * 1.5, cx + headR * 0.85,
          headY + headR * 1.15)
      ..lineTo(cx + headR * 0.95, headY + headR * 0.45)
      // head dome with the flat cap; brim toward the table (left)
      ..quadraticBezierTo(
          cx + headR * 1.25, headY - headR * 0.9, cx, headY - headR * 1.2)
      ..lineTo(cx - headR * 1.9, headY - headR * 0.4)
      ..lineTo(cx - headR * 0.95, headY - headR * 0.05)
      // jaw and chest, leaning in
      ..quadraticBezierTo(cx - headR * 1.05, headY + headR * 0.9, cx - w * 0.045,
          headY + headR * 1.9)
      // forearm reaching onto the table
      ..quadraticBezierTo(cx - w * 0.12, h * 0.665, cx - w * 0.195, h * 0.712)
      ..lineTo(cx - w * 0.195, h * 0.736)
      ..quadraticBezierTo(cx - w * 0.09, h * 0.735, cx - w * 0.05, h * 0.80)
      ..close();

    canvas.drawPath(p, Paint()..color = _silhouette);

    // Rim light along cap and shoulder facing the lamp (left side).
    canvas.drawPath(
      Path()
        ..moveTo(cx - headR * 1.8, headY - headR * 0.45)
        ..lineTo(cx - headR * 1.0, headY - headR * 0.05)
        ..quadraticBezierTo(cx - headR * 1.1, headY + headR * 0.9,
            cx - w * 0.065, headY + headR * 1.7),
      Paint()
        ..color = AppColors.amber
            .withValues(alpha: (0.12 * dim + 0.22 * lightning).clamp(0.0, 0.4))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
  }

  @override
  bool shouldRepaint(_BarSetPainter old) =>
      old.t != t ||
      old.emberFlare != emberFlare ||
      old.lightning != lightning ||
      old.dim != dim;
}

/// Hanging cone lamp over the table with a volumetric light shaft and dust
/// motes drifting through it. Swings almost imperceptibly.
class HangingLamp extends StatefulWidget {
  const HangingLamp({super.key, this.intensity = 1.0});

  /// 0..1+ light intensity (the scene dims it during the wager).
  final double intensity;

  @override
  State<HangingLamp> createState() => _HangingLampState();
}

class _HangingLampState extends State<HangingLamp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 9))
      ..repeat();
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
            painter: _LampPainter(t: _c.value, intensity: widget.intensity),
          ),
        ),
      ),
    );
  }
}

class _LampPainter extends CustomPainter {
  _LampPainter({required this.t, required this.intensity});
  final double t;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final swing = math.sin(t * 2 * math.pi) * 0.018;
    final top = Offset(w * 0.5, 0);
    final shade = Offset(w * 0.5 + swing * h * 0.10, h * 0.085);
    final i = intensity.clamp(0.0, 1.5);

    // Cord.
    canvas.drawLine(
      top,
      shade,
      Paint()
        ..color = const Color(0xFF0A0A0C)
        ..strokeWidth = 2.5,
    );

    // Volumetric shaft: cone from the shade to the table pool.
    final poolY = h * 0.76;
    final spread = w * 0.38;
    final cone = Path()
      ..moveTo(shade.dx - w * 0.045, shade.dy)
      ..lineTo(shade.dx + swing * h * 0.35 - spread, poolY)
      ..lineTo(shade.dx + swing * h * 0.35 + spread, poolY)
      ..lineTo(shade.dx + w * 0.045, shade.dy)
      ..close();
    canvas.drawPath(
      cone,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.amber.withValues(alpha: 0.20 * i),
            AppColors.amber.withValues(alpha: 0.05 * i),
            Colors.transparent,
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromLTRB(
            shade.dx - spread, shade.dy, shade.dx + spread, poolY))
        ..blendMode = BlendMode.plus,
    );

    // Dust motes hanging in the shaft.
    final rnd = math.Random(23);
    final mote = Paint()..blendMode = BlendMode.plus;
    for (var j = 0; j < 34; j++) {
      final u = rnd.nextDouble() * 2 - 1; // -1..1 across the cone
      final depth = rnd.nextDouble(); // 0 top .. 1 pool
      final drift = ((t * (0.15 + rnd.nextDouble() * 0.25) + rnd.nextDouble()) %
          1.0);
      final y = shade.dy + (poolY - shade.dy) * ((depth + drift) % 1.0);
      final frac = (y - shade.dy) / (poolY - shade.dy);
      final halfW = w * 0.045 + (spread - w * 0.045) * frac;
      final x = shade.dx +
          swing * h * 0.35 * frac +
          u * halfW +
          math.sin((t * 4 + j) * math.pi) * 2;
      mote.color = AppColors.brassLight
          .withValues(alpha: 0.28 * (1 - u.abs()) * (1 - frac * 0.5) * i);
      canvas.drawCircle(Offset(x, y), 0.8 + rnd.nextDouble() * 0.9, mote);
    }

    // Bulb glow + cone shade drawn last so they sit over the shaft.
    canvas.drawCircle(
      shade + Offset(0, h * 0.012),
      h * 0.02,
      Paint()
        ..color = AppColors.brassLight.withValues(alpha: 0.75 * i)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    final shadePath = Path()
      ..moveTo(shade.dx - w * 0.075, shade.dy + h * 0.006)
      ..lineTo(shade.dx - w * 0.02, shade.dy - h * 0.028)
      ..lineTo(shade.dx + w * 0.02, shade.dy - h * 0.028)
      ..lineTo(shade.dx + w * 0.075, shade.dy + h * 0.006)
      ..close();
    canvas.drawPath(
      shadePath,
      Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFF15130F),
            Color.lerp(const Color(0xFF241D12), AppColors.brassDeep, 0.35 * i)!,
          ],
        ).createShader(Rect.fromCenter(
            center: shade, width: w * 0.15, height: h * 0.06)),
    );
  }

  @override
  bool shouldRepaint(_LampPainter old) =>
      old.t != t || old.intensity != intensity;
}
