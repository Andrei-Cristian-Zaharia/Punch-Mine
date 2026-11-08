#!/usr/bin/env python3
"""Composes App Store screenshots (HTML -> headless Chrome PNG) from raw simulator captures."""
import os, subprocess, sys, html
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from store_text import LOCALES, fonts, FIT_JS

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "..", "AppStore", "Screenshots")
ONLY = sys.argv[2] if len(sys.argv) > 2 else None  # matches a shot id or a locale code
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
ICON = os.path.join(HERE, "..", "..", "Punch Mine", "Assets.xcassets", "AppIcon.appiconset", "icon-ios-1024.png")

# Zone palettes: (glow, mid, deep)
PAL = {
    "magma":   ("#FF8A3D", "#9A2E14", "#2A0C08"),
    "ruins":   ("#3FD8C8", "#11606A", "#06161C"),
    "heart":   ("#7CF2E4", "#14707A", "#051419"),
    "quarry":  ("#FFB25A", "#8A4A1E", "#24130A"),
    "gold":    ("#FFD25A", "#A8641A", "#2A1606"),
    "perk":    ("#B98CFF", "#4A2A9A", "#120A2A"),
    "caverns": ("#5FE0F0", "#1E5A9A", "#081428"),
}

SHOTS = [  # text for each shot lives in store_text.LOCALES, in this order
    dict(id="01-punch", pal="magma", logo=True, phone="raw4/magma.png", ipad="raw-ipad/magma.png"),
    dict(id="02-heart", pal="heart", phone="raw4/heart.png", ipad="raw-ipad/heart.png"),
    dict(id="03-zones", pal="ruins", phone="raw3/zones.png", ipad="raw-ipad/zones.png"),
    dict(id="04-loot", pal="gold", phone="raw3/reveal3.png", ipad="raw-ipad/reveal.png"),
    dict(id="05-perks", pal="perk", phone="raw3/perks.png", ipad="raw-ipad/perks.png"),
    dict(id="06-away", pal="caverns", phone="raw3/away.png", ipad="raw-ipad/away.png"),
]

SIZES = {
    "iphone": dict(w=1179, h=2556, key="phone", dev_w=0.70, radius=0.115, bezel=0.022, top_logo=0.30, top=0.215),
    "ipad":   dict(w=2048, h=2732, key="ipad",  dev_w=0.65, radius=0.045, bezel=0.016, top_logo=0.325, top=0.255),
}

CHUNKS = [  # x%, y%, size (fraction of W), rotation, color
    (6, 30, 0.07, 18, "#9A948E"), (91, 44, 0.055, -22, "#FFC93C"), (92, 58, 0.08, 30, "#8A847E"),
    (3, 70, 0.05, -12, "#FFC93C"), (85, 88, 0.06, 8, "#9A948E"), (10, 92, 0.075, -28, "#7E7872"),
]
SPARKS = [(14, 18, 0.05), (82, 38, 0.04), (8, 52, 0.035), (90, 76, 0.045)]


