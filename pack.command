#!/bin/bash
# macOS pack for 统一用户身份管理系统（UUIMS） client (double-click or run from client root).
# Builds: macos + iOS tablet + Android tablet. Does not build web.
# Linux/WSL → ./pack.sh   |   Windows → .\pack.ps1
#
#   ./pack.command
#   ./pack.command --skip-macos
#   ./pack.command --skip-ios
#   ./pack.command --skip-android

cd "$(dirname "$0")" || exit 1
set -euo pipefail

SKIP_MACOS=0
SKIP_IOS=0
SKIP_ANDROID=0
# NOTE: do not write ${VAR:-https://{host}} — bash ends the default at the first '}'
# which corrupts it to http://{host:21000}.
_DEFAULT_API_BASE_URL='https://{host}'
API_BASE_URL="${API_BASE_URL:-$_DEFAULT_API_BASE_URL}"

die() { echo "$*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-macos) SKIP_MACOS=1; shift ;;
    --skip-ios) SKIP_IOS=1; shift ;;
    --skip-android) SKIP_ANDROID=1; shift ;;
    --android) SKIP_ANDROID=0; shift ;;
    --api-base-url) API_BASE_URL="$2"; shift 2 ;;
    --skip-web|--web|--base-href)
      die "已不再构建 web。本脚本只构建 macos、iOS 平板与 Android 平板。"
      ;;
    --windows|--linux)
      die "请在对应系统执行: Windows → .\\pack.ps1；Linux/WSL → ./pack.sh（本脚本 pack.command 只构建 macos / iOS 平板 / Android 平板）"
      ;;
    --flutter-version)
      die "不要传 --flutter-version；请在 .fvmrc 中固定版本"
      ;;
    -h|--help)
      sed -n '2,14p' "$0"
      exit 0
      ;;
    *) die "unknown arg: $1" ;;
  esac
done

export FLUTTER_STORAGE_BASE_URL="${FLUTTER_STORAGE_BASE_URL:-https://storage.flutter-io.cn}"
export PUB_HOSTED_URL="${PUB_HOSTED_URL:-https://pub.flutter-io.cn}"

CLIENT_ROOT="$(pwd)"
DIST_DIR="$CLIENT_ROOT/dist"

step() { printf '\n==> %s\n' "$*"; }

find_android_sdk() {
  local d
  for d in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" "$HOME/Library/Android/sdk" "$HOME/Android/Sdk"; do
    [[ -n "$d" && -d "$d/platform-tools" ]] && printf '%s\n' "$d" && return 0
  done
  return 1
}

command -v fvm >/dev/null || die "未找到 macOS fvm，请先安装 https://fvm.app"
echo "fvm=$(command -v fvm) $(fvm --version 2>/dev/null || true)"

[[ -f "$CLIENT_ROOT/.fvmrc" ]] || die "缺少 .fvmrc，请先固定 Flutter 版本"
PINNED="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["flutter"])' "$CLIENT_ROOT/.fvmrc")"
echo ".fvmrc flutter=$PINNED"

step "fvm use .fvmrc ($PINNED) — no auto-install"
SDK_OK=0
for d in \
  "${FVM_CACHE_PATH:-$HOME/fvm}/versions/$PINNED" \
  "$HOME/fvm/versions/$PINNED" \
  "$HOME/Library/Application Support/fvm/versions/$PINNED"
do
  if [[ -x "$d/bin/flutter" ]]; then SDK_OK=1; echo "SDK=$d"; break; fi
done
if [[ "$SDK_OK" -eq 0 ]]; then
  die "Flutter $PINNED 未安装，打包已中断。
请先手动安装: fvm install $PINNED
查看已安装版本: fvm list"
fi

fvm use "$PINNED" --force
fvm flutter --version

if [[ "$SKIP_MACOS" -eq 0 ]]; then
  step "fvm flutter build macos"
  fvm flutter pub get
  fvm flutter build macos --release
  APP=""
  for c in \
    "$CLIENT_ROOT/build/macos/Build/Products/Release"/*.app \
    "$CLIENT_ROOT/build/macos/Build/Products/Release"
  do
    # shellcheck disable=SC2086
    for hit in $c; do
      [[ -e "$hit" ]] && APP="$hit" && break 2
    done
  done
  [[ -n "$APP" ]] || die "macos .app 未找到"
  mkdir -p "$DIST_DIR"
  ZIP="$DIST_DIR/uuims-pc-macos.zip"
  rm -f "$ZIP"
  step "Zip -> $ZIP"
  ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
  echo "OK $ZIP"
else
  echo "Skip macos"
fi

if [[ "$SKIP_IOS" -eq 0 ]]; then
  if [[ ! -d "$CLIENT_ROOT/ios" ]]; then
    echo "Skip iOS tablet（缺少 ios/ 平台目录）" >&2
  elif ! command -v xcodebuild >/dev/null; then
    echo "Skip iOS tablet（未找到 Xcode / xcodebuild）" >&2
  else
    step "fvm flutter build ios --no-codesign (iPad only)"
    fvm flutter pub get
    fvm flutter build ios --release --no-codesign --dart-define="API_BASE_URL=$API_BASE_URL"
    APP=""
    for c in \
      "$CLIENT_ROOT/build/ios/iphoneos"/*.app \
      "$CLIENT_ROOT/build/ios/Release-iphoneos"/*.app
    do
      for hit in $c; do
        [[ -e "$hit" ]] && APP="$hit" && break 2
      done
    done
    [[ -n "$APP" ]] || die "iOS .app 未找到（未签名构建）"
    mkdir -p "$DIST_DIR"
    ZIP="$DIST_DIR/uuims-ios-tablet.zip"
    rm -f "$ZIP"
    step "Zip (unsigned iPad .app) -> $ZIP"
    ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
    echo "OK $ZIP"
    echo "Note: 未签名，真机/TestFlight 需在 Xcode 中签名后再出 IPA。"
  fi
else
  echo "Skip iOS tablet"
fi

if [[ "$SKIP_ANDROID" -eq 0 ]]; then
  if [[ ! -d "$CLIENT_ROOT/android" ]]; then
    echo "Skip Android tablet（缺少 android/ 平台目录）" >&2
  elif ! ANDROID_SDK="$(find_android_sdk)"; then
    echo "Skip Android tablet（未找到 Android SDK。请安装 SDK 并设置 ANDROID_HOME 或 ANDROID_SDK_ROOT）" >&2
  else
    export ANDROID_HOME="${ANDROID_HOME:-$ANDROID_SDK}"
    export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_SDK}"
    echo "ANDROID_SDK=$ANDROID_SDK"
    step "fvm flutter build apk (Android tablet)"
    fvm flutter pub get
    fvm flutter build apk --release --dart-define="API_BASE_URL=$API_BASE_URL"
    APK="$CLIENT_ROOT/build/app/outputs/flutter-apk/app-release.apk"
    [[ -f "$APK" ]] || die "missing $APK"
    mkdir -p "$DIST_DIR"
    cp -f "$APK" "$DIST_DIR/uuims-android-tablet.apk"
    echo "OK $DIST_DIR/uuims-android-tablet.apk"
  fi
else
  echo "Skip Android tablet"
fi

printf '\nDone (macOS pack.command, .fvmrc=%s). Targets: macos + ios tablet + android tablet (no web).\n' "$PINNED"
