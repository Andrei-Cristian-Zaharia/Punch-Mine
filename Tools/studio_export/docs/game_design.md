# Punch Mine: Game Design

All paths are relative to the repository root. `Game/…` and `UI/…` mean `Punch Mine/Game/…` and `Punch Mine/UI/…`.

## Genre & pitch

**Genre:** Idle / incremental tapper (mining clicker) with prestige, loot and boss fights, for iPhone, iPad and Mac.

**Pitch:** Punch rocks with your bare fists, hire a mining crew that keeps digging while you're away, and smash your way down through five zones to the giant Heart waiting at area 100.

## Core loop

1. **Punch blocks.** Each area is a 5 × 6 grid of blocks (`Game/Config.swift:6-7`). Tap a block to punch it. From area 2 you can hold to keep punching and slide between blocks (`Config.swift:29-31`).
2. **Break blocks for coins.** Every block has HP and armour and pays the zone's currency. Cracks appear at 75 / 50 / 25% HP (`Game/Models.swift:15-23`).
3. **Clear the area.** When every block is broken you get a clear bonus of 25% of the area's block rewards (`Config.swift:18`), and the next, tougher area appears.
4. **Spend coins on upgrades** in the drawer: Strength, Speed, crits, tools, miners and bonus upgrades (`Config.swift:298-418`, `Game/Zones.swift:236-374`).
5. **Hire miners** (Diggers, Drillers, Blasters). They hit blocks on their own and keep earning while you're away (`Config.swift:420-460`, `Game/Perks.swift:265-281`).
6. **Find treasure blocks and chests.** Open chests for items in 5 rarities (`Game/Items.swift`).
7. **Prestige** when progress slows (from area 12). Reset the zone's run for Perk Coins and buy permanent perks (`Game/Perks.swift:223-246`).
8. **Reach area 100 and defeat the zone's Heart** (`Game/Zones.swift:421-452`). This opens Endless Depths, a 25% coin bonus in every zone, and the next zone.
9. **Between runs:** daily rewards, the Weekly Heart challenge, seasonal events with their own boss, pets and cosmetics.

## Controls

- **Tap** a block to punch it. Taps count up to 12 per second (`Config.swift:28`).
- **Hold** (unlocks at area 2) to punch after 0.25 s at 4 punches/s, +0.3/s per Speed level. You can slide a held finger between blocks (`Config.swift:29-32`; `UI/MineView.swift:599-614`).
- **Tap-to-auto-punch** setting: a tap locks the block as the auto-punch target (`Game/GameModel.swift:524-536`).
- **Dynamite:** tap the gadget, then tap a block (`Game/Zones.swift:513`).
- **Fever Horn:** one tap to start Fever.
- **Upgrade drawer:** swipe or tap to expand, collapse or minimize. It has four tabs: Punch, Tools, Miners, Bonus (`UI/UpgradeDrawer.swift:4-22`).
- **Top-bar and strip buttons:** zone picker, items/backpack, daily gift, event, Weekly Heart, shop, settings (`UI/MineView.swift:250-469`).

## Main mechanics

- **Damage after armour:** `max(10% of punch, punch − armour × (1 − penetration))`. Penetration is capped at 90% (`Config.swift:115-118`).
  - Hits stuck at the 10% floor show **DEFLECT** (`Game/GameModel.swift:673-681`).
- **Strength:** punch = (1 + level) × 2^floor(level / 25) (`Config.swift:94-97`). Max level 100.
- **Crits:** 2% chance per Crit Chance level; ×2 damage plus 0.1 per Crit Damage level (`Config.swift:35-37`).
  - **Rhythm:** every (12 − level)th punch is a guaranteed crit (`Config.swift:64-65`).
- **Focus:** repeated hits on the same block stack +4% damage (`Config.swift:59-60`).
- **Fever:** 60 punches within 15 s starts 8 s of ×2 damage (`Config.swift:40-43`).
  - Breaking Coal or Brimstone adds 5 charge (`Config.swift:150`).
- **Treasure blocks:** a 15% chance per area from area 3. They have 3× HP and pay ×10 (`Config.swift:19-22`).
  - When only treasure is left, it collapses in 10 s unless you break it (`Config.swift:23`).
  - 35% of treasure breaks drop a chest (`Game/Items.swift:407`).
- **Tools:** each zone has 9 or 10 tools, bought in order. They add damage ×, penetration, splash, pierce (hits the block below), "lucky" double coins, and lightning that zaps random blocks every Nth punch (`Game/Zones.swift:236-374`).
- **Zone twists:** see Biomes below.
- **Gadgets:**
  - Dynamite: 3×3 blast for 8× punch, 45 s cooldown, from area 12.
  - Fever Horn: starts Fever, 90 s cooldown, from area 18 (`Game/Zones.swift:501-520`).
