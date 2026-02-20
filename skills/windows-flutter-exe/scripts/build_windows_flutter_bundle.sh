#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  build_windows_flutter_bundle.sh --app-root <APP_ROOT> --out-dir <OUTPUT_DIR> [options]

Options:
  --skip-build                 Use existing build output without running flutter build
  --bundle-name <NAME>         Override bundle directory/archive base name
  --vc-redist-path <PATH>      Include VC++ redistributable installer in output bundle
  -h, --help                   Show this help

Example:
  bash ./skills/windows-flutter-exe/scripts/build_windows_flutter_bundle.sh \
    --app-root ./my_app \
    --out-dir ./dist
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $1" >&2
    exit 1
  fi
}

abspath() {
  local target="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$target"
  else
    (cd "$target" && pwd)
  fi
}

APP_ROOT=""
OUT_DIR=""
BUNDLE_NAME=""
VC_REDIST_PATH=""
SKIP_BUILD=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-root)
      APP_ROOT="${2:-}"
      shift 2
      ;;
    --out-dir)
      OUT_DIR="${2:-}"
      shift 2
      ;;
    --bundle-name)
      BUNDLE_NAME="${2:-}"
      shift 2
      ;;
    --vc-redist-path)
      VC_REDIST_PATH="${2:-}"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$APP_ROOT" || -z "$OUT_DIR" ]]; then
  echo "ERROR: --app-root and --out-dir are required" >&2
  usage >&2
  exit 1
fi

if [[ ! -d "$APP_ROOT" ]]; then
  echo "ERROR: app root does not exist: $APP_ROOT" >&2
  exit 1
fi

if [[ ! -f "$APP_ROOT/pubspec.yaml" ]]; then
  echo "ERROR: pubspec.yaml not found in app root: $APP_ROOT" >&2
  exit 1
fi

APP_ROOT="$(abspath "$APP_ROOT")"
mkdir -p "$OUT_DIR"
OUT_DIR="$(abspath "$OUT_DIR")"

if [[ $SKIP_BUILD -eq 0 ]]; then
  require_cmd flutter
  (
    cd "$APP_ROOT"
    flutter config --enable-windows-desktop >/dev/null
    flutter pub get
    flutter build windows --release
  )
fi

RELEASE_DIR="$APP_ROOT/build/windows/x64/runner/Release"
if [[ ! -d "$RELEASE_DIR" ]]; then
  echo "ERROR: release output not found: $RELEASE_DIR" >&2
  exit 1
fi

EXE_PATH="$(find "$RELEASE_DIR" -maxdepth 1 -type f -name '*.exe' | head -n 1 || true)"
if [[ -z "$EXE_PATH" ]]; then
  echo "ERROR: no .exe found in: $RELEASE_DIR" >&2
  exit 1
fi

if [[ ! -f "$RELEASE_DIR/flutter_windows.dll" ]]; then
  echo "ERROR: flutter_windows.dll missing in: $RELEASE_DIR" >&2
  exit 1
fi

if [[ ! -d "$RELEASE_DIR/data" ]]; then
  echo "ERROR: data/ directory missing in: $RELEASE_DIR" >&2
  exit 1
fi

if [[ -z "$BUNDLE_NAME" ]]; then
  APP_BASENAME="$(basename "$EXE_PATH" .exe)"
  BUNDLE_NAME="${APP_BASENAME}-windows-x64"
fi

BUNDLE_DIR="$OUT_DIR/$BUNDLE_NAME"
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR"
cp -R "$RELEASE_DIR"/. "$BUNDLE_DIR"/

if [[ -n "$VC_REDIST_PATH" ]]; then
  if [[ ! -f "$VC_REDIST_PATH" ]]; then
    echo "ERROR: vc redist installer not found: $VC_REDIST_PATH" >&2
    exit 1
  fi
  cp "$VC_REDIST_PATH" "$BUNDLE_DIR/vc_redist.x64.exe"
fi

if command -v shasum >/dev/null 2>&1; then
  (
    cd "$BUNDLE_DIR"
    find . -type f ! -name 'SHA256SUMS.txt' -print0 \
      | xargs -0 shasum -a 256 \
      | sed 's# \./# #g' > SHA256SUMS.txt
  )
fi

ZIP_PATH="$OUT_DIR/${BUNDLE_NAME}.zip"
if command -v zip >/dev/null 2>&1; then
  (
    cd "$OUT_DIR"
    rm -f "$ZIP_PATH"
    zip -rq "$ZIP_PATH" "$BUNDLE_NAME"
  )
elif command -v powershell.exe >/dev/null 2>&1; then
  powershell.exe -NoProfile -Command \
    "Compress-Archive -Path '$BUNDLE_DIR\\*' -DestinationPath '$ZIP_PATH' -Force" >/dev/null
else
  echo "WARNING: zip archive not created (neither zip nor powershell.exe found)." >&2
fi

echo "Bundle directory: $BUNDLE_DIR"
if [[ -f "$ZIP_PATH" ]]; then
  echo "Zip artifact: $ZIP_PATH"
fi
if [[ -f "$BUNDLE_DIR/SHA256SUMS.txt" ]]; then
  echo "Checksums: $BUNDLE_DIR/SHA256SUMS.txt"
fi
