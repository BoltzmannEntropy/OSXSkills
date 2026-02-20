#!/usr/bin/env bash
set -euo pipefail

APP_ROOT=""
INFO_PLIST=""
EXPORT_OPTIONS=""
SCHEME=""
WORKSPACE=""
PROJECT=""
PRIVACY_URL=""
SUPPORT_URL=""

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

usage() {
  cat <<'EOF'
Usage:
  check_ios_dist.sh --app-root <path> [options]

Options:
  --info-plist <path>       Explicit Info.plist path
  --export-options <path>   Explicit ExportOptions.plist path
  --workspace <path>        Explicit .xcworkspace path
  --project <path>          Explicit .xcodeproj path
  --scheme <name>           Expected shared scheme name
  --privacy-url <url>       Expected privacy policy URL (https)
  --support-url <url>       Expected support URL (https)
  -h, --help                Show this help
EOF
}

say_pass() {
  printf 'PASS  %s\n' "$1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

say_warn() {
  printf 'WARN  %s\n' "$1"
  WARN_COUNT=$((WARN_COUNT + 1))
}

say_fail() {
  printf 'FAIL  %s\n' "$1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

plist_get() {
  local plist_path="$1"
  local key="$2"
  /usr/libexec/PlistBuddy -c "Print :$key" "$plist_path" 2>/dev/null || true
}

file_exists() {
  [[ -f "$1" ]]
}

dir_exists() {
  [[ -d "$1" ]]
}

detect_info_plist() {
  local root="$1"
  local candidate=""
  if file_exists "$root/ios/Runner/Info.plist"; then
    candidate="$root/ios/Runner/Info.plist"
  elif file_exists "$root/Runner/Info.plist"; then
    candidate="$root/Runner/Info.plist"
  else
    candidate="$(find "$root" -maxdepth 6 -type f -name Info.plist | head -n 1 || true)"
  fi
  printf '%s' "$candidate"
}

detect_export_options() {
  local root="$1"
  local candidate=""
  if file_exists "$root/ios/ExportOptions.plist"; then
    candidate="$root/ios/ExportOptions.plist"
  else
    candidate="$(find "$root" -maxdepth 6 -type f -name ExportOptions.plist | head -n 1 || true)"
  fi
  printf '%s' "$candidate"
}

detect_workspace() {
  local root="$1"
  local candidate=""
  if dir_exists "$root/ios/Runner.xcworkspace"; then
    candidate="$root/ios/Runner.xcworkspace"
  else
    candidate="$(find "$root" -maxdepth 5 -type d -name "*.xcworkspace" | head -n 1 || true)"
  fi
  printf '%s' "$candidate"
}

detect_project() {
  local root="$1"
  local candidate=""
  if dir_exists "$root/ios/Runner.xcodeproj"; then
    candidate="$root/ios/Runner.xcodeproj"
  else
    candidate="$(find "$root" -maxdepth 5 -type d -name "*.xcodeproj" | head -n 1 || true)"
  fi
  printf '%s' "$candidate"
}

repo_uses_pattern() {
  local pattern="$1"
  if has_cmd rg; then
    rg -n --glob '!**/*Tests*' --glob '!**/Pods/**' --glob '!**/.build/**' --glob '!**/build/**' "$pattern" "$APP_ROOT" >/dev/null 2>&1
  else
    grep -R -n -E "$pattern" "$APP_ROOT" >/dev/null 2>&1
  fi
}

plist_has_nonempty_key() {
  local plist_path="$1"
  local key="$2"
  local val
  val="$(plist_get "$plist_path" "$key")"
  [[ -n "${val// }" ]]
}

validate_https_url() {
  local url="$1"
  [[ "$url" =~ ^https://[^[:space:]]+$ ]]
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-root)
      APP_ROOT="${2:-}"
      shift 2
      ;;
    --info-plist)
      INFO_PLIST="${2:-}"
      shift 2
      ;;
    --export-options)
      EXPORT_OPTIONS="${2:-}"
      shift 2
      ;;
    --workspace)
      WORKSPACE="${2:-}"
      shift 2
      ;;
    --project)
      PROJECT="${2:-}"
      shift 2
      ;;
    --scheme)
      SCHEME="${2:-}"
      shift 2
      ;;
    --privacy-url)
      PRIVACY_URL="${2:-}"
      shift 2
      ;;
    --support-url)
      SUPPORT_URL="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown arg: %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$APP_ROOT" ]]; then
  printf '--app-root is required\n\n' >&2
  usage >&2
  exit 2
