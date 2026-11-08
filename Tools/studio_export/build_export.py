#!/usr/bin/env python3
"""Assembles PunchMine_StudioExport.zip for Asar Studio.

    build_export.py --render DIR --capture DIR [--out export]

--render   output of render_assets.sh (assets/… and rendered.json)
--capture  output of capture_clips.sh (clips/*.mp4, shots/*.png)
Everything else is copied from the repo: app icons, store screenshots and art, shop product art, store texts and the
documents in Tools/studio_export/docs. Then manifest.json is written, the package is checked and zipped.
"""
import argparse, glob, json, os, re, shutil, struct, subprocess, sys, zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
NAME = "PunchMine_StudioExport"
CATEGORIES = {"characters", "objects", "environment", "ui", "fx", "audio", "branding", "clips", "reference"}

ap = argparse.ArgumentParser()
ap.add_argument("--render", required=True)
ap.add_argument("--capture", required=True)
ap.add_argument("--out", default=os.path.join(ROOT, "export"))
args = ap.parse_args()

pkg = os.path.join(args.out, NAME)
shutil.rmtree(pkg, ignore_errors=True)
os.makedirs(pkg)
entries = []


def copy(src, rel, entry=None):
    dst = os.path.join(pkg, rel)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copyfile(src, dst)
    if entry is not None:
        entries.append({"path": rel, **entry})


def png_info(path):
    """(width, height, has alpha) from the PNG header."""
    with open(path, "rb") as f:
        head = f.read(33)
    assert head[:8] == b"\x89PNG\r\n\x1a\n", path
    w, h, depth, color = struct.unpack(">IIBB", head[16:26])
    return w, h, color in (4, 6)


# --- Rendered from code -------------------------------------------------------------------------------------------
for e in json.load(open(os.path.join(args.render, "rendered.json"))):
    copy(os.path.join(args.render, e["path"]), e["path"], {**e, "source": "rendered from code (Tools/studio_export/render.swift)"})

# --- Gameplay clips (simulator recordings) ------------------------------------------------------------------------
CLIPS = {
    "quarry_autopunch": "Pebble Quarry, area 38: late-game punching with crits, splash and Dynamite (game plays itself via -debugScreen autopunch)",
    "caverns_autopunch": "Crystal Caverns, area 34: crystal chain breaks",
    "magma_autopunch": "Magma Depths, area 30: regrowing blocks and vents",
    "ruins_autopunch": "Sunken Ruins, area 22: high tide, runestones, Titan and ZAP numbers",
    "crypt_autopunch": "Haunted Crypt, area 18: ghosts fading, cursed urns, area-clear banner",
    "heart_fight": "Heart of the Ruins fight at area 100 (zaps, Titan Punches, HP bar draining)",
    "first_minute": "Brand-new save: area 1, punching dirt for +1 coins, the Fever tip",
    "weekly_heart_fight": "Weekly Heart: 30-second fight, tier counter, crit pops",
    "chest_reveal": "Golden Chest reveal: Legendary item with bad-luck protection",
    "heart_conquest": "Crown card after a Heart falls (opened by the debug helper: its +100 Perk Coins skip the zone multiplier the real reward uses)",
}
# Simulator recordings are ~25 Mbit/s at 1320 px wide; re-encode to 1080 px wide, ~8 Mbit/s H.264.
os.makedirs(os.path.join(pkg, "assets", "clips"))
clip_paths = []
for src in sorted(glob.glob(os.path.join(args.capture, "clips", "*.mp4"))):
    dst = os.path.join(pkg, "assets", "clips", os.path.basename(src))
    subprocess.run(["xcrun", "swift", os.path.join(HERE, "transcode.swift"), src, dst], check=True, stderr=subprocess.DEVNULL)
    clip_paths.append(dst)
probe = json.loads(subprocess.check_output(["xcrun", "swift", os.path.join(HERE, "probe_media.swift"), *clip_paths], text=True,
                                           stderr=subprocess.DEVNULL))
for dst in clip_paths:
    name = os.path.splitext(os.path.basename(dst))[0]
    info = probe[dst]
    entries.append({"path": f"assets/clips/{name}.mp4", **{
        "id": f"clip_{name}", "category": "clips", "role": CLIPS.get(name, "gameplay"), "width": int(info["width"]),
        "height": int(info["height"]), "durationSec": info["durationSec"], "audio": False,
        "fps": 30, "source": "iOS Simulator recording, iPhone 17 Pro Max (Tools/studio_export/capture_clips.sh)"}})
