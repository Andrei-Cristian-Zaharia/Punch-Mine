# Punch Mine: Studio Export

The asset and information package for Asar Studio, built from the Punch Mine repository (version 1.1, build 2).

## What's inside

| Path | Contents |
|---|---|
| `manifest.json` | Every asset, screenshot and clip, with its category, role, size, sprite-sheet frames and audio loop/volume |
| `game_design.md` | Genre, core loop, controls, zones, blocks, bosses, upgrades, perks, rewards, events, wow moments, screen layout, numbers from code |
| `visual_style.md` | Palette with hex codes, art rules, typography, UI, animation, camera, music and SFX style |
| `store_info.md` | Store name, subtitle, texts, bundle ID, platforms, keywords, in-app purchases, and where the store text no longer matches the game |
| `video_ideas.md` | Five 30–40 s vertical video ideas, built from real moments and the files in this package |
| `assets/characters/` | The player fist, the 5 zone Hearts (full and low HP), 4 Weekly Heart variants, 6 event bosses, 8 pets, 3 miner badges |
| `assets/objects/` | Every block in the 5 zones, crack-stage strips, 5 treasure blocks, 6 event blocks, 45 original items by rarity |
| `assets/environment/` | 1080 × 1920 backgrounds per zone: the ground colour, a full block grid, and the area-100 Heart grid |
| `assets/ui/` | Currency icons, the Perk Coin, damage and coin popups, the Mythic relic cards, the boss name tag, shop product art |
| `assets/fx/` | Debris bursts (rock, treasure, Heart), the 7 break effects, the 8 fist-skin hit flashes, cracks, the impact star |
| `assets/audio/` | 5 zone music loops and 23 sound effects (WAV) |
| `assets/branding/` | Logo (transparent), logo on the game background, logo mark, app icon (plus rounded and 7 alternate icons), title card, App Store key art |
| `assets/clips/` | 10 real gameplay recordings (MP4, vertical, no audio) |
| `reference/` | App Store screenshots (iPhone and iPad, en-GB), in-app event art, shop review screenshots, gameplay stills, every store text file |

## How it was made

The game draws everything in code (SwiftUI `Canvas`) and synthesizes all of its sound, so the art and audio were rendered from the game's own source. Nothing was redrawn by hand. The scripts are kept in the repository at `Tools/studio_export/`:

- **`render_assets.sh` + `render.swift`:** compiles `Punch Mine/Game/*.swift` and the art files from `Punch Mine/UI/` for macOS. The copies are patched only to make a few private drawing functions callable. It renders the drawings to PNG with `ImageRenderer`.
  - Sprites use transparent backgrounds.
  - Effects are horizontal sprite strips, timed exactly like the game's animations (debris 0.6 s, hit flash 0.3 s).
  - The music loops and SFX come from `Synth.swift` with the same seeds as `SoundEngine.load`, written as 44.1 kHz 16-bit WAV.
- **`capture_clips.sh` + `make_capture_saves.py`:** builds the Debug app and records the iOS Simulator (iPhone 17 Pro Max).
  - It loads the save files used for the App Store screenshots (`Tools/store-screenshots/`), plus a Haunted Crypt variant.
  - The game's own debug helpers then play it (`-debugScreen autopunch`, `weeklyfight`, `reveal`, `conquest`).
- **`build_export.py`:** copies the icons, store art, screenshots and store texts from the repository, writes `manifest.json`, checks the package and zips it.
  - Checks: valid JSON, every path exists, unique ids, sprite-sheet maths, alpha on sprites, 1080 × 1920 backgrounds, file formats, no junk files, and every path quoted in these documents exists.
- **`make_export.sh <simulator udid>`:** runs all of the above. The zip lands in `export/`, which git ignores.

## Known gaps

- **No store links, support e-mail or age rating** in the project. They are marked "Not found in the project".
- **The store text is out of date.** It says four zones and 42 items; the code has five zones and 61 items (see `store_info.md`).
- **Items that nod to other games are left out.** 16 items reference Super Mario, Minecraft, Zelda, Dark Souls, Portal, Diablo or Hollow Knight by name and look, which is risky in ads. None of them is in this package; the docs only mention them.
- **The clips have no audio.** The simulator records picture only. Use `assets/audio/`.
- **Clips are 1080 × 2346** (iPhone aspect 9 : 19.5), not 1080 × 1920. Crop or letterbox them. They were re-encoded from the 1320 × 2868 recordings (`transcode.swift`).
- **The game plays itself in the clips.** The debug autopunch helper hits the weakest block every 90 ms, so the clips show no finger or touch indicator.
- **The `heart_conquest.mp4` crown card is debug-triggered.** Its "+100 Perk Coins" leaves out the zone multiplier that a real Heart kill applies.
- **Sample numbers.** Damage and coin popups in `assets/ui/popups/` use sample values in the game's number style. Real values depend on progress.
- **Weekly Heart colours.** The Weekly Heart is rendered in the Sunken Ruins palette. In game its colours follow the player's strongest zone.
- **No sprite or animation files.** The game has none. Animations (block squash, Heart pulse, damage-number rise) are SwiftUI animations; only debris, hit flashes and crack stages are exported as strips.
- **Not in the project:** concept art, mood boards, a trailer, a Google Play listing or an Android build.
- **No walking characters, tiles or parallax.** The game has none (see `assets/characters/README.txt` and `assets/environment/README.txt`).
