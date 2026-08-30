#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT_DIR/Voltly.xcodeproj"
APP_SCHEME="VoltlyiOS"
WIDGET_SCHEME="VoltlyWidgetsExtension"

resolve_simulator_destination() {
  local preferred_name="${QA_SIMULATOR_NAME:-iPhone 16}"
  local destinations
  local fallback_name

  destinations="$(xcodebuild -project "$PROJECT" -scheme "$APP_SCHEME" -showdestinations 2>/dev/null || true)"
  if echo "$destinations" | grep -q "name:${preferred_name}[[:space:]]*}"; then
    SIMULATOR_NAME="$preferred_name"
    SIMULATOR_DESTINATION="platform=iOS Simulator,name=${SIMULATOR_NAME}"
    return 0
  fi

  fallback_name="$(echo "$destinations" | sed -n 's/.*name:\(iPhone[^,}]*\).*/\1/p' | head -n1 | sed 's/[[:space:]]*$//')"
  if [[ -n "$fallback_name" ]]; then
    SIMULATOR_NAME="$fallback_name"
    SIMULATOR_DESTINATION="platform=iOS Simulator,name=${SIMULATOR_NAME}"
    return 0
  fi

  SIMULATOR_NAME=""
  SIMULATOR_DESTINATION="generic/platform=iOS Simulator"
}

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild bulunamadi. Xcode yukleyip xcode-select ile secmelisin." >&2
  exit 1
fi

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "xcodebuild aktif degil. Tam Xcode yukleyip 'sudo xcode-select -s /Applications/Xcode.app' ile secmelisin." >&2
  exit 1
fi

if [[ ! -d "$PROJECT" ]]; then
  echo "Proje bulunamadi: $PROJECT" >&2
  exit 1
fi

resolve_simulator_destination
if [[ -n "$SIMULATOR_NAME" ]]; then
  echo "Simulator hedefi: $SIMULATOR_NAME"
else
  echo "Simulator hedefi bulunamadi, generic iOS Simulator kullanilacak."
fi

echo "[1/5] Schemes"
xcodebuild -list -project "$PROJECT"

echo "[2/5] App build (iOS Simulator)"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$APP_SCHEME" \
  -destination "$SIMULATOR_DESTINATION" \
  build

echo "[3/5] Widget build (iOS Simulator)"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$WIDGET_SCHEME" \
  -destination "$SIMULATOR_DESTINATION" \
  build

echo "[4/5] Archive sanity (generic iOS)"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$APP_SCHEME" \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  archive \
  -archivePath "$ROOT_DIR/.build/VoltlyiOS.xcarchive"

echo "[5/5] Smoke launch in simulator"
if [[ -n "$SIMULATOR_NAME" ]] && command -v xcrun >/dev/null 2>&1 && xcrun simctl list devices >/dev/null 2>&1; then
  SAFE_SCRIPT="$ROOT_DIR/scripts/run_simulator_safe.sh"
  if [[ -x "$SAFE_SCRIPT" ]]; then
    SKIP_BUILD=1 \
    PROJECT_PATH="$PROJECT" \
    SCHEME="$APP_SCHEME" \
    APP_NAME="Voltly" \
    SIMULATOR_NAME="$SIMULATOR_NAME" \
    ERASE_ON_RECOVERY="${QA_ERASE_ON_RECOVERY:-0}" \
    "$SAFE_SCRIPT"
  else
    RUNTIME_UDID="$(xcrun simctl list devices available | grep -F "$SIMULATOR_NAME (" | head -n1 | sed -E 's/.*\(([0-9A-F-]+)\).*/\1/')"
    if [[ -n "${RUNTIME_UDID:-}" ]]; then
      if ! xcrun simctl list devices | grep -q "$RUNTIME_UDID) (Booted)"; then
        xcrun simctl boot "$RUNTIME_UDID" || true
      fi
      APP_PATH="$(find "$ROOT_DIR" -type d \( -path '*Build/Products/Debug-iphonesimulator/Voltly.app' -o -path '*Build/Products/Debug-iphonesimulator/VoltlyiOS.app' \) | head -n1)"
      if [[ -n "${APP_PATH:-}" ]]; then
        BUNDLE_ID="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP_PATH/Info.plist" 2>/dev/null || true)"
        [[ -n "$BUNDLE_ID" ]] || BUNDLE_ID="com.voltly.app"
        xcrun simctl install "$RUNTIME_UDID" "$APP_PATH"
        xcrun simctl launch "$RUNTIME_UDID" "$BUNDLE_ID" || true
      fi
    fi
  fi
fi

echo "QA script tamamlandi."