- **Titan Punch** (perk): every 20th punch is ×10 and ignores armour (`Game/Perks.swift:26`; `Game/GameModel.swift:662-667`).
- **Offline earnings:** miners earn 10–50% of their live rate while you're away. The cap is 2 h, plus 30 min per Night Shift level, up to 4 h (`Game/Perks.swift:265-281`).

## Biomes / Zones

Each zone is its own mine with its own currency, blocks, tools, music, upgrades and prestige (`Game/Zones.swift:3-57`). Every zone runs to area 100, where its Heart waits (`Zones.swift:113`).

| Zone | Currency | Twist | HP × / reward × | Unlock | Prestige × |
|---|---|---|---|---|---|
| Pebble Quarry | Copper Coins | Armour: Iron Ore deflects weak punches | 1 / 1 | Open from the start | 1.0 |
| Crystal Caverns | Crystal Shards | Crystals chain-break touching crystals of the same type (40% share, up to 3 steps, `Zones.swift:523-526`) | 2.5 / 2 | Clear Quarry area 25 + 150,000 Copper | 1.6 |
| Magma Depths | Ember Coins | Blocks left alone for 2 s heal back to their last crack (5%/s). Vents erupt every 25 s for 25% of their neighbours' HP (`Zones.swift:455-461`) | 5 / 4 | Clear Caverns area 25 + 300,000 Shards + 1,000,000 Copper | 2.5 |
| Sunken Ruins | Pearls | High tide every 40 s for 12 s: hits 25% weaker, blocks pay ×2.5. A broken runestone hits its whole row for 25% (`Zones.swift:464-482`) | 9 / 7 | Clear Magma area 25 + 600,000 Embers + 2,000,000 Shards | 4 |
| Haunted Crypt | Soul Coins | Ghost blocks are solid 6 s, then faded 4 s and can't be hit. Cursed urns pay ×3 but weaken your punches by 40% for 5 s (`Zones.swift:485-498`) | 15 / 11 | Clear Ruins area 40 + 40,000,000 Pearls + 80,000,000 Embers | 6 |

Sources: names, currencies and twists `Zones.swift:19-57`; multipliers `Zones.swift:72-89`; unlock `Zones.swift:386-403`; prestige `Zones.swift:145-153`.

Per-area growth: HP ×1.16–1.20 and rewards ×1.12–1.16 up to area 30. After area 30, every zone grows at ×1.11 HP and ×1.06 rewards (`Zones.swift:90-110`).

## Enemies / Creatures (blocks)

There are no walking enemies. The "opponents" are the blocks you punch. HP, armour and reward below are base values at area 1, before the zone and area multipliers (`Game/Config.swift:154-214`).

| Block | Zone | First area | Base HP | Armour | Reward | Note |
|---|---|---|---|---|---|---|
| Dirt | Pebble Quarry | 1 | 5 | 0 | 1 | |
| Stone | Pebble Quarry | 1 | 15 | 0 | 3 | |
| Iron Ore | Pebble Quarry | 6 | 50 | 5 | 10 | the zone's armour lesson |
| Copper Ore | Pebble Quarry | 6 | 30 | 2 | 18 | |
| Gold Ore | Pebble Quarry | 11 | 140 | 12 | 28 | |
| Coal | Pebble Quarry | 11 | 60 | 0 | 12 | +5 Fever charge |
| Granite | Pebble Quarry | 21 | 400 | 30 | 80 | |
| Silver Ore | Pebble Quarry | 26 | 260 | 18 | 60 | |
| Diamond | Pebble Quarry | 41 | 700 | 45 | 160 | |
| Mithril | Pebble Quarry | 61 | 1,500 | 80 | 380 | |
| Adamantite | Pebble Quarry | 81 | 3,000 | 130 | 800 | |
| Limestone | Crystal Caverns | 1 | 5 | 0 | 1 | |
| Quartz | Crystal Caverns | 1 | 15 | 0 | 3 | crystal, chains |
| Amethyst | Crystal Caverns | 6 | 50 | 5 | 10 | crystal, chains |
| Voidstone | Crystal Caverns | 11 | 140 | 12 | 28 | |
| Sapphire | Crystal Caverns | 31 | 450 | 25 | 110 | crystal, chains |
| Starstone | Crystal Caverns | 46 | 2,000 | 110 | 600 | |
| Basalt | Magma Depths | 1 | 5 | 0 | 1 | |
| Obsidian | Magma Depths | 1 | 15 | 3 | 3 | |
| Vent | Magma Depths | 1 | 50 | 5 | 10 | erupts every 25 s |
| Magma Core | Magma Depths | 6 | 50 | 5 | 10 | |
| Ember Ore | Magma Depths | 11 | 140 | 12 | 28 | |
| Heartstone | Magma Depths | 21 | 400 | 30 | 80 | |
| Brimstone | Magma Depths | 31 | 450 | 25 | 110 | +5 Fever charge |
| Dragonglass | Magma Depths | 46 | 2,000 | 110 | 600 | |
| Sand | Sunken Ruins | 1 | 5 | 0 | 1 | |
| Coral | Sunken Ruins | 1 | 15 | 0 | 3 | |
| Runestone | Sunken Ruins | 1 | 140 | 4 | 28 | hits its whole row when broken |
| Ruin Stone | Sunken Ruins | 6 | 50 | 6 | 10 | |
| Abyssite | Sunken Ruins | 11 | 400 | 32 | 80 | |
| Leviathan Bone | Sunken Ruins | 31 | 2,000 | 115 | 600 | |
| Grave Dirt | Haunted Crypt | 1 | 5 | 0 | 1 | |
| Bone Pile | Haunted Crypt | 1 | 15 | 0 | 3 | |
| Wraithstone | Haunted Crypt | 1 | 140 | 4 | 28 | ghost: fades out of reach |
| Tombstone | Haunted Crypt | 6 | 50 | 6 | 10 | |
| Cursed Urn | Haunted Crypt | 6 | 50 | 0 | 30 | pays ×3, weakens your punches |
| Soulstone | Haunted Crypt | 11 | 400 | 32 | 80 | |
| Lich Crystal | Haunted Crypt | 31 | 2,000 | 115 | 600 | |

