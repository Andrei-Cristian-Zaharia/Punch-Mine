#!/usr/bin/env python3
"""In-app purchase art (1024 x 1024, no alpha): App Store promotional images and the Shop tiles in the game.

Writes AppStore/InAppPurchases/<product id>.png and the matching image sets in Assets.xcassets.
Same look as the app icon: sunburst, flat colors, bold dark outlines. No text, as Apple asks for promo images.
"""
import json, math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from compose import render, HERE

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "AppStore", "InAppPurchases", "promotional-images")
ASSETS = os.path.join(ROOT, "Punch Mine", "Assets.xcassets")
INK = "#1A120E"
S = 9  # outline width on the 1024 canvas


def gear(cx, cy, r, teeth=8, color="#C8D0DC", rot=0):
    pts = []
    for i in range(teeth * 4):
        a = math.radians(rot + i * 360 / (teeth * 4))
        rr = r if (i % 4) in (0, 1) else r * 0.76
        pts.append(f"{cx + rr * math.cos(a):.1f},{cy + rr * math.sin(a):.1f}")
    return (f'<polygon points="{" ".join(pts)}" fill="{color}" stroke="{INK}" stroke-width="{S}" stroke-linejoin="round"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{r*0.42:.1f}" fill="#8A94A2" stroke="{INK}" stroke-width="{S*0.8}"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{r*0.17:.1f}" fill="{INK}"/>'
            f'<path d="M{cx - r*0.55:.1f},{cy - r*0.2:.1f} A{r*0.6:.1f},{r*0.6:.1f} 0 0 1 {cx - r*0.1:.1f},{cy - r*0.6:.1f}" '
            f'stroke="#fff" stroke-opacity=".7" stroke-width="{r*0.09:.1f}" fill="none" stroke-linecap="round"/>')


CHESTS = {  # body, lid, bands, lock
    "wooden": ("#A86A36", "#C27C42", "#6A4020", "#FFC93C"),
    "iron": ("#8A96A6", "#AEB9C6", "#4A5260", "#FFC93C"),
    "golden": ("#F2B33C", "#FFD45E", "#B5741A", "#E8414A"),
}


def chest(x, y, w, kind="golden", rot=0):
    body, lid, band, lock = CHESTS[kind]
    k = w / 100
    return f'''<g transform="translate({x},{y}) rotate({rot}) scale({k}) translate(-50,-45)" stroke="{INK}" stroke-width="{S / k:.2f}" stroke-linejoin="round">
<rect x="0" y="36" width="100" height="50" rx="7" fill="{body}"/>
<path d="M0,38 L0,24 Q50,-6 100,24 L100,38 Z" fill="{lid}"/>
<rect x="13" y="12" width="9" height="74" fill="{band}"/><rect x="78" y="12" width="9" height="74" fill="{band}"/>
<rect x="41" y="30" width="18" height="22" rx="4" fill="{lock}"/>
<circle cx="50" cy="39" r="3" fill="{INK}" stroke="none"/><rect x="48.6" y="40" width="2.8" height="7" fill="{INK}" stroke="none"/>
<path d="M8,30 Q30,14 44,13" stroke="#fff" stroke-opacity=".55" stroke-width="5" fill="none" stroke-linecap="round"/>
</g>'''


def perk_coin(cx, cy, r):
    star = []
    for i in range(10):
        a = math.radians(-90 + i * 36)
        rr = r * (0.58 if i % 2 == 0 else 0.25)
        star.append(f"{cx + rr * math.cos(a):.1f},{cy + rr * math.sin(a):.1f}")
    return (f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="#7A4FE0" stroke="{INK}" stroke-width="{S}"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{r*0.8:.1f}" fill="none" stroke="#B89AFF" stroke-width="{r*0.08:.1f}"/>'
            f'<polygon points="{" ".join(star)}" fill="#F4ECFF" stroke="{INK}" stroke-width="{S*0.7}" stroke-linejoin="round"/>')


