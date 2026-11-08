import SwiftUI
import AppKit

// Renders the Studio Export art and audio from the game's own drawing and synth code.
// Built by render_assets.sh together with Punch Mine/Game and the art files in Punch Mine/UI.
//   render <out dir>   writes PNGs and WAVs under <out dir>/assets and a list of them to <out dir>/rendered.json

let out = CommandLine.arguments[1]
var entries: [[String: Any]] = []

/// One block in the mine at iPhone Pro Max width: (440 − 2 × 16 − 4 × 6) / 5 ≈ 76 pt, see MineGrid in MineView.swift.
let side: CGFloat = 76
let gap: CGFloat = 6

/// 8-bit sRGB RGBA, so the PNGs open everywhere.
func eightBit(_ image: CGImage) -> CGImage? {
    guard let ctx = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    return ctx.makeImage()
}

func write(_ cg: CGImage, _ rel: String) {
    let url = URL(fileURLWithPath: out + "/" + rel)
    try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try! NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])!.write(to: url)
}

/// Renders `view` in a `w` × `h` pt frame at `scale` pixels per point (transparent unless the view paints a background).
@discardableResult
func png(_ view: some View, w: CGFloat, h: CGFloat, scale: CGFloat, _ rel: String, category: String, role: String,
         id: String? = nil, extra: [String: Any] = [:]) -> CGImage {
    // The app's text colour and dark scheme, as MineView sets them for everything inside it.
    let renderer = ImageRenderer(content: view.frame(width: w, height: h).foregroundStyle(Theme.text)
        .environment(\.colorScheme, .dark).environment(\.locale, Locale(identifier: "en_US")))
    renderer.scale = scale
    // Float rendering keeps soft glows smooth; 8-bit premultiplied output bands at low alpha.
    renderer.colorMode = .extendedLinear
    guard let float = renderer.cgImage, let cg = eightBit(float) else { fatalError("render failed: \(rel)") }
    write(cg, rel)
    var e: [String: Any] = ["path": rel, "category": category, "role": role, "width": cg.width, "height": cg.height]
    if let id { e["id"] = id }
    e.merge(extra) { a, _ in a }
    entries.append(e)
    return cg
}

/// Horizontal strip of `frames` frames, each drawn by `frame(i)` in a `w` × `h` pt cell.
func sheet(frames: Int, w: CGFloat, h: CGFloat, scale: CGFloat, fps: Int, loop: Bool, _ rel: String, category: String,
           role: String, extra: [String: Any] = [:], frame: @escaping (Int) -> some View) {
    let strip = HStack(spacing: 0) { ForEach(0..<frames, id: \.self) { i in frame(i).frame(width: w, height: h) } }
    var e = extra
    e["frameSize"] = ["width": Int(w * scale), "height": Int(h * scale)]
    e["frameCount"] = frames
    e["fps"] = fps
    e["loop"] = loop
    png(strip, w: w * CGFloat(frames), h: h, scale: scale, rel, category: category, role: role, extra: e)
}

func slug(_ s: String) -> String {
    var r = ""
    for ch in s {
        if ch.isUppercase { r += "_" + ch.lowercased() } else if ch.isLetter || ch.isNumber { r.append(ch) } else { r += "_" }
    }
    return r.replacingOccurrences(of: "__", with: "_").trimmingCharacters(in: CharacterSet(charactersIn: "_"))
}

func block(_ ore: Ore, id: Int = 7, hpFraction: Double = 1) -> Block {
    Block(id: id, material: ore, maxHP: 100, hp: 100 * hpFraction, armor: 0, reward: 0)
}

// MARK: - Which zone each block belongs to (from ZoneID.mix, areas 1–100)

var zoneOres: [ZoneID: [Ore]] = [:]
for zone in ZoneID.allCases {
    var seen: [Ore] = []
    for area in 1...100 { for (ore, _) in zone.mix(area: area) where !seen.contains(ore) { seen.append(ore) } }
    zoneOres[zone] = seen
}
func firstArea(_ ore: Ore, _ zone: ZoneID) -> Int { (1...100).first { a in zone.mix(area: a).contains { $0.0 == ore } } ?? 0 }