First areas come from `ZoneID.mix(area:)`, `Game/Zones.swift:166-233`.

### Treasure blocks

| Block | Zone |
|---|---|
| Treasure | Pebble Quarry |
| Geode | Crystal Caverns |
| Fire Opal | Magma Depths |
| Giant Clam | Sunken Ruins |
| Reliquary | Haunted Crypt |

Treasure blocks have 3× HP, pay ×10 and glow gold (`Zones.swift:155-163`; `Config.swift:19-22`; `UI/BlockView.swift:75-85`).

### Miners (your helpers)

| Miner | Hit every | Damage factor | Armour felt | Hire costs (before ×1.5 shop scaling) | Unlock |
|---|---|---|---|---|---|
| Digger | 1 s | ×1 | 50% | 350 / 1,500 / 8,000 / 40,000 / 200,000 | area 4 |
| Driller | 3 s | ×4 | 25% | 2,000 / 15,000 / 90,000 | area 8 |
| Blaster | 5 s, 3×3 blast | ×3 | 50% | 25,000 / 250,000 | area 14 |

Sources: `Config.swift:53-55, 336-343, 420-460`.

### Pets

One pet is active at a time and gives a bonus (`Game/Pets.swift:22-31`).

| Pet | Bonus |
|---|---|
| Candy Bat | +2% crit chance |
| Snow Owl | +1% treasure chance |
| Lucky Cat | +10% coins |
| Spring Bunny | +2% lucky |
| Beach Crab | +15% treasure reward |
| Gold Mole | +5% miner speed |
| Rock Golem | +15% miner damage |
| Ember Fox | +1 s Fever |

## Bosses

| Boss | Where | HP | What makes it different |
|---|---|---|---|
| **Heart of the Quarry** | Pebble Quarry, area 100 | ≈5.9 B | Half the armour of the blocks around it |
| **Heart of the Caverns** | Crystal Caverns, area 100 | ≈12.4 B | Crystal chains that touch the Heart hit it too |
| **Heart of the Depths** | Magma Depths, area 100 | ≈29.5 B | Heals back to its last crack when left alone; every vent eruption heals it 5% |
| **Heart of the Ruins** | Sunken Ruins, area 100 | ≈74.3 B | Takes double damage at high tide; runestone pulses that cross it hit it too |
| **Heart of the Crypt** | Haunted Crypt, area 100 | ≈134 B | Fades out with the ghosts; punches in the first second after it returns always crit |
| **Weekly Heart** | Weekly challenge (from area 12) | 25 at tier 1, +18% per tier, up to tier 4,000 | 30-second fight against an endless stack of tiers. Weekly twists: Armoured, Regenerating, Brittle, Phantom |
| **The Pumpkin Lord** | Haunted Harvest event | your punch × 2,500 | 30 s fights, 2 free tries a day; damage carries over between fights |
| **The Frost Giant** | Frostfall event | same rules | |
| **The Golden Dragon** | Lantern Festival event | same rules | |
| **The Thorn Queen** | Spring Bloom event | same rules | |
| **The Kraken** | Sunny Splash event | same rules | |
| **The Gold Golem** | Gold Rush event | same rules | |

**Hearts**
- A Heart fills the centre 3 × 3 of the grid (`Game/Zones.swift:425-429`).
- Its HP is 25 × the area's average block HP (`Game/Models.swift:293-306`).
- The HP values above are computed by the game's own area generator at area 100 (`Tools/studio_export/render.swift`). The exact number depends on that area's block mix.
- Defeating a zone's first Heart gives:
  - its **Crown**: +25% coins in every zone,
  - 100 Perk Coins × the zone multiplier,
  - a Golden Chest,
  - a Mythic relic,
  - **Endless Depths**, with a 50% tougher Heart every 25 areas (`Zones.swift:421-452`; `Game/GameModel.swift:1201-1221`).
