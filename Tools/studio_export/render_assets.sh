#!/bin/zsh
# Renders sprites, backgrounds, effects and audio from the game's own SwiftUI Canvas and synth code (macOS build).
#   Tools/studio_export/render_assets.sh <out dir>
# Copies of the art files are patched only to widen visibility (private → internal) so the renderer can call them;
# the drawing code itself is unchanged.
set -eu
S=${0:A:h}; ROOT=${S:h:h}; OUT=${1:A}
SRC="$ROOT/Punch Mine"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/src" "$OUT"

for f in Theme OreArt BlockView ItemArt CosmeticArt Synth SoundEngine Haptics; do cp "$SRC/UI/$f.swift" "$WORK/src/"; done
# Previews don't build outside Xcode; the logo's painter and its fist/burst become callable.
sed -e '/^#Preview {/,$d' -e 's/^private struct LogoPainter/struct LogoPainter/' -e 's/^private struct Wordmark/struct Wordmark/' \
    -e 's/    private func fist()/    func fist()/' -e 's/    private func burst()/    func burst()/' \
    "$SRC/UI/Logo.swift" > "$WORK/src/Logo.swift"
sed -e 's/    private func draw(/    func draw(/' -e 's/    private func center(/    func center(/' \
    "$SRC/UI/Feedback.swift" > "$WORK/src/Feedback.swift"

# Single views out of larger screens: from the declaration to its closing brace at column 0.
extract() { awk -v pat="$2" '$0 ~ pat {on=1} on {print} on && /^}$/ {exit}' "$SRC/UI/$1.swift"; }
{
    echo "import SwiftUI"
    extract ItemsView '^extension Rarity'
    extract ItemsView '^extension ChestTier'
    extract ItemsView '^struct ItemIcon'
    extract EventView '^struct BossArt'
    extract WeeklyHeartView '^struct WeeklyHeartArt'
    extract MineView '^private struct MinerBadge' | sed 's/^private struct/struct/'
} > "$WORK/src/Extracted.swift"
cp "$S/render.swift" "$WORK/src/main.swift"

xcrun swiftc -swift-version 5 -default-isolation MainActor -O -o "$WORK/render" \
    "$SRC"/Game/*.swift "$WORK"/src/*.swift 2> "$WORK/build.txt" || { grep error: "$WORK/build.txt"; exit 1; }
"$WORK/render" "$OUT" -AppleLocale en_US   # NumberText formats with Locale.current: "27.8B", not "27,8B"