def sparkle(cx, cy, r):
    return (f'<path d="M{cx},{cy-r} Q{cx+r*0.18},{cy-r*0.18} {cx+r},{cy} Q{cx+r*0.18},{cy+r*0.18} {cx},{cy+r} '
            f'Q{cx-r*0.18},{cy+r*0.18} {cx-r},{cy} Q{cx-r*0.18},{cy-r*0.18} {cx},{cy-r} Z" fill="#fff"/>')


def shard(cx, cy, s, rot, color="#9A948E"):
    return (f'<rect x="{cx - s/2}" y="{cy - s/2}" width="{s}" height="{s}" rx="{s*0.18:.0f}" fill="{color}" stroke="{INK}" '
            f'stroke-width="{S*0.8}" transform="rotate({rot} {cx} {cy})"/>')


def remove_ads():
    return f'''
<g stroke="{INK}" stroke-width="{S}" stroke-linejoin="round">
  <rect x="232" y="292" width="560" height="380" rx="44" fill="#2E3440"/>
  <rect x="268" y="326" width="488" height="312" rx="22" fill="#F4F0E8"/>
  <polygon points="462,420 462,544 566,482" fill="#3FA0FF"/>
  <rect x="452" y="672" width="120" height="58" fill="#2E3440"/><rect x="372" y="724" width="280" height="40" rx="16" fill="#2E3440"/>
</g>
<circle cx="512" cy="480" r="300" fill="none" stroke="{INK}" stroke-width="96"/>
<circle cx="512" cy="480" r="300" fill="none" stroke="#FF5A3C" stroke-width="66"/>
<line x1="300" y1="268" x2="724" y2="692" stroke="{INK}" stroke-width="96" stroke-linecap="round"/>
<line x1="300" y1="268" x2="724" y2="692" stroke="#FF5A3C" stroke-width="66" stroke-linecap="round"/>
{sparkle(842, 190, 46)}{sparkle(176, 806, 34)}'''


def starter_pack():
    return (chest(330, 600, 330, "iron", -10) + chest(700, 610, 300, "iron", 9) + chest(520, 500, 430, "golden")
            + gear(250, 820, 92, rot=10) + gear(790, 840, 70, rot=25) + perk_coin(520, 805, 104)
            + sparkle(820, 250, 52) + sparkle(200, 300, 36) + sparkle(560, 180, 30))


def scrap_pile(n):
    layouts = {
        1: [(420, 600, 150, 0), (610, 640, 120, 18), (520, 470, 110, 8)],
    }
    g = "".join(gear(x, y, r, rot=a) for x, y, r, a in layouts[n])
    return g + shard(300, 720, 70, 20) + shard(740, 760, 56, -18) + sparkle(800, 300, 44) + sparkle(230, 330, 30)


def scrap_crate():
    planks = "".join(f'<rect x="250" y="{y}" width="524" height="92" fill="{c}" stroke="{INK}" stroke-width="{S}"/>'
                     for y, c in ((520, "#B9783E"), (612, "#A86A36"), (704, "#B9783E")))
    return (gear(380, 470, 120, rot=5) + gear(600, 440, 140, rot=20) + gear(500, 330, 100, rot=12) + gear(700, 520, 90, rot=33)
            + planks + f'<path d="M250,520 L774,796 M774,520 L250,796" stroke="#6A4020" stroke-width="30"/>'
            f'<rect x="250" y="520" width="524" height="276" fill="none" stroke="{INK}" stroke-width="{S*1.4}"/>'
            f'<rect x="226" y="500" width="572" height="36" rx="10" fill="#8A5A2C" stroke="{INK}" stroke-width="{S}"/>'
            + sparkle(840, 260, 46) + sparkle(190, 380, 32))


