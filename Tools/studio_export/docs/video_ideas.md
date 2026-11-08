# Punch Mine: Video ideas

Five short vertical videos (1080 × 1920, 30–40 s), built only from real moments in the game.

The clips in `assets/clips/` are 1080 × 2346 (an iPhone 17 Pro Max screen). Crop about 9% from the top and bottom to fit 1080 × 1920, or letterbox them. They have no sound, so lay the music and SFX from `assets/audio/` over them.

The store links are not in the project. Use the store name "Punch Mine: Idle Mining Game" in the CTA until a link exists.

---

## 1. "This is a boss. It's a giant heart."

- **Hook (0–2 s):** `assets/clips/heart_fight.mp4` starts mid-fight: the glowing Heart of the Ruins fills the middle of the grid while "ZAP 12.2M" and "TITAN" numbers fly.
- **What happens:**
  - **2–6 s:** cut to `assets/characters/bosses/quarry_heart/quarry_heart.png` scaling in on `assets/environment/backgrounds/bg_quarry_heart_area.png`, with the caption "Every mine ends at area 100…".
  - **6–24 s:** back to `heart_fight.mp4`. The HP bar drains under zaps, splash hits and Titan Punches.
  - **24–28 s:** overlay `assets/fx/debris/debris_heart_sheet.png` on the Heart and play `sfx_heart.wav`.
  - **28–34 s:** `assets/clips/heart_conquest.mp4`, the crown card ("Endless Depths open").
- **On-screen text:**
  - "A giant boss waits at area 100" (store caption)
  - "5 mines. 5 Hearts."
  - "Defeat it… then go deeper."
- **Assets:**
  - `assets/clips/heart_fight.mp4`
  - `assets/clips/heart_conquest.mp4`
  - `assets/characters/bosses/quarry_heart/quarry_heart.png`
  - `assets/characters/bosses/magma_heart/magma_heart.png`
  - `assets/characters/bosses/crypt_heart/crypt_heart.png`
  - `assets/environment/backgrounds/bg_quarry_heart_area.png`
  - `assets/fx/debris/debris_heart_sheet.png`
  - `assets/audio/sfx/sfx_heart.wav`
  - `assets/audio/music/music_magma.wav`
- **CTA:** "Punch Mine: Idle Mining Game. Free on the App Store." End on `assets/branding/logo.png` over `assets/branding/title_card.png`.

---

## 2. "From punching dirt to billions"

- **Hook (0–2 s):** `assets/clips/first_minute.mp4`: an empty grid, a tiny "2" over a dirt block. Caption: "Day 1: 2 damage."
- **What happens:**
  - **2–10 s:** the first minute. Dirt and stone break, "+1" coins pop, and the Fever tip appears.
  - **10–12 s:** a hard cut on the punch sound.
  - **12–30 s:** `assets/clips/quarry_autopunch.mp4`. The same Pebble Quarry with millions of copper, gold and silver ores shattering, crits and Dynamite.
  - **30–36 s:** end card.
- **On-screen text:**
  - "Area 1: 2 damage per punch"
  - "Area 38: …" (read the real numbers off the clip)
  - "Tap. Upgrade. Hire a crew."
  - "Punch rocks. Get rich!" (store caption)
- **Assets:**
  - `assets/clips/first_minute.mp4`
  - `assets/clips/quarry_autopunch.mp4`
  - `assets/ui/currency/currency_quarry.png`
  - `assets/ui/popups/popup_crit.png`
  - `assets/audio/sfx/sfx_punch.wav`
  - `assets/audio/sfx/sfx_coin.wav`
  - `assets/audio/music/music_quarry.wav`
- **CTA:** "Start punching: Punch Mine on the App Store" over `assets/branding/logo_on_ground.png`.

---

## 3. "Five mines, five rules"

- **Hook (0–2 s):** a fast five-way split of `bg_quarry_mine.png`, `bg_caverns_mine.png`, `bg_magma_mine.png`, `bg_ruins_mine.png` and `bg_crypt_mine.png`, each with its currency icon. Caption: "Every mine fights back."
- **What happens:** a 6 s beat per zone, each with its zone music loop and its rule as a caption.
  1. **Pebble Quarry:** `quarry_autopunch.mp4`, "Iron armour deflects weak punches" with `popup_deflect.png`.
  2. **Crystal Caverns:** `caverns_autopunch.mp4`, "Crystals chain-break their neighbours".
  3. **Magma Depths:** `magma_autopunch.mp4`, "Magma regrows and vents erupt" with `block_vent_charged.png` and `sfx_erupt.wav`.
  4. **Sunken Ruins:** `ruins_autopunch.mp4`, "High tide: blocks pay ×2.5".
  5. **Haunted Crypt:** `crypt_autopunch.mp4`, "Ghosts fade out of reach".
