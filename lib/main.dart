import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'scenes/toss_scene.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const CoinTossApp());
}

class CoinTossApp extends StatelessWidget {
  const CoinTossApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Coin Toss',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const TossScene(),
    );
  }
}