// MARK: - Blocks (objects)

for zone in ZoneID.allCases {
    for ore in zoneOres[zone]! {
        png(BlockView(block: block(ore), pulse: 0, reducedMotion: true, collapsing: false).frame(width: side, height: side),
            w: side + 20, h: side + 20, scale: 3, "assets/objects/blocks/\(zone.rawValue)/block_\(slug(ore.rawValue)).png",
            category: "objects", role: "\(ore.displayName) block (\(zone.name)), punched until it breaks",
            id: "block_\(slug(ore.rawValue))",
            extra: ["zone": zone.name, "firstArea": firstArea(ore, zone), "baseHP": ore.baseHP, "baseArmor": ore.baseArmor,
                    "baseReward": ore.baseReward])
    }
    let t = zone.treasureOre
    png(BlockView(block: block(t), pulse: 0, reducedMotion: true, collapsing: false).frame(width: side, height: side),
        w: side + 28, h: side + 28, scale: 3, "assets/objects/treasure/treasure_\(slug(t.rawValue)).png", category: "objects",
        role: "\(t.displayName): \(zone.name) treasure block (gold glow), pays ×\(Int(Config.treasureRewardMultiplier)) and can drop a chest",
        id: "treasure_\(slug(t.rawValue))", extra: ["zone": zone.name])
}
for season in SeasonID.allCases {
    let ore = season.ore
    png(BlockView(block: block(ore), pulse: 0, reducedMotion: true, collapsing: false).frame(width: side, height: side),
        w: side + 20, h: side + 20, scale: 3, "assets/objects/event_blocks/event_\(slug(ore.rawValue)).png", category: "objects",
        role: "\(ore.displayName): \(season.name) event block, drops \(season.currency)", id: "event_\(slug(ore.rawValue))")
}
// Vent about to erupt (Magma Depths) and a faded ghost (Haunted Crypt).
png(BlockView(block: block(.vent), pulse: 0, reducedMotion: true, collapsing: false, ventCharge: 1).frame(width: side, height: side),
    w: side + 40, h: side + 40, scale: 3, "assets/objects/blocks/magma/block_vent_charged.png", category: "objects",
    role: "Vent about to erupt (glow at full charge)", id: "block_vent_charged")
png(BlockView(block: block(.wraithstone), pulse: 0, reducedMotion: true, collapsing: false, faded: true).frame(width: side, height: side),
    w: side + 20, h: side + 20, scale: 3, "assets/objects/blocks/crypt/block_wraithstone_faded.png", category: "objects",
    role: "Wraithstone faded out of reach (25% opacity)", id: "block_wraithstone_faded")

// Crack stages 0–3 (at 100 / 75 / 50 / 25% HP), as a 4-frame strip, for a block from each zone.
for (zone, ore) in [(ZoneID.quarry, Ore.gold), (.caverns, .amethyst), (.magma, .magmaCore), (.ruins, .runestone), (.crypt, .tombstone)] {
    sheet(frames: 4, w: side + 20, h: side + 20, scale: 3, fps: 4, loop: false,
          "assets/objects/blocks/\(zone.rawValue)/block_\(slug(ore.rawValue))_cracks_sheet.png", category: "objects",
          role: "\(ore.displayName) cracking: intact, 75%, 50%, 25% HP",
          extra: ["id": "cracks_\(slug(ore.rawValue))"]) { i in
        BlockView(block: block(ore, id: 7, hpFraction: [1, 0.7, 0.45, 0.2][i]), pulse: 0, reducedMotion: true, collapsing: false)
            .frame(width: side, height: side)
    }
}

// MARK: - Bosses and characters

