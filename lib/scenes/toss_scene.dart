import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import '../audio/sound_engine.dart';
import '../settings.dart';
import '../theme/app_theme.dart';
import '../widgets/atmosphere.dart';
import '../widgets/bar_set.dart';
import '../widgets/cinema.dart';
import '../widgets/coin.dart';
import '../widgets/sparks.dart';

/// "The Wager" — a real-time GTA-cutscene-grade toss. One 13-second scene:
///
///   0.0–2.2   ESTABLISH  crane down through smoke, lightning, "CALL IT."
///   2.2–4.2   FACES      lateral dolly across the men; the ember flares
///   4.2–5.3   THE SET    the hand rises, sovereign on the thumbnail
///   5.3–5.75  FLICK      ting — the coin fires up out of the light pool
///   5.75–9.6  APEX       time collapses; slow orbit in the lamp shaft
///   9.6–10.05 DROP       whip-tilt, heavy directional blur
///   10.05     SLAM       clink, shake, sparks, haptic
///   10.35–13  REVEAL     push-in, halation, HEADS/TAILS stamped in gold
///
/// Any tap skips to the drop. Settings offer the ~3 s quick toss instead.
const double _kDurSec = 13.0;

/// Legacy quick-flip timing: fast launch → slow-motion apex dwell → landing.
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

enum TossPhase { idle, cinematic, flipping, revealed }

/// A one-shot audio/haptic event on the master timeline.
class _Cue {
  _Cue(this.at, this.fire);
  final double at; // seconds
  final void Function() fire;
  bool fired = false;
}

class TossScene extends StatefulWidget {
  const TossScene({super.key});

  @override
  State<TossScene> createState() => _TossSceneState();
}

class _TossSceneState extends State<TossScene> with TickerProviderStateMixin {
  late final AnimationController _master; // the 13 s cutscene
  late final AnimationController _flip; // quick-toss flip
  late final AnimationController _shake;
  late final AnimationController _lightning; // idle storm flashes
  Timer? _stormTimer;
  final _rnd = math.Random();

  TossPhase _phase = TossPhase.idle;
  CoinSide _result = CoinSide.heads;
  double _totalSpin = 0;
  bool _clinked = false;
  int _tossCount = 0;
  List<ui.Image>? _frames;
  List<_Cue> _cues = [];

  static const _flipCurve = _CinematicFlipCurve();

