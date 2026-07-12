import 'package:audioplayers/audioplayers.dart';

/// Layered cinematic audio. Assets are added in Phase 4; every call is
/// wrapped so the app runs silently-but-cleanly until they exist.
class SoundEngine {
  SoundEngine._();
  static final SoundEngine instance = SoundEngine._();

  final AudioPlayer _ambient = AudioPlayer(playerId: 'ambient');
  final AudioPlayer _sfx = AudioPlayer(playerId: 'sfx');
  final AudioPlayer _fx2 = AudioPlayer(playerId: 'fx2'); // parallel one-shots
  final AudioPlayer _layer = AudioPlayer(playerId: 'layer'); // apex bed

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

  /// Ducks the room bed while time dilates, restores it after.
  Future<void> duckAmbient(bool duck) async {
    try {
      await _ambient.setVolume(duck ? 0.12 : 0.35);
    } catch (_) {/* nothing playing */}
  }

  Future<void> whoosh() => _play(_sfx, 'audio/whoosh.wav', volume: 0.8);
  Future<void> clink() => _play(_sfx, 'audio/clink.wav', volume: 1.0);
  Future<void> reveal() => _play(_sfx, 'audio/reveal.wav', volume: 0.9);
  Future<void> ting() => _play(_sfx, 'audio/ting.wav', volume: 0.9);
  Future<void> thunder() => _play(_fx2, 'audio/thunder.wav', volume: 0.7);
  Future<void> sting() => _play(_fx2, 'audio/sting.wav', volume: 0.9);

  /// Sub-drone + heartbeat that carries the slow-motion apex.
  Future<void> apexStart() async {
    if (muted) return;
    try {
      await _layer.setReleaseMode(ReleaseMode.loop);
      await _layer.setVolume(0.85);
      await _layer.play(AssetSource('audio/apex.wav'));
    } catch (_) {/* asset not present yet */}
  }

  Future<void> apexStop() async {
    try {
      await _layer.stop();
    } catch (_) {/* nothing playing */}
  }

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
    _fx2.dispose();
    _layer.dispose();
  }
}
