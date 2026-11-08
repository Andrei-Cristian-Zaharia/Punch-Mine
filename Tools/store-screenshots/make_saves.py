#!/usr/bin/env python3
"""Marketing saves for store screenshots: late-game player, original items only (no other-game references)."""
import json, os, copy

HERE = os.path.dirname(os.path.abspath(__file__))
base = json.load(open(os.path.join(HERE, "base-save.json")))

base["items"] = {
    "tidecallerHelm": 1, "heartstoneBuckle": 1, "prismHeart": 1, "magmaTreads": 1,
    "seersVisor": 2, "titanBelt": 1, "phoenixFeather": 2, "windwalkers": 1,
    "crownOfEmbers": 3, "stormCharm": 2, "quakeBoots": 2, "echoShard": 1, "bandolier": 2,
    "lanternCap": 4, "luckySash": 3, "coinPouch": 4, "stompBoots": 3, "emberGreaves": 2, "hourglass": 3,
    "minersHelmet": 6, "toolBelt": 5, "rabbitsFoot": 5, "sprintBoots": 4, "hardHat": 3, "magnetCharm": 4,
}
base.pop("affixes", None)
base["equipped"] = {"helmet": "tidecallerHelm", "belt": "heartstoneBuckle", "charm": "prismHeart", "boots": "magmaTreads"}
base["chests"] = {"wooden": 14, "iron": 6, "golden": 3}
base["perkCoins"] = 1840
base["scrap"] = 2650
base["perks"] = {
    "heavyFists": 14, "keenEye": 8, "brutalCrits": 4, "piercer": 7, "resonantKnuckles": 3, "titanPunch": 1,
    "foreman": 12, "dayOneCrew": 2, "doubleShift": 2, "treasureCrew": 2, "nightShift": 3, "overtime": 3, "toolsmith": 2,
    "seedMoney": 4, "scrapper": 3, "expressElevator": 2, "prospector": 3, "luckyHaul": 2,
}
base["stars"] = {"fists": 12, "crew": 6, "fortune": 5, "luck": 4}
base["unlockedZones"] = ["quarry", "caverns", "magma", "ruins"]
base["heartsDefeated"] = 3
base["deepestHeart"] = 100
base["coinRushRemaining"] = 0
base["seenTips"] = ["upgrade","hold","armor","miner","fever","treasure","chest","drawer","gadget","newZone","prestige","perks"]

MID = {"strength": 46, "speed": 12, "critChance": 9, "critDamage": 10, "focus": 5, "rhythm": 4,
       "hireMiner": 6, "hireDriller": 3, "hireBlaster": 1, "training": 18, "shiftPace": 5,
       "feverStamina": 5, "contracts": 2, "deepPockets": 6, "treasureHunter": 4, "lockpick": 3}

def run(area, coins, tool, levels=None):
    r = _run(area, coins, tool)
    if levels: r["levels"] = levels
    return r

def _run(area, coins, tool):
    return {"area": area, "maxCleared": area - 1, "coins": coins, "lifetimeCoins": coins * 6, "toolIndex": tool, "blocks": [],
            "levels": {"strength": 160, "speed": 45, "critChance": 30, "critDamage": 28, "focus": 12, "rhythm": 10,
                       "hireMiner": 40, "hireDriller": 22, "hireBlaster": 12, "training": 25, "shiftPace": 15,
                       "feverStamina": 10, "contracts": 8, "deepPockets": 9, "treasureHunter": 10, "lockpick": 6}}

base["records"] = {
    "quarry": {"bestCleared": 140, "bestArea": 141, "heartsDefeated": 1, "deepestHeart": 100, "seenIntro": True, "prestigeCount": 9, "lastPrestigeDepth": 120, "bestPrestigeArea": 141, "lastRunSeconds": 2400},
    "caverns": {"bestCleared": 112, "bestArea": 113, "heartsDefeated": 1, "deepestHeart": 100, "seenIntro": True, "prestigeCount": 6, "lastPrestigeDepth": 100, "bestPrestigeArea": 113, "lastRunSeconds": 2600},
    "magma": {"bestCleared": 101, "bestArea": 102, "heartsDefeated": 1, "deepestHeart": 100, "seenIntro": True, "prestigeCount": 4, "lastPrestigeDepth": 90, "bestPrestigeArea": 102, "lastRunSeconds": 3000},
    "ruins": {"bestCleared": 99, "bestArea": 100, "seenIntro": True, "prestigeCount": 2},
}
base["stats"] = {"chestsOpened": 412, "blocksBroken": 268_400, "playSeconds": 96_000, "areasCleared": 3_120, "crits": 81_200,
                 "treasuresBroken": 1_904, "coins": {}, "dailyClaims": 21, "punches": 640_000}

variants = {
    "ruins":   ("ruins", 22, 8.4e6, 4),
    "heart":   ("ruins", 100, 9.1e10, 6),
    "caverns": ("caverns", 34, 3.1e6, 4),
    "magma":   ("magma", 30, 5.2e6, 4),
    "quarry":  ("quarry", 38, 7.2e6, 4),
}
for name, (zone, area, coins, tool) in variants.items():
    s = copy.deepcopy(base)
    s["activeZone"] = zone
    s["runs"] = {z: run(a, c, t) for z, (_, a, c, t) in
                 {"quarry": variants["quarry"], "caverns": variants["caverns"], "magma": variants["magma"], "ruins": variants["ruins"]}.items()}
    s["runs"][zone] = run(area, coins, tool, None if name == "heart" else MID)
    json.dump(s, open(os.path.join(HERE, f"save-{name}.json"), "w"))
    print("wrote", name)

# Fresh timestamps so no "Welcome back" card (except the `away` save, which keeps an old one on purpose).
import time, glob, sys
now = time.time() - 978307200  # Foundation reference date
for path in glob.glob(os.path.join(HERE, "save-*.json")):
    s = json.load(open(path))
    s["lastActive"] = now - (5 * 3600 if path.endswith("save-away.json") else 5)
    json.dump(s, open(path, "w"))

# Next golden chest hits the legendary pity, for the chest-reveal shot.
s = json.load(open(os.path.join(HERE, "save-ruins.json")))
s["chestsSinceLegendary"] = 249
for k in ("titanBelt", "seersVisor", "windwalkers", "phoenixFeather"): s["items"].pop(k, None)
json.dump(s, open(os.path.join(HERE, "save-legend.json"), "w"))
