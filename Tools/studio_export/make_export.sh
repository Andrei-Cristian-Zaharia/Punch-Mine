#!/bin/zsh
# Builds export/PunchMine_StudioExport.zip for Asar Studio: renders art and audio from code, records gameplay clips in the
# iOS Simulator, then assembles, checks and zips the package.
#   Tools/studio_export/make_export.sh <simulator udid>        e.g. an iPhone 17 Pro Max (xcrun simctl list devices)
set -eu
S=${0:A:h}; ROOT=${S:h:h}; UDID=$1
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
"$S/render_assets.sh" "$WORK/render"
"$S/capture_clips.sh" "$UDID" "$WORK/capture"
python3 "$S/build_export.py" --render "$WORK/render" --capture "$WORK/capture" --out "$ROOT/export"
