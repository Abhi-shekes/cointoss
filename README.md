# Coin Toss

A Flutter app that turns a coin flip into a short cinematic moment: a Blender-rendered 3D coin toss film ("The Wager"), full-screen and portrait-optimized, followed by a photoreal minted-coin result — with haptic feedback and sound instead of a plain heads/tails popup.

## Tech Stack

- Flutter (Dart)
- `flutter_animate` — result/transition animations
- `audioplayers` — toss/land sound effects
- `vibration` — haptic feedback on landing
- `google_fonts`

## How It Works

The entire app is a single scene (`lib/scenes/toss_scene.dart`): tap to toss, the pre-rendered coin film plays full-screen, and the result (heads/tails) resolves with matching audio and haptics. Playback is tuned specifically for smooth full-screen video on low-end devices.

## Project Structure

```
lib/
  main.dart          # App entry, immersive full-screen mode
  scenes/
    toss_scene.dart  # The toss flow: play film -> resolve -> result
  theme/              # App theming
  widgets/            # Shared UI
  audio/              # Sound playback helpers
assets/
  coin/               # Coin toss video/render assets
  audio/               # Toss/land sound effects
  icon/                # App icon + splash assets
  store/               # Store listing assets
```

## Getting Started

```bash
flutter pub get
flutter run
```

### Release build

```bash
flutter build appbundle --release   # Android
```

App icon and splash screen are generated from `assets/icon/` via `flutter_launcher_icons` and `flutter_native_splash` — regenerate after changing them:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```