for zone in ZoneID.allCases {
    let blocks = AreaGenerator.blocks(zone: zone, area: Conquest.heartArea, seed: 1, treasureChance: 0)
    let heart = blocks[Conquest.heartIndex]
    let size = side * 3 + gap * 2
    png(HeartView(block: heart, zone: zone, rank: 0, pulse: 0, reducedMotion: true).frame(width: size, height: size),
        w: size + 40, h: size + 40, scale: 3, "assets/characters/bosses/\(zone.rawValue)_heart/\(zone.rawValue)_heart.png",
        category: "characters", role: "\(zone.heartName): \(zone.name) boss at area \(Conquest.heartArea), covers the centre 3×3 of the grid",
        id: "boss_\(zone.rawValue)_heart", extra: ["hp": heart.maxHP, "area": Conquest.heartArea, "twist": zone.heartTwist])
    var hurt = heart
    hurt.hp = heart.maxHP * 0.18
    png(HeartView(block: hurt, zone: zone, rank: 0, pulse: 0, reducedMotion: true).frame(width: size, height: size),
        w: size + 40, h: size + 40, scale: 3, "assets/characters/bosses/\(zone.rawValue)_heart/\(zone.rawValue)_heart_low_hp.png",
        category: "characters", role: "\(zone.heartName) at 18% HP (HP bar nearly empty)", id: "boss_\(zone.rawValue)_heart_low")
}
for season in SeasonID.allCases {
    png(BossArt(season: season, share: 0, reducedMotion: true).frame(width: 260, height: 278),
        w: 300, h: 318, scale: 3, "assets/characters/bosses/event_\(season.rawValue)/\(slug(season.bossName)).png",
        category: "characters", role: "\(season.bossName): \(season.name) event boss (30 s fights, full HP bar)",
        id: "boss_event_\(season.rawValue)")
}
for modifier in WeeklyModifier.allCases {
    png(WeeklyHeartArt(fight: WeeklyFight(modifier: modifier), palette: HeartView.palette(.ruins), reducedMotion: true)
            .frame(width: 340, height: 340),
        w: 340, h: 340, scale: 3, "assets/characters/bosses/weekly_heart/weekly_heart_\(modifier.rawValue).png", category: "characters",
        role: "Weekly Heart (\(modifier.name)), tier 1, in the Sunken Ruins palette (the palette follows the player's strongest zone)",
        id: "boss_weekly_\(modifier.rawValue)")
}
for pet in PetDef.all {
    png(PetArt(pet: pet, size: 64), w: 64, h: 64, scale: 4, "assets/characters/pets/pet_\(pet.id).png", category: "characters",
        role: "\(pet.name) pet (sits by the grid)", id: "pet_\(pet.id)")
}
for kind in MinerKind.allCases {
    png(MinerBadge(kind: kind), w: 32, h: 32, scale: 6, "assets/characters/miners/miner_\(kind.rawValue).png", category: "characters",
        role: "\(kind.name) miner badge (hired helper that hits blocks every \(Int(kind.interval)) s)", id: "miner_\(kind.rawValue)")
}
// The player is a fist: the only drawing of it is in the logo (LogoPainter.fist in Logo.swift).
png(Canvas { context, size in
        let s = size.width / 100
        var ctx = context
        ctx.translateBy(x: 40 * s, y: -40 * s)
        LogoPainter(context: ctx, s: s).fist()
    }, w: 100, h: 80, scale: 5.12, "assets/characters/player/player_fist.png", category: "characters",
    role: "Player: the punching fist with red cuff (drawn from the logo art; in play the player is the tap itself)",
    id: "player_fist")

// MARK: - Items

// Items that nod to other games (ItemDef.nod) are left out: their names and looks refer to other studios' games.
for def in ItemDef.all where def.nod == nil {
    png(ItemArt(itemID: def.id), w: 64, h: 64, scale: 4, "assets/objects/items/\(def.rarity.name.lowercased())/item_\(slug(def.id)).png",
        category: "objects", role: "\(def.name): \(def.rarity.name) \(def.slot.rawValue) item", id: "item_\(slug(def.id))",
        extra: ["rarity": def.rarity.name])
}
for def in ItemDef.all where def.rarity == .mythic {
    png(ItemIcon(def: def, size: 120), w: 120, h: 120, scale: 3, "assets/ui/item_cards/card_\(slug(def.id)).png", category: "ui",
        role: "\(def.name) on its Mythic rarity tile (as in the chest reveal)", id: "card_\(slug(def.id))")
}

// MARK: - UI

