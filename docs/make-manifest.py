#!/usr/bin/env python3
"""Rebuild docs/manifest.json from the m4a files in docs/audio/.

File naming (key lowercase, e.g. bb):
  wash-<key>-<tempo>.m4a   full mix (drone + drums)
  drums-<tempo>.m4a        drums only (key-independent)
  drone-<key>.m4a          drone only (tempo-independent)
  drone-hi-<key>.m4a       drone an octave up (Logic "Wash Up" bounces)
  noise-<id>.m4a           BackTrack Noise mode renders (seamless loops); titles in NOISE_TITLES
Run from the repo root after adding or re-rendering files.
"""
import json, os, re, subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
BASE = "https://harmonicsystems.github.io/google-cast/audio/"
KEY_ORDER = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

ART = "https://harmonicsystems.github.io/google-cast/art/wash.jpg"
NOISE_TITLES = {
    "deep": "Deep", "fan": "Fan", "rain": "Soft rain", "falls": "Waterfall", "surf": "Surf",
    "pink": "Pink noise", "brown": "Brown noise", "grey": "Grey noise",
    "rain-waves": "Soft rain, waves", "deep-waves": "Deep, waves",
}

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
        continue
    m = re.match(r"drone-hi-([a-g]b?)\.m4a$", name)
    if m:
        key = m.group(1).capitalize()
        tracks.append(dict(base, layer="droneHi", code=f"drone-hi-{m.group(1)}",
                           title=f"Drone up in {key}", key=key, tempo=None))
        continue
    m = re.match(r"noise-([a-z-]+)\.m4a$", name)
    if m:
        nid = m.group(1)
        tracks.append(dict(base, layer="noise", code=f"noise-{nid}",
                           title=NOISE_TITLES.get(nid, nid.replace("-", " ").capitalize()), key=None, tempo=None))

LAYER_ORDER = ["wash", "drums", "drone", "droneHi", "noise"]
NOISE_ORDER = list(NOISE_TITLES)
tracks.sort(key=lambda t: (LAYER_ORDER.index(t["layer"]), t["tempo"] or 0, KEY_ORDER.index(t["key"]) if t["key"] else -1,
                           NOISE_ORDER.index(t["code"][6:]) if t["layer"] == "noise" and t["code"][6:] in NOISE_ORDER else 99))
manifest = {
    "artist": "BackTrack",
    "setup": "Wash with Drums",
    "art": ART,
    "layers": {
        "wash":    {"title": "Wash with Drums", "needs": ["key", "tempo"]},
        "drums":   {"title": "Drums",           "needs": ["tempo"]},
        "drone":   {"title": "Drone",           "needs": ["key"]},
        "droneHi": {"title": "Drone up",        "needs": ["key"]},
        "noise":   {"title": "Noise",           "needs": []},
    },
    "tempos": sorted({t["tempo"] for t in tracks if t["tempo"]}),
    "drumTempos": sorted({t["tempo"] for t in tracks if t["layer"] == "drums"}),
    "keys": [k for k in KEY_ORDER if any(t["key"] == k for t in tracks)],
    "tracks": tracks,
}
for lid, layer in manifest["layers"].items():
    mine = [t for t in tracks if t["layer"] == lid]
    layer["keys"] = [k for k in KEY_ORDER if any(t["key"] == k for t in mine)]
    layer["tempos"] = sorted({t["tempo"] for t in mine if t["tempo"]})
    layer["codes"] = [t["code"] for t in mine]

with open(os.path.join(HERE, "manifest.json"), "w") as f:
    json.dump(manifest, f, indent=1)
print(f"{len(tracks)} tracks, {sum(t['bytes'] for t in tracks)/1e6:.0f} MB")
