#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="${PROJECT_PATH:-$ROOT_DIR/Voltly.xcodeproj}"
SCHEME="${SCHEME:-VoltlyiOS}"
APP_NAME="${APP_NAME:-Voltly}"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 16e}"
SIMULATOR_UDID="${SIMULATOR_UDID:-}"
BUNDLE_ID="${BUNDLE_ID:-}"
SKIP_BUILD="${SKIP_BUILD:-0}"
ERASE_ON_RECOVERY="${ERASE_ON_RECOVERY:-1}"

log() {
  echo "[sim-safe] $*"
}

fail() {
  echo "[sim-safe][error] $*" >&2
  exit 1
}

resolve_simulator_udid() {
  if [[ -n "$SIMULATOR_UDID" ]]; then
    return 0
  fi

  SIMULATOR_UDID="$(
    xcrun simctl list devices available | awk -v name="$SIMULATOR_NAME" '
      index($0, name " (") > 0 {
        if (match($0, /\(([0-9A-F-]+)\)/)) {
          print substr($0, RSTART + 1, RLENGTH - 2)
          exit
        }
      }'
  )"

  if [[ -z "$SIMULATOR_UDID" ]]; then
    SIMULATOR_UDID="$(
      xcrun simctl list devices | awk '
        index($0, "(Booted)") > 0 {
          if (match($0, /\(([0-9A-F-]+)\)/)) {
            print substr($0, RSTART + 1, RLENGTH - 2)
            exit
          }
        }'
    )"
  fi

  [[ -n "$SIMULATOR_UDID" ]] || fail "Simulator bulunamadi. SIMULATOR_NAME veya SIMULATOR_UDID ver."
}

build_app_if_needed() {
  [[ "$SKIP_BUILD" == "1" ]] && return 0

  log "Build basliyor: scheme=$SCHEME simulator=$SIMULATOR_UDID"
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -destination "id=$SIMULATOR_UDID" \
    build >/tmp/voltly_sim_safe_build.log 2>&1
  log "Build tamamlandi. Log: /tmp/voltly_sim_safe_build.log"
}

resolve_app_path() {
  local latest_derived

  latest_derived="$(ls -td "$HOME"/Library/Developer/Xcode/DerivedData/Voltly-* 2>/dev/null | head -n1 || true)"
  if [[ -n "$latest_derived" ]]; then
    APP_PATH="$latest_derived/Build/Products/Debug-iphonesimulator/${APP_NAME}.app"
  fi

  if [[ -z "${APP_PATH:-}" || ! -d "$APP_PATH" ]]; then
    APP_PATH="$(find "$HOME/Library/Developer/Xcode/DerivedData" -type d -path "*/Build/Products/Debug-iphonesimulator/${APP_NAME}.app" -print 2>/dev/null | head -n1 || true)"
  fi

  [[ -n "${APP_PATH:-}" && -d "$APP_PATH" ]] || fail "App bundle bulunamadi (${APP_NAME}.app)."
}

resolve_bundle_id() {
  if [[ -n "$BUNDLE_ID" ]]; then
    return 0
  fi

  BUNDLE_ID="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP_PATH/Info.plist" 2>/dev/null || true)"
  [[ -n "$BUNDLE_ID" ]] || fail "CFBundleIdentifier okunamadi. BUNDLE_ID env ile ver."
}

boot_if_needed() {
  if ! xcrun simctl list devices | grep -q "$SIMULATOR_UDID) (Booted)"; then
    log "Simulator boot ediliyor: $SIMULATOR_UDID"
    xcrun simctl boot "$SIMULATOR_UDID"
    xcrun simctl bootstatus "$SIMULATOR_UDID" -b
  fi
}

install_and_launch() {
  log "Install: $APP_PATH"
  xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"
  log "Launch: $BUNDLE_ID"
  xcrun simctl launch --terminate-running-process "$SIMULATOR_UDID" "$BUNDLE_ID"
}

recover_simulator() {
  log "CoreSimulator servisi resetleniyor"
  pkill -x com.apple.CoreSimulator.CoreSimulatorService || true
  xcrun simctl shutdown "$SIMULATOR_UDID" || true

  if [[ "$ERASE_ON_RECOVERY" == "1" ]]; then
    log "Cihaz erase ediliyor: $SIMULATOR_UDID"
    xcrun simctl erase "$SIMULATOR_UDID"
  fi

  xcrun simctl boot "$SIMULATOR_UDID"
  xcrun simctl bootstatus "$SIMULATOR_UDID" -b
}

main() {
  command -v xcodebuild >/dev/null 2>&1 || fail "xcodebuild bulunamadi."
  command -v xcrun >/dev/null 2>&1 || fail "xcrun bulunamadi."

  resolve_simulator_udid
  build_app_if_needed
  resolve_app_path
  resolve_bundle_id

  log "Target simulator: $SIMULATOR_UDID"
  log "Bundle id: $BUNDLE_ID"
  boot_if_needed

  set +e
  install_and_launch
  local launch_status=$?
  set -e

  if [[ "$launch_status" -eq 0 ]]; then
    log "Uygulama basariyla acildi."
    exit 0
  fi

  log "Ilk launch denemesi basarisiz. Otomatik recovery deneniyor..."
  recover_simulator
  install_and_launch
  log "Uygulama recovery sonrasi basariyla acildi."
}

main "$@"
