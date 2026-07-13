import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'scenes/film_scene.dart';
import 'scenes/toss_scene.dart';
import 'settings.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final film = await filmAvailable();
  runApp(CoinTossApp(filmAvailable: film));
}

class CoinTossApp extends StatelessWidget {
  const CoinTossApp({super.key, required this.filmAvailable});

  /// Whether the Blender-rendered film segments are bundled in this build.
  final bool filmAvailable;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Coin Toss',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      // Film cutscene when the footage is bundled and cinematic mode is on;
      // otherwise the real-time scene (which also hosts the quick toss).
      home: ListenableBuilder(
        listenable: Settings.instance,
        builder: (_, __) => filmAvailable && Settings.instance.cinematic
            ? const FilmScene()
            : const TossScene(),
      ),
    );
  }
}
