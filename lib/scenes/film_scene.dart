import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:vibration/vibration.dart';
import 'package:video_player/video_player.dart';
import '../audio/sound_engine.dart';
import '../settings.dart';
import '../theme/app_theme.dart';
import '../widgets/atmosphere.dart';
import '../widgets/cinema.dart';
import '../widgets/sparks.dart';

/// "The Wager" as an actual film: Blender-rendered, ray-traced segments
/// played back gaplessly. `intro.mp4` (11.5 s, shared) runs from the crane
/// shot to the top of the drop; the result — decided at tap — picks
/// `end_heads.mp4` or `end_tails.mp4` (4.5 s: drop, slam, macro reveal).
/// Grain, titles, sparks, haptics and the audio cue track stay live in
/// Flutter on top of the footage.
///
/// Timing map (24 fps): flick at 7.0 s into the intro; in the endings the
/// slam lands at 0.58 s.

/// True when the film segments are bundled in this build.
Future<bool> filmAvailable() async {
  try {
    await rootBundle.load('assets/film/intro.mp4');
    return true;
  } catch (_) {
    return false;
  }
}

enum FilmPhase { loading, idle, intro, ending, revealed }

class FilmScene extends StatefulWidget {
  const FilmScene({super.key});

  @override
  State<FilmScene> createState() => _FilmSceneState();
}

class _FilmSceneState extends State<FilmScene>
    with SingleTickerProviderStateMixin {
  late final VideoPlayerController _intro;
  late final VideoPlayerController _endHeads;
  late final VideoPlayerController _endTails;
  late final AnimationController _shake;
  final List<Timer> _cues = [];
  final _rnd = math.Random();

  FilmPhase _phase = FilmPhase.loading;
  bool _heads = true;
  double _stamp = 0;
  int _tossCount = 0;

  VideoPlayerController get _ending => _heads ? _endHeads : _endTails;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _intro = VideoPlayerController.asset('assets/film/intro.mp4');
    _endHeads = VideoPlayerController.asset('assets/film/end_heads.mp4');
    _endTails = VideoPlayerController.asset('assets/film/end_tails.mp4');
    _init();
    SoundEngine.instance.startAmbient();
  }

  Future<void> _init() async {
    await Future.wait(
        [_intro.initialize(), _endHeads.initialize(), _endTails.initialize()]);
    _intro.addListener(_onIntroTick);
    _endHeads.addListener(_onEndingTick);
    _endTails.addListener(_onEndingTick);
    if (mounted) setState(() => _phase = FilmPhase.idle);
  }

  @override
  void dispose() {
    _clearCues();
    _intro.dispose();
    _endHeads.dispose();
    _endTails.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _clearCues() {
    for (final t in _cues) {
      t.cancel();
    }
    _cues.clear();
  }

  void _cue(double seconds, void Function() fn) {
    _cues.add(
        Timer(Duration(milliseconds: (seconds * 1000).round()), () {
      if (mounted) fn();
    }));
  }

  // ------------------------------------------------------------- playback

  void _onIntroTick() {
    if (_phase != FilmPhase.intro) return;
    final v = _intro.value;
    if (v.isInitialized &&
        v.position >= v.duration - const Duration(milliseconds: 45)) {
      _startEnding();
    }
  }

  void _onEndingTick() {
    if (_phase != FilmPhase.ending) return;
    final v = _ending.value;
    if (v.isInitialized &&
        v.position >= v.duration - const Duration(milliseconds: 30)) {
      _intro.pause();
      setState(() => _phase = FilmPhase.revealed);
    }
  }

  void _toss() {
    _heads = _rnd.nextBool();
    _tossCount++;
    _stamp = 0;
    _clearCues();
    _intro.seekTo(Duration.zero);
    _ending.seekTo(Duration.zero);
    setState(() => _phase = FilmPhase.intro);
    _intro.play();

    final s = SoundEngine.instance;
    s.duckAmbient(true);
    _cue(0.1, s.thunder);
    _cue(6.9, s.ting);
    _cue(7.05, s.whoosh);
    _cue(7.4, s.apexStart);
  }

  void _startEnding() {
    _clearCues();
    _intro.pause();
    setState(() => _phase = FilmPhase.ending);
    _ending.play();

    final s = SoundEngine.instance;
    s.apexStop();
    _cue(0.58, _slam);
    _cue(1.35, s.sting);
    _cue(1.6, () => setState(() => _stamp = 1));
    _cue(3.2, () => s.duckAmbient(false));
  }

  Future<void> _slam() async {
    SoundEngine.instance.clink();
    _shake.forward(from: 0);
    if (Settings.instance.haptics && await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 55, amplitude: 180);
    }
  }

  void _onTap() {
    switch (_phase) {
      case FilmPhase.intro:
        _startEnding(); // skip straight to the drop — the verdict still lands
      case FilmPhase.idle || FilmPhase.revealed:
        _toss();
      case FilmPhase.loading || FilmPhase.ending:
        return;
    }
  }

  // --------------------------------------------------------------- layout

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final playing = _phase == FilmPhase.intro || _phase == FilmPhase.ending;
    final active = _phase == FilmPhase.ending || _phase == FilmPhase.revealed
        ? _ending
        : _intro;

    return GestureDetector(
      onTap: _onTap,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: AnimatedBuilder(
          animation: _shake,
          builder: (context, _) {
            final shakeAmt = (1 - _shake.value) *
                math.sin(_shake.value * math.pi * 7) *
                8;
            return Stack(
              fit: StackFit.expand,
              children: [
                // The film band — 2.39:1 footage cover-fit into a wide
                // window, cinema black above and below.
                Center(
                  child: Transform.translate(
                    offset: Offset(shakeAmt, shakeAmt * 0.4),
                    child: SizedBox(
                      width: size.width,
                      height: size.height * 0.44,
                      child: _phase == FilmPhase.loading
                          ? const ColoredBox(color: Colors.black)
                          : ClipRect(
                              child: FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: active.value.size.width,
                                  height: active.value.size.height,
                                  child: VideoPlayer(active),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
                Sparks(progress: _shake.value, seed: _tossCount),
                const ColorGrade(strength: 0.5),
                const Vignette(strength: 0.7),
                const FilmGrain(),
                GoldStamp(
                  text: _heads ? 'HEADS' : 'TAILS',
                  progress: _stamp,
                  alignment: const Alignment(0, 0.42),
                ),
                if (!playing) _Hud(phase: _phase, heads: _heads),
                if (!playing) _SettingsButton(onTap: _openSettings),
              ],
            );
          },
        ),
      ),
    );
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141418),
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const SettingsSheet(),
    );
  }
}

/// Title + prompt + result overlay around the idle/revealed film frame.
class _Hud extends StatelessWidget {
  const _Hud({required this.phase, required this.heads});
  final FilmPhase phase;
  final bool heads;

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
              switch (phase) {
                FilmPhase.revealed => Column(
                    children: [
                      Text(heads ? 'HEADS' : 'TAILS',
                          style: text.displayLarge),
                      const SizedBox(height: 8),
                      Text('TAP TO TOSS AGAIN', style: text.bodyMedium),
                    ],
                  ),
                FilmPhase.idle => Text(
                    'TAP — CALL IT',
                    style: text.bodyMedium?.copyWith(letterSpacing: 4),
                  ),
                _ => const SizedBox(height: 24),
              },
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

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

/// Shared settings sheet (film + realtime scenes).
class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
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