def scrap_cart():
    return (gear(330, 430, 120, rot=4) + gear(540, 360, 150, rot=22) + gear(740, 440, 120, rot=12) + gear(440, 280, 90, rot=30)
            + gear(650, 250, 80, rot=8) + gear(250, 330, 70, rot=18)
            + f'<g stroke="{INK}" stroke-width="{S}" stroke-linejoin="round">'
              f'<polygon points="170,470 854,470 790,720 234,720" fill="#7A8696"/>'
              f'<rect x="150" y="452" width="724" height="46" rx="14" fill="#5A6472"/>'
              f'<rect x="300" y="540" width="40" height="140" rx="10" fill="#5A6472"/><rect x="684" y="540" width="40" height="140" rx="10" fill="#5A6472"/>'
              f'<rect x="120" y="830" width="784" height="26" rx="10" fill="#6A4020"/>'
              f'<circle cx="330" cy="760" r="70" fill="#3A3F48"/><circle cx="330" cy="760" r="26" fill="#B8C0CC"/>'
              f'<circle cx="694" cy="760" r="70" fill="#3A3F48"/><circle cx="694" cy="760" r="26" fill="#B8C0CC"/></g>'
            + f'<path d="M210,520 L250,690" stroke="#fff" stroke-opacity=".45" stroke-width="16" stroke-linecap="round"/>'
            + sparkle(870, 200, 48) + sparkle(150, 220, 34))


def chest_stack(kind, layout):
    return "".join(chest(x, y, w, kind, r) for x, y, w, r in layout)


IRON5 = [(290, 690, 300, -6), (512, 700, 300, 0), (734, 690, 300, 6), (400, 470, 290, -4), (624, 470, 290, 4)]
GOLD3 = [(320, 640, 340, -8), (704, 640, 340, 8), (512, 430, 380, 0)]

PRODUCTS = {
    "punchmine.removeads": ("#3FA0FF", "#164A8A", "#081A33", remove_ads),
    "punchmine.starterpack": ("#FF9A3D", "#9A3A14", "#2A0E06", starter_pack),
    "punchmine.scrap.small": ("#B8D4F0", "#3A5A7A", "#0E1A26", lambda: scrap_pile(1)),
    "punchmine.scrap.medium": ("#FFC27A", "#7A4A24", "#1E1008", scrap_crate),
    "punchmine.scrap.large": ("#9AF0B0", "#2A6A44", "#08180E", scrap_cart),
    "punchmine.chests.iron5": ("#D8E4F2", "#4A5A70", "#10161E", lambda: chest_stack("iron", IRON5) + sparkle(860, 220, 46) + sparkle(170, 280, 34)),
    "punchmine.chests.golden3": ("#FFE07A", "#A8661A", "#2A1606", lambda: chest_stack("golden", GOLD3) + sparkle(850, 210, 54) + sparkle(170, 250, 40) + sparkle(512, 140, 30)),
}


def page(glow, mid, deep, art):
    return f'''<!doctype html><html><head><meta charset="utf-8"><style>*{{margin:0}}html,body{{width:1024px;height:1024px;overflow:hidden}}
body{{background:radial-gradient(circle at 50% 50%, {mid} 0%, {deep} 75%)}}
.rays{{position:absolute;inset:0;background:repeating-conic-gradient(from 0deg at 50% 50%, rgba(255,255,255,.09) 0deg 8deg, transparent 8deg 20deg)}}
.glow{{position:absolute;inset:0;background:radial-gradient(circle at 50% 52%, {glow}88 0%, transparent 55%)}}
svg{{position:absolute;inset:0}}</style></head><body><div class="rays"></div><div class="glow"></div>
<svg width="1024" height="1024" viewBox="0 0 1024 1024">{art()}</svg></body></html>'''


def asset_name(pid):
    return "product-" + pid.replace("punchmine.", "").replace(".", "-")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for pid, (glow, mid, deep, art) in PRODUCTS.items():
        png = os.path.join(OUT, f"{pid}.png")
        render(page(glow, mid, deep, art), png, 1024, 1024)
        d = os.path.join(ASSETS, asset_name(pid) + ".imageset")
        os.makedirs(d, exist_ok=True)
        os.system(f'sips -Z 360 "{png}" --out "{d}/{asset_name(pid)}.png" >/dev/null')
        json.dump({"images": [{"filename": f"{asset_name(pid)}.png", "idiom": "universal"}], "info": {"author": "xcode", "version": 1}},
                  open(os.path.join(d, "Contents.json"), "w"), indent=2)
        print("wrote", pid)
