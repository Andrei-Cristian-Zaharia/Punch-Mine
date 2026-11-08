#!/bin/zsh
# Records real gameplay clips and screenshots from the Debug build in the iOS Simulator.
# The game plays itself through its own debug helpers (`-debugScreen autopunch`, `weeklyfight`, `reveal`, `conquest`,
# see Punch Mine/UI/MineView.swift), loaded with the store-screenshot saves.
#   Tools/studio_export/capture_clips.sh <simulator udid> <out dir> [path to Punch Mine.app]
# Without an .app path it builds the Debug app first. Video has no audio (simctl records picture only).
set -eu
S=${0:A:h}; ROOT=${S:h:h}; UDID=$1; OUT=$2; APP=${3:-}
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
mkdir -p "$OUT/clips" "$OUT/shots"
if [[ -z $APP ]]; then
    xcodebuild -project "$ROOT/Punch Mine.xcodeproj" -scheme "Punch Mine" -configuration Debug \
        -destination "id=$UDID" -derivedDataPath "$WORK/dd" build >/dev/null
    APP="$WORK/dd/Build/Products/Debug-iphonesimulator/Punch Mine.app"
fi
BUNDLE=com.andreizaharia.punchmine
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4 || true
xcrun simctl install "$UDID" "$APP"

# clip <name> <save> <debugScreen> <seconds before recording> <seconds recorded>
clip() {
    local name=$1 save=$2 screen=$3 lead=$4 length=$5
    xcrun simctl terminate "$UDID" $BUNDLE >/dev/null 2>&1 || true
    # Fresh timestamps right before each launch, or a "Welcome back" card covers the mine.
    python3 "$S/make_capture_saves.py" "$WORK/saves" >/dev/null
    local args=(-debugSave "$save" -AppleLocale en_US -AppleLanguages "(en)")
    [[ $screen != - ]] && args+=(-debugScreen $screen)
    xcrun simctl launch "$UDID" $BUNDLE $args >/dev/null
    sleep $lead
    xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$OUT/clips/$name.mp4" >/dev/null 2>&1 &
    local rec=$!
    sleep $(( length / 2.0 ))
    xcrun simctl io "$UDID" screenshot --type=png "$OUT/shots/$name.png" >/dev/null 2>&1
    sleep $(( length / 2.0 ))
    kill -INT $rec; wait $rec || true
    echo "recorded $name"
}

clip quarry_autopunch    "$WORK/saves/save-quarry.json"  autopunch   1.5 20
clip caverns_autopunch   "$WORK/saves/save-caverns.json" autopunch   1.5 20
clip magma_autopunch     "$WORK/saves/save-magma.json"   autopunch   1.5 20
clip ruins_autopunch     "$WORK/saves/save-ruins.json"   autopunch   1.5 30
clip crypt_autopunch     "$WORK/saves/save-crypt.json"   autopunch   1.5 20
clip heart_fight         "$WORK/saves/save-heart.json"   autopunch   1.5 30
clip first_minute        fresh                           autopunch   1.5 25
clip weekly_heart_fight  "$WORK/saves/save-ruins.json"   weeklyfight 1.0 34
clip chest_reveal        "$WORK/saves/save-legend.json"  reveal      0.5 8
clip heart_conquest      "$WORK/saves/save-heart.json"   conquest    0.5 6
xcrun simctl terminate "$UDID" $BUNDLE >/dev/null 2>&1 || true
xcrun simctl status_bar "$UDID" clear || true