- Later Hearts give a **Crown Star**: +5% coins and 50 Perk Coins × the zone multiplier.
- Heart twists are at `Zones.swift:135-143`.

**Weekly Heart:** `Game/Weekly.swift:151-200`.

**Event bosses**
- Names are at `Game/Seasons.swift:80-85`. The rules are at `Seasons.swift:385-401`.
- An event boss pays phase rewards at 33%, 66% and 100% of its HP. The last phase gives 3 Golden Chests, the event title and the Heartbreaker fist skin.
- On screen, an event boss is the event block drawn big with the event colour (`UI/EventView.swift:361-393`).

## Upgrades / Workshop

Prices below are the base costs. Each upgrade's price is then scaled ×1.5, or ×2.5 for Bonus-tab upgrades (`Game/Config.swift:71-73, 378-406`).

| Upgrade | Tab | Unlock area | Max level | Base cost (L = current level) | Effect |
|---|---|---|---|---|---|
| Strength | Punch | 1 | 100 | 15 × 1.17^L | punch = (1+L)·2^⌊L/25⌋ |
| Speed | Punch | 2 | 20 | 40 × 1.25^L | +0.3 hold punches/s |
| Crit Chance | Punch | 6 | 15 | 120 × 1.32^L | +2% crit |
| Focus | Punch | 7 | 10 | 200 × 1.35^L | +2 focus stacks |
| Crit Damage | Punch | 9 | 20 | 300 × 1.28^L | +0.1× crit |
| Rhythm | Punch | 10 | 9 | 400 × 1.5^L | every (12−L)th punch crits |
| Hire Digger | Miners | 4 | 5 | 350 … 200,000 | +1 Digger |
| Miner Training | Miners | 4 | 50 | 100 × 1.18^L | +3 miner hit, +3% punch share |
| Shift Pace | Miners | 4 | 10 | 500 × 1.45^L | +4% miner speed |
| Hire Driller | Miners | 8 | 3 | 2,000 … 90,000 | +1 Driller |
| Hire Blaster | Miners | 14 | 2 | 25,000 / 250,000 | +1 Blaster |
| Deep Pockets | Bonus | 3 | 20 | 60 × 1.3^L (steeper after 10) | +5% coins |
| Treasure Hunter | Bonus | 5 | 10 | 200 × 1.35^L | +1% treasure chance |
| Fever Stamina | Bonus | 5 | 10 | 150 × 1.4^L | +0.5 s Fever |
| Overcharge | Bonus | 7 | 10 | 250 × 1.38^L | +0.1× Fever multiplier |
| Lockpick | Bonus | 8 | 10 | 500 × 1.4^L | +5% chance of a 2nd chest |
| Contracts | Bonus | 10 | 5 | 1,000 × 1.6^L | +5% clear bonus |

Sources:
- Unlock areas: `Config.swift:327-345`
- Max levels: `Config.swift:347-367`
- Costs: `Config.swift:385-406`
- Effects: `Config.swift:58-69`

### Tools (Tools tab)

Each tool replaces the last. These are the Pebble Quarry tools (`Game/Zones.swift:238-264`); every zone has its own list (`Zones.swift:236-374`).

| Tool | Cost | Unlock area | Effect |
|---|---|---|---|
| Brass Knuckles | 250 | 3 | ×1.5 damage |
| Pickaxe Gauntlet | 4,000 | 8 | ×1.5 damage, ignores 60% armour |
| Spiked Gloves | 15,000 | 12 | ×1.75 damage, 60% pen, +5% crit |
| Shockwave Glove | 40,000 | 16 | ×2 damage, 60% pen, 35% splash, +5% crit |
| Titan Fists | 400,000 | 24 | ×3 damage, 75% pen, 40% splash, +5% crit |
| Silver Knuckles | 600,000 | 32 | ×4 damage, 80% pen, 40% splash, 10% lucky double coins |
| Diamond Drill-Fist | 1,500,000 | 45 | ×6 damage, 85% pen, pierces the block below for 50% |
| Mithril Gauntlet | 6,000,000 | 60 | ×9 damage, 90% pen, 45% splash, pierce, 15% lucky, +10% crit |
| Thunder Fist | 20,000,000 | 75 | ×13 damage, pierce, lucky; every 10th punch zaps 3 blocks |
| Adamant Breaker | 80,000,000 | 90 | ×18 damage, 50% splash, pierce, 20% lucky; every 8th punch zaps 4 |

The final tools in the other zones are Celestial Prism, Heartforge, Poseidon's Fist and Phantom King's Fist. Each is ×22 damage and zaps 5 blocks every 7th punch (`Zones.swift:288-290, 315-317, 342-344, 369-371`).