for zone in ZoneID.allCases {
    png(CurrencyIcon(zone: zone, size: 64), w: 64, h: 64, scale: 4, "assets/ui/currency/currency_\(zone.rawValue).png", category: "ui",
        role: "\(zone.currencyName) (\(zone.name) currency)", id: "currency_\(zone.rawValue)")
}
png(PerkCoinIcon(size: 64), w: 64, h: 64, scale: 4, "assets/ui/currency/perk_coin.png", category: "ui", role: "Perk Coin (prestige currency)",
    id: "perk_coin")
/// FloaterView's look (BlockView.swift:110-145) without its rise-and-fade animation.
func popup(_ text: String, _ kind: Floater.Kind) -> some View {
    let font: Font = switch kind {
    case .crit: Theme.display(26)
    case .coins: Theme.body(15, .heavy)
    case .miner, .weak, .chain: Theme.body(14, .heavy)
    case .hit: Theme.display(19)
    }
    let color: Color = switch kind {
    case .crit: Theme.crit
    case .coins: Color(hex: 0xFFD2A6)
    case .miner: Theme.minerLight
    case .chain: Color(hex: 0x9AF0F3)
    case .weak: Color(hex: 0xB9B1A8)
    case .hit: .white
    }
    return Text(text).font(font).lineLimit(1).fixedSize().foregroundStyle(color)
        .shadow(color: .black.opacity(0.8), radius: 0, x: 0, y: 2)
        .rotationEffect(.degrees(kind == .crit ? -8 : 0))
}
let popups: [(String, Floater.Kind, String, String)] = [
    ("popup_crit", .crit, "2.4K", "Crit damage number (sample value; −8° tilt, orange)"),
    ("popup_hit", .hit, "640", "Normal hit number (sample value)"),
    ("popup_titan", .crit, "TITAN 25K", "Titan Punch number (every 20th punch with the Titan Punch perk; sample value)"),
    ("popup_deflect", .weak, "DEFLECT", "Weak hit bounced off armour"),
    ("popup_phase", .weak, "PHASE", "Hit on a faded ghost block"),
    ("popup_coins", .coins, "+1.2K", "Coins from a broken block (sample value)"),
    ("popup_lucky", .coins, "LUCKY +2.4K", "Lucky double payout (sample value)"),
    ("popup_miner", .miner, "85", "Miner hit number (sample value)"),
    ("popup_chain", .chain, "320", "Crystal chain damage (sample value)"),
]
for (name, kind, text, role) in popups {
    png(popup(text, kind),
        w: 200, h: 60, scale: 3, "assets/ui/popups/\(name).png", category: "ui", role: role, id: name)
}
for (rel, text, role) in [("assets/ui/banners/heart_name_tag.png", "HEART OF THE QUARRY", "Boss name tag style")] {
    png(Text(text).font(Theme.body(11, .black)).tracking(0.3).padding(.horizontal, 8).padding(.vertical, 3)
            .background(Color.black.opacity(0.65), in: Capsule()).foregroundStyle(Theme.gold),
        w: 180, h: 26, scale: 4, rel, category: "ui", role: role)
}
// GameLogo's soft orange glow fringes on a transparent PNG, so the transparent logo is GameLogo's layout without the glow
// (Logo.swift:25-40), and the exact GameLogo goes on the game's ground colour.
let logoSize: CGFloat = 300
png(VStack(spacing: logoSize * 0.04) {
        LogoMark()
            .frame(width: logoSize * 0.62, height: logoSize * 0.62)
            .clipShape(RoundedRectangle(cornerRadius: logoSize * 0.14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: logoSize * 0.14, style: .continuous)
                .strokeBorder(Color(hex: 0x1A120E), lineWidth: max(2, logoSize * 0.018)))
        VStack(spacing: -logoSize * 0.05) {
            Wordmark(text: "PUNCH", size: logoSize * 0.24)
            Wordmark(text: "MINE", size: logoSize * 0.2)
        }
    }, w: 320, h: 340, scale: 3.2, "assets/branding/logo.png", category: "branding",
    role: "logo", id: "logo", extra: ["note": "Mark plus PUNCH MINE wordmark, transparent, without the in-game glow"])