fi

if ! dir_exists "$APP_ROOT"; then
  printf 'App root not found: %s\n' "$APP_ROOT" >&2
  exit 2
fi

APP_ROOT="$(cd "$APP_ROOT" && pwd)"

# Ensure this is actually an iOS-capable project.
if ! dir_exists "$APP_ROOT/ios"; then
  say_fail "No ios/ directory found (run: flutter create --platforms=ios .)"
  printf '\n== Summary ==\n'
  printf 'PASS: %d\n' "$PASS_COUNT"
  printf 'WARN: %d\n' "$WARN_COUNT"
  printf 'FAIL: %d\n' "$FAIL_COUNT"
  exit 1
fi

if [[ -z "$INFO_PLIST" ]]; then
  INFO_PLIST="$(detect_info_plist "$APP_ROOT")"
fi
if [[ -z "$EXPORT_OPTIONS" ]]; then
  EXPORT_OPTIONS="$(detect_export_options "$APP_ROOT")"
fi
if [[ -z "$WORKSPACE" ]]; then
  WORKSPACE="$(detect_workspace "$APP_ROOT")"
fi
if [[ -z "$PROJECT" ]]; then
  PROJECT="$(detect_project "$APP_ROOT")"
fi

printf '== iOS Distribution Preflight ==\n'
printf 'App root: %s\n' "$APP_ROOT"

if [[ -n "$INFO_PLIST" ]] && file_exists "$INFO_PLIST"; then
  say_pass "Info.plist found: $INFO_PLIST"
else
  say_fail "Info.plist not found (pass --info-plist)"
fi