## Perks / Power-ups

### Prestige perks (Perk Coins)

There are 25 perks in three branches: Power has 7, Industry 10 and Exploration 8 (`Game/Perks.swift:11-45`). Cost is round(base × rate^L) (`Perks.swift:124-150`).

- **Heavy Fists:** +10% punch damage per level (max 20).
- **Keen Eye:** +1% crit chance (max 10).
- **Brutal Crits:** +0.2× crit damage (max 5).
- **Piercer:** +3% armour penetration (max 10).
- **Resonant Knuckles:** stronger crystal chains (Caverns only).
- **Quarry Brawler:** +25% punch in Zone 1 only.
- **Titan Punch:** every 20th punch ×10 and ignores armour (capstone, 600 PC).
- **Foreman:** +15% miner damage (max 20).
- **Day-One Crew:** start each run with miners.
- **Double Shift:** miners swing 10% faster.
- **Treasure Crew:** miners can mine treasure.
- **Night Shift:** +30 min offline cap (max 4).
- **Overtime:** +5 points offline rate.
- **Toolsmith:** tools 8% cheaper.
- **Shared Drills:** miners use half your tool's penetration.
- **Gadgeteer:** gadget cooldowns −5%.
- **Cold Crew:** miner hits stop regrowth for 3 s (Magma only).
- **Seed Money:** start a run with 200 to 16,200 coins.
- **Scrapper:** +10% Scrap from chests.
- **Express Elevator:** start a run at area 1 + 2 × level.
- **Prospector:** treasure chance 15% + 3% per level.
- **Lucky Haul:** treasure pays +20%.
- **Chest Hunter:** +5% chance of a second treasure chest.
- **Surveyor:** −5% zone unlock costs.
- **Geode Sense:** Caverns treasure pays +50%.

**Prestige** is available from area 12.
- Perk Coins up to area 30 = floor(Z × 0.15 × (A − 5)²), where Z is the zone's prestige multiplier.
- Each area past 30 adds 3.75 × Z.
- A new record area adds a bonus of 2 × Z per area (`Perks.swift:223-246`).

### Ascension (from your first Crown)

**Star Perks** cost round(base × 1.12^L) (`Game/Ascension.swift:12-45`):

| Star Perk | Effect per level |
|---|---|
| Starforged Fists | ×(1 + 3%) punch |
| Star Crew | ×(1 + 3%) miner damage |
| Star Fortune | ×(1 + 3%) coins |
| Star Luck | +2% chest luck |
| Star Salvage | +5% Scrap |

**One-off Ascension perks** (`Ascension.swift:92-109`):

| Perk | Cost | Effect |
|---|---|---|
| Auto-Prestige | 2,500 PC | prestiges for you after 120 s without a new area |
| Union Contract | 1,800 PC | miners stay after prestige |
| Second Wind | 1,500 PC | Fever ×3 instead of ×2 |

### Boosts and gadgets (Stash consumables)

These come from events, rewards and ads (`Game/Consumables.swift:16-24, 72-79`).

| Consumable | Effect |
|---|---|
| Coin Rush Token | 600 s of ×2 coins |
| Fever Starter | starts Fever |
| Double Shift | doubles the next offline payout |
| Event Rush | 1,800 s of ×2 event currency |
| Snowball | punches ×3 for 15 s |
| Firework | hits a row and a column for 10× punch |
| Treasure Magnet | collects every treasure in the area |
| Golden Pickaxe | breaks pay ×5 for 20 s |
| Time Bell | miners swing twice as fast for 30 s |

## Treasure / Rewards

### Items

Items are equipped in 4 slots: helmet, belt, charm and boots (`Game/Items.swift:31`).

| Rarity | Max level |
|---|---|
| Common | 10 |
| Rare | 15 |
| Epic | 20 |
| Legendary | 25 |
| Mythic | 30 |

Source: `Items.swift:3-28`.

- Upgrades cost Scrap: round(base × 1.25^(level − 1)) (`Items.swift:74`).
- Each item rolls one bonus stat (affix) the first time it is found (`Items.swift:259-309`).
- **Sets** give extra bonuses at 2 and 4 pieces (`Items.swift:311-349`).
- **Forge:** 3 duplicates plus Scrap give an item one rarity up (`Items.swift:424-428`).

The code defines 61 items (`Items.swift:117-250`). 16 of them nod to other studios' games and are left out of this package. Examples of the original items:

| Item | Slot | Rarity | Effect |
|---|---|---|---|
| Miner's Helmet | helmet | Common | +10% miner damage |
| Crown of Embers | helmet | Epic | Fever ×(2.3) |
| Seer's Visor | helmet | Legendary | +0.5× crit damage |
| Titan Belt | belt | Legendary | +20% Strength bonus |
| Phoenix Feather | charm | Legendary | treasure pays +100% |
| Storm Charm | charm | Epic | zaps blocks every 15th punch |
| Quake Boots | boots | Epic | quake every 20th punch |
| Windwalkers | boots | Legendary | +4 Focus stacks |

