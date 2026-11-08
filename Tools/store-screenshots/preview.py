#!/usr/bin/env python3
"""App Store previews (search row, product page) and In-App Event artwork, rendered with headless Chrome."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from compose import render, ICON, HERE, CHUNKS, SPARKS
from store_text import LOCALES, fonts, FIT_JS

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "..", "AppStore", "Screenshots")
SHOTS = os.path.join(OUT, "en-GB", "iphone-1179x2556")
NAME, SUB = "Punch Mine: Idle Mining Game", "Tap, Smash Rocks & Find Loot"
PROMO = "New zone: Sunken Ruins! Ride the high tide for ×2.5 rewards, break runestones that hit a whole row, and dig up Pearls and new relics."

STATUS = '''<div class="status"><b>9:41</b><span>●●●● ᯤ ▮</span></div>'''
BASE_CSS = '''*{box-sizing:border-box;margin:0;padding:0}
body{font-family:-apple-system,system-ui,"SF Pro Text",sans-serif;background:#fff;color:#000;-webkit-font-smoothing:antialiased}
.status{display:flex;justify-content:space-between;padding:42px 96px 0 96px;font-size:50px;font-weight:600}
.get{background:#EEF0F6;color:#0A7AFF;font-weight:800;border-radius:999px;padding:16px 58px;font-size:46px;letter-spacing:.5px}
.iap{font-size:26px;color:#8A8A8E;text-align:center;margin-top:10px;line-height:1.1}
.icon{border-radius:22.5%;border:2px solid rgba(0,0,0,.08)}
.shots{display:flex;gap:28px}
.shots img{border-radius:34px;border:2px solid rgba(0,0,0,.06);display:block}
'''


def search_page():
    shots = "".join(f'<img src="file://{SHOTS}/{n}.png" style="width:347px">' for n in ("01-punch", "02-heart", "03-zones"))
    return f'''<!doctype html><html><head><meta charset="utf-8"><style>{BASE_CSS}
.search{{margin:40px 48px 0;background:#EEEEF0;border-radius:30px;padding:24px 32px;font-size:48px;color:#000;display:flex;gap:20px;align-items:center}}
.search i{{color:#8A8A8E;font-style:normal}}
.hdr{{display:flex;justify-content:space-between;align-items:center;margin:38px 48px 0}}
.hdr h2{{font-size:46px;font-weight:700}}
.row{{margin:30px 48px 0;display:flex;align-items:center;gap:34px}}
.row .t{{flex:1;min-width:0}}
.row .n{{font-size:46px;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}}
.row .s{{font-size:38px;color:#8A8A8E;margin-top:6px}}
.row .c{{font-size:30px;color:#8A8A8E;margin-top:10px}}
.shots{{margin:40px 48px 0}}
.dim{{opacity:.35;margin-top:70px}}
.note{{margin:70px 48px 0;font-size:34px;color:#6A6A70;line-height:1.35}}
</style></head><body>{STATUS}
<div class="search"><i>⌕</i> idle mining</div>
<div class="row"><img class="icon" src="file://{ICON}" style="width:196px">
  <div class="t"><div class="n">{NAME}</div><div class="s">{SUB}</div><div class="c">Games · Casual</div></div>
  <div><div class="get">Get</div><div class="iap">In-App<br>Purchases</div></div></div>
<div class="shots">{shots}</div>
<div class="dim"><div class="row"><div class="icon" style="width:196px;height:196px;background:#ddd"></div>
  <div class="t"><div class="n">Another game</div><div class="s">Next search result</div></div><div class="get">Get</div></div></div>
<div class="note">How the listing appears in App Store search on iPhone: icon, name, subtitle and the first three screenshots. New apps show no stars until they get ratings.</div>
</body></html>'''


def product_page():
    shots = "".join(f'<img src="file://{SHOTS}/{n}.png" style="width:470px">' for n in ("01-punch", "02-heart", "03-zones"))
    return f'''<!doctype html><html><head><meta charset="utf-8"><style>{BASE_CSS}
.nav{{margin:30px 48px 0;color:#0A7AFF;font-size:48px}}
.top{{display:flex;gap:44px;margin:40px 48px 0;align-items:flex-start}}
.top .n{{font-size:62px;font-weight:700;line-height:1.1}}
.top .s{{font-size:40px;color:#8A8A8E;margin-top:12px}}
.top .acts{{display:flex;align-items:center;gap:26px;margin-top:40px}}
.get2{{background:#0A7AFF;color:#fff;font-weight:800;border-radius:999px;padding:16px 64px;font-size:46px}}
.chips{{display:flex;margin:56px 48px 0;border-top:2px solid #E5E5EA;padding-top:30px}}
.chip{{flex:1;text-align:center;border-right:2px solid #E5E5EA}}
.chip:last-child{{border:none}}
.chip .k{{font-size:26px;color:#8A8A8E;font-weight:600;letter-spacing:.5px}}
.chip .v{{font-size:44px;color:#6A6A70;font-weight:700;margin-top:8px}}
.chip .x{{font-size:26px;color:#8A8A8E;margin-top:6px}}
.shots{{margin:44px 0 0 48px;overflow:hidden;width:1131px}}
.promo{{margin:48px 48px 0;font-size:40px;line-height:1.35}}
.more{{color:#0A7AFF}}
</style></head><body>{STATUS}
<div class="nav">‹ Search</div>
<div class="top"><img class="icon" src="file://{ICON}" style="width:330px">
  <div><div class="n">{NAME}</div><div class="s">{SUB}</div>
  <div class="acts"><div class="get2">Get</div><div class="iap" style="text-align:left">In-App<br>Purchases</div></div></div></div>
<div class="chips">
  <div class="chip"><div class="k">RATINGS</div><div class="v">—</div><div class="x">Not enough</div></div>
  <div class="chip"><div class="k">AGE</div><div class="v">4+</div><div class="x">Years</div></div>
  <div class="chip"><div class="k">CATEGORY</div><div class="v">🎮</div><div class="x">Casual</div></div>
  <div class="chip"><div class="k">DEVELOPER</div><div class="v">👤</div><div class="x">You</div></div></div>
<div class="shots"><div style="display:flex;gap:28px">{shots}</div></div>
<div class="promo">{PROMO} <span class="more">more</span></div>
</body></html>'''


def event_art(W, H):
    u = W / 100
    phones = [("raw4/heart", -9, 0.22, 0.62), ("raw4/magma", 0, 0.50, 0.605), ("raw3/reveal3", 9, 0.78, 0.62)] if W > H else \
             [("raw4/heart", -7, 0.25, 0.66), ("raw4/magma", 0, 0.5, 0.60), ("raw3/reveal3", 7, 0.75, 0.66)]
    pw = W * (0.17 if W > H else 0.34)
    imgs = "".join(
        f'<img src="file://{HERE}/{n}.png" style="position:absolute;left:{x*W - pw/2:.0f}px;top:{y*H - pw*1.09:.0f}px;width:{pw:.0f}px;'
        f'transform:rotate({r}deg);border-radius:{pw*0.14:.0f}px;border:{pw*0.035:.0f}px solid #0B0B0E;outline:{u*0.35:.0f}px solid #1A120E;box-shadow:0 {u:.0f}px {u*3:.0f}px rgba(0,0,0,.6);z-index:{3 if r == 0 else 2}">'
        for n, r, x, y in phones)
    chunks = "".join(
        f'<div style="position:absolute;left:{x}%;top:{y}%;width:{s*min(W,H)*0.9:.0f}px;height:{s*min(W,H)*0.9:.0f}px;transform:rotate({r}deg);background:{c};'
        f'border:{u*0.5:.0f}px solid #1A120E;border-radius:{u:.0f}px"></div>' for x, y, s, r, c in CHUNKS)
    return f'''<!doctype html><html><head><meta charset="utf-8"><style>*{{margin:0}}
html,body{{width:{W}px;height:{H}px;overflow:hidden}}
body{{position:relative;background:radial-gradient(ellipse 70% 70% at 50% 45%, #11606A 0%, #06161C 80%)}}
.rays{{position:absolute;inset:0;background:repeating-conic-gradient(from 0deg at 50% 45%, rgba(255,255,255,.08) 0deg 7deg, transparent 7deg 18deg)}}
.glow{{position:absolute;left:50%;top:45%;width:{min(W,H)*1.2:.0f}px;height:{min(W,H)*1.2:.0f}px;transform:translate(-50%,-50%);background:radial-gradient(circle,#3FD8C866 0%,transparent 62%)}}
.icon{{position:absolute;left:50%;top:{(0.05 if W > H else 0.06)*H:.0f}px;transform:translateX(-50%) rotate(-6deg);width:{min(W,H)*0.17:.0f}px;border-radius:22.5%;
  border:{u*0.5:.0f}px solid #1A120E;box-shadow:0 {u*0.6:.0f}px 0 #1A120E;z-index:4}}
</style></head><body><div class="rays"></div><div class="glow"></div>{chunks}{imgs}
<img class="icon" src="file://{ICON}"></body></html>'''




# --- App Store creative assets (iOS 27+): product page header and search results image ---------------------------
# Header 3840x1646 (21:9), safe area 1646x661 centred. Search 3840x2560 (3:2), safe area 2168x1030 centred.
# Key art (logo, words, phones) stays inside the safe area; rays, rocks and extra phones fill the bleed.

def _phone(src, x, y, w, rot, z=2, shadow=1.0):
    h = w * 2622 / 1206
    return (f'<img src="file://{HERE}/{src}.png" style="position:absolute;left:{x - w/2:.0f}px;top:{y - h/2:.0f}px;width:{w:.0f}px;'
            f'transform:rotate({rot}deg);border-radius:{w*0.13:.0f}px;border:{w*0.035:.0f}px solid #0B0B0E;'
            f'outline:{w*0.012:.0f}px solid #1A120E;box-shadow:0 {w*0.05:.0f}px {w*0.12*shadow:.0f}px rgba(0,0,0,.6);z-index:{z}">')


def _scene(W, H, cx, cy, body, safe=None, code="en-GB"):
    link, display, text, weight = fonts(code)
    k = min(W, H) / 100
    rocks = [(4, 12, 7, 18, "#9A948E"), (14, 78, 5, -22, "#FFC93C"), (30, 8, 4, 30, "#7E7872"), (66, 86, 6, -12, "#9A948E"),
             (84, 10, 5, 8, "#FFC93C"), (95, 64, 8, -28, "#8A847E"), (48, 92, 3.5, 40, "#FFC93C"), (2, 50, 4.5, 10, "#7E7872")]
    rock_html = "".join(
        f'<div style="position:absolute;left:{x}%;top:{y}%;width:{s*k:.0f}px;height:{s*k:.0f}px;transform:rotate({r}deg);background:{c};'
        f'border:{k*0.7:.0f}px solid #1A120E;border-radius:{k*1.2:.0f}px;box-shadow:inset {-k*0.6:.0f}px {-k*0.6:.0f}px 0 rgba(0,0,0,.25)"></div>'
        for x, y, s, r, c in rocks)
    sparks = "".join(
        f'<div style="position:absolute;left:{x}%;top:{y}%;width:{s*k:.0f}px;height:{s*k:.0f}px;background:#fff;opacity:.9;'
        f'clip-path:polygon(50% 0,61% 39%,100% 50%,61% 61%,50% 100%,39% 61%,0 50%,39% 39%)"></div>'
        for x, y, s in [(22, 20, 4), (76, 24, 3.4), (10, 30, 2.6), (88, 80, 3.6), (36, 84, 2.4), (60, 14, 2.4)])
    guide = ""
    if safe and os.environ.get("SAFE_GUIDE"):
        sw, sh = safe
        guide = f'<div style="position:absolute;left:{(W-sw)/2}px;top:{(H-sh)/2}px;width:{sw}px;height:{sh}px;outline:6px dashed #0f0;z-index:99"></div>'
    return f'''<!doctype html><html><head><meta charset="utf-8">
{link}
<style>*{{margin:0;padding:0;box-sizing:border-box}}html,body{{width:{W}px;height:{H}px;overflow:hidden}}
body{{position:relative;background:radial-gradient(ellipse 60% 75% at {cx}% {cy}%, #B8541E 0%, #5A1E0C 45%, #1C0A05 85%)}}
.rays{{position:absolute;inset:0;background:repeating-conic-gradient(from 0deg at {cx}% {cy}%, rgba(255,210,140,.10) 0deg 6deg, transparent 6deg 15deg)}}
.word{{font-family:{display};font-weight:{weight};color:#FFC93C;line-height:.9;-webkit-text-stroke:var(--st) #1A120E;paint-order:stroke fill;text-shadow:0 var(--sh) 0 #1A120E}}
.white{{color:#fff}}
.brand{{font-family:'Lilita One';font-weight:400}}
.tag{{font-family:{text};font-weight:900;color:#FFF3E2;text-shadow:0 var(--sh2) 0 rgba(0,0,0,.55)}}
.icon{{border-radius:22.5%;border:var(--ib) solid #1A120E;box-shadow:0 var(--sh) 0 #1A120E}}
</style></head><body><div class="rays"></div>{rock_html}{sparks}{body}{guide}{FIT_JS}</body></html>'''


def creative_header(code="en-GB"):
    W, H = 3840, 1646
    body = f'''
<div style="position:absolute;left:50%;top:50%;transform:translate(-50%,-50%);display:flex;align-items:center;gap:70px;z-index:5;
  --st:30px;--sh:22px;--sh2:8px;--ib:14px">
  <img class="icon" src="file://{ICON}" style="width:470px;transform:rotate(-5deg)">
  <div><div class="word brand" style="font-size:270px">PUNCH<br>MINE</div>
  <div class="tag fit" style="font-size:78px;margin-top:26px;white-space:nowrap;max-width:1000px">{LOCALES[code]["header"]}</div></div></div>
''' + _phone("raw4/heart", 560, 860, 560, -12) + _phone("raw3/reveal3", 860, 1010, 450, -4, 1) \
    + _phone("raw4/magma", 3280, 860, 560, 12) + _phone("raw3/zones", 2980, 1010, 450, 4, 1)
    return _scene(W, H, 50, 50, body, (1646, 661), code), W, H


def creative_search(code="en-GB"):
    W, H = 3840, 2560
    # Search tiles are small, so use one large phone instead of three: its HUD and block grid sit inside the
    # safe area and the upgrade list runs off into the bleed below.
    body = f'''
<div style="position:absolute;left:{(W-2168)/2 + 10:.0f}px;top:50%;transform:translateY(-50%);z-index:5;--st:40px;--sh:26px;--sh2:10px;--ib:14px">
  <div style="display:flex;align-items:center;gap:40px;margin-bottom:50px">
    <img class="icon" src="file://{ICON}" style="width:210px">
    <div class="word brand" style="font-size:120px">PUNCH<br>MINE</div></div>
  <div class="word white fit" style="font-size:250px;line-height:.93;white-space:nowrap;max-width:1280px">{LOCALES[code]["search"].replace("<span>", '<span style="color:#FFC93C">')}</div></div>
''' + _phone("raw4/magma", 2530, 1590, 780, 6, 3)
    return _scene(W, H, 68, 45, body, (2168, 1030), code), W, H


def build_creatives(out):
    for code in LOCALES:
        d = os.path.join(out, code, "creative-assets"); os.makedirs(d, exist_ok=True)
        for name, fn in (("header-3840x1646", creative_header), ("search-results-3840x2560", creative_search)):
            page, W, H = fn(code)
            render(page, os.path.join(d, f"{name}.png"), W, H)
            print("rendered", code, name)


if __name__ == "__main__":
    build_creatives(OUT)
    e = os.path.join(OUT, "in-app-event"); os.makedirs(e, exist_ok=True)
    render(event_art(1920, 1080), os.path.join(e, "event-card-1920x1080.png"), 1920, 1080)
    render(event_art(1080, 1920), os.path.join(e, "event-details-1080x1920.png"), 1080, 1920)
    print("done")
