# Punch Mine: Visual style

All art in the game is drawn in code: SwiftUI `Canvas` paths, gradients and SF Symbols. All sound is synthesized at launch (`Punch Mine/UI/Synth.swift`); the app ships no sprite or audio files except the app icons and shop product images.

## Tone

Warm, chunky and cartoonish:
- A flat comic look: two-tone bodies, thick dark ink outlines, one white shine per object.
- Sparkles on valuable ores.
- Big rounded numbers that pop out of the blocks.

It reads like a cosy underground workshop: dark brown earth, glowing gold and copper, punchy hits with a little screen shake. Each zone shifts the palette:

| Zone | Mood | Colours |
|---|---|---|
| Pebble Quarry | warm earth | brown, copper |
| Crystal Caverns | cold | teal and violet |
| Magma Depths | hot | red and ember |
| Sunken Ruins | deep sea | blue and coral |
| Haunted Crypt | spooky | violet |

## Colour palette

### Interface (`Punch Mine/UI/Theme.swift:4-25, 343-348`)

| Name | Hex | Use |
|---|---|---|
| Ground | #18130F | Pebble Quarry background, launch screen |
| Panel | #241D18 | panels, drawer |
| Card | #2E251F | cards |
| Card raised | #3A2F26 | raised cards, locked tiles |
| Line | #4A3B2F | separators, borders |
| Text | #F5EDE3 | main text |
| Text muted | #C9B8A6 | secondary text |
| Text faint | #8F7D6C | hints |
| Copper | #E0843A | Pebble Quarry accent, copper coin |
| Copper dark | #8A4A1C | coin rim |
| Fever | #FF7A3D | Fever bar |
| Buy | #3E7A3A (shadow #24501F) | buy buttons |
| Miner | #2F6FB0 (light #A9D2FF) | miners, miner damage numbers |
| Crit | #FF8A3D | crit numbers |
| Gold | #F5C64F | treasure glow, crowns, Heart name tags |
| Crystal | #3FC1C9 | Crystal Caverns accent |
| Ember | #E2553A | Magma Depths accent, regrowth HP bar |
| Tide | #3FA6E8 | Sunken Ruins accent |
| Spirit | #A98CFF | Haunted Crypt accent |
| Perk | #7A55D6 (light #A98BFF, panel #2B2240, ground #15111F) | Perk Coins, perk screens |
| Ink (outlines) | #1A120E | every outline in blocks, items, logo, pets |

### Zone backgrounds and cards (`Theme.swift:153-220`)

| Zone | Ground | Panel | Card fill | Card edge | Accent |
|---|---|---|---|---|---|
| Pebble Quarry | #18130F | #241D18 | #2A2019 | #5A4130 | #E0843A |
| Crystal Caverns | #111719 | #1A2326 | #1A2426 | #2F5A5E | #3FC1C9 |
| Magma Depths | #1A100E | #261614 | #2A1614 | #6A2C20 | #E2553A |
| Sunken Ruins | #0C141C | #142028 | #14222E | #24506A | #3FA6E8 |
| Haunted Crypt | #100E16 | #1C1826 | #1E1A2A | #4A3A6E | #A98CFF |

### Heart (boss) palettes (`Punch Mine/UI/BlockView.swift:212-220`)

| Heart | Gradient (centre → edge) | Rim | Core |
|---|---|---|---|
| Quarry | #FF8A3D → #A8202A → #3A0810 | #FF5A3D | #FFD27A |
| Caverns | #9FF6FF → #3A6CD8 → #14163A | #6FE0E6 | #E4F0FF |
| Depths | #FFF0A0 → #FF6A1A → #3A0A04 | #FFB040 | #FFF6D0 |
| Ruins | #A8FFE0 → #2A9AB0 → #06203A | #5FE0C8 | #E8FFF8 |
| Crypt | #E8DCFF → #7A5AD8 → #1A0E3A | #B89AFF | #F4EEFF |

### Item rarity colours (`Punch Mine/UI/ItemsView.swift:3-13`)

| Rarity | Hex |
|---|---|
| Common | #B8B0A6 |
| Rare | #4FA3FF |
| Epic | #B06CFF |
| Legendary | #FFB020 |
| Mythic | #FF4A6A |

Chest colours (`ItemsView.swift:15-23`): Wooden #B8763A, Iron #A8B0BC, Golden #F5C64F.

### Event accents (`Punch Mine/Game/Seasons.swift:103-108`)

| Event | Hex |
|---|---|
| Haunted Harvest | #FF8A2A |
| Frostfall | #8FD8FF |
| Lantern Festival | #E8343A |
| Spring Bloom | #FF8AC8 |
| Sunny Splash | #3FD8E8 |
| Gold Rush | #E0A82A |

## Art rules

The block art is described in `Punch Mine/UI/OreArt.swift:3-160` and `OreRenderer`.

- **Grid:** shapes are drawn on a 56 × 56 grid and scaled. Blocks are rounded squares with a 10 pt corner radius.
- **Two-tone bodies:** a flat base colour with a darker band along the bottom, plus a light texture (dots, dashes, columns or tiny stars).
- **Deposits:** chunky deposits carry the material's identity in both shape and colour. Examples: nuggets for iron and gold, crystals for quartz, rings for mithril, coral, runes, skulls, tombstones, ghosts, urns.
- **Outlines:** bold dark ink #1A120E, about 1.6–2.4 units on the 56 grid. Line caps and joins are round.
- **Shading:** no gradients on blocks or items. Each object gets a single white highlight stroke for shine, and four-point white sparkles on valuable ores.
- **Glows:** soft coloured shadows only for things that matter:
  - treasure blocks: gold, radius 10
  - vents about to erupt: ember glow growing to radius 14
  - Hearts: rim colour, pulsing between radius 10 and 18
  - chest reveal: rarity colour, radius 28