**Mythic Heart relics**, dropped only by a zone's first Heart (`Items.swift:203-212`):

| Relic | Zone | Effect |
|---|---|---|
| Heartstone Buckle | Quarry | +50% punch |
| Prism Heart | Caverns | 12% double hit |
| Magma Treads | Magma | +60% miner damage |
| Tidecaller's Helm | Ruins | +40% coins |
| Lich's Lantern | Crypt | +1× crit damage |

### Chests

| Chest | Common / Rare / Epic / Legendary odds | Bonus Scrap |
|---|---|---|
| Wooden | 86 / 12.9 / 1 / 0.1% | 5 |
| Iron | 62 / 32.5 / 5 / 0.5% | 15 |
| Golden | 0 / 66 / 29 / 5% | 50 |

Source: `Items.swift:360-382`.

- **Bad-luck protection:** an Epic is guaranteed after 50 chests without one, and a Legendary after 250 (`Items.swift:419-420`).
- **Where chests come from:**
  - 35% of treasure breaks (12% of those are Iron)
  - an Iron Chest every record area divisible by 10
  - a Golden Chest per record Heart kill
  - the daily reward, the Weekly Heart, events and the shop (`Items.swift:407-413`; `Game/GameModel.swift:798-801, 868-869, 1217`)

### Daily login (7 days)

The daily reward unlocks at area 6 (`Game/Meta.swift:54-90`).

| Day | Reward |
|---|---|
| 1 | 1 Wooden |
| 2 | 60 Scrap |
| 3 | 2 Wooden |
| 4 | 1 Iron |
| 5 | 200 Scrap |
| 6 | 2 Iron |
| 7 | 1 Golden + 100 Scrap |

### Cosmetics

Cosmetics change looks only (`Game/Cosmetics.swift:46-102`):

- 8 fist skins: hit flash and tinted damage numbers
- 7 break effects: what blocks burst into
- 8 titles
- 7 alternate app icons

### Rewarded ads

Daily limits, 20 ads a day in total (`Game/Ads.swift:12-48`):

- **Coin Rush:** ×2 coins for 120 s, 6 a day
- **Double offline earnings**
- **Double treasure:** offered for 4 s, 5 a day
- **Chest upgrade:** Wooden→Iron or Iron→Golden, 3 a day
- **Free gadget:** 2 a day
- **Event Rush:** 3 a day
- **Double daily reward:** 1 a day
- **Extra Weekly Heart try** and **extra event boss try**

## Events

| Event | Window (UTC) | Event block | Currency | Boss | Mini-mine |
|---|---|---|---|---|---|
| **Haunted Harvest** | Oct 17 – Nov 8 | Pumpkin | Candy | The Pumpkin Lord | Candy Mine |
| **Frostfall** | Dec 5 – Jan 6 | Frost Shard | Snowflakes | The Frost Giant | Ice Cave |
| **Lantern Festival** | Lunar New Year −7 to +15 days | Red Lantern | Lucky Coins | The Golden Dragon | Lantern Vault |
| **Spring Bloom** | Mar 20 – Apr 21 | Bloom Bud | Petals | The Thorn Queen | Flower Mine |
| **Sunny Splash** | Jun 10 – Jul 11 | Seashell | Pearls | The Kraken | Tide Pools |
| **Gold Rush** | Aug 20 – Sep 21 | Lucky Nugget | Gold Dust | The Gold Golem | Panning Creek |

Sources: `Game/Seasons.swift:12-132`. Gaps of 7 days or more are filled by an Encore of an earlier event (`Seasons.swift:142-150, 252`).

- **Unlock:** events open at area 6 (`Seasons.swift:230`).
- **Event blocks:** 2 per area, in every zone (`Seasons.swift:228`).
- **Reward track:** 20 steps. The free track has chests, boosts and a 3-piece Legendary item set (`Seasons.swift:351-381`).
- **Event Pass track** adds:
  - a fist skin (step 1)
  - a break effect (step 5)
  - a pet (step 10)
  - an app icon (step 15)
  - Golden Chests
- **Event shop:** the event currency buys chests, boosts, pets and the Gold Rain break effect (`Seasons.swift:433-444`).
- **Weekly Heart:** runs Monday to Monday UTC with 3 free tries a day. Milestones pay out at 10, 25, 50 and 100 tiers. The Game Center leaderboard top 3 win the Golden Glove fist skin and the Weekly Champion title; 1st place also wins the Golden icon (`Game/Weekly.swift:151-223`).

## Top wow moments for video hooks