def page(shot, size, code="en-GB"):
    title, sub, sticker = LOCALES[code]["shots"][SHOTS.index(shot)]
    link, display, body, weight = fonts(code)
    W, H = size["w"], size["h"]
    glow, mid, deep = PAL[shot["pal"]]
    img = os.path.join(HERE, shot[size["key"]])
    top = size["top_logo"] if shot.get("logo") else size["top"]
    dev_w = W * size["dev_w"] * (0.94 if shot.get("logo") else 1)
    u = W / 100  # 1 unit = 1% of width
    chunks = "".join(
        f'<div class="chunk" style="left:{x}%;top:{y}%;width:{s*W:.0f}px;height:{s*W:.0f}px;transform:rotate({r}deg);background:{c}"></div>'
        for x, y, s, r, c in CHUNKS)
    sparks = "".join(f'<div class="spark" style="left:{x}%;top:{y}%;width:{s*W:.0f}px;height:{s*W:.0f}px"></div>' for x, y, s in SPARKS)
    logo = ""
    if shot.get("logo"):
        logo = f'''<div class="brand"><img src="file://{ICON}"><div class="word">PUNCH<br>MINE</div></div>'''
    return f'''<!doctype html><html><head><meta charset="utf-8">
{link}
<style>
*{{box-sizing:border-box;margin:0;padding:0}}
html,body{{width:{W}px;height:{H}px;overflow:hidden}}
body{{position:relative;background:radial-gradient(ellipse 85% 60% at 50% 42%, {mid} 0%, {deep} 78%);font-family:{body}}}
.rays{{position:absolute;inset:0;background:repeating-conic-gradient(from 0deg at 50% 46%, rgba(255,255,255,.07) 0deg 7deg, transparent 7deg 18deg);
  -webkit-mask:radial-gradient(circle at 50% 46%, #000 0%, transparent 70%);mask:radial-gradient(circle at 50% 46%, #000 0%, transparent 70%)}}
.glow{{position:absolute;left:50%;top:58%;width:{W*1.1:.0f}px;height:{W*1.1:.0f}px;transform:translate(-50%,-50%);
  background:radial-gradient(circle, {glow}66 0%, transparent 60%)}}
.chunk{{position:absolute;border:{u*0.9:.0f}px solid #1A120E;border-radius:{u*1.6:.0f}px;box-shadow:inset {-u*0.8:.0f}px {-u*0.8:.0f}px 0 rgba(0,0,0,.25)}}
.spark{{position:absolute;background:#fff;clip-path:polygon(50% 0,61% 39%,100% 50%,61% 61%,50% 100%,39% 61%,0 50%,39% 39%);opacity:.9}}
.head{{position:absolute;left:0;right:0;top:{u*(5.5 if not shot.get("logo") else 3.5):.0f}px;text-align:center;padding:0 {u*5:.0f}px}}
h1{{font-family:{display};font-weight:{weight};white-space:nowrap;font-size:{u*(12.2 if size["key"]=="phone" else 9.2):.0f}px;line-height:.98;color:#fff;letter-spacing:{u*0.15:.1f}px;
  -webkit-text-stroke:{u*1.5:.0f}px #1A120E;paint-order:stroke fill;text-shadow:0 {u*1.1:.0f}px 0 #1A120E}}
h1 span{{color:#FFC93C}}
p.sub{{white-space:nowrap;margin-top:{u*2.4:.0f}px;font-weight:900;font-size:{u*(4.3 if size["key"]=="phone" else 3.0):.0f}px;color:rgba(255,248,236,.92);text-shadow:0 {u*0.4:.0f}px 0 rgba(0,0,0,.5)}}
.brand{{display:flex;align-items:center;justify-content:center;gap:{u*2.6:.0f}px;margin-bottom:{u*3:.0f}px}}
.brand img{{width:{u*(17 if size["key"]=="phone" else 11):.0f}px;border-radius:22.5%;border:{u*0.7:.0f}px solid #1A120E;box-shadow:0 {u*1:.0f}px 0 #1A120E}}
.word{{font-family:'Lilita One';font-size:{u*(8.4 if size["key"]=="phone" else 5.6):.0f}px;line-height:.9;text-align:left;color:#FFC93C;
  -webkit-text-stroke:{u*1.1:.0f}px #1A120E;paint-order:stroke fill;text-shadow:0 {u*0.8:.0f}px 0 #1A120E}}
.device{{position:absolute;left:50%;top:{H*top:.0f}px;width:{dev_w:.0f}px;transform:translateX(-50%);background:#0B0B0E;
  border-radius:{W*size["radius"]:.0f}px;padding:{W*size["bezel"]:.0f}px;
  box-shadow:0 0 0 {u*0.5:.0f}px #3A3A40, 0 0 0 {u*1.1:.0f}px #1A120E, 0 {u*3:.0f}px {u*6:.0f}px rgba(0,0,0,.55)}}
.device img{{display:block;width:100%;border-radius:{W*(size["radius"]-size["bezel"]):.0f}px}}
.sticker{{position:absolute;right:{u*4:.0f}px;top:{H*top + u*(-4.5 if size["key"]=="phone" else 1.5):.0f}px;transform:rotate(6deg);background:#FFC93C;color:#1A120E;
  font-family:{display};font-weight:{weight};white-space:nowrap;max-width:{u*62:.0f}px;font-size:{u*(5.0 if size["key"]=="phone" else 3.4):.0f}px;padding:{u*1.4:.0f}px {u*3:.0f}px;border-radius:{u*2.2:.0f}px;
  border:{u*0.9:.0f}px solid #1A120E;box-shadow:0 {u*0.9:.0f}px 0 #1A120E;z-index:5}}
</style></head><body>
<div class="rays"></div><div class="glow"></div>{chunks}{sparks}
<div class="head">{logo}<h1 class="fit">{title}</h1><p class="sub fit">{html.escape(sub)}</p></div>
<div class="device"><img src="file://{img}"></div>
<div class="sticker fit">{html.escape(sticker)}</div>
{FIT_JS}</body></html>'''


def render(html_text, path, W, H):
    path = os.path.abspath(path)  # Chrome needs absolute file:// URLs; a relative one fails silently
    hp = path.replace(".png", ".html")
    open(hp, "w").write(html_text)
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--allow-file-access-from-files",
                    "--force-device-scale-factor=1", f"--window-size={W},{H}", "--virtual-time-budget=4000",
                    f"--screenshot={path}", "file://" + hp], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
    os.remove(hp)


def jobs(out):
    """(html, path, W, H) for every locale x device x shot, filtered by ONLY."""
    for code in LOCALES:
        for name, size in SIZES.items():
            d = os.path.join(out, code, f"{name}-{size['w']}x{size['h']}")
            os.makedirs(d, exist_ok=True)
            for shot in SHOTS:
                if ONLY and ONLY not in (shot["id"], code) and ONLY not in shot["id"]:
                    continue
                yield page(shot, size, code), os.path.join(d, f"{shot['id']}.png"), size["w"], size["h"]


if __name__ == "__main__":
    with ThreadPoolExecutor(6) as pool:
        for path in pool.map(lambda j: (render(*j), j[1])[1], jobs(OUT)):
            print("rendered", os.path.relpath(path, OUT))
