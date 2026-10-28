#!/bin/bash
# Macilla: bash $MAC_PROJ/expresso/expresso-ohjain/tyytyvaisyys.sh — simulaattorin brew_shots.jsonl rivi kerrallaan
# (indeksi, saved_at, satisfaction_level, emoji) ja tyhjät rivit: updateSatisfactionAt kirjoittaa
# tiedoston uudelleen ilman tyhjiä rivejä, joten rivien indeksit eivät saa siirtyä.
set -e
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
UDID=F47C2720-C9C5-48E7-B776-F597F234A110
D=$(xcrun simctl get_app_container "$UDID" io.github.rolppe.silviaPicoUi data)
/usr/bin/python3 -I - "$D/Documents/brew_shots.jsonl" <<'PY'
import json, sys
p = sys.argv[1]
rivit = open(p, encoding="utf-8").read().split("\n")
print(f"TIEDOSTO: {p} ({len([r for r in rivit if r.strip()])} riviä)")
for i, r in enumerate(rivit):
    if not r.strip():
        if i < len(rivit) - 1: print(f"{i}: TYHJÄ")
        continue
    m = json.loads(r)
    print(f"{i}: {m.get('saved_at')} level={m.get('satisfaction_level')} emoji={m.get('satisfaction_emoji')}")
PY
