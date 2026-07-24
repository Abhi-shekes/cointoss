import 'package:audioplayers/audioplayers.dart';

/// Toss sound effects. Every call is wrapped so the app runs
/// silently-but-cleanly if an asset is missing.
class SoundEngine {
  SoundEngine._();
  static final SoundEngine instance = SoundEngine._();

  final AudioPlayer _ambient = AudioPlayer(playerId: 'ambient');
  final AudioPlayer _sfx = AudioPlayer(playerId: 'sfx');

  bool muted = false;

  Future<void> startAmbient() async {
    if (muted) return;
    try {
      await _ambient.setReleaseMode(ReleaseMode.loop);
      await _ambient.setVolume(0.35);
      await _ambient.play(AssetSource('audio/ambient_bar.wav'));
    } catch (_) {/* asset not present yet */}
  }

  Future<void> stopAmbient() async {
    try {
      await _ambient.stop();
    } catch (_) {/* nothing playing */}
  }

  Future<void> whoosh() => _play(_sfx, 'audio/whoosh.wav', volume: 0.8);
  Future<void> clink() => _play(_sfx, 'audio/clink.wav', volume: 1.0);
  Future<void> reveal() => _play(_sfx, 'audio/reveal.wav', volume: 0.9);

  Future<void> _play(AudioPlayer p, String asset, {double volume = 1.0}) async {
    if (muted) return;
    try {
      await p.stop();
      await p.setVolume(volume);
      await p.play(AssetSource(asset));
    } catch (_) {/* asset not present yet */}
  }

  void dispose() {
    _ambient.dispose();
    _sfx.dispose();
  }
}