1. **Heart of the Quarry falls:** a glowing 3 × 3 heart block with a gold name tag takes up the middle of the grid.
   - On the killing punch the screen shakes at strength 14, the strongest shake in the game.
   - It bursts into 18 chunks and 14 gold sparkles, and the boss-defeat jingle plays (`UI/Feedback.swift:113-116, 263-298`; `UI/Synth.swift:82-87`).
   - Then a gold crown card appears: "Endless Depths open" (`UI/ZonesView.swift:243-300`).
   - Clip: `assets/clips/heart_fight.mp4`, `assets/clips/heart_conquest.mp4`.
2. **Dynamite:** tap the gadget, tap a block, and a 3×3 area takes 8× punch damage (`Game/Zones.swift:513, 519`).
   - Shake 10, heavy haptic and the boom sound (`UI/Feedback.swift:99-102`).
   - The autopunch helper fires it on punch 40 (`UI/MineView.swift:165-174`).
3. **Legendary chest reveal:** the item springs from 40% to full size with a rarity-coloured glow and the 6-note legendary chime (`UI/ItemsView.swift:434-488`; `UI/Synth.swift:98-101`). Clip: `assets/clips/chest_reveal.mp4`.
4. **High tide in the Sunken Ruins:** the water floods the grid and every block pays ×2.5 for 12 s. Runestones break and hit their whole row (`Game/Zones.swift:464-482`; `UI/MineView.swift:700-756`). Clip: `assets/clips/ruins_autopunch.mp4`.
5. **Crystal chain reaction:** one punch on a crystal chain-breaks up to 3 steps of touching crystals of the same colour, with cyan chain numbers and the glassy chime (`Game/Zones.swift:523-526`). Clip: `assets/clips/caverns_autopunch.mp4`.
6. **Weekly Heart, 30 seconds:** a giant heart cracks wider with every tier. "TIER n" counts up in huge type, and "TIME!" ends the run (`UI/WeeklyHeartView.swift:280-450`). Clip: `assets/clips/weekly_heart_fight.mp4`.
7. **From dirt to diamonds:** a fresh save punches 5-HP dirt for "+1" coins. The late-game clips show billions per Heart. The upgrade curve on screen is the game's own (`assets/clips/first_minute.mp4` vs `assets/clips/quarry_autopunch.mp4`).
8. **Titan Punch:** every 20th punch hits ×10 through armour with a "TITAN" number and shake 9 (`Game/GameModel.swift:662-681`; `UI/Feedback.swift:76-79`).

## Target audience

There is no explicit target-audience statement in the project. From the store category (casual games), the store keywords (clicker, tapper, tycoon, incremental, prestige, offline) and the description ("Short sessions or long ones, it all counts"), the game targets:
- casual and mid-core mobile players who like idle / incremental and clicker games,
- players who enjoy number-go-up progression, loot chests and prestige,
- players who check in for short sessions.

The age rating is not in the project.

## Gameplay screen layout

Measured on the iPhone 17 Pro Max simulator captures in `reference/screenshots/gameplay/` (1320 × 2868 px, 440 × 956 pt), with the upgrade drawer collapsed. The layout is from `UI/MineView.swift:33-64`. Coordinates are relative (0–1), origin top-left.

| Element | x | y | w | h | Notes |
|---|---|---|---|---|---|
| Status bar (iOS) | 0 | 0 | 1 | 0.05 | |
| Top bar: currency counter, Perk Coins, Coin Rush ×2, shop, settings | 0.03 | 0.055 | 0.94 | 0.07 | `MineView.swift:250-323` |
| Zone strip: zone picker, items, daily, event, Weekly Heart, "Area N / 100" + progress bar | 0.03 | 0.13 | 0.94 | 0.08 | `MineView.swift:325-469` |
| Block grid, the action (5 × 6, square cells) | 0.15 | 0.215 | 0.70 | 0.385 | `MineView.swift:472-650`; the Heart covers the centre 3 × 3; damage numbers can spill outside it |
| Status row: Fever bar, Prestige button, gadget buttons | 0.03 | 0.615 | 0.94 | 0.035 | `MineView.swift:794-865` |
| Upgrade drawer (collapsed): Punch / Tools / Miners / Bonus tabs + upgrade rows | 0 | 0.66 | 1 | 0.34 | `UI/UpgradeDrawer.swift`; 284 pt collapsed, slides up over the grid when expanded |
| Player input | – | – | – | – | anywhere on the grid: tap, hold, slide |

There is no player character on screen. The player is the finger: hits show as the block squashing, damage numbers, a fist-skin flash and debris.

# Appendix: numbers from code

