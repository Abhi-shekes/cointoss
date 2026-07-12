import 'package:flutter/foundation.dart';
import 'audio/sound_engine.dart';

/// In-memory settings (no persistence — the app stores nothing on disk).
/// Resets to defaults each launch, which is fine for a single-screen toy.
class Settings extends ChangeNotifier {
  Settings._();
  static final Settings instance = Settings._();

  bool _sound = true;
  bool _haptics = true;
  bool _cinematic = true;

  bool get sound => _sound;
  bool get haptics => _haptics;

  /// Full ~13 s "The Wager" cutscene vs. the ~3 s quick toss.
  bool get cinematic => _cinematic;

  set cinematic(bool v) {
    _cinematic = v;
    notifyListeners();
  }

  set sound(bool v) {
    _sound = v;
    SoundEngine.instance.muted = !v;
    if (v) {
      SoundEngine.instance.startAmbient();
    } else {
      SoundEngine.instance.stopAmbient();
    }
    notifyListeners();
  }

  set haptics(bool v) {
    _haptics = v;
    notifyListeners();
  }
}
