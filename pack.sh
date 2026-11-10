#!/usr/bin/env bash
# Linux / WSL pack for 统一用户身份管理系统（UUIMS） client (run from client root).
# Builds: linux + Android tablet. Does not build web.
# Windows → .\pack.ps1   |   macOS → ./pack.command
#
#   ./pack.sh
#   ./pack.sh --skip-linux
#   ./pack.sh --skip-android

set -euo pipefail

DO_LINUX=1
DO_ANDROID=1
# NOTE: do not write ${VAR:-http://{host}:21000} — bash ends the default at the first '}'
# which corrupts it to http://{host:21000}.
_DEFAULT_API_BASE_URL='http://{host}:21000'
API_BASE_URL="${API_BASE_URL:-$_DEFAULT_API_BASE_URL}"

die() { echo "$*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --linux) DO_LINUX=1; shift ;;
    --skip-linux) DO_LINUX=0; shift ;;
    --android) DO_ANDROID=1; shift ;;
    --skip-android) DO_ANDROID=0; shift ;;
    --api-base-url) API_BASE_URL="$2"; shift 2 ;;
    --skip-web|--web|--base-href)
      die "已不再构建 web。本脚本只构建 linux 与 Android 平板。"
      ;;
    --windows|--skip-windows|-SkipWindows)
      die "Windows 请在 Windows 上执行: .\\pack.ps1（本脚本 pack.sh 只构建 linux / Android 平板）"
      ;;
    --macos|--osx|--ios|--skip-macos|--skip-ios)
      die "macOS / iOS 平板请在 macOS 上执行: ./pack.command"
      ;;
    --flutter-version)
      die "不要传 --flutter-version；请在 .fvmrc 中固定版本"
      ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *) die "unknown arg: $1" ;;
  esac
done

export FLUTTER_STORAGE_BASE_URL="${FLUTTER_STORAGE_BASE_URL:-https://storage.flutter-io.cn}"
export PUB_HOSTED_URL="${PUB_HOSTED_URL:-https://pub.flutter-io.cn}"

CLIENT_ROOT="$(cd "$(dirname "$0")" && pwd)"
DIST_DIR="$CLIENT_ROOT/dist"

step() { printf '\n==> %s\n' "$*"; }

# Refuse Windows fvm.exe wrappers (common leftover from older pack.sh).
resolve_linux_fvm() {
  local cand
  for cand in "$(command -v fvm 2>/dev/null || true)" /usr/local/bin/fvm "$HOME/.pub-cache/bin/fvm"; do
    [[ -n "$cand" && -x "$cand" ]] || continue
    if head -c 200 "$cand" 2>/dev/null | grep -qE 'fvm\.exe|/mnt/[a-z]/fvm'; then
      continue
    fi
    if file -b "$cand" 2>/dev/null | grep -qiE 'PE32|MS-DOS|Windows'; then
      continue
    fi
    # shell wrapper that only execs .exe
    if head -5 "$cand" 2>/dev/null | grep -q 'fvm\.exe'; then
      continue
    fi
    printf '%s\n' "$cand"
    return 0
  done
  return 1
}

find_android_sdk() {
  local d
  for d in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" "$HOME/Android/Sdk" /opt/android-sdk /opt/Android/Sdk; do
    [[ -n "$d" && -d "$d/platform-tools" ]] && printf '%s\n' "$d" && return 0
  done
  return 1
}

FVM_BIN="$(resolve_linux_fvm || true)"
if [[ -z "${FVM_BIN:-}" ]]; then
  cat >&2 <<'MSG'
未找到 Linux 版 fvm（当前 PATH 上的 fvm 若是 exec …/fvm.exe 的包装脚本，不能用于本脚本）。

请安装 Linux 版 fvm，例如:
  dart pub global activate fvm
  # 或 https://fvm.app/documentation/getting-started/installation

若 /usr/local/bin/fvm 是 Windows 包装，请删掉或移走后再装 Linux 版。
Windows 桌面包请用: .\pack.ps1
macOS / iOS 平板请用: ./pack.command
MSG
  exit 127
fi

echo "fvm=$FVM_BIN $($FVM_BIN --version 2>/dev/null || true)"

[[ -f "$CLIENT_ROOT/.fvmrc" ]] || die "缺少 .fvmrc，请先固定 Flutter 版本"
PINNED="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["flutter"])' "$CLIENT_ROOT/.fvmrc")"
echo ".fvmrc flutter=$PINNED"

cd "$CLIENT_ROOT"

step "fvm use .fvmrc ($PINNED) — no auto-install"
SDK_OK=0
CACHE_ROOT="${FVM_CACHE_PATH:-/opt/fvm}"
for d in \
  "$CACHE_ROOT/versions/$PINNED" \
  "$HOME/fvm/versions/$PINNED" \
  "$HOME/.fvm/versions/$PINNED" \
  "/opt/fvm/versions/$PINNED"
do
  if [[ -x "$d/bin/flutter" ]]; then SDK_OK=1; echo "SDK=$d"; break; fi
done
if [[ "$SDK_OK" -eq 0 ]]; then
  die "Flutter $PINNED 未安装，打包已中断。
请先手动安装: fvm install $PINNED
查看已安装版本: fvm list"
fi

"$FVM_BIN" use "$PINNED" --force
"$FVM_BIN" flutter --version

if [[ "$DO_LINUX" -eq 1 ]]; then
  step "fvm flutter build linux"
  "$FVM_BIN" flutter pub get
  "$FVM_BIN" flutter build linux --release
  RELEASE=""
  for c in \
    "$CLIENT_ROOT/build/linux/x64/release/bundle" \
    "$CLIENT_ROOT/build/linux/release/bundle"
  do
    [[ -d "$c" ]] && RELEASE="$c" && break
  done
  [[ -n "$RELEASE" ]] || die "linux release bundle 未找到"
  mkdir -p "$DIST_DIR"
  ZIP="$DIST_DIR/uuims-pc-linux.zip"
  rm -f "$ZIP"
  step "Zip -> $ZIP"
  (cd "$RELEASE" && zip -r -q "$ZIP" .)
  echo "OK $ZIP"
else
  echo "Skip linux"
fi

if [[ "$DO_ANDROID" -eq 1 ]]; then
  if [[ ! -d "$CLIENT_ROOT/android" ]]; then
    echo "Skip Android tablet（缺少 android/ 平台目录）" >&2
  elif ! ANDROID_SDK="$(find_android_sdk)"; then
    echo "Skip Android tablet（未找到 Android SDK。请安装 SDK 并设置 ANDROID_HOME 或 ANDROID_SDK_ROOT）" >&2
  else
    export ANDROID_HOME="${ANDROID_HOME:-$ANDROID_SDK}"
    export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_SDK}"
    echo "ANDROID_SDK=$ANDROID_SDK"
    step "fvm flutter build apk (Android tablet)"
    "$FVM_BIN" flutter pub get
    "$FVM_BIN" flutter build apk --release --dart-define="API_BASE_URL=$API_BASE_URL"
    APK="$CLIENT_ROOT/build/app/outputs/flutter-apk/app-release.apk"
    [[ -f "$APK" ]] || die "missing $APK"
    mkdir -p "$DIST_DIR"
    cp -f "$APK" "$DIST_DIR/uuims-android-tablet.apk"
    echo "OK $DIST_DIR/uuims-android-tablet.apk"
  fi
else
  echo "Skip Android tablet"
fi

printf '\nDone (Linux pack.sh, .fvmrc=%s). Targets: linux + android tablet (no web).\n' "$PINNED"
