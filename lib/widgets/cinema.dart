import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Film-language overlays: letterbox mattes, teal/amber grade, lightning,
/// halation flare and engraved title cards. All are cheap gradient/blend
/// layers driven by scalar params so the scene can animate them per shot.

/// 2.39:1-style black mattes that close in as the cutscene starts.
/// [amount] 0 = open (no bars), 1 = fully closed cinema frame.
class Letterbox extends StatelessWidget {
  const Letterbox({super.key, required this.amount});
  final double amount;

  @override
  Widget build(BuildContext context) {
    if (amount <= 0) return const SizedBox.shrink();
    final h = MediaQuery.of(context).size.height * 0.13 * amount;
    return IgnorePointer(
      child: Column(
        children: [
          Container(height: h, color: Colors.black),
          const Spacer(),
          Container(height: h, color: Colors.black),
        ],
      ),
    );
  }
}

/// Cinematic split-tone grade: teal creeping into the shadows at the edges,
/// warm amber lifted in the lamp pool. [strength] 0..1.
class ColorGrade extends StatelessWidget {
  const ColorGrade({super.key, this.strength = 1.0});
  final double strength;

  @override
  Widget build(BuildContext context) {
    if (strength <= 0) return const SizedBox.shrink();
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Teal shadows — screen-blended from the frame edges inward.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.1),
                radius: 1.25,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  const Color(0xFF0E3A42).withValues(alpha: 0.20 * strength),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
              backgroundBlendMode: BlendMode.screen,
            ),
          ),
          // Amber highlight lift in the lamp pool.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.1),
                radius: 0.7,
                colors: [
                  AppColors.amber.withValues(alpha: 0.06 * strength),
                  Colors.transparent,
                ],
              ),
              backgroundBlendMode: BlendMode.plus,
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-frame lightning flash: cold blue-white, brightest at the window side.
/// [value] 0..1 flash envelope.
class LightningFlash extends StatelessWidget {
  const LightningFlash({super.key, required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    if (value <= 0.01) return const SizedBox.shrink();
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.75, -0.65), // from the window
            radius: 1.6,
            colors: [
              const Color(0xFFD8E6F5).withValues(alpha: 0.32 * value),
              const Color(0xFF9FB6CF).withValues(alpha: 0.10 * value),
              Colors.transparent,
            ],
            stops: const [0.0, 0.45, 1.0],
          ),
          backgroundBlendMode: BlendMode.plus,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Warm halation bloom centered on the coin for the reveal flare.
/// [value] 0..1, [center] in alignment space.
class Halation extends StatelessWidget {
  const Halation({
    super.key,
    required this.value,
    this.center = Alignment.center,
  });
  final double value;
  final Alignment center;

  @override
  Widget build(BuildContext context) {
    if (value <= 0.01) return const SizedBox.shrink();
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: center,
            radius: 0.85,
            colors: [
              AppColors.brassLight.withValues(alpha: 0.22 * value),
              AppColors.amber.withValues(alpha: 0.08 * value),
              Colors.transparent,
            ],
            stops: const [0.0, 0.35, 1.0],
          ),
          backgroundBlendMode: BlendMode.plus,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Whispered engraved title ("CALL IT.") that breathes in and out.
/// [opacity] 0..1 drives both fade and a slight tracking widen.
class TitleCard extends StatelessWidget {
  const TitleCard({super.key, required this.text, required this.opacity});
  final String text;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0.01) return const SizedBox.shrink();
    return IgnorePointer(
      child: Center(
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cinzel',
              fontSize: 30,
              fontWeight: FontWeight.w600,
              letterSpacing: 10 + 4 * (1 - opacity),
              color: AppColors.brassLight.withValues(alpha: 0.92),
              shadows: const [
                Shadow(color: Colors.black87, blurRadius: 18),
                Shadow(color: Color(0x66E8A54B), blurRadius: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