- **Cracks:** bold black zig-zags that branch at 75 / 50 / 25% HP (`OreArt.swift:697-725`).
- **Items, pets, logo:** the same flat-plus-ink style (`UI/ItemArt.swift`, `UI/CosmeticArt.swift:104-197`, `UI/Logo.swift`).
- **Icons:** UI icons are SF Symbols, for example hammer.fill, screwdriver.fill and burst.fill for the miners, and flame.circle.fill and megaphone.fill for the gadgets.

## Typography

- **In game:** the system rounded font (SF Pro Rounded), always heavy (`Theme.swift:27-28`).
  - Display text is Black weight: currency counters, "Area N", damage numbers, banners.
  - Body text is Bold, Heavy or Black.
  - Numbers use monospaced digits in HP bars.
- **Logo wordmark:** "PUNCH / MINE" in black-weight SF Rounded.
  - Gold-to-copper vertical gradient: #FFF3B0 → #FFC93C → #E0843A.
  - Thick #1A120E outline plus a deeper drop shadow, and a white shine on the top 42% (`Logo.swift:43-73`).
- **App Store art:** Lilita One (display) and Nunito 800/900 (body), from Google Fonts (`Tools/store-screenshots/store_text.py:116-117`).
- **Damage numbers** (`UI/BlockView.swift:102-146`):
  - Black outline shadow offset 2 pt down.
  - Crits are 26 pt orange, tilted −8°. Normal hits are 19 pt white.
  - Coins are peach #FFD2A6, miner hits light blue #A9D2FF, chain hits cyan #9AF0F3.

## UI style

- Dark, warm panels with rounded corners (10–16 pt) and thin borders. Zone colours tint the wallet, tabs and progress bars.
- Buttons are chunky rounded rectangles; buy buttons are green with the zone currency icon.
- Pill-shaped status chips, for example "FOCUS +96%", "Tide in 25 s", "CURSED −40% · 5 s".
- **Currency icons** differ in shape as well as colour (`Theme.swift:222-341`):

  | Currency | Icon |
  |---|---|
  | Copper | round coin |
  | Crystal Shards | teal hexagon shard |
  | Ember Coins | red notched coin with a flame |
  | Pearls | white pearl in a blue ring |
  | Soul Coins | violet wisp on a dark coin |

- The upgrade drawer sits at the bottom with four tabs: Punch, Tools, Miners, Bonus.
- Full-screen sheets (items, perks, events) use the same dark ground.

## Animation feel

- **Every hit squashes the block** to 88% in 0.04 s, then springs back (response 0.22, damping 0.45) (`BlockView.swift:51-59`).
- **Damage numbers** rise 36 pt and fade over 0.85 s with ±10 pt horizontal jitter (`BlockView.swift:118-122`).
- **Debris:** a broken block throws 8 dark-edged chunks (18 for a Heart) that arc under gravity for 0.6 s. Treasure and Hearts add gold sparkles (`Feedback.swift:257-314`).
- **Screen shake:** a decaying wobble over 0.35 s (`Feedback.swift:151-216`). Strength by event: crit 2.5, zap 2, rune 3, treasure 4, vent 5, Titan 9, dynamite 10, Heart 14.
- **Hearts** breathe: their glow pulses over 1.1 s.
- **Banners and reveals** spring in: area-clear banner (response 0.3), chest reveal (0.45 / 0.6 damping), launch logo (0.5 / 0.7).
- **Reduced Motion** turns off shake, squash and debris.

## Camera

Fixed, front-on 2D. The 5 × 6 grid sits in the upper-middle of a portrait screen. There is no scrolling or zoom; the only camera motion is the screen shake. Expanding the upgrade drawer slides it up over the bottom of the grid.

## Music and SFX style

Everything is synthesized chiptune / soft-synth at 44.1 kHz mono. Each zone has a seamless 8-bar loop: bass, soft pad, plucked arpeggio, kick and optional shaker (`Synth.swift:282-388`).

| Zone | Music | Loop length |
|---|---|---|
| Pebble Quarry | bouncy A minor chiptune, 100 BPM | 19.2 s |
| Crystal Caverns | slow glassy D major-seventh bells, 84 BPM | 22.9 s |
| Magma Depths | driving E Phrygian with a four-on-the-floor kick, 112 BPM | 17.1 s |
| Sunken Ruins | slow watery C# minor with long sine bells, 72 BPM | 26.7 s |
| Haunted Crypt | slow D minor with a heavy pad and a heartbeat kick, 76 BPM | 25.3 s |

The SFX are layered from simple building blocks: a pitch-dropping "thump", noise clicks, crumbles, bells, chip-tune note runs, risers and bubbles (`Synth.swift:25-280`).
- Punches are short bassy thumps.
- Crits add a bell ping.
- Breaks crunch, with a soft, hard or crystal variant.
- Coins are a two-note chip blip.
- Treasure, area clear and Heart defeat are rising arpeggios.
- Chest openings get longer and brighter with rarity, up to a 6-note legendary chime with sparkles.
- Pitch variants (±8%) stop rapid punches from sounding mechanical.

In game the music plays at 0.55 × the master level of 0.7 (`UI/SoundEngine.swift:26, 42`).
