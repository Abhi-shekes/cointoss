import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Film-language overlays: teal/amber grade and lightning flash. Cheap
/// gradient/blend layers driven by scalar params so the scene can animate
/// them per shot.

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
