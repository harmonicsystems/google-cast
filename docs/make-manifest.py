#!/usr/bin/env python3
"""Rebuild docs/manifest.json from the m4a files in docs/audio/.

File naming: wash-<key>-<tempo>.m4a (key lowercase, e.g. wash-bb-96.m4a).
Run from the repo root after adding or re-rendering files.
"""
import json, os, re

HERE = os.path.dirname(os.path.abspath(__file__))
BASE = "https://harmonicsystems.github.io/google-cast/audio/"
KEY_ORDER = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

tracks = []
for name in sorted(os.listdir(os.path.join(HERE, "audio"))):
    m = re.match(r"wash-([a-g]b?)-(\d+)\.m4a$", name)
    if not m:
        continue
    key = m.group(1).capitalize()
    tempo = int(m.group(2))
    size = os.path.getsize(os.path.join(HERE, "audio", name))
    tracks.append({
        "title": f"Wash in {key} at {tempo} BPM",
        "key": key, "tempo": tempo,
        "url": BASE + name, "contentType": "audio/mp4",
        "durationSec": 180, "bytes": size,
    })

tracks.sort(key=lambda t: (t["tempo"], KEY_ORDER.index(t["key"])))
manifest = {
    "artist": "BackTrack",
    "setup": "Wash with Drums",
    "tempos": sorted({t["tempo"] for t in tracks}),
    "keys": [k for k in KEY_ORDER if any(t["key"] == k for t in tracks)],
    "tracks": tracks,
}
with open(os.path.join(HERE, "manifest.json"), "w") as f:
    json.dump(manifest, f, indent=1)
print(f"{len(tracks)} tracks, {sum(t['bytes'] for t in tracks)/1e6:.0f} MB")
