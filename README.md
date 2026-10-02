# BackTrack Cast

A small iOS Cast sender that plays hosted BackTrack renders on a Nest speaker through
Google's Default Media Receiver. No receiver app, no server. See `HANDOFF.md` for the
why and the step-by-step.

## Layout
- `docs/` — GitHub Pages site. `docs/audio/*.m4a` are the hosted tracks (AAC 192 kbps,
  3 min each), `docs/manifest.json` lists them, `docs/index.html` is a check-it-plays page.
  Rebuild the manifest with `python3 docs/make-manifest.py` after adding files.
- `BackTrackCast/` — SwiftUI sources + generated `Info.plist`.
- `project.yml` — XcodeGen spec. `xcodegen generate` recreates `BackTrackCast.xcodeproj`.
- `Podfile` — `pod 'google-cast-sdk'`. Open `BackTrackCast.xcworkspace`, not the project.

## Setup
```bash
brew install xcodegen cocoapods
xcodegen generate
LANG=en_US.UTF-8 pod install
open BackTrackCast.xcworkspace
```
Then in Xcode: Signing & Capabilities → pick your personal team, run on a real iPhone.

## Adding tracks
Name files `wash-<key>-<tempo>.m4a` (lowercase key, e.g. `wash-bb-96.m4a`), drop them in
`docs/audio/`, run the manifest script, and add the key/tempo to `Library` in
`BackTrackCast/Sources/Track.swift` if it's new.

To re-encode a Logic WAV bounce:
```bash
ffmpeg -i in.wav -c:a aac -b:a 192k -movflags +faststart out.m4a
```
