#!/usr/bin/env bash
# Fail the APK release before publication if Android cannot install and launch it.
# Called by the Android-emulator-runner action after flutter build apk --release.
set -euo pipefail

apk="app/build/app/outputs/flutter-apk/app-release.apk"
package="com.shiaai.app"
activity="$package/.MainActivity"

if [[ ! -s "$apk" ]]; then
  echo "::error title=Missing APK::$apk does not exist"
  exit 1
fi

# Check the entire supported Android range, not only the CI emulator's API.
apksigner=$(find "$ANDROID_HOME/build-tools" -maxdepth 2 -type f -name apksigner | sort -V | tail -1)
if [[ -z "$apksigner" ]]; then
  echo '::error title=Missing Android SDK signer::Cannot verify APK signing'
  exit 1
fi
"$apksigner" verify --verbose --print-certs --min-sdk-version 24 "$apk"

echo "Emulator API: $(adb shell getprop ro.build.version.sdk | tr -d '\r')"
echo "Emulator ABI: $(adb shell getprop ro.product.cpu.abi | tr -d '\r')"

# Isolate any regression from the previous release. A failure on the old APK
# is diagnostic, not a pass for the new one. Also check upgrade compatibility.
# The baseline is the release installed on the owner's phone (1.13.1): a
# successful `adb install -r` here is exactly the in-place update that phone
# would do. A production-key build is expected to warn on this step — different
# signing keys cannot update each other (docs/signing-and-migration-plan.md).
baseline_tag="${SMOKE_BASELINE_TAG:-app-v1.13.1}"
baseline_asset="${SMOKE_BASELINE_ASSET:-ShiaVerse-1.13.1.apk}"
mkdir -p build/install-smoke
if gh release download "$baseline_tag" -p "$baseline_asset" -D build/install-smoke --clobber; then
  old="build/install-smoke/$baseline_asset"
  echo "Previous release SHA-256: $(sha256sum "$old" | cut -d' ' -f1)"
  if adb install --no-streaming "$old"; then
    echo 'Previous release installed on emulator; trying an in-place update.'
    if ! adb install -r --no-streaming "$apk"; then
      echo '::warning title=APK update failed::Could be different release signing keys; clean install is checked separately.'
    fi
  else
    echo '::warning title=Previous APK would not install on emulator::See the adb failure above.'
  fi
else
  echo '::warning title=Previous APK not downloaded::Only the new APK will be tested.'
fi

# A clean install is mandatory regardless of how the previous-release test went.
adb uninstall "$package" || true
printf '\nInstalling the NEW signed release APK on a clean Android emulator...\n'
adb install --no-streaming "$apk"
if ! adb shell pm path "$package" | grep -q 'base.apk'; then
  echo '::error title=APK installation failed::The package manager cannot find the installed APK'
  exit 1
fi

launch=$(adb shell am start -W -n "$activity" 2>&1)
echo "$launch"
if grep -Eq 'Error:|Exception|unable to resolve' <<< "$launch"; then
  echo '::error title=App launch failed::Android rejected the main activity'
  exit 1
fi

# am start can report success just before Flutter crashes; confirm it stays up.
sleep 6
if ! adb shell pidof "$package" | grep -Eq '[0-9]+'; then
  adb logcat -d -t 200 -s AndroidRuntime:E ActivityTaskManager:E flutter:E || true
  echo '::error title=App launch failed::Process exited during startup'
  exit 1
fi

# Optional: capture listing screenshots from the live emulator (the production
# workflow collects these for the store submission kit).
if [[ -n "${SHIAVERSE_SMOKE_SHOTS:-}" ]]; then
  mkdir -p "$SHIAVERSE_SMOKE_SHOTS"
  adb exec-out screencap -p > "$SHIAVERSE_SMOKE_SHOTS/01-home-clean-install.png" || true
  sleep 2
  adb exec-out screencap -p > "$SHIAVERSE_SMOKE_SHOTS/02-home-settled.png" || true
  echo "Screenshots saved under $SHIAVERSE_SMOKE_SHOTS"
fi

echo 'Android emulator clean install AND launch verified.'
