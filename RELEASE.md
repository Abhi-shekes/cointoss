# Coin Toss — Release Guide

Paid Android app (₹100). No login, no database, no network — nothing is stored
or transmitted. Single cinematic coin-flip screen.

- **applicationId:** `com.abhishektiwari.cointoss`
- **App name:** Coin Toss
- **Version:** bump `version:` in `pubspec.yaml` (e.g. `1.0.0+1`) before each release.
  The `+N` build number must increase for every Play upload.

## Building

```bash
# Play Store bundle (upload this):
flutter build appbundle --release     # -> build/app/outputs/bundle/release/app-release.aab

# Installable APK for sideload testing:
flutter build apk --release           # -> build/app/outputs/flutter-apk/app-release.apk
```

Both are signed with the upload key (see below). The AAB is ~45 MB but Play
delivers ~15 MB per device (per-ABI split); the universal APK is larger because
it bundles every CPU ABI.

## ⚠️ Signing keystore — READ THIS

Release signing is configured in `android/app/build.gradle.kts`, reading
`android/key.properties`. I generated a starter keystore so builds work:

- Keystore: `android/app/upload-keystore.jks`
- `key.properties` password (placeholder): `cointoss123`, alias `upload`

**Before you publish:**
1. **Back up `upload-keystore.jks` and `key.properties` somewhere safe.** If you
   enroll in **Play App Signing** (recommended, default for new apps), this is
   your *upload* key — if lost, Google can reset it. If you DON'T use Play App
   Signing, losing this key means you can never update the app.
2. Consider regenerating with your own strong password:
   ```bash
   keytool -genkeypair -v -keystore android/app/upload-keystore.jks \
     -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
   then update `android/key.properties`.
3. **Never commit** `key.properties` or `*.jks` if you put this in git. Add to
   `.gitignore`:
   ```
   android/key.properties
   android/app/*.jks
   ```

## Play Console submission checklist

- [ ] Create app in Play Console → set as **Paid**, price ₹100 (needs a payments
      profile / merchant account).
- [ ] Upload `app-release.aab`.
- [ ] **Data safety form:** declare *no data collected, no data shared* (true here).
- [ ] **Privacy policy URL:** Play requires one even for no-data apps. A one-page
      "we collect nothing" policy is enough.
- [ ] Store listing: short + full description, app icon (auto from bundle),
      **feature graphic** (1024×500), and **2–8 phone screenshots**.
- [ ] Content rating questionnaire.
- [ ] Target audience & ads declaration (no ads).

## Assets / tools

Regenerate any art with the scripts in `tools/`:
- `gen_placeholder_frames.py` — procedural coin frames (interim)
- `render_coin.py` — **Blender** photoreal coin (drop-in upgrade, same filenames)
- `gen_audio.py` — synthesized SFX
- `gen_icon.py` — launcher icon + splash art
- `make_preview.py` — preview.gif
