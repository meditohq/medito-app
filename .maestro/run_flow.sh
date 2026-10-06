#!/usr/bin/env bash
# Runs one Maestro flow and retries it once if it fails.
#
#   .maestro/run_flow.sh <debug-dir> <maestro test args...>
#
# Every flow we run in CI starts with `launchApp: clearState: true`, so a second
# attempt starts from scratch. The retry absorbs failures that come from the CI
# machine rather than the app: the iOS XCUITest driver dying mid-flow ("Device
# became unreachable", run 37440292038) or the emulator killing the app. A real
# regression fails both attempts. A pass on retry is flagged as a warning
# annotation so flakiness stays visible.
#
# Don't echo "$@": it carries the test account credentials.
set -u

debug_dir="$1"
shift

flow=""
for arg in "$@"; do
  case "$arg" in *.yaml) flow="$(basename "$arg")" ;; esac
done

for attempt in 1 2; do
  out="$debug_dir"
  [ "$attempt" -gt 1 ] && out="$debug_dir/retry"
  mkdir -p "$out"
  if "$HOME/.maestro/bin/maestro" test "$@" --no-ansi --debug-output "$out"; then
    if [ "$attempt" -gt 1 ]; then
      echo "::warning::Maestro flow $flow failed once and passed on retry — see the first attempt in the job log"
    fi
    exit 0
  fi
  echo "Maestro flow $flow failed (attempt $attempt/2)"
  # The Android emulator can drop offline under the software-rendered donation
  # webview ("device offline", run 37440292038 attempt 2). Bring it back before
  # retrying. Skipped on iOS runners, where adb sees no emulator.
  if [ "$attempt" -eq 1 ] && command -v adb >/dev/null && adb devices | grep -q '^emulator-'; then
    adb reconnect offline || true
    timeout 180 adb wait-for-device || true
    timeout 180 adb shell 'while [ "$(getprop sys.boot_completed)" != 1 ]; do sleep 2; done' || true
  fi
done
exit 1
