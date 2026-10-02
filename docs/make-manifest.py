#!/usr/bin/env python3
"""Rebuild docs/manifest.json from the m4a files in docs/audio/.

File naming (key lowercase, e.g. bb):
  wash-<key>-<tempo>.m4a   full mix (drone + drums)
  drums-<tempo>.m4a        drums only (key-independent)
  drone-<key>.m4a          drone only (tempo-independent)
Run from the repo root after adding or re-rendering files.
"""
import json, os, re, subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
BASE = "https://harmonicsystems.github.io/google-cast/audio/"
KEY_ORDER = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

ART = "https://harmonicsystems.github.io/google-cast/art/wash.jpg"

def duration(path):
    try:
        out = subprocess.check_output(["afinfo", path], text=True)
        m = re.search(r"estimated duration: ([\d.]+)", out)
        return round(float(m.group(1))) if m else None
    except Exception:
        return None

tracks = []
for name in sorted(os.listdir(os.path.join(HERE, "audio"))):
    full = os.path.join(HERE, "audio", name)
    base = {"url": BASE + name, "contentType": "audio/mp4", "bytes": os.path.getsize(full),
            "durationSec": duration(full), "image": ART}
    m = re.match(r"wash-([a-g]b?)-(\d+)\.m4a$", name)
    if m:
        key, tempo = m.group(1).capitalize(), int(m.group(2))
        tracks.append(dict(base, layer="wash", code=f"{m.group(1)}-{tempo}",
                           title=f"Wash in {key} at {tempo} BPM", key=key, tempo=tempo))
        continue
    m = re.match(r"drums-(\d+)\.m4a$", name)
    if m:
        tempo = int(m.group(1))
        tracks.append(dict(base, layer="drums", code=f"drums-{tempo}",
                           title=f"Drums at {tempo} BPM", key=None, tempo=tempo))
        continue
    m = re.match(r"drone-([a-g]b?)\.m4a$", name)
    if m:
        key = m.group(1).capitalize()
        tracks.append(dict(base, layer="drone", code=f"drone-{m.group(1)}",
                           title=f"Drone in {key}", key=key, tempo=None))

LAYER_ORDER = ["wash", "drums", "drone"]
tracks.sort(key=lambda t: (LAYER_ORDER.index(t["layer"]), t["tempo"] or 0, KEY_ORDER.index(t["key"]) if t["key"] else -1))
manifest = {
    "artist": "BackTrack",
    "setup": "Wash with Drums",
    "art": ART,
    "layers": {
        "wash":  {"title": "Wash with Drums", "needs": ["key", "tempo"]},
        "drums": {"title": "Drums",           "needs": ["tempo"]},
        "drone": {"title": "Drone",           "needs": ["key"]},
    },
    "tempos": sorted({t["tempo"] for t in tracks if t["tempo"]}),
    "drumTempos": sorted({t["tempo"] for t in tracks if t["layer"] == "drums"}),
    "keys": [k for k in KEY_ORDER if any(t["key"] == k for t in tracks)],
    "tracks": tracks,
}
with open(os.path.join(HERE, "manifest.json"), "w") as f:
    json.dump(manifest, f, indent=1)
print(f"{len(tracks)} tracks, {sum(t['bytes'] for t in tracks)/1e6:.0f} MB")