if [[ "$FAIL_COUNT" -eq 0 ]]; then
  bundle_id="$(plist_get "$INFO_PLIST" "CFBundleIdentifier")"
  app_version="$(plist_get "$INFO_PLIST" "CFBundleShortVersionString")"
  build_number="$(plist_get "$INFO_PLIST" "CFBundleVersion")"
  device_family="$(plist_get "$INFO_PLIST" "UIDeviceFamily")"

  if [[ -n "${bundle_id// }" ]]; then
    say_pass "CFBundleIdentifier set: $bundle_id"
  else
    say_fail "CFBundleIdentifier missing in Info.plist"
  fi

  if [[ -n "${app_version// }" ]]; then
    say_pass "CFBundleShortVersionString set: $app_version"
  else
    say_fail "CFBundleShortVersionString missing"
  fi

  if [[ -n "${build_number// }" ]]; then
    say_pass "CFBundleVersion set: $build_number"
  else
    say_fail "CFBundleVersion missing"
  fi

  if plist_has_nonempty_key "$INFO_PLIST" "ITSAppUsesNonExemptEncryption"; then
    say_pass "ITSAppUsesNonExemptEncryption is present"
  else
    say_warn "ITSAppUsesNonExemptEncryption not set (export compliance friction risk)"
  fi

  # API usage -> purpose-string alignment checks
  if repo_uses_pattern 'AVCaptureDevice|requestAccess\(for:[[:space:]]*\.video|UIImagePickerController'; then
    if plist_has_nonempty_key "$INFO_PLIST" "NSCameraUsageDescription"; then
      say_pass "Camera usage key present for camera API usage"
    else
      say_fail "Camera APIs found but NSCameraUsageDescription missing"
    fi
  fi

  if repo_uses_pattern 'AVAudioSession|requestRecordPermission|SFSpeechRecognizer|requestAccess\(for:[[:space:]]*\.audio'; then
    if plist_has_nonempty_key "$INFO_PLIST" "NSMicrophoneUsageDescription"; then
      say_pass "Microphone usage key present for audio API usage"
    else
      say_fail "Audio/mic APIs found but NSMicrophoneUsageDescription missing"
    fi
  fi

  if repo_uses_pattern 'PHPhotoLibrary|PHPickerViewController|UIImageWriteToSavedPhotosAlbum'; then
    if plist_has_nonempty_key "$INFO_PLIST" "NSPhotoLibraryUsageDescription" || plist_has_nonempty_key "$INFO_PLIST" "NSPhotoLibraryAddUsageDescription"; then
      say_pass "Photo library usage key present for photo API usage"
    else
      say_fail "Photo APIs found but NSPhotoLibraryUsageDescription / NSPhotoLibraryAddUsageDescription missing"
    fi
  fi

  if repo_uses_pattern 'CLLocationManager|requestWhenInUseAuthorization|requestAlwaysAuthorization'; then
    if plist_has_nonempty_key "$INFO_PLIST" "NSLocationWhenInUseUsageDescription" || plist_has_nonempty_key "$INFO_PLIST" "NSLocationAlwaysAndWhenInUseUsageDescription"; then
      say_pass "Location usage key present for location API usage"
    else
      say_fail "Location APIs found but location usage description key missing"
    fi
  fi

  if repo_uses_pattern 'ATTrackingManager|requestTrackingAuthorization'; then
    if plist_has_nonempty_key "$INFO_PLIST" "NSUserTrackingUsageDescription"; then
      say_pass "ATT usage key present for tracking API usage"
    else
      say_fail "ATTrackingManager usage found but NSUserTrackingUsageDescription missing"
    fi
  fi

  # Sign in with Apple warning heuristic
  if repo_uses_pattern 'GIDSignIn|FBSDKLoginKit|LoginManager|GoogleSignIn'; then
    if repo_uses_pattern 'ASAuthorizationAppleIDProvider|AuthenticationServices'; then
      say_pass "Third-party sign-in detected and Apple sign-in API references found"
    else
      say_warn "Third-party sign-in detected without obvious Sign in with Apple references (review App Review Guideline 4.8)"
    fi
  fi

  # iPad support + screenshots heuristic
  if [[ "$device_family" == *"2"* ]] || plist_has_nonempty_key "$INFO_PLIST" "UISupportedInterfaceOrientations~ipad"; then
    say_pass "iPad support appears enabled in UIDeviceFamily"
    if dir_exists "$APP_ROOT/fastlane/screenshots"; then
      if find "$APP_ROOT/fastlane/screenshots" -type f | grep -qi 'ipad'; then
        say_pass "iPad screenshots detected in fastlane/screenshots"
      else
        say_warn "iPad support enabled but no obvious iPad screenshots found in fastlane/screenshots"
      fi
    else
      say_warn "iPad support enabled and no fastlane/screenshots directory found"
    fi
  else
    say_warn "Could not confirm iPad support in UIDeviceFamily; verify target device family manually"
  fi
fi

