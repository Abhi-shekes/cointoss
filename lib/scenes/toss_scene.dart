import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import '../audio/sound_engine.dart';
import '../settings.dart';
import '../theme/app_theme.dart';
import '../widgets/atmosphere.dart';
import '../widgets/coin.dart';
import '../widgets/sparks.dart';

/// Cinematic flip timing: fast launch → slow-motion apex dwell → landing.
class _CinematicFlipCurve extends Curve {
  const _CinematicFlipCurve();

  @override
  double transformInternal(double t) {
    if (t < 0.45) {
      final u = t / 0.45;
      return 0.5 * Curves.easeOut.transform(u); // fast, decelerating launch
    } else if (t < 0.72) {
      final u = (t - 0.45) / (0.72 - 0.45);
      return 0.5 + 0.12 * u; // slow-motion dwell at the apex
    } else {
      final u = (t - 0.72) / (1 - 0.72);
      return 0.62 + 0.38 * Curves.easeInOut.transform(u); // land & settle
    }
  }
}

enum TossPhase { idle, flipping, revealed }

class TossScene extends StatefulWidget {
  const TossScene({super.key});

  @override
  State<TossScene> createState() => _TossSceneState();
}

class _TossSceneState extends State<TossScene>
    with TickerProviderStateMixin {
  late final AnimationController _flip;
  late final AnimationController _shake;
  final _rnd = math.Random();

  TossPhase _phase = TossPhase.idle;
  CoinSide _result = CoinSide.heads;
  double _totalSpin = 0;
  bool _clinked = false;
  int _tossCount = 0;
  List<ui.Image>? _frames;

  static const _flipCurve = _CinematicFlipCurve();

  @override
  void initState() {
    super.initState();
    _flip = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..addListener(_onFlipTick);
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    SoundEngine.instance.startAmbient();
    loadCoinFrames().then((f) {
      if (mounted && f.isNotEmpty) setState(() => _frames = f);
    });
  }

  @override
  void dispose() {
    _flip.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _onFlipTick() {
    // Fire the landing beat once, just before the coin settles.
    if (!_clinked && _flip.value > 0.9) {
      _clinked = true;
      _land();
    }
    if (_flip.isCompleted) {
      setState(() => _phase = TossPhase.revealed);
      SoundEngine.instance.reveal();
    }
  }

  Future<void> _land() async {
    SoundEngine.instance.clink();
    _shake.forward(from: 0);
    if (Settings.instance.haptics && await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 55, amplitude: 180);
    }
  }

  void _toss() {
    if (_phase == TossPhase.flipping) return;
    _result = _rnd.nextBool() ? CoinSide.heads : CoinSide.tails;
    // Land so the chosen face rests upward: heads at a whole turn, tails a
    // half-turn past it (frame 0 = heads, frame N/2 = tails).
    final turns = 5 + _rnd.nextInt(4); // 5..8 full rotations
    final landing = _result == CoinSide.tails ? math.pi : 0.0;
    _totalSpin = turns * 2 * math.pi + landing;
    _clinked = false;
    _tossCount++;
    setState(() => _phase = TossPhase.flipping);
    SoundEngine.instance.whoosh();
    _flip.forward(from: 0);
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141418),
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _SettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final coinSize = math.min(media.size.width * 0.62, 300.0);

    return GestureDetector(
      onTap: _toss,
      child: Scaffold(
        body: AnimatedBuilder(
          animation: Listenable.merge([_flip, _shake]),
          builder: (context, _) {
            final p = _flipCurve.transform(_flip.value);
            final spin = _totalSpin * p;

            // Vertical arc — coin lifts, dwells, drops back to the table.
            final arc =
                math.sin(math.pi * Curves.easeInOut.transform(_flip.value));
            final lift = -arc * media.size.height * 0.22;

            // Landing screen-shake, decaying.
            final shakeAmt = (1 - _shake.value) *
                math.sin(_shake.value * math.pi * 7) *
                8;

            // Dim the room during the flip, flare on reveal.
            final glow = switch (_phase) {
              TossPhase.idle => 1.0,
              TossPhase.flipping => 0.55 + 0.25 * arc,
              TossPhase.revealed => 1.25,
            };

            // Motion blur from angular speed (crisp at the slow-mo apex).
            const dt = 0.001;
            final v = (_flipCurve.transform((_flip.value + dt).clamp(0.0, 1.0)) -
                    _flipCurve.transform((_flip.value - dt).clamp(0.0, 1.0))) /
                (2 * dt) *
                _totalSpin;
            final blur = _phase == TossPhase.flipping
                ? (v.abs() / 12).clamp(0.0, 7.0)
                : 0.0;

            // Camera push-in: lean toward the coin as it rises / on reveal.
            final push = switch (_phase) {
              TossPhase.flipping => 1 + 0.06 * arc,
              TossPhase.revealed => 1.04,
              TossPhase.idle => 1.0,
            };

            Widget coin = Coin(spin: spin, frames: _frames, size: coinSize);
            if (blur > 0.15) {
              coin = ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: coin,
              );
            }

            return Transform.translate(
              offset: Offset(shakeAmt, shakeAmt * 0.4),
              child: Transform.scale(
                scale: push,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    BarBackground(glow: glow),
                    const SmokeHaze(),
                    _TableShadow(arc: arc, coinSize: coinSize),
                    Center(
                      child: Transform.translate(
                        offset: Offset(0, lift),
                        child: coin,
                      ),
                    ),
                    Sparks(progress: _shake.value, seed: _tossCount),
                    const Vignette(),
                    const FilmGrain(),
                    _Hud(phase: _phase, result: _result),
                    _SettingsButton(onTap: _openSettings),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Soft shadow that shrinks and fades as the coin rises.
class _TableShadow extends StatelessWidget {
  const _TableShadow({required this.arc, required this.coinSize});
  final double arc;
  final double coinSize;

  @override
  Widget build(BuildContext context) {
    final scale = 1 - arc * 0.55;
    return Align(
      alignment: const Alignment(0, 0.62),
      child: Transform.scale(
        scaleX: scale,
        scaleY: scale * 0.25,
        child: Container(
          width: coinSize,
          height: coinSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.black.withValues(alpha: 0.55 * (1 - arc * 0.6)),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Title + prompt + result overlay.
class _Hud extends StatelessWidget {
  const _Hud({required this.phase, required this.result});
  final TossPhase phase;
  final CoinSide result;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return IgnorePointer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Column(
            children: [
              Text('COIN TOSS', style: text.titleLarge),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: switch (phase) {
                  TossPhase.revealed => Column(
                      key: const ValueKey('result'),
                      children: [
                        Text(
                          result == CoinSide.heads ? 'HEADS' : 'TAILS',
                          style: text.displayLarge,
                        ),
                        const SizedBox(height: 8),
                        Text('TAP TO TOSS AGAIN', style: text.bodyMedium),
                      ],
                    ),
                  TossPhase.idle => Text(
                      'TAP TO TOSS',
                      key: const ValueKey('idle'),
                      style: text.bodyMedium?.copyWith(letterSpacing: 4),
                    ),
                  TossPhase.flipping => const SizedBox(
                      key: ValueKey('flip'), height: 24),
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Brass gear in the top-right that opens the settings sheet.
class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 8, top: 4),
          child: IconButton(
            onPressed: onTap,
            icon: const Icon(Icons.settings, color: AppColors.brass),
            tooltip: 'Settings',
          ),
        ),
      ),
    );
  }
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet();

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  @override
  Widget build(BuildContext context) {
    final s = Settings.instance;
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SETTINGS',
                style: text.titleLarge?.copyWith(fontSize: 18)),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.brass,
              title: Text('Sound', style: text.bodyMedium),
              value: s.sound,
              onChanged: (v) => setState(() => s.sound = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.brass,
              title: Text('Haptics', style: text.bodyMedium),
              value: s.haptics,
              onChanged: (v) => setState(() => s.haptics = v),
            ),
          ],
        ),
      ),
    );
  }
}