| Value | Number | Source |
|---|---|---|
| Grid | 5 columns × 6 rows | `Punch Mine/Game/Config.swift:6-7` |
| Clear bonus | 25% of area rewards | `Config.swift:18` |
| Treasure chance / first area / HP × / reward × / collapse | 15% / 3 / 3 / 10 / 10 s | `Config.swift:19-23` |
| Damage floor / penetration cap | 10% / 90% | `Config.swift:26-27` |
| Tap cap | 12 per second | `Config.swift:28` |
| Hold unlock area / delay / base rate / per level | 2 / 0.25 s / 4 per s / +0.3 | `Config.swift:29-32` |
| Crit chance per level / base crit / per level | 2% / ×2 / +0.1 | `Config.swift:35-37` |
| Fever: punches / window / duration / multiplier | 60 / 15 s / 8 s / ×2 | `Config.swift:40-43` |
| Miner base hit / per Training / punch share | 5 / +3 / 30% (+3%) | `Config.swift:46-50` |
| Hire costs: Digger / Driller / Blaster | 350…200,000 / 2,000…90,000 / 25,000, 250,000 | `Config.swift:53-55` |
| Shop price scaling (normal / Bonus) | ×1.5 / ×2.5 | `Config.swift:72-73` |
| Block HP formula | baseHP × zone HP× × growth^(area−1) (late growth past 30) | `Config.swift:81-83` |
| Strength formula | (1 + L) × 2^⌊L/25⌋ | `Config.swift:94-97` |
| Damage after armour | max(0.1·raw, raw − armour·(1 − pen)) | `Config.swift:115-118` |
| Base HP / armour / reward per block | see table | `Config.swift:154-214` |
| Upgrade costs | see table | `Config.swift:385-406` |
| Miner intervals 1 / 3 / 5 s, damage ×1 / ×4 / ×3 | | `Config.swift:438-452` |
| Zone HP × 1 / 2.5 / 5 / 9 / 15 | | `Punch Mine/Game/Zones.swift:72-80` |
| Zone reward × 1 / 2 / 4 / 7 / 11 | | `Zones.swift:81-89` |
| HP growth 1.16–1.20, reward growth 1.12–1.16, late 1.11 / 1.06 | | `Zones.swift:90-110` |
| Prestige multiplier 1 / 1.6 / 2.5 / 4 / 6 | | `Zones.swift:145-153` |
| Zone unlock costs | | `Zones.swift:386-403` |
| Heart area / Endless Heart every / HP per block / toughening | 100 / 25 / ×25 / +50% | `Zones.swift:422-431` |
| Crown +25% coins, Star +5%, 100 / 50 Perk Coins | | `Zones.swift:434-437` |
| Magma regrow delay / rate / vent interval / vent share | 2 s / 5% per s / 25 s / 25% | `Zones.swift:455-461` |
| Tide interval / duration / damage / reward / Heart | 40 s / 12 s / ×0.75 / ×2.5 / ×2 | `Zones.swift:464-470` |
| Runestone share / Heart share | 25% / 3% | `Zones.swift:479-482` |
| Haunt solid / faded / return-crit window | 6 s / 4 s / 1 s | `Zones.swift:485-491` |
| Curse reward / damage / seconds | ×3 / ×0.6 / 5 s | `Zones.swift:494-498` |
| Dynamite cost / unlock / cooldown / multiplier | 5,000 ×1.5 / 12 / 45 s / ×8 | `Zones.swift:507-519` |
| Fever Horn cost / unlock / cooldown | 20,000 ×1.5 / 18 / 90 s | `Zones.swift:507-509` |
| Crystal chain share / steps | 40% / 3 | `Zones.swift:524-525` |
| Prestige first area | 12 | `Punch Mine/Game/Perks.swift:224` |
| Offline efficiency base / max, cap base / per Night Shift | 10% / 50%, 2 h / +0.5 h | `Perks.swift:267-273` |
| Star Perk cost growth | ×1.12 | `Punch Mine/Game/Ascension.swift:108` |
| Auto-Prestige idle time | 120 s | `Ascension.swift:109` |
| Chest odds | see table | `Punch Mine/Game/Items.swift:360-362` |
| Treasure → chest chance / Iron share | 35% / 12% | `Items.swift:407-409` |
| Epic / Legendary pity | 50 / 250 chests | `Items.swift:419-420` |
| Coin Rush ad | ×2 for 120 s, 6 a day | `Punch Mine/Game/Ads.swift:12, 44-45` |
| Weekly Heart unlock / fight / base HP / growth | area 12 / 30 s / 25 / ×1.18 | `Punch Mine/Game/Weekly.swift:151, 158, 165, 167` |
| Event blocks per area / unlock | 2 / area 6 | `Punch Mine/Game/Seasons.swift:228-230` |
| Event boss HP / free tries / fight | punch × 2,500 / 2 a day / 30 s | `Seasons.swift:388-391` |
| Screen shake: crit / treasure / dynamite / Heart | 2.5 / 4 / 10 / 14 | `Punch Mine/UI/Feedback.swift:80-116` |
| Debris life / chunks / Heart chunks | 0.6 s / 8 / 18 | `Feedback.swift:28, 263` |
| Music tempo: Quarry / Caverns / Magma / Ruins / Crypt | 100 / 84 / 112 / 72 / 76 BPM | `Punch Mine/UI/Synth.swift:302-320` |
