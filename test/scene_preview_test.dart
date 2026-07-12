// Renders "The Wager" at key timecodes and writes PNGs to build/preview/.
// Skipped in normal runs; generate frames with:
//
//   flutter test --dart-define=PREVIEW=true test/scene_preview_test.dart
//
// This is a look-dev tool, not a correctness test.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:cointoss/scenes/toss_scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Silences the audioplayers/vibration platform channels, which have no
/// implementation under flutter_test.
void _mockPlugins(WidgetTester tester) {
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'), (_) async => 1);
  messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'), (_) async => 1);
  messenger.setMockMethodCallHandler(
      const MethodChannel('vibration'), (_) async => false);
  final silent = MockStreamHandler.inline(onListen: (_, __) {});
  messenger.setMockStreamHandler(
      const EventChannel('xyz.luan/audioplayers.global/events'), silent);
  for (final id in ['ambient', 'sfx', 'fx2', 'layer']) {
    messenger.setMockStreamHandler(
        EventChannel('xyz.luan/audioplayers/events/$id'), silent);
  }
}

const _preview = bool.fromEnvironment('PREVIEW');

// Timecodes matched to the shot list in toss_scene.dart.
const _shots = <String, double>{
  'idle': -1, // before the tap
  '1_establish': 1.0,
  '2_faces': 3.1,
  '3_the_set': 4.9,
  '4_flick': 5.6,
  '5_apex': 7.6,
  '6_drop': 9.85,
  '7_slam': 10.18,
  '8_reveal': 11.4,
};

void main() {
  testWidgets('render shot frames', (tester) async {
    _mockPlugins(tester);
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final outDir = Directory('build/preview')..createSync(recursive: true);

    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          // Plain dark theme: google_fonts can't fetch in tests, and these
          // previews are for composition, not typography.
          theme: ThemeData.dark(useMaterial3: true),
          debugShowCheckedModeBanner: false,
          home: const RepaintBoundary(
            key: ValueKey('scene'),
            child: TossScene(),
          ),
        ),
      );
      // Let the coin frame assets decode.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await tester.pump();

      Future<void> snap(String name) async {
        await tester.pump();
        final boundary = tester
            .renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('scene')));
        final image = await boundary.toImage(pixelRatio: 1.0);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${outDir.path}/$name.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      }

      var elapsed = -1.0;
      for (final entry in _shots.entries) {
        if (entry.value < 0) {
          await snap(entry.key);
          continue;
        }
        if (elapsed < 0) {
          await tester.tap(find.byType(TossScene));
          // Anchor frame: the controller's ticker sets its epoch on the
          // first tick, so pump once before advancing the clock.
          await tester.pump();
          elapsed = 0;
        }
        final delta = entry.value - elapsed;
        await tester.pump(Duration(milliseconds: (delta * 1000).round()));
        elapsed = entry.value;
        await snap(entry.key);
      }

      // Finish the scene so no animations are mid-flight at teardown.
      await tester.pump(const Duration(seconds: 3));
    });
    await tester.pumpWidget(const SizedBox.shrink());
  }, skip: !_preview);
}