# Privacy manifests (bash 3 compatible; avoid mapfile)
manifests_raw="$(find "$APP_ROOT" -maxdepth 7 -type f -name PrivacyInfo.xcprivacy ! -path "*/build/*" ! -path "*/.dart_tool/*" 2>/dev/null || true)"
if [[ -z "$manifests_raw" ]]; then
  say_warn "No PrivacyInfo.xcprivacy found"
else
  while IFS= read -r manifest; do
    [[ -z "$manifest" ]] && continue
    if plutil -lint "$manifest" >/dev/null 2>&1; then
      say_pass "Valid privacy manifest: $manifest"
      if plutil -p "$manifest" 2>/dev/null | grep -q "NSPrivacyAccessedAPITypes"; then
        say_pass "Required-reason API section found in: $manifest"
      else
        say_warn "No NSPrivacyAccessedAPITypes in: $manifest"
      fi
    else
      say_fail "Invalid privacy manifest syntax: $manifest"
    fi
  done <<EOF
$manifests_raw
EOF
fi

# Export options checks
if [[ -n "$EXPORT_OPTIONS" ]] && file_exists "$EXPORT_OPTIONS"; then
  say_pass "ExportOptions.plist found: $EXPORT_OPTIONS"
  export_method="$(plist_get "$EXPORT_OPTIONS" "method")"
  export_team="$(plist_get "$EXPORT_OPTIONS" "teamID")"
  signing_style="$(plist_get "$EXPORT_OPTIONS" "signingStyle")"

  case "$export_method" in
    app-store|app-store-connect)
      say_pass "Export method is suitable for App Store/TestFlight: $export_method"
      ;;
    "")
      say_fail "ExportOptions.plist missing :method"
      ;;
    *)
      say_fail "Unexpected ExportOptions.plist method for store distribution: $export_method"
      ;;
  esac

  if [[ -n "${export_team// }" ]] && [[ "$export_team" != "YOUR_TEAM_ID" ]]; then
    say_pass "ExportOptions.plist teamID appears configured"
  else
    say_warn "ExportOptions.plist teamID missing or placeholder"
  fi

  if [[ -n "${signing_style// }" ]]; then
    say_pass "ExportOptions.plist signingStyle set: $signing_style"
  else
    say_warn "ExportOptions.plist signingStyle not set"
  fi
else
  say_warn "ExportOptions.plist not found"
fi

# Workspace/project and scheme checks
if [[ -n "$WORKSPACE" || -n "$PROJECT" ]]; then
  if [[ -n "$WORKSPACE" ]] && dir_exists "$WORKSPACE"; then
    say_pass "Workspace detected: $WORKSPACE"
  fi
  if [[ -n "$PROJECT" ]] && dir_exists "$PROJECT"; then
    say_pass "Project detected: $PROJECT"
  fi

  if [[ -n "$SCHEME" ]] && has_cmd xcodebuild; then
    if [[ -n "$WORKSPACE" ]] && dir_exists "$WORKSPACE"; then
      if xcodebuild -list -workspace "$WORKSPACE" 2>/dev/null | grep -qE "^[[:space:]]+$SCHEME$"; then
        say_pass "Scheme found in workspace: $SCHEME"
      else
        say_fail "Scheme not found in workspace: $SCHEME"
      fi
    elif [[ -n "$PROJECT" ]] && dir_exists "$PROJECT"; then
      if xcodebuild -list -project "$PROJECT" 2>/dev/null | grep -qE "^[[:space:]]+$SCHEME$"; then
        say_pass "Scheme found in project: $SCHEME"
      else
        say_fail "Scheme not found in project: $SCHEME"
      fi
    fi
  elif [[ -z "$SCHEME" ]]; then
    say_warn "Scheme not provided; pass --scheme for strict checking"
  else
    say_warn "xcodebuild not available; cannot verify scheme"
  fi
else
  say_warn "No .xcworkspace or .xcodeproj detected"
fi

# URL checks
if [[ -n "$PRIVACY_URL" ]]; then
  if validate_https_url "$PRIVACY_URL"; then
    say_pass "Privacy URL format looks valid"
  else
    say_fail "Privacy URL must be https://..."
  fi
else
  say_warn "Privacy URL not supplied (use --privacy-url)"
fi

if [[ -n "$SUPPORT_URL" ]]; then
  if validate_https_url "$SUPPORT_URL"; then
    say_pass "Support URL format looks valid"
  else
    say_fail "Support URL must be https://..."
  fi
else
  say_warn "Support URL not supplied (use --support-url)"
fi

printf '\n== Summary ==\n'
printf 'PASS: %d\n' "$PASS_COUNT"
printf 'WARN: %d\n' "$WARN_COUNT"
printf 'FAIL: %d\n' "$FAIL_COUNT"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi
