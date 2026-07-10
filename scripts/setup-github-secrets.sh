#!/usr/bin/env bash
# Upload the local Android signing config to GitHub Actions secrets, so the
# release workflow can sign builds. Contains no secrets itself — it reads them
# from your local android/key.properties + upload-keystore.jks at runtime.
#
# Usage (after `gh auth login` and the repo exists):
#   scripts/setup-github-secrets.sh                 # uses the repo of the cwd
#   scripts/setup-github-secrets.sh owner/cointoss  # or target explicitly
set -euo pipefail
cd "$(dirname "$0")/.."

KS="android/app/upload-keystore.jks"
KP="android/key.properties"
[ -f "$KS" ] || { echo "Missing $KS"; exit 1; }
[ -f "$KP" ] || { echo "Missing $KP"; exit 1; }

prop() { grep "^$1=" "$KP" | cut -d= -f2-; }
REPO=()
[ "${1:-}" ] && REPO=(-R "$1")

base64 -w0 "$KS" | gh secret set ANDROID_KEYSTORE_BASE64 "${REPO[@]}"
gh secret set ANDROID_KEYSTORE_PASSWORD "${REPO[@]}" --body "$(prop storePassword)"
gh secret set ANDROID_KEY_PASSWORD      "${REPO[@]}" --body "$(prop keyPassword)"
gh secret set ANDROID_KEY_ALIAS         "${REPO[@]}" --body "$(prop keyAlias)"

echo "✓ Secrets set: ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_PASSWORD, ANDROID_KEY_ALIAS"
