#!/usr/bin/env bash
# Build release artifacts for Google Play and App Store.
# Usage:
#   export SUPABASE_URL="https://YOUR_PROJECT.supabase.co"
#   export SUPABASE_ANON_KEY="your_anon_key"
#   ./scripts/build_release.sh

set -euo pipefail
cd "$(dirname "$0")/.."

DART_DEFINES=()
if [[ -n "${SUPABASE_URL:-}" ]]; then
  DART_DEFINES+=(--dart-define=SUPABASE_URL="$SUPABASE_URL")
fi
if [[ -n "${SUPABASE_ANON_KEY:-}" ]]; then
  DART_DEFINES+=(--dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY")
fi

echo "==> flutter pub get"
flutter pub get

echo "==> Android App Bundle (Play Store)"
flutter build appbundle --release "${DART_DEFINES[@]}"

echo "==> Android APK (optional sideload)"
flutter build apk --release "${DART_DEFINES[@]}"

echo "==> iOS (requires macOS + Xcode signing)"
flutter build ipa --release "${DART_DEFINES[@]}"

echo ""
echo "Done."
echo "  AAB: build/app/outputs/bundle/release/app-release.aab"
echo "  APK: build/app/outputs/flutter-apk/app-release.apk"
echo "  IPA: build/ios/ipa/*.ipa"
