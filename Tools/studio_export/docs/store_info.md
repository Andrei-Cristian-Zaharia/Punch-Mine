# Punch Mine: Store info

Sources: `AppStore/Localization/en-GB.md` (primary store language), `Tools/store-screenshots/store_text.py` (store art captions),
`Config/PunchMine.storekit`, `Punch Mine/Game/Store.swift`, `Punch Mine.xcodeproj/project.pbxproj`.
Copies of every store text file are in `reference/store_text/`.

| Field | Value | Source |
|---|---|---|
| Store name | Punch Mine: Idle Mining Game | `AppStore/Localization/en-GB.md` (App Name) |
| Subtitle | Tap, Smash Rocks & Find Loot | `en-GB.md` (Subtitle) |
| Short / promo text | New zone: Sunken Ruins! Ride the high tide for ×2.5 rewards, break runestones that hit a whole row, and dig up Pearls and new relics. | `en-GB.md` (Promotional Text) |
| One-line hook | Punch rocks. Hire miners. Dig deeper. | first line of the `en-GB.md` description |
| Tagline | Smash. Loot. Conquer. | `store_text.py:18` (App Store header art) |
| Bundle ID / package name | com.andreizaharia.punchmine | `project.pbxproj` `PRODUCT_BUNDLE_IDENTIFIER` |
| Display name on device | Punch Mine | `project.pbxproj` `INFOPLIST_KEY_CFBundleDisplayName` |
| Version | 1.1 (build 2) | `project.pbxproj` `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION` |
| Platforms | iPhone, iPad, Mac (native macOS target), Apple Vision Pro (`TARGETED_DEVICE_FAMILY = 1,2,7`; `SUPPORTED_PLATFORMS = iphoneos iphonesimulator macosx xros xrsimulator`). iPhone is portrait only. No Android version in the project. | `project.pbxproj` |
| Category | Casual games (`public.app-category.casual-games`) | `project.pbxproj` `INFOPLIST_KEY_LSApplicationCategoryType` |
| Age rating | Not found in the project | |
| Price model | Free to play with optional in-app purchases and ads: rewarded ads you choose (Coin Rush, double earnings…) plus interstitial "break" ads between runs, removable with the Remove Ads purchase (AdMob, `Config/Info.plist` `GADApplicationIdentifier`) | `en-GB.md` description; `Punch Mine/Game/Ads.swift` |
| Store languages | English (U.K.), Chinese (Simplified), French, German, Japanese, Korean, Portuguese (Brazil), Romanian, Spanish (Mexico). The game UI itself is English only (`knownRegions = en, Base`). | `AppStore/Localization/*.md`; `project.pbxproj` |
| Support e-mail | Not found in the project (the support and privacy pages contain the placeholder `{{CONTACT_EMAIL}}`) | `AppStore/Web/support.html` |
| Support / privacy pages | Drafts only, no public URL: `AppStore/Web/support.html`, `AppStore/Web/privacy.html` | |
| App Store link | Not found in the project | |
| Google Play link | Not found in the project | |

## Keywords

From `en-GB.md` (100 / 100 bytes):

clicker, tapper, tycoon, dig, digger, ore, gold, gems, incremental, prestige, chest, cave, offline, miner, pickaxe

## App Store screenshot captions (en-GB)

`Tools/store-screenshots/store_text.py:10-15`. The matching images are in `reference/screenshots/store/`.

| # | Headline | Line | Badge |
|---|---|---|---|
| 1 | PUNCH ROCKS. GET RICH! | Tap to smash, hire a crew, dig deeper | IDLE + TAPPER |
| 2 | DEFEAT THE HEART | A giant boss waits at area 100 | BOSS FIGHT! |
| 3 | 4+ WORLDS TO CONQUER | Each with its own boss, music and loot | UNLOCK THEM ALL |
| 4 | LEGENDARY LOOT | 42+ items, 5 rarities, 3 chest types | LEGENDARY! |
| 5 | 25 PERKS TO MASTER | Prestige, ascend, get stronger | PRESTIGE & ASCEND |
| 6 | YOUR CREW DIGS FOR YOU | Miners earn while you're away | UP TO 4 H AWAY |

Search-results art: "TAP. SMASH. GET RICH!" (`store_text.py:17`).

## In-app purchases

Prices are the StoreKit test configuration's USD prices (`Config/PunchMine.storekit`). The live App Store prices are not in the project.

| Product ID | Name | Type | Price (USD) | Contents | Source |
|---|---|---|---|---|---|
| punchmine.removeads | Remove Ads | Non-consumable | 3.99 | No more ads between runs. Bonus ads you choose stay available. | `PunchMine.storekit`; `Store.swift` |
| punchmine.starterpack | Starter Pack | Non-consumable (once per player) | 1.99 | 1 Golden Chest, 3 Iron Chests, 500 Scrap and 200 Perk Coins | `PunchMine.storekit`; `Store.swift:92-100` |
| punchmine.scrap.small | Pile of Scrap | Consumable | 0.99 | 300 Scrap | `PunchMine.storekit` |
| punchmine.scrap.medium | Crate of Scrap | Consumable | 4.99 | 2,000 Scrap | `PunchMine.storekit` |
| punchmine.scrap.large | Cart of Scrap | Consumable | 9.99 | 5,000 Scrap (tagged "+25% EXTRA" in the shop, `Store.swift:78`) | `PunchMine.storekit` |
| punchmine.chests.iron5 | 5 Iron Chests | Consumable | 2.99 | Five Iron Chests | `PunchMine.storekit` |
| punchmine.chests.golden3 | 3 Golden Chests | Consumable | 4.99 | Three Golden Chests | `PunchMine.storekit` |
| punchmine.eventpass | Event Pass | Consumable (once per event) | 4.99 | Premium reward track of the current event and +50% event currency. Pays 3 Golden Chests if no event is running. | `PunchMine.storekit`; `Store.swift:52, 99-100`; `AppStore/Localization/WhatsNew-EventPass.md` |

## Store text vs. current code

The store text describes an earlier build. Check these before quoting the store text in a video:

- The description says "FOUR ZONES". The code has five: the Haunted Crypt was added (`Punch Mine/Game/Zones.swift:5`), and the en-GB What's New text announces it.
- The description says "42 items across 5 rarities". The code defines 61 items (`Punch Mine/Game/Items.swift:117-250`). 16 of them are named after other studios' games (Super Mario, Minecraft, Zelda, Dark Souls, Portal, Diablo, Hollow Knight). This package leaves those 16 out.
- "Up to 4 hours" away is the maximum: the base cap is 2 h, plus 0.5 h per Night Shift perk level, up to level 4 (`Punch Mine/Game/Perks.swift:111, 269-273`).