  @override
  void initState() {
    super.initState();
    _master = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: (_kDurSec * 1000) ~/ 1),
    )..addListener(_onMasterTick);
    _flip = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..addListener(_onFlipTick);
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _lightning = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scheduleStorm();
    SoundEngine.instance.startAmbient();
    loadCoinFrames().then((f) {
      if (mounted && f.isNotEmpty) setState(() => _frames = f);
    });
  }

  @override
  void dispose() {
    _stormTimer?.cancel();
    _master.dispose();
    _flip.dispose();
    _shake.dispose();
    _lightning.dispose();
    super.dispose();
  }

  /// Random distant lightning while the room idles.
  void _scheduleStorm() {
    _stormTimer = Timer(Duration(milliseconds: 9000 + _rnd.nextInt(11000)), () {
      if (!mounted) return;
      if (_phase != TossPhase.cinematic) _lightning.forward(from: 0);
      _scheduleStorm();
    });
  }

  // ---------------------------------------------------------------- timeline

  void _onMasterTick() {
    final t = _master.value * _kDurSec;
    for (final c in _cues) {
      if (!c.fired && t >= c.at) {
        c.fired = true;
        c.fire();
      }
    }
    if (_master.isCompleted && _phase == TossPhase.cinematic) {
      setState(() => _phase = TossPhase.revealed);
    }
  }

  void _onFlipTick() {
    // Quick toss: fire the landing beat once, just before the coin settles.
    if (!_clinked && _flip.value > 0.9) {
      _clinked = true;
      _land();
    }
    if (_flip.isCompleted && _phase == TossPhase.flipping) {
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

  void _onTap() {
    switch (_phase) {
      case TossPhase.cinematic:
        _skip();
      case TossPhase.flipping:
        return;
      case TossPhase.idle || TossPhase.revealed:
        _toss();
    }
  }

  void _toss() {
    _result = _rnd.nextBool() ? CoinSide.heads : CoinSide.tails;
    // Land so the chosen face rests upward: heads at a whole turn, tails a
    // half-turn past it (frame 0 = heads, frame N/2 = tails).
    final turns = 6 + _rnd.nextInt(3); // 6..8 full rotations
    final landing = _result == CoinSide.tails ? math.pi : 0.0;
    _totalSpin = turns * 2 * math.pi + landing;
    _clinked = false;
    _tossCount++;

    if (Settings.instance.cinematic) {
      final s = SoundEngine.instance;
      _cues = [
        _Cue(0.02, s.thunder),
        _Cue(4.2, () => s.duckAmbient(true)),
        _Cue(5.25, s.ting),
        _Cue(5.70, s.whoosh),
        _Cue(5.85, s.apexStart),
        _Cue(9.58, s.apexStop),
        _Cue(10.05, _land),
        _Cue(10.55, s.sting),
        _Cue(10.95, () => s.duckAmbient(false)),
      ];
      setState(() => _phase = TossPhase.cinematic);
      _master.forward(from: 0);
    } else {
      setState(() => _phase = TossPhase.flipping);
      SoundEngine.instance.whoosh();
      _flip.forward(from: 0);
    }
  }

  /// Tap mid-scene: cut straight to the drop (the verdict still lands).
  void _skip() {
    final t = _master.value * _kDurSec;
    if (t >= 9.4) return;
    for (final c in _cues) {
      if (c.at < 9.5) c.fired = true;
    }
    SoundEngine.instance.apexStop();
    SoundEngine.instance.duckAmbient(true);
    _master.forward(from: 9.5 / _kDurSec);
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

  // ------------------------------------------------------------------ shots

  static double _seg(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0.0, 1.0);

  static double _gauss(double t, double at, double width) =>
      math.exp(-math.pow((t - at) / width, 2).toDouble());

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final w = media.size.width;
    final h = media.size.height;
    final coinSize = math.min(w * 0.62, 300.0);
    final baseDy = h * 0.10; // resting height over the table pool

    return GestureDetector(
      onTap: _onTap,
      child: Scaffold(
        body: AnimatedBuilder(
          animation:
              Listenable.merge([_master, _flip, _shake, _lightning]),
          builder: (context, _) {
            final cine = _phase == TossPhase.cinematic;
            final t = _master.value * _kDurSec;

            // ---- camera ----
            double camS = 1.0, camX = 0, camY = 0;
            // ---- coin ----
            double spin = _totalSpin;
            double dy = baseDy;
            double coinScale = 1.0;
            bool coinVisible = true;
            double blurX = 0, blurY = 0;
            // ---- light & film ----
            double glow = _phase == TossPhase.revealed ? 1.25 : 1.0;
            double letterbox = 0, title = 0, ember = 0, stamp = 0;
            double halation = 0, glint = 0, hand = 0;
            double flash =
                _stormEnvelope(_lightning.isAnimating ? _lightning.value : 1);

            if (cine) {
              final hand0 = math.sin(t * 7.3) * 1.5 + math.sin(t * 11.1);

              if (t < 2.2) {
                // ESTABLISH — crane down through the smoke.
                final u = Curves.easeOutCubic.transform(_seg(t, 0, 2.2));
                camS = 1.30 - 0.22 * u;
                camY = -40 * (1 - u);
                glow = 1.0 - 0.25 * u;
                coinVisible = false;
              } else if (t < 4.2) {
                // FACES — lateral dolly; the witness drags his cigarette.
                final u = _seg(t, 2.2, 4.2);
                camS = 1.08;
                camX = ui.lerpDouble(-10, 10, u)!;
                glow = 0.75 - 0.13 * u;
                coinVisible = false;
              } else if (t < 5.3) {
                // THE SET — the hand rises, coin on the thumbnail.
                final u = Curves.easeInOut.transform(_seg(t, 4.2, 5.3));
                camS = ui.lerpDouble(1.08, 1.14, u)!;
                camX = ui.lerpDouble(10, 0, u)!;
                glow = 0.62 - 0.07 * u;
                dy = ui.lerpDouble(
                    h * 0.55, baseDy, Curves.easeOutCubic.transform(u))!;
              } else if (t < 5.75) {
                // FLICK — thumb fires; camera kicks back to follow.
                final u = _seg(t, 5.3, 5.75);
                camS = ui.lerpDouble(1.14, 1.06, Curves.easeOut.transform(u))!;
                camY = 8 * math.sin(math.pi * u);
                glow = 0.55;
                dy = ui.lerpDouble(baseDy, -h * 0.16,
                    Curves.easeOut.transform(_seg(t, 5.3, 6.4)))!;
                coinScale = ui.lerpDouble(1.0, 1.3, _seg(t, 5.3, 6.4))!;
                blurX = blurY = 6 * math.sin(math.pi * u);
              } else if (t < 9.6) {
                // APEX — time collapses; slow push with handheld drift.
                final u = _seg(t, 5.75, 9.6);
                camS = ui.lerpDouble(1.06, 1.18, u)!;
                camX = 6 * math.sin(u * math.pi * 1.6) + hand0;
                camY = hand0 * 0.7;
                glow = 0.5;
                final rise = Curves.easeOut.transform(_seg(t, 5.3, 6.4));
                dy = ui.lerpDouble(baseDy, -h * 0.16, rise)! +
                    math.sin((t - 6.4) * 2 * math.pi / 2.4) * h * 0.008;
                coinScale = ui.lerpDouble(1.0, 1.3, _seg(t, 5.3, 6.4))!;
              } else if (t < 10.05) {
                // DROP — whip-tilt, heavy vertical blur.
                final u = _seg(t, 9.6, 10.05);
                camS = ui.lerpDouble(1.18, 1.10, u)!;
                camY = ui.lerpDouble(-18, 14, Curves.easeIn.transform(u))!;
                glow = 0.5;
                dy = ui.lerpDouble(
                    -h * 0.16, baseDy, Curves.easeIn.transform(u))!;
                coinScale = ui.lerpDouble(1.3, 1.0, u)!;
                blurY = 16 * math.sin(math.pi * u);
                blurX = 1.5;
              } else {
                // SLAM + REVEAL — bounce, settle, push in on the verdict.
                final bounce = _seg(t, 10.05, 10.35);
                final u = Curves.easeOut.transform(_seg(t, 10.35, 12.0));
                camS = ui.lerpDouble(1.10, 1.24, u)!;
                camY = -baseDy * (camS - 1);
                glow = ui.lerpDouble(0.6, 1.25, _seg(t, 10.05, 11.5))!;
                dy = baseDy -
                    h * 0.03 * math.sin(math.pi * bounce) * (1 - bounce);
                halation = Curves.easeOut.transform(_seg(t, 10.35, 11.2));
                stamp = _seg(t, 10.5, 10.9);
              }

              // Spin: fast flick → 4% apex crawl → violent drop.
              spin = _totalSpin * _spinProgress(t);

              letterbox =
                  _seg(t, 0, 1.2) * (1 - _seg(t, 12.2, _kDurSec));
              title = _seg(t, 0.9, 1.6) * (1 - _seg(t, 2.1, 2.8));
              ember = _gauss(t, 3.0, 0.35);
              hand = _seg(t, 4.3, 4.9) * (1 - _seg(t, 5.75, 6.05));

              // Scripted storm: double flash on the crane, spark on the slam.
              flash = math.max(
                flash,
                math.max(
                  _gauss(t, 0.5, 0.12) + 0.5 * _gauss(t, 0.85, 0.2),
                  0.35 * _gauss(t, 10.12, 0.15),
                ),
              );

              // Lens glint when the engraving squares up to the lamp.
              if (t >= 6.2 && t < 9.6) {
                glint = ((math.cos(spin).abs() - 0.90) / 0.10).clamp(0.0, 1.0);
              }
            } else if (_phase == TossPhase.flipping) {
              // Quick toss — the legacy ~3 s flip.
              final p = _flipCurve.transform(_flip.value);
              spin = _totalSpin * p;
              final arc =
                  math.sin(math.pi * Curves.easeInOut.transform(_flip.value));
              dy = baseDy - arc * h * 0.30;
              glow = 0.55 + 0.25 * arc;
              camS = 1 + 0.06 * arc;
              const dt = 0.001;
              final v = (_flipCurve
                          .transform((_flip.value + dt).clamp(0.0, 1.0)) -
                      _flipCurve
                          .transform((_flip.value - dt).clamp(0.0, 1.0))) /
                  (2 * dt) *
                  _totalSpin;
              blurX = blurY = (v.abs() / 12).clamp(0.0, 7.0);
            } else if (_phase == TossPhase.revealed) {
              camS = 1.04;
            }

            // Landing screen-shake, decaying.
            final shakeAmt =
                (1 - _shake.value) * math.sin(_shake.value * math.pi * 7) * 8;

            Widget coin = Coin(
                spin: spin, frames: _frames, size: coinSize * coinScale);
            if (blurX > 0.15 || blurY > 0.15) {
              coin = ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                    sigmaX: math.max(blurX, 0.01),
                    sigmaY: math.max(blurY, 0.01)),
                child: coin,
              );
            }

            final heightFrac =
                ((baseDy - dy) / (h * 0.26)).clamp(0.0, 1.0); // 0 table, 1 apex

            // The world — everything the camera moves through.
            final world = Transform.translate(
              offset: Offset(camX + shakeAmt, camY + shakeAmt * 0.4),
              child: Transform.scale(
                scale: camS,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    BarBackground(glow: glow),
                    BarSet(
                      emberFlare: ember,
                      lightning: flash,
                      dim: glow.clamp(0.0, 1.0),
                    ),
                    const SmokeHaze(),
                    HangingLamp(intensity: glow.clamp(0.0, 1.2)),
                    _TableShadow(arc: heightFrac, coinSize: coinSize),
                    if (hand > 0.01)
                      _TosserHand(
                        opacity: hand,
                        coinCenter: Offset(w / 2, h / 2 + dy),
                        coinSize: coinSize,
                      ),
                    if (coinVisible)
                      Center(
                        child: Transform.translate(
                          offset: Offset(0, dy),
                          child: coin,
                        ),
                      ),
                    if (glint > 0.02)
                      _Glint(
                        center: Offset(w / 2, h / 2 + dy),
                        width: coinSize * coinScale * 2.2,
                        alpha: glint,
                      ),
                    Sparks(progress: _shake.value, seed: _tossCount),
                    Halation(
                        value: halation,
                        center: Alignment(0, (baseDy * 2) / h)),
                  ],
                ),
              ),
            );

            // The lens — grade, grain, mattes and titles stay locked.
            return Stack(
              fit: StackFit.expand,
              children: [
                world,
                const ColorGrade(),
                const Vignette(),
                const FilmGrain(),
                LightningFlash(value: flash),
                Letterbox(amount: letterbox),
                TitleCard(text: 'CALL IT.', opacity: title),
                if (stamp > 0.01)
                  _ResultStamp(result: _result, progress: stamp),
                if (!cine) _Hud(phase: _phase, result: _result),
                if (!cine) _SettingsButton(onTap: _openSettings),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Spin progress over the master timeline: 34% of the rotation in the
  /// flick, a 12% crawl across the apex, the rest slammed into the drop.
  double _spinProgress(double t) {
    if (t < 5.3) return 0;
    if (t < 5.75) {
      final u = _seg(t, 5.3, 5.75);
      return 0.34 * u * u * (3 - 2 * u); // smoothstep launch
    }
    if (t < 9.6) return 0.34 + 0.12 * _seg(t, 5.75, 9.6);
    final u = _seg(t, 9.6, 10.05);
    return 0.46 + 0.54 * u * u;
  }

  /// Double-spike envelope for an idle lightning flash.
  double _stormEnvelope(double v) {
    if (v >= 1 || v <= 0) return 0;
    return _gauss(v, 0.15, 0.07) + 0.55 * _gauss(v, 0.45, 0.12);
  }
}

/// Soft shadow that shrinks and fades as the coin rises. [arc] 0 = on the
/// table, 1 = at the apex.
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

/// The tosser's silhouetted hand rising from the bottom of frame with the
/// sovereign set on the thumbnail — the player is the third man.
class _TosserHand extends StatelessWidget {
  const _TosserHand({
    required this.opacity,
    required this.coinCenter,
    required this.coinSize,
  });
  final double opacity;
  final Offset coinCenter;
  final double coinSize;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _HandPainter(
            opacity: opacity, coinCenter: coinCenter, coinSize: coinSize),
      ),
    );
  }
}

class _HandPainter extends CustomPainter {
  _HandPainter({
    required this.opacity,
    required this.coinCenter,
    required this.coinSize,
  });
  final double opacity;
  final Offset coinCenter;
  final double coinSize;

  @override
  void paint(Canvas canvas, Size size) {
    final fist = coinCenter + Offset(0, coinSize * 0.62);
    final rx = coinSize * 0.34;
    final ry = coinSize * 0.26;
    final dark = Paint()
      ..color = const Color(0xFF060607).withValues(alpha: opacity);

    // Forearm from the bottom edge up to the fist.
    final arm = Path()
      ..moveTo(fist.dx - rx * 1.15, size.height + 20)
      ..quadraticBezierTo(fist.dx - rx * 1.05, fist.dy + ry * 2, fist.dx - rx,
          fist.dy + ry * 0.4)
      ..lineTo(fist.dx + rx * 0.95, fist.dy + ry * 0.4)
      ..quadraticBezierTo(fist.dx + rx * 1.15, fist.dy + ry * 2.2,
          fist.dx + rx * 1.35, size.height + 20)
      ..close();
    canvas.drawPath(arm, dark);

    // Fist, thumb cocked under the coin.
    canvas.drawOval(
        Rect.fromCenter(center: fist, width: rx * 2, height: ry * 2), dark);
    final thumb = Path()
      ..moveTo(fist.dx - rx * 0.35, fist.dy - ry * 0.6)
      ..quadraticBezierTo(fist.dx - rx * 0.1, fist.dy - ry * 1.6, fist.dx + rx * 0.25,
          fist.dy - ry * 1.45)
      ..quadraticBezierTo(
          fist.dx + rx * 0.4, fist.dy - ry * 0.8, fist.dx + rx * 0.3, fist.dy)
      ..close();
    canvas.drawPath(thumb, dark);

    // Lamp rim light along the knuckles.
    canvas.drawArc(
      Rect.fromCenter(center: fist, width: rx * 1.9, height: ry * 1.9),
      -math.pi * 0.85,
      math.pi * 0.7,
      false,
      Paint()
        ..color = AppColors.amber.withValues(alpha: 0.20 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  @override
  bool shouldRepaint(_HandPainter old) =>
      old.opacity != opacity || old.coinCenter != coinCenter;
}

/// Anamorphic lens streak fired when the coin face squares up to the lamp.
class _Glint extends StatelessWidget {
  const _Glint(
      {required this.center, required this.width, required this.alpha});
  final Offset center;
  final double width;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _GlintPainter(center: center, width: width, alpha: alpha),
      ),
    );
  }
}

class _GlintPainter extends CustomPainter {
  _GlintPainter({required this.center, required this.width, required this.alpha});
  final Offset center;
  final double width;
  final double alpha;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(center: center, width: width, height: 6);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            AppColors.brassLight.withValues(alpha: 0.85 * alpha),
            Colors.transparent,
          ],
        ).createShader(rect)
        ..blendMode = BlendMode.plus
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(
      center,
      10 * alpha,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55 * alpha)
        ..blendMode = BlendMode.plus
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  @override
  bool shouldRepaint(_GlintPainter old) =>
      old.alpha != alpha || old.center != center;
}

