# CI / Release automation

`.github/workflows/release.yml` runs on every push to `main` (and can be run
manually from the **Actions** tab). It:

1. Sets up JDK 17 + Flutter 3.35.7
2. Restores the signing keystore from repo **secrets**
3. Builds a **release APK** and **release AAB**
4. Publishes a **GitHub Release** tagged `v<version>-build.<run#>` with both files
   attached (auto-generated release notes)

## Required GitHub secrets

The signing keystore never lives in git. It's stored as four Actions secrets:

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | base64 of `android/app/upload-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | store password |
| `ANDROID_KEY_PASSWORD` | key password |
| `ANDROID_KEY_ALIAS` | key alias (`upload`) |

Set them all at once from your local signing config:

```bash
gh auth login                       # once
scripts/setup-github-secrets.sh     # reads android/key.properties + the .jks
```

Or manually: Repo → Settings → Secrets and variables → Actions → New secret.
Get the keystore blob with `base64 -w0 android/app/upload-keystore.jks`.

## Cutting a release

Bump `version:` in `pubspec.yaml` (e.g. `1.0.1+2`), commit, and push to `main`.
The workflow tags and publishes automatically. Download `CoinToss-<version>.aab`
from the Release and upload it to the Play Console; the `.apk` is for sideloading.

> ⚠️ The starter keystore uses a placeholder password (`cointoss123`). Rotate it
> to your own before real releases and update both the local `key.properties`
> and the GitHub secrets (re-run the script). Keep `upload-keystore.jks` backed
> up — see `RELEASE.md`.
