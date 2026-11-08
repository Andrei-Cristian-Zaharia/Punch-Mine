"""Builds the alternate app icons (seasonal and Weekly Heart champion) from the main icon.

Each is the main icon re-tinted with a CSS filter plus a themed frame and corner badge, rendered by headless
Chrome. Writes AppIcon-<Name>.appiconset (the icon) and IconPreview-<Name>.imageset (for the Style screen).
Run: python3 Tools/make_alt_icons.py
"""
import base64, json, os, shutil, subprocess, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "store-screenshots"))
from compose import render

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "Punch Mine", "Assets.xcassets")
SRC = os.path.join(ASSETS, "AppIcon.appiconset", "icon-ios-1024.png")

# name: (CSS filter on the icon, frame color, badge svg)
ICONS = {
    "Pumpkin": ("hue-rotate(-10deg) saturate(1.5) brightness(0.95)", "#FF8A2A",
                '<circle cx="50" cy="56" r="34" fill="#FF8A2A" stroke="#1A120E" stroke-width="6"/>'
                '<path d="M50 22 q4 -12 14 -14" stroke="#4E8A2E" stroke-width="7" fill="none" stroke-linecap="round"/>'
                '<path d="M34 50 l8 -10 l8 10z M58 50 l8 -10 l8 10z" fill="#FFE85A"/>'
                '<path d="M32 64 q18 16 36 0 l-6 2 l-6 -4 l-6 4 l-6 -4 l-6 4z" fill="#FFE85A"/>'),
    "Frost": ("hue-rotate(170deg) saturate(0.7) brightness(1.15)", "#8FD8FF",
              '<g stroke="#1A120E" stroke-width="12" stroke-linecap="round">'
              '<path d="M50 14v72M19 32l62 36M19 68l62-36"/></g>'
              '<g stroke="#FFFFFF" stroke-width="6" stroke-linecap="round"><path d="M50 14v72M19 32l62 36M19 68l62-36"/></g>'),
    "Lantern": ("hue-rotate(-25deg) saturate(1.8) contrast(1.05)", "#E8343A",
                '<rect x="38" y="8" width="24" height="10" rx="3" fill="#FFC93C" stroke="#1A120E" stroke-width="5"/>'
                '<ellipse cx="50" cy="50" rx="34" ry="30" fill="#E8343A" stroke="#1A120E" stroke-width="6"/>'
                '<path d="M38 22 q-12 28 0 56 M62 22 q12 28 0 56" stroke="#9A1A20" stroke-width="4" fill="none"/>'
                '<rect x="38" y="78" width="24" height="10" rx="3" fill="#FFC93C" stroke="#1A120E" stroke-width="5"/>'),
    "Bloom": ("hue-rotate(-60deg) saturate(1.3) brightness(1.08)", "#FF8AC8",
              '<g fill="#FF8AC8" stroke="#1A120E" stroke-width="5">'
              '<circle cx="50" cy="26" r="16"/><circle cx="74" cy="44" r="16"/><circle cx="64" cy="72" r="16"/>'
              '<circle cx="36" cy="72" r="16"/><circle cx="26" cy="44" r="16"/></g>'
              '<circle cx="50" cy="50" r="13" fill="#FFD25A" stroke="#1A120E" stroke-width="5"/>'),
    "Sun": ("hue-rotate(155deg) saturate(1.4) brightness(1.12)", "#3FD8E8",
            '<g stroke="#1A120E" stroke-width="12" stroke-linecap="round"><path d="M50 8v14M50 78v14M8 50h14M78 50h14M20 20l10 10M70 70l10 10M80 20l-10 10M30 70l-10 10"/></g>'
            '<g stroke="#FFC93C" stroke-width="6" stroke-linecap="round"><path d="M50 8v14M50 78v14M8 50h14M78 50h14M20 20l10 10M70 70l10 10M80 20l-10 10M30 70l-10 10"/></g>'
            '<circle cx="50" cy="50" r="22" fill="#FFD25A" stroke="#1A120E" stroke-width="6"/>'),
    "Nugget": ("sepia(0.8) saturate(1.6) hue-rotate(-15deg) brightness(0.9)", "#E0A82A",
               '<path d="M18 62 L28 30 L52 18 L78 32 L84 60 L62 82 L32 80 Z" fill="#FFC93C" stroke="#1A120E" stroke-width="6" stroke-linejoin="round"/>'
               '<path d="M34 40 L50 30 L62 38" stroke="#FFF3B0" stroke-width="6" fill="none" stroke-linecap="round"/>'),
    "Gold": ("sepia(1) saturate(3) hue-rotate(-8deg) brightness(1.1)", "#F5C64F",
             '<path d="M14 72 L14 30 L32 48 L50 18 L68 48 L86 30 L86 72 Z" fill="#F5C64F" stroke="#1A120E" stroke-width="6" stroke-linejoin="round"/>'
             '<rect x="12" y="70" width="76" height="14" rx="4" fill="#E0A82A" stroke="#1A120E" stroke-width="6"/>'),
}

src64 = base64.b64encode(open(SRC, "rb").read()).decode()
for name, (flt, frame, badge) in ICONS.items():
    html = f'''<html><body style="margin:0;width:1024px;height:1024px;overflow:hidden;background:#000">
<img src="data:image/png;base64,{src64}" style="position:absolute;inset:0;width:1024px;height:1024px;filter:{flt}">
<div style="position:absolute;inset:0;box-shadow:inset 0 0 0 44px {frame}, inset 0 0 0 58px #1A120E"></div>
<svg viewBox="0 0 100 100" style="position:absolute;right:70px;bottom:70px;width:300px;height:300px">{badge}</svg>
</body></html>'''
    icon_dir = os.path.join(ASSETS, f"AppIcon-{name}.appiconset")
    prev_dir = os.path.join(ASSETS, f"IconPreview-{name}.imageset")
    for d in (icon_dir, prev_dir):
        os.makedirs(d, exist_ok=True)
    png = os.path.join(icon_dir, f"icon-{name.lower()}-1024.png")
    render(html, png, 1024, 1024)
    json.dump({"images": [{"filename": os.path.basename(png), "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
               "info": {"author": "xcode", "version": 1}}, open(os.path.join(icon_dir, "Contents.json"), "w"), indent=2)
    prev = os.path.join(prev_dir, f"preview-{name.lower()}.png")
    subprocess.run(["sips", "-z", "256", "256", png, "--out", prev], stdout=subprocess.DEVNULL, check=True)
    json.dump({"images": [{"filename": os.path.basename(prev), "idiom": "universal"}], "info": {"author": "xcode", "version": 1}},
              open(os.path.join(prev_dir, "Contents.json"), "w"), indent=2)
    print("wrote", name)
