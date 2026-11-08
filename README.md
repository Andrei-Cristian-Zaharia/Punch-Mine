# Punch Mine

Idle mining clicker for iPhone, iPad and Mac, written in SwiftUI: punch blocks, hire a crew of miners, and smash your way down five zones to the Heart waiting at area 100. Game design notes are in `Tools/studio_export/docs/game_design.md`; the logic tests run with `Tests/run-logic-tests.sh`.

## Director mode: scripted scenarios (Debug builds only)

Debug builds can start straight into a scripted gameplay scenario played by an autopilot, for recording promo footage. Everything lives in `Punch Mine/Director/` and is wrapped in `#if DEBUG`, so none of it exists in Release / App Store builds; the hooks in the rest of the app are `#if DEBUG` too.

A directed launch skips the splash, the consent form and ads, iCloud, Game Center, the store, the daily / event / zone pop-ups, tips and break ads. It plays on a fresh in-memory profile that is never saved, so it cannot touch real progress, and it needs no network. The upgrade drawer stays minimized so the grid is as large as possible.

| Scenario | What it shows | Default length | What the seed varies |
| --- | --- | --- | --- |
| `heartFight` | A zone's Heart at area 100 melts under hits, zaps, Titan punches, Fever Horn and Dynamite; the killing punch (strongest shake in the game, Heart burst), the crown card, then Endless Depths | 38 s | zone (all 5 Hearts), starting HP, kill time (23-29 s), loadout, fist skin, break effect, pet, autopilot style |
| `areaBlitz` | An area cleared every ~3 s: "Area N cleared!" banners, coins racing up, treasure, Fever, Dynamite, a boost from the stash | 35 s | zone, area (15-90), boost (Golden Pickaxe, Snowball, Time Bell), gadget timing, looks, style |
| `crystalChain` | Crystal Caverns with crystal-rich layouts: punches set off chains of cyan "CHAIN" hits through same-colour crystals | 30 s | area, layout (best of 12 for chains), Resonant Knuckles, looks, style |
| `highTide` | Sunken Ruins: the water floods the grid ("HIGH TIDE ×2.5"), runestones pulse along their rows, then a second tide | 35 s | area, first tide (3-7 s), gap to the second tide, looks, style |
| `magmaVents` | Magma Depths: vents charge and erupt twice, blocks regrow with health bars, Fever Horn | 30 s | area, eruption times, perks, looks, style |
| `weeklyHeart` | The 30-second Weekly Heart fight: TIER counting up, hit numbers, the timer ring, "TIME!" | 32 s | weekly twist (Armoured, Regenerating, Brittle, Phantom), Heart colours (zone), tier goal, tap rhythm |
| `quarryMining` | Plain mining in Pebble Quarry: the player punches next to Diggers, Drillers and Blasters, each area breaks in ~4 s and the next one drops in | 30 s | area (6-95), crew size, pet, looks, style, Dynamite or not |
| `cavernsMining` | The same in Crystal Caverns | 30 s | as above |
| `magmaMining` | The same in Magma Depths (one vent eruption) | 30 s | as above, eruption time |
| `ruinsMining` | The same in Sunken Ruins (one high tide) | 30 s | as above, tide time |
| `cryptMining` | The same in Haunted Crypt (ghosts fade and return) | 30 s | as above |

**Pacing.** Areas never drag: for each new area the pacer sets the punch power from that area's real HP so it breaks in the scenario's clear time (about 3-5 s), and corrects itself from how long the last area really took. The power comes from Starforged Fists levels (and Strength), the game's own uncapped multiplier, so every number on screen is real damage maths. The Heart is paced to fall at the planned kill time; the Weekly Heart to reach about the planned tier.

**Autopilot.** It plays through the same entry points as a finger: the grid's press / slide / release handlers (taps, holds, sweeps along rows or columns), the gadget buttons, the stash and the Weekly Heart's punch. Its plan is a seeded sequence of stretches (taps at 7.5-11 a second, holds, sweeps, short pauses under 0.5 s); it goes for treasure, runestones at high tide, the biggest crystal cluster and the Heart, avoids vents until they erupt and faded ghosts.

Launch arguments (`-key value` pairs land in `UserDefaults`):