png(ZStack { Theme.ground; GameLogo(size: logoSize) }, w: 360, h: 400, scale: 3, "assets/branding/logo_on_ground.png",
    category: "branding", role: "Logo exactly as in the app (GameLogo with its orange glow) on the Pebble Quarry ground", id: "logo_on_ground")
png(LogoMark(), w: 1024, h: 1024, scale: 1, "assets/branding/logo_mark_square.png", category: "branding",
    role: "Logo mark, full-bleed square (same drawing as the app icon)", id: "logo_mark")

// MARK: - Effects

// Rock debris from a broken block (DebrisLayer in Feedback.swift): 0.6 s, 12 frames at 20 fps.
func debrisFrame(_ burst: DebrisBurst, t: Double, w: CGFloat, h: CGFloat) -> some View {
    Canvas { context, size in
        let layer = DebrisLayer(side: side, gap: gap)
        let c = layer.center(burst.index)
        context.translateBy(x: size.width / 2 - c.x, y: size.height / 2 - c.y)
        layer.draw(burst, in: &context, at: burst.born.addingTimeInterval(t))
    }
}
let born = Date(timeIntervalSinceReferenceDate: 0)
let debrisLife = GameFeedback.debrisLife
for (zone, ore) in [(ZoneID.quarry, Ore.stone), (.quarry, .gold), (.caverns, .amethyst), (.magma, .magmaCore), (.ruins, .coral), (.crypt, .soulstone)] {
    let burst = DebrisBurst(id: 3, index: 0, colors: ore.debrisColors, born: born, scale: 1, sparkle: false)
    sheet(frames: 12, w: 320, h: 320, scale: 1.25, fps: 20, loop: false, "assets/fx/debris/debris_\(slug(ore.rawValue))_sheet.png",
          category: "fx", role: "\(ore.displayName) block shattering into chunks (\(zone.name))") { i in
        debrisFrame(burst, t: Double(i) / 20, w: 320, h: 320)
    }
}
let treasureBurst = DebrisBurst(id: 5, index: 0, colors: Ore.treasure.debrisColors + [Theme.gold], born: born, scale: 1, sparkle: true)
sheet(frames: 12, w: 320, h: 320, scale: 1.25, fps: 20, loop: false, "assets/fx/debris/debris_treasure_sheet.png", category: "fx",
      role: "Treasure block bursting with gold sparkles") { i in debrisFrame(treasureBurst, t: Double(i) / 20, w: 320, h: 320) }
let heartBurst = DebrisBurst(id: 9, index: Conquest.heartIndex, colors: Ore.heart.debrisColors, born: born, scale: 3, sparkle: true)
sheet(frames: 12, w: 640, h: 640, scale: 0.75, fps: 20, loop: false, "assets/fx/debris/debris_heart_sheet.png", category: "fx",
      role: "Heart defeated: big 18-chunk burst with 14 gold sparkles") { i in debrisFrame(heartBurst, t: Double(i) / 20, w: 640, h: 640) }
for c in Cosmetic.all where c.kind == .burst {
    let burst = DebrisBurst(id: 4, index: 0, colors: c.colors.map { Color(hex: $0) }, born: born, scale: 1, sparkle: false, shape: c.shape)
    sheet(frames: 12, w: 320, h: 320, scale: 1.25, fps: 20, loop: false, "assets/fx/break_effects/\(slug(c.id))_sheet.png", category: "fx",
          role: "\(c.name) break effect (cosmetic; \(c.source))") { i in debrisFrame(burst, t: Double(i) / 20, w: 320, h: 320) }
}
// Fist-skin flash where a punch lands: 0.3 s, 6 frames at 20 fps.
for c in Cosmetic.all where c.kind == .fist {
    let mark = ImpactMark(id: 1, index: 0, born: born, shape: c.shape, colors: c.colors.map { Color(hex: $0) })
    sheet(frames: 6, w: 120, h: 120, scale: 2, fps: 20, loop: false, "assets/fx/impacts/\(slug(c.id))_sheet.png", category: "fx",
          role: "\(c.name) fist skin hit flash (\(c.source))") { i in
        Canvas { context, size in
            let layer = DebrisLayer(side: side, gap: gap)
            let p = layer.center(0)
            context.translateBy(x: size.width / 2 - p.x, y: size.height / 2 - p.y)
            layer.draw(mark, in: &context, at: born.addingTimeInterval(Double(i) / 20))
        }
    }
}
for stage in 1...3 {
    png(Canvas { context, size in OreRenderer.drawCracks(stage: stage, seed: 7, in: &context, size: size) },
        w: side, h: side, scale: 3, "assets/fx/cracks/crack_stage\(stage).png", category: "fx",
        role: "Crack overlay, stage \(stage) (block at \([75, 50, 25][stage - 1])% HP)", id: "crack_stage\(stage)")
}
png(Canvas { context, size in
        let s = size.width / 40
        var ctx = context
        ctx.translateBy(x: -22 * s, y: -30 * s)
        LogoPainter(context: ctx, s: s).burst()
    }, w: 40, h: 40, scale: 10, "assets/fx/impacts/punch_impact_star.png", category: "fx",
    role: "Comic impact star (from the logo art)", id: "punch_impact_star")

