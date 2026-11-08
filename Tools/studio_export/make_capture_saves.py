#!/usr/bin/env python3
"""Saves for the Studio Export gameplay clips.

Copies the store-screenshot saves (Tools/store-screenshots/save-*.json) into OUT_DIR with a fresh
`lastActive`, so no "Welcome back" card covers the mine, and adds a Haunted Crypt variant.
Never writes into the repo.
    make_capture_saves.py OUT_DIR
"""
import copy, glob, json, os, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "store-screenshots")
out = sys.argv[1]
os.makedirs(out, exist_ok=True)
now = time.time() - 978307200  # Foundation reference date

for path in glob.glob(os.path.join(SRC, "save-*.json")):
    s = json.load(open(path))
    s["lastActive"] = now - 5
    json.dump(s, open(os.path.join(out, os.path.basename(path)), "w"))

# Haunted Crypt: the ruins save with Zone 5 open and active (the store saves stop at Zone 4).
s = json.load(open(os.path.join(out, "save-ruins.json")))
s["unlockedZones"] = ["quarry", "caverns", "magma", "ruins", "crypt"]
s["activeZone"] = "crypt"
s["runs"]["crypt"] = copy.deepcopy(s["runs"]["ruins"])
s["runs"]["crypt"].update({"area": 18, "maxCleared": 17, "coins": 2.4e6, "toolIndex": 3})
s["records"]["crypt"] = {"bestCleared": 17, "bestArea": 18, "seenIntro": True}
s["records"]["ruins"].update({"bestCleared": 99, "bestArea": 100})
json.dump(s, open(os.path.join(out, "save-crypt.json"), "w"))
print("saves in", out)