- **On-screen text:** each zone's twist, word for word from `Punch Mine/Game/Zones.swift:49-57`. End line: "Each with its own boss, music and loot" (store caption).
- **Assets:**
  - Clips:
    - `assets/clips/quarry_autopunch.mp4`
    - `assets/clips/caverns_autopunch.mp4`
    - `assets/clips/magma_autopunch.mp4`
    - `assets/clips/ruins_autopunch.mp4`
    - `assets/clips/crypt_autopunch.mp4`
  - Backgrounds: `assets/environment/backgrounds/bg_*_mine.png`
  - Currency icons: `assets/ui/currency/currency_*.png`
  - Effects: `assets/objects/blocks/magma/block_vent_charged.png`, `assets/ui/popups/popup_deflect.png`
  - Music: `assets/audio/music/music_*.wav`
- **CTA:** "Which mine would you clear first? Punch Mine, free on the App Store."

---

## 4. "Bad luck? Guaranteed Legendary."

- **Hook (0–2 s):** `assets/clips/chest_reveal.mp4`. The Golden Chest opens and the item springs up with a gold glow. Caption: "LEGENDARY!"
- **What happens:**
  - **2–8 s:** the full reveal: Windwalkers, "Bad-luck protection kicked in", +4 Focus stacks.
  - **8–20 s:** a carousel of real item art on rarity colours:
    - `assets/objects/items/legendary/item_seers_visor.png`
    - `item_titan_belt.png`
    - `item_phoenix_feather.png`
    - `assets/objects/items/epic/item_crown_of_embers.png`
  - **20–28 s:** the five Mythic relic cards (`assets/ui/item_cards/card_*.png`) with "Mythic relics drop only from a zone's Heart".
  - **28–34 s:** end card.
- **On-screen text:**
  - "Wooden, Iron and Golden chests"
  - "5 rarities: Common → Mythic"
  - "A Legendary is guaranteed within 250 chests" (`Punch Mine/Game/Items.swift:420`)

  Don't quote "42+ items": see `store_info.md`.
- **Assets:**
  - `assets/clips/chest_reveal.mp4`
  - `assets/objects/items/legendary/*.png`
  - `assets/ui/item_cards/card_heartstone_buckle.png`
  - `assets/ui/item_cards/card_prism_heart.png`
  - `assets/ui/item_cards/card_magma_treads.png`
  - `assets/ui/item_cards/card_tidecaller_helm.png`
  - `assets/ui/item_cards/card_lich_lantern.png`
  - `assets/audio/sfx/sfx_chest_legendary.wav`
  - `assets/audio/sfx/sfx_chest_epic.wav`
- **CTA:** "Open your first chest: Punch Mine on the App Store."

---

## 5. "30 seconds. How many tiers can you break?"

- **Hook (0–2 s):** `assets/clips/weekly_heart_fight.mp4`. The countdown ring and a huge "TIER" number climbing while "1.4M!" crit pops burst off the Heart.
- **What happens:**
  - **2–26 s:** the Weekly Heart run. Tiers go up while the timer ring runs out.
  - Overlay the four weekly twists as cards:
    - `assets/characters/bosses/weekly_heart/weekly_heart_armoured.png`
    - `weekly_heart_regenerating.png`
    - `weekly_heart_critical.png`
    - `weekly_heart_phasing.png`
  - **26–32 s:** results ("TIME!") and the caption "Top 3 on the Game Center leaderboard win the Golden Glove".
  - **32–36 s:** end card.
- **On-screen text:**
  - "New twist every week" (Armoured, Regenerating, Brittle, Phantom)
  - "30 seconds"
  - "Beat your friends on Game Center"
- **Assets:**
  - `assets/clips/weekly_heart_fight.mp4`
  - `assets/characters/bosses/weekly_heart/*.png`
  - `assets/fx/impacts/fist_golden_sheet.png`
  - `assets/audio/sfx/sfx_crit.wav`
  - `assets/audio/sfx/sfx_clear.wav`
  - `assets/audio/music/music_magma.wav`
- **CTA:** "Take your shot this week. Punch Mine, free on the App Store."