// MARK: - Backgrounds and title card (1080 × 1920: 360 × 640 pt at 3×)

/// The 5 × 6 mine as MineGrid lays it out, on the zone's ground colour.
func minePlate(_ zone: ZoneID, area: Int) -> some View {
    let blocks = AreaGenerator.blocks(zone: zone, area: area, seed: 11, treasureChance: area < 3 ? 0 : 0.1)
    let s: CGFloat = 60
    return ZStack {
        zone.ground
        ZStack(alignment: .topLeading) {
            ForEach(blocks) { b in
                if b.material == .heart {
                    HeartView(block: b, zone: zone, rank: 0, pulse: 0, reducedMotion: true)
                        .frame(width: s * 3 + gap * 2, height: s * 3 + gap * 2)
                        .offset(x: CGFloat(b.id % 5 - 1) * (s + gap), y: CGFloat(b.id / 5 - 1) * (s + gap))
                } else if b.material != .heartPart {
                    BlockView(block: b, pulse: 0, reducedMotion: true, collapsing: false).frame(width: s, height: s)
                        .offset(x: CGFloat(b.id % 5) * (s + gap), y: CGFloat(b.id / 5) * (s + gap))
                }
            }
        }
        .frame(width: s * 5 + gap * 4, height: s * 6 + gap * 5, alignment: .topLeading)
    }
}
let plateAreas: [ZoneID: Int] = [.quarry: 12, .caverns: 12, .magma: 12, .ruins: 12, .crypt: 12]
for zone in ZoneID.allCases {
    png(zone.ground, w: 360, h: 640, scale: 3, "assets/environment/backgrounds/bg_\(zone.rawValue)_ground.png", category: "environment",
        role: "\(zone.name) mine background colour (full screen)", id: "bg_\(zone.rawValue)_ground")
    png(minePlate(zone, area: plateAreas[zone]!), w: 360, h: 640, scale: 3,
        "assets/environment/backgrounds/bg_\(zone.rawValue)_mine.png", category: "environment",
        role: "\(zone.name): full 5×6 block grid of area \(plateAreas[zone]!) on the zone ground (game's own area generator)",
        id: "bg_\(zone.rawValue)_mine", extra: ["biome": zone.name, "depth": plateAreas[zone]!])
    png(minePlate(zone, area: Conquest.heartArea), w: 360, h: 640, scale: 3,
        "assets/environment/backgrounds/bg_\(zone.rawValue)_heart_area.png", category: "environment",
        role: "\(zone.name) area \(Conquest.heartArea): the Heart in the middle of the grid", id: "bg_\(zone.rawValue)_heart_area",
        extra: ["biome": zone.name, "depth": Conquest.heartArea])
}
png(ZStack { Color(hex: 0x18130F); GameLogo(size: 230) }, w: 360, h: 640, scale: 3, "assets/branding/title_card.png",
    category: "branding", role: "Title card: the launch splash (logo on the Pebble Quarry ground)", id: "title_card")

// MARK: - Audio (Synth.swift, same seeds as SoundEngine.load)

