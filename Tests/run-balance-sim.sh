#!/bin/zsh
# Balance simulation: a bot plays Pebble Quarry and reports pacing against the design doc's targets.
#   Tests/run-balance-sim.sh [hours of play, default 12] [taps per second, default 6]
set -eu
ROOT="${0:A:h:h}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/src"; cp "$ROOT/Tests/Balance/BalanceSim.swift" "$WORK/src/main.swift"
# A command-line tool's UserDefaults domain is its executable name, so each run gets its own name:
# parallel sims would otherwise share (and overwrite) one save.
BIN="$WORK/balance-sim-$$-$RANDOM"
xcrun swiftc -O -swift-version 5 -default-isolation MainActor -o "$BIN" "$ROOT"/MyApp/Game/*.swift "$WORK/src/main.swift"
"$BIN" "$@"
defaults delete "${BIN:t}" >/dev/null 2>&1 || true
