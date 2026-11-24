#!/usr/bin/env bash
# Runs inside reactivecircus/android-emulator-runner. Installs the debug APK,
# launches Pulse, waits, then fails if the app crashed or is not in the
# foreground. Writes logcat and a screenshot to emulator-out/.
set -u
OUT=emulator-out
PKG=com.pulse.pulse
APK=build/app/outputs/flutter-apk/app-debug.apk
mkdir -p "$OUT"

adb logcat -c
adb install -r "$APK" || { echo "install failed" | tee "$OUT/summary.txt"; exit 1; }
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1
sleep 25
adb exec-out screencap -p > "$OUT/launch.png"
adb logcat -d -v time > "$OUT/logcat.txt"

fail=0
if grep -E "FATAL EXCEPTION|AndroidRuntime: .*$PKG|ANR in $PKG|Process $PKG .* has died" "$OUT/logcat.txt" >/dev/null; then
  echo "crash found in logcat" | tee -a "$OUT/summary.txt"
  grep -E -A12 "FATAL EXCEPTION" "$OUT/logcat.txt" | head -60 | tee -a "$OUT/summary.txt"
  fail=1
fi
if ! adb shell pidof "$PKG" >/dev/null; then
  echo "app process is not running" | tee -a "$OUT/summary.txt"
  fail=1
fi
[ "$fail" = 0 ] && echo "ok: app launched and stayed up for 25s" | tee -a "$OUT/summary.txt"
exit "$fail"