func wav(_ samples: [Float], _ rel: String) -> Double {
    var data = Data()
    func le<T: FixedWidthInteger>(_ v: T) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
    let rate = UInt32(Synth.rate)
    data.append("RIFF".data(using: .ascii)!); le(UInt32(36 + samples.count * 2)); data.append("WAVEfmt ".data(using: .ascii)!)
    le(UInt32(16)); le(UInt16(1)); le(UInt16(1)); le(rate); le(rate * 2); le(UInt16(2)); le(UInt16(16))
    data.append("data".data(using: .ascii)!); le(UInt32(samples.count * 2))
    for s in samples { le(Int16(max(-1, min(1, s)) * 32_767)) }
    let url = URL(fileURLWithPath: out + "/" + rel)
    try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try! data.write(to: url)
    return (Double(samples.count) / Synth.rate * 100).rounded() / 100
}
let styles: [(ZoneID, Synth.MusicStyle, String)] = [
    (.quarry, .quarry, "bouncy A minor chiptune"), (.caverns, .caverns, "slow glassy D major-seventh bells"),
    (.magma, .magma, "driving E Phrygian, four-on-the-floor kick"), (.ruins, .ruins, "slow watery C# minor sine bells"),
    (.crypt, .crypt, "slow D minor, heavy pad, heartbeat kick"),
]
for (zone, style, mood) in styles {
    let rel = "assets/audio/music/music_\(zone.rawValue).wav"
    let d = wav(Synth.musicLoop(style), rel)
    entries.append(["path": rel, "category": "audio", "role": "music", "id": "music_\(zone.rawValue)", "loop": true,
                    "durationSec": d, "bpm": style.bpm, "biome": zone.name, "description": "\(zone.name) loop: \(mood)"])
}
/// In-game playback volume per cue (Feedback.swift `sound.play(…, volume:)`), where it isn't 1.
let cueVolume: [Synth.Cue: Double] = [.punch: 0.85, .minerTick: 0.45, .crunch: 0.8, .crunchHard: 0.8, .crunchCrystal: 0.8,
                                      .coin: 0.55, .lucky: 0.55, .clear: 0.9, .purchase: 0.8]
let cueRole: [Synth.Cue: String] = [
    .punch: "hit", .crit: "Critical hit", .deflect: "Punch deflected by armour", .titan: "Titan Punch (every 20th punch)",
    .minerTick: "Miner hit", .crunch: "Soft block breaks (dirt, sand, coal…)", .crunchHard: "Hard block breaks (stone, ores)",
    .crunchCrystal: "Crystal block breaks", .coin: "reward", .lucky: "Lucky double payout", .treasure: "Treasure block broken",
    .chain: "Crystal chain / ghosts fading", .zap: "Lightning zap / runestone pulse", .boom: "Dynamite explosion",
    .erupt: "Vent eruption / tide rising", .clear: "Area cleared", .fever: "Fever starts", .heart: "Heart defeated",
    .purchase: "Upgrade bought", .chestCommon: "Chest opens: Common item", .chestRare: "Chest opens: Rare item",
    .chestEpic: "Chest opens: Epic item", .chestLegendary: "Chest opens: Legendary item",
]
for (n, cue) in Synth.Cue.allCases.enumerated() {
    let rel = "assets/audio/sfx/sfx_\(slug(cue.rawValue)).wav"
    // The unpitched variant when there is one (index v of SoundEngine's seed n * 31 + v), else the first.
    let v = Synth.variants(cue).firstIndex(of: 1.0) ?? 0
    let d = wav(Synth.render(cue, pitch: Synth.variants(cue)[v], seed: UInt64(n * 31 + v)), rel)
    var e: [String: Any] = ["path": rel, "category": "audio", "role": cueRole[cue]!, "id": "sfx_\(slug(cue.rawValue))", "durationSec": d]
    if let v = cueVolume[cue] { e["volume"] = v }
    entries.append(e)
}

let json = try! JSONSerialization.data(withJSONObject: entries, options: [.prettyPrinted, .sortedKeys])
try! json.write(to: URL(fileURLWithPath: out + "/rendered.json"))
print("rendered \(entries.count) assets")