for src in sorted(glob.glob(os.path.join(args.capture, "shots", "*.png"))):
    name = os.path.splitext(os.path.basename(src))[0]
    w, h, _ = png_info(src)
    copy(src, f"reference/screenshots/gameplay/{name}.png",
         {"id": f"shot_{name}", "category": "reference", "role": f"Gameplay still from clip {name}", "width": w, "height": h})

# --- Branding from the repo ---------------------------------------------------------------------------------------
xc = os.path.join(ROOT, "Punch Mine", "Assets.xcassets")
copy(os.path.join(xc, "AppIcon.appiconset", "icon-ios-1024.png"), "assets/branding/app_icon.png",
     {"id": "app_icon", "category": "branding", "role": "icon", "width": 1024, "height": 1024,
      "note": "iOS app icon (full-bleed square, no transparency; the system rounds the corners)"})
copy(os.path.join(xc, "AppIcon.appiconset", "icon-mac-1024.png"), "assets/branding/app_icon_rounded.png",
     {"id": "app_icon_rounded", "category": "branding", "role": "App icon with rounded corners and shadow on transparency (Mac icon)",
      "width": 1024, "height": 1024})
for src in sorted(glob.glob(os.path.join(xc, "AppIcon-*.appiconset", "*.png"))):
    name = os.path.basename(os.path.dirname(src)).replace("AppIcon-", "").replace(".appiconset", "").lower()
    copy(src, f"assets/branding/app_icons/app_icon_{name}.png",
         {"id": f"app_icon_{name}", "category": "branding", "role": f"Alternate app icon '{name}' (cosmetic reward)", "width": 1024, "height": 1024})
art = os.path.join(ROOT, "AppStore", "Screenshots", "en-GB", "creative-assets")
copy(os.path.join(art, "header-3840x1646.png"), "assets/branding/key_art_header.png",
     {"id": "key_art_header", "category": "branding", "role": "Key art: App Store header 'Smash. Loot. Conquer.'", "width": 3840, "height": 1646})
copy(os.path.join(art, "search-results-3840x2560.png"), "assets/branding/key_art_search_results.png",
     {"id": "key_art_search", "category": "branding", "role": "Key art: App Store search-results image 'TAP. SMASH. GET RICH!'",
      "width": 3840, "height": 2560})

# --- Shop product art (in-game shop tiles and App Store promo images) --------------------------------------------
for src in sorted(glob.glob(os.path.join(ROOT, "AppStore", "InAppPurchases", "promotional-images", "*.png"))):
    pid = os.path.splitext(os.path.basename(src))[0]
    w, h, _ = png_info(src)
    copy(src, f"assets/ui/shop/{pid.replace('.', '_')}.png",
         {"id": pid.replace(".", "_"), "category": "ui", "role": f"Shop product art for {pid} (opaque, no text)", "width": w, "height": h})
src = os.path.join(ROOT, "AppStore", "InAppPurchase", "event-pass-1024.png")
w, h, _ = png_info(src)
copy(src, "assets/ui/shop/punchmine_eventpass.png",
     {"id": "punchmine_eventpass", "category": "ui", "role": "Shop product art for punchmine.eventpass (opaque)", "width": w, "height": h})

# --- Reference: store screenshots, event art, review shots, store texts -------------------------------------------
shots = os.path.join(ROOT, "AppStore", "Screenshots")
for device in ("iphone-1179x2556", "ipad-2048x2732"):
    for src in sorted(glob.glob(os.path.join(shots, "en-GB", device, "*.png"))):
        name = os.path.splitext(os.path.basename(src))[0]
        w, h, _ = png_info(src)
        kind = device.split("-")[0]
        copy(src, f"reference/screenshots/store/{kind}/store_{name}.png",
             {"id": f"store_{kind}_{name}", "category": "reference", "role": f"App Store screenshot ({kind}, en-GB) {name}", "width": w, "height": h})
for src in sorted(glob.glob(os.path.join(shots, "in-app-event", "*.png"))):
    name = os.path.splitext(os.path.basename(src))[0]
    w, h, _ = png_info(src)
    copy(src, f"reference/screenshots/store/in_app_event/{name}.png",
         {"id": f"in_app_event_{name}", "category": "reference", "role": "App Store in-app event art", "width": w, "height": h})
