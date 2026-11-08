#!/bin/zsh
# Renders the app icon from Punch Mine/UI/Logo.swift (LogoMark) into the asset catalog.
#   Tools/make-app-icon.sh
set -eu
ROOT="${0:A:h:h}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
SET="$ROOT/Punch Mine/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$SET" "$WORK/src"
cp "$ROOT/Punch Mine/UI/Logo.swift" "$WORK/src/Logo.swift"
# Previews don't build outside Xcode.
sed -i '' '/^#Preview {/,$d' "$WORK/src/Logo.swift"
cat > "$WORK/src/main.swift" <<'SWIFT'
import SwiftUI
import AppKit

func png(_ view: some View, _ px: Int, _ path: String) {
    let renderer = ImageRenderer(content: view.frame(width: CGFloat(px), height: CGFloat(px)))
    renderer.scale = 1
    guard let cg = renderer.cgImage else { fatalError("render failed") }
    let rep = NSBitmapImageRep(cgImage: cg)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

let out = CommandLine.arguments[1]
// iPhone and iPad: one full-bleed square; the system rounds it.
png(LogoMark(), 1024, out + "/icon-ios-1024.png")
// Mac: the classic rounded square on a transparent canvas with a little margin and shadow.
for px in [16, 32, 64, 128, 256, 512, 1024] {
    let inset = CGFloat(px) * 0.1
    let mac = LogoMark()
        .clipShape(RoundedRectangle(cornerRadius: CGFloat(px) * 0.18, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: CGFloat(px) * 0.012, y: CGFloat(px) * 0.01)
        .padding(inset)
    png(mac, px, out + "/icon-mac-\(px).png")
}
SWIFT
xcrun swiftc -swift-version 5 -default-isolation MainActor -o "$WORK/render" "$WORK/src/Logo.swift" "$WORK/src/main.swift" 2>&1 | grep -v warning || true
[[ -x "$WORK/render" ]] || { echo "build failed"; exit 1; }
"$WORK/render" "$SET"
cat > "$SET/Contents.json" <<'JSON'
{
  "images" : [
    { "filename" : "icon-ios-1024.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" },
    { "filename" : "icon-mac-16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon-mac-32.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon-mac-32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon-mac-64.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon-mac-128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon-mac-256.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon-mac-256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon-mac-512.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon-mac-512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon-mac-1024.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON
echo "Wrote $(ls "$SET"/*.png | wc -l | tr -d ' ') icons to $SET"