/// HEADS / TAILS stamped in engraved gold over the reveal push-in.
class _ResultStamp extends StatelessWidget {
  const _ResultStamp({required this.result, required this.progress});
  final CoinSide result;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scale = 1.15 - 0.15 * Curves.easeOutCubic.transform(progress);
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, -0.45),
        child: Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: progress.clamp(0.0, 1.0),
            child: Text(
              result == CoinSide.heads ? 'HEADS' : 'TAILS',
              style: text.displayLarge?.copyWith(
                shadows: const [
                  Shadow(color: Colors.black87, blurRadius: 24),
                  Shadow(color: Color(0x88E8A54B), blurRadius: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Title + prompt + result overlay (idle / quick-toss / after the scene).
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
                      'TAP — CALL IT',
                      key: const ValueKey('idle'),
                      style: text.bodyMedium?.copyWith(letterSpacing: 4),
                    ),
                  _ => const SizedBox(key: ValueKey('flip'), height: 24),
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
            Text('SETTINGS', style: text.titleLarge?.copyWith(fontSize: 18)),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.brass,
              title: Text('Cinematic scene', style: text.bodyMedium),
              subtitle: Text('The full Wager — tap mid-scene to skip',
                  style: text.bodyMedium?.copyWith(
                      fontSize: 12,
                      color: AppColors.smoke.withValues(alpha: 0.6))),
              value: s.cinematic,
              onChanged: (v) => setState(() => s.cinematic = v),
            ),
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