for src in [os.path.join(ROOT, "AppStore", "InAppPurchase", "event-pass-review-1206x2622.png")] + \
        sorted(glob.glob(os.path.join(ROOT, "AppStore", "InAppPurchases", "review-screenshots", "*.png"))):
    name = os.path.splitext(os.path.basename(src))[0].replace(".", "_")
    w, h, _ = png_info(src)
    copy(src, f"reference/screenshots/shop/{name}.png",
         {"id": f"review_{name}", "category": "reference", "role": "In-app purchase review screenshot (shop screen)", "width": w, "height": h})
for src in sorted(glob.glob(os.path.join(ROOT, "AppStore", "Localization", "*.md"))):
    copy(src, f"reference/store_text/{os.path.basename(src)}")
copy(os.path.join(ROOT, "Tools", "store-screenshots", "store_text.py"), "reference/store_text/store_art_captions.py.txt")
copy(os.path.join(ROOT, "Config", "PunchMine.storekit"), "reference/store_text/PunchMine.storekit.json")

# --- Documents and folder notes -----------------------------------------------------------------------------------
for doc in ("game_design.md", "visual_style.md", "store_info.md", "video_ideas.md", "README.md"):
    copy(os.path.join(HERE, "docs", doc), doc)
NOTES = {
    "assets/characters/README.txt": "Punch Mine has no walking characters or enemies. The player is the punching fist (player/), "
        "the opponents are blocks (see objects/blocks), the bosses are the zone Hearts, the Weekly Heart and the event bosses "
        "(bosses/), and the helpers are miners (shown in game as round badges) and pets.\n",
    "assets/environment/README.txt": "The game has no tiles, terrain or parallax: each mine is a flat zone colour behind a 5 x 6 grid "
        "of blocks. backgrounds/ holds 1080 x 1920 plates: the plain ground colour, a full grid of real blocks for each zone "
        "(laid out like MineView, generated by the game's AreaGenerator) and the area-100 Heart grid.\n",
    "assets/clips/README.txt": "iOS Simulator recordings (iPhone 17 Pro Max, scaled to 1080 x 2346, H.264 30 fps, no audio track: the simulator records "
        "picture only). The game plays itself through its debug helpers; nothing is staged or edited. Add music/SFX from assets/audio.\n",
    "reference/gameplay/README.txt": "The gameplay videos are in assets/clips/ (not duplicated here to keep the zip small). "
        "Stills from each clip are in reference/screenshots/gameplay/.\n",
    "reference/README.txt": "screenshots/store: App Store screenshots (en-GB, iPhone and iPad) and in-app event art. screenshots/gameplay: "
        "stills from the clips. screenshots/shop: in-app purchase review screenshots. store_text: every store text file in the project "
        "(all languages), the store-art captions and the StoreKit configuration. No concept art or mood boards exist in the project.\n",
    "assets/audio/README.txt": "All audio is synthesized by Punch Mine/UI/Synth.swift (the app ships no audio files) and rendered here "
        "with the same seeds the game uses: 44.1 kHz, 16-bit, mono WAV. Music files are seamless loops (8 bars). 'volume' in the "
        "manifest is the in-game playback volume where it is not 1; music plays at 0.55 of the master in game.\n",
}
for rel, text in NOTES.items():
    os.makedirs(os.path.join(pkg, os.path.dirname(rel)), exist_ok=True)
    open(os.path.join(pkg, rel), "w").write(text)

# --- Manifest -----------------------------------------------------------------------------------------------------
seen = {}
for e in entries:
    e.setdefault("id", os.path.splitext(os.path.basename(e["path"]))[0])
    if e["id"] in seen:
        e["id"] = f'{e["category"]}_{e["id"]}'
    seen[e["id"]] = e["path"]
