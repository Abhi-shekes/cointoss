import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../theme/app_theme.dart';

enum CoinSide { heads, tails }

/// Number of frames in one full rotation. Frame 0 = heads up, frame N/2 =
/// tails up. Both gen_placeholder_frames.py and render_coin.py honor this.
const int kCoinFrameCount = 90;

/// Loads the coin frame sequence once; returns [] if assets aren't present
/// (the app then falls back to the procedural Matrix4 coin).
Future<List<ui.Image>> loadCoinFrames() async {
  final frames = <ui.Image>[];
  for (var i = 0; i < kCoinFrameCount; i++) {
    final name = 'assets/coin/frame_${i.toString().padLeft(3, '0')}.png';
    try {
      final data = await rootBundle.load(name);
      final codec =
          await ui.instantiateImageCodec(data.buffer.asUint8List());
      frames.add((await codec.getNextFrame()).image);
    } catch (_) {
      return frames.isEmpty ? const [] : frames;
    }
  }
  return frames;
}

/// The coin. Renders purely from [spin] (radians). Front face is heads,
/// back is tails, so the scene lands on a multiple of 2π for heads and an
/// odd multiple of π for tails. Uses baked [frames] when supplied.
class Coin extends StatelessWidget {
  const Coin({
    super.key,
    required this.spin,
    this.frames,
    this.size = 240,
  });

  final double spin;
  final List<ui.Image>? frames;
  final double size;

  @override
  Widget build(BuildContext context) {
    final f = frames;
    if (f != null && f.isNotEmpty) {
      final turns = spin / (2 * math.pi);
      final frac = turns - turns.floorToDouble();
      final idx = (frac * f.length).round() % f.length;
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _FramePainter(f[idx])),
      );
    }
    return _FallbackCoin(spin: spin, size: size);
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.image);
  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
        0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Offset.zero & size;
    canvas.drawImageRect(image, src, dst,
        Paint()..filterQuality = FilterQuality.high);
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.image != image;
}

/// Matrix4 fake-3D fallback used until frame assets exist.
class _FallbackCoin extends StatelessWidget {
  const _FallbackCoin({required this.spin, required this.size});
  final double spin;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cos = math.cos(spin);
    final showingFront = cos >= 0;
    final faceUp = showingFront ? CoinSide.heads : CoinSide.tails;
    final edgeFactor = cos.abs();

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0015)
        ..rotateX(spin),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: (1 - edgeFactor).clamp(0.0, 1.0),
            child: _MilledEdge(size: size),
          ),
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..rotateY(showingFront ? 0 : math.pi),
            child: _CoinFace(side: faceUp, size: size),
          ),
        ],
      ),
    );
  }
}

class _CoinFace extends StatelessWidget {
  const _CoinFace({required this.side, required this.size});
  final CoinSide side;
  final double size;

  @override
  Widget build(BuildContext context) {
    final label = side == CoinSide.heads ? 'H' : 'T';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const SweepGradient(
          colors: [
            AppColors.brassDeep,
            AppColors.brassLight,
            AppColors.brass,
            AppColors.brassDeep,
            AppColors.brassLight,
            AppColors.brassDeep,
          ],
          stops: [0.0, 0.2, 0.45, 0.6, 0.82, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.amber.withValues(alpha: 0.35),
            blurRadius: 40,
            spreadRadius: 4,
          ),
          const BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: size * 0.82,
          height: size * 0.82,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              center: Alignment(-0.3, -0.4),
              colors: [
                AppColors.brassLight,
                AppColors.brass,
                AppColors.brassDeep,
              ],
              stops: [0.0, 0.55, 1.0],
            ),
            border: Border.all(
              color: AppColors.brassDeep.withValues(alpha: 0.8),
              width: size * 0.02,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Cinzel',
                fontSize: size * 0.42,
                fontWeight: FontWeight.w800,
                color: AppColors.oxbloodDeep.withValues(alpha: 0.85),
                shadows: [
                  Shadow(
                    color: AppColors.brassLight.withValues(alpha: 0.6),
                    offset: const Offset(0, -1.5),
                  ),
                  const Shadow(color: Colors.black45, offset: Offset(0, 2)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MilledEdge extends StatelessWidget {
  const _MilledEdge({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.brassDeep, AppColors.brass, AppColors.brassDeep],
        ),
      ),
    );
  }
}