- `-scenario <name>` — one of the names above, or `random` (the seed picks one).
- `-scenarioSeed <number>` — seeds everything: the zone, area and loadout, the terrain, every roll in play (crits, lucky coins, chests, zaps, hit positions) and the autopilot's plan. The same seed gives the same set-up and the same plan; without one, the clock picks it.
- `-scenarioDuration <seconds>` — how long the autopilot plays (default 40); afterwards the app idles while the miners keep digging.
- `-scenarioCapture <seconds>` — record this many seconds offline at exactly 60 fps (see below).
- `-scenarioZone <quarry|caverns|magma|ruins|crypt>` — `heartFight`, `areaBlitz`, `weeklyHeart`: force the zone.
- `-scenarioArea <n>` — mine scenarios except `heartFight`: force the starting area.
- `-scenarioStyle <tapper|holder|sweeper|focus>` — force the autopilot style.
- `-scenarioTwist <armoured|regenerating|critical|phasing>` — `weeklyHeart`: force the twist.
- `-scenarioDate <yyyy-MM-dd>` — the in-game date (seasonal event, weekly twist). Default: today at 12:00 UTC, so clips show the event that is live when they are recorded (the game always has one running) and a seed reproduces the same clip all day.

The app logs to stderr with the prefix `[Director]`: one `PLAN {json}` line before anything is recorded (scenario, key, parameters, movement), a `status` line every second (area, pace, punch power, coins, Fever, tide / vent / ghosts / Heart / tier, the current move), area clears and scripted beats, `CAPTURE …` lines and `WARNING …` lines for anything suspicious.

### Running locally

In Xcode: Product → Scheme → Edit Scheme… → Run → Arguments. The shared `Punch Mine` scheme lists `-scenario quarryMining`, `-scenarioSeed 1234` and `-scenarioDuration 30` (disabled); tick them, change the name, and run on an iPhone simulator in the Debug configuration.

From the command line, with a booted simulator and the Debug app installed:

```bash
xcrun simctl launch --console-pty booted com.andreizaharia.punchmine \
  -scenario heartFight -scenarioSeed 42 -scenarioDuration 50 -scenarioCapture 39
# … wait for "[Director] CAPTURE done", then:
open "$(xcrun simctl get_app_container booted com.andreizaharia.punchmine data)/Documents/DirectorCapture/capture.mp4"
```

With `-scenarioCapture <seconds>` the app runs on a virtual clock (exactly 1/60 s per frame), draws every frame, captures the key window itself and writes `Documents/DirectorCapture/capture.mp4` in its data container; the log ends with `[Director] CAPTURE done …` (or `CAPTURE failed …`). While capturing, SwiftUI animations are switched off and every moving effect (block squash, damage numbers, debris, screen shake, banners, toasts, waves, glows, the pet's bob, the crown card) is computed from the virtual clock, so a slow machine only makes the capture take longer, never the clip choppier. A screen recording of a GPU-less CI simulator only gets the ~30 frames per second it can draw in real time, which is why CI uses this mode. Without `-scenarioCapture` the scenario plays in real time with the normal animations.

### Recording in GitHub Actions

`.github/workflows/record-scenarios.yml` builds the Debug app for an iPhone SE simulator (750×1334, exactly 9:16) on a macOS runner, records each clip offline and uploads them as one artifact, `scenario-clips` (`<scenario>_seed<seed>.mp4` plus `manifest.json`, kept for 1 day). It only runs when triggered by hand:

- GitHub → Actions → **Record scenarios** → **Run workflow**, optionally setting `scenario` (`random` by default, one name, a comma list, or `all`), `count` (1-12 clips, default 5), `seed` (blank = a new seed every run) and `duration` (blank = the defaults above, a number for all, or `name=seconds` pairs).
- Or: `gh workflow run record-scenarios.yml -f scenario=all -f count=11`. To reproduce one clip: `-f seed=<its seed> -f count=1 -f scenario=<its scenario>`.

Each run logs its base seed (`Base seed: <n>` and a notice on the run page); clip *i* uses seed + *i*. A clip whose key (scenario + the parameters that change the picture) repeats an earlier clip of the same run is re-rolled with another seed (up to 6 times, then skipped with a warning). Every clip is encoded to 1080×1920 H.264 (high, yuv420p, CRF 18, faststart) at a constant 60 fps with no audio, and validated: it must decode cleanly, have the right format and length (±1 s), not be static, and show at least 55 unique frames per second in the gameplay area. Clips that fail go to the `rejected-clips` artifact instead; `clip-validation` always holds the summary and the Director logs. `manifest.json` lists every clip's seed, scenario, key, parameters, movement and validation result.

Download the clips from the run's page, or with `gh run download <run-id> -n scenario-clips`.