manifest = {
    "gameName": "Punch Mine",
    "engine": "SwiftUI (native iOS / iPadOS / macOS / visionOS app, no game engine): art drawn with SwiftUI Canvas, audio synthesized with AVAudioEngine",
    "orientation": "portrait",
    "designResolution": {"width": 1080, "height": 2346},
    "designResolutionNote": "SwiftUI layout is resolution-independent (points, not pixels). The gameplay clips are an iPhone 17 Pro Max screen "
                            "(440 x 956 pt, captured at 1320 x 2868) scaled to 1080 x 2346. App Store iPhone screenshots are 1179 x 2556. "
                            "Rendered backgrounds are 1080 x 1920.",
    "bundleId": "com.andreizaharia.punchmine",
    "version": "1.1 (2)",
    "assets": sorted(entries, key=lambda e: (e["category"], e["path"])),
}
open(os.path.join(pkg, "manifest.json"), "w").write(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")

# --- Checks -------------------------------------------------------------------------------------------------------
problems = []
m = json.load(open(os.path.join(pkg, "manifest.json")))
ids = [a["id"] for a in m["assets"]]
if len(ids) != len(set(ids)):
    problems.append("duplicate ids")
listed = set()
for a in m["assets"]:
    p = a["path"]
    listed.add(p)
    if p.startswith("/") or ".." in p.split("/") or "\\" in p:
        problems.append(f"bad path {p}")
    full = os.path.join(pkg, p)
    if not os.path.isfile(full):
        problems.append(f"missing {p}"); continue
    if a["category"] not in CATEGORIES:
        problems.append(f"bad category {p}")
    ext = os.path.splitext(p)[1].lower()
    if a["category"] == "audio" and ext not in (".wav", ".mp3", ".ogg", ".m4a"):
        problems.append(f"audio format {p}")
    if a["category"] == "clips" and ext not in (".mp4", ".mov"):
        problems.append(f"video format {p}")
    if ext == ".png":
        w, h, alpha = png_info(full)
        if (w, h) != (a["width"], a["height"]):
            problems.append(f"size mismatch {p}: {w}x{h} vs {a['width']}x{a['height']}")
        if "frameCount" in a and a["frameSize"]["width"] * a["frameCount"] != w:
            problems.append(f"sheet maths {p}")
        sprite = a["category"] in ("characters", "objects", "fx") or (a["category"] == "ui" and "/shop/" not in p)
        if sprite and not alpha:
            problems.append(f"sprite without alpha {p}")
        if "/backgrounds/" in p and (w, h) != (1080, 1920):
            problems.append(f"background not 1080x1920 {p}")
# Every asset and reference image/video in the package is listed.
for dirpath, _, files in os.walk(pkg):
    for f in files:
        rel = os.path.relpath(os.path.join(dirpath, f), pkg)
        if f == ".DS_Store" or "__MACOSX" in rel:
            problems.append(f"junk {rel}")
        if (rel.startswith("assets/") or rel.startswith("reference/")) and \
                os.path.splitext(f)[1].lower() in (".png", ".wav", ".mp4", ".mov") and rel not in listed:
            problems.append(f"not in manifest {rel}")
# Every assets/… or reference/… path quoted in the documents exists (globs allowed).
for doc in ("game_design.md", "visual_style.md", "store_info.md", "video_ideas.md", "README.md"):
    text = open(os.path.join(pkg, doc)).read()
    for q in set(re.findall(r"`((?:assets|reference)/[^`\s]+)`", text)):
        if not glob.glob(os.path.join(pkg, q)):
            problems.append(f"{doc} cites missing {q}")
    for q in set(re.findall(r"`((?:bg|block|popup|card|item|weekly_heart|sfx|music)_[a-z_*]+\.(?:png|wav))`", text)):
        if not glob.glob(os.path.join(pkg, "**", q), recursive=True):
            problems.append(f"{doc} cites missing file {q}")
for folder in ("assets/characters", "assets/objects", "assets/environment", "assets/ui", "assets/fx", "assets/audio/music",
               "assets/audio/sfx", "assets/branding", "assets/clips", "reference", "reference/store_text", "reference/gameplay"):
    if not os.path.isdir(os.path.join(pkg, folder)) or not os.listdir(os.path.join(pkg, folder)):
        problems.append(f"empty or missing folder {folder}")
if problems:
    print("\n".join("PROBLEM " + p for p in problems)); sys.exit(1)

# --- Zip ----------------------------------------------------------------------------------------------------------
zpath = os.path.join(args.out, NAME + ".zip")
if os.path.exists(zpath):
    os.remove(zpath)
with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
    for dirpath, dirs, files in os.walk(pkg):
        dirs.sort()
        for f in sorted(files):
            full = os.path.join(dirpath, f)
            rel = os.path.join(NAME, os.path.relpath(full, pkg))
            stored = os.path.splitext(f)[1].lower() in (".mp4", ".mov", ".png")
            z.write(full, rel, compress_type=zipfile.ZIP_STORED if stored else zipfile.ZIP_DEFLATED)
counts = {}
for a in m["assets"]:
    counts[a["category"]] = counts.get(a["category"], 0) + 1
print(json.dumps(counts))
print(f"{zpath} {os.path.getsize(zpath) / 1e6:.1f} MB, {len(m['assets'])} manifest entries")
