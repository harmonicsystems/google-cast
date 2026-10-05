# BackTrack → Nest: Shape A handoff

Goal: a small native iOS **Cast sender** that plays a BackTrack audio file on David's Nest speakers through Google's **Default Media Receiver**. No receiver app, no server of our own. This is the MVP for learning the Cast system; the content comes from BackTrack's existing **Setup ▸ Save ▸ Save as audio** (`~/Code/backtrack`, `js/export.js`), which renders any setup to a WAV.

How Cast works, in one line: the phone never streams audio. The sender tells the speaker *what URL to play*; the speaker fetches and plays it itself. So the file must sit at an HTTPS URL the Nest can reach.

## Non-goals (for now)
- No custom Web Receiver (Shape B: BackTrack's engine running on the speaker). Different handoff.
- No in-app rendering of the WAV on the iPhone, no local HTTP server. The file is pre-made and hosted.
- No queueing, no artwork beyond a title, no multi-room grouping. Playing one file end to end is the win.

## Prerequisites (David)
- Xcode (current), an iPhone on iOS 16+, and a Nest speaker on the **same Wi-Fi** as the iPhone.
- An Apple Developer account is NOT needed to run on his own iPhone (free personal team signing is enough).
- CocoaPods installed (`brew install cocoapods`). The Cast SDK ships as the pod `google-cast-sdk` (4.8.x); there is no Swift Package Manager distribution, only CocoaPods or a manually dropped-in XCFramework.
- One hosted WAV (step 1).

## Step 1 — make and host the test file
1. In BackTrack **on the Mac** (`python3 -m http.server 8766` in `~/Code/backtrack`, or the live site), pick a setup and use Setup ▸ Save ▸ Save as audio, length **1 min** (the browser render is fast: ~0.3 s for 70 s). Good first candidates:
   - **Noise mode, Soft rain**: `renderNoise` makes whole buffer periods, so the file loops seamlessly when a player repeats it. Nice on a speaker.
   - **A Groove at 96 with the Wash**: proves drums + drone come through.
2. Host it as a static file. Simplest: a `docs/` folder in this repo with GitHub Pages on `main`/`docs`, giving `https://harmonicsystems.github.io/google-cast/<name>.wav`. (Or drop it in BackTrack's repo under `audio/cast/` — but keep it out of BackTrack's service worker `SHELL`.)
3. Check the URL in a desktop browser plays it. Note the size: 48 kHz stereo 16-bit is ~11 MB/min and 1.536 Mbps — under the audio devices' 2 Mbps cap but not by much. If the Nest stutters, re-render at 44.1 kHz or convert to AAC (`ffmpeg -i in.wav -c:a aac -b:a 192k out.m4a`) and serve that instead; Cast plays both.

Checkpoint: a public HTTPS URL that plays in Safari.

## Step 2 — the Xcode project
- New iOS App, SwiftUI, name `BackTrackCast`, bundle id `org.harmonic-systems.backtrackcast` (any id; personal team signing).
- Minimum deployment iOS 16.
- `pod init`, Podfile: `pod 'google-cast-sdk'`, `pod install`, open the `.xcworkspace` from now on.
- Do NOT set the optimization flag to `-Ofast` (the SDK crashes); leave the default `-Os`.

`Info.plist` additions (the local-network prompt won't appear and discovery will silently find nothing without these):
```
NSBonjourServices
  _googlecast._tcp
  _CC1AD845._googlecast._tcp
NSLocalNetworkUsageDescription
  BackTrack Cast finds speakers on your Wi-Fi to play your backing tracks.
```
`CC1AD845` is the Default Media Receiver's app id (`kGCKDefaultMediaReceiverApplicationID` in the SDK).

## Step 3 — initialize Cast once, at launch
In the `App` struct's `init` (or an `AppDelegate` adaptor):
```swift
import GoogleCast

let criteria = GCKDiscoveryCriteria(applicationID: kGCKDefaultMediaReceiverApplicationID)
let options = GCKCastOptions(discoveryCriteria: criteria)
options.physicalVolumeButtonsWillControlDeviceVolume = true
GCKCastContext.setSharedInstanceWith(options)
GCKLogger.sharedInstance().delegate = nil   // set a delegate while debugging discovery
```

## Step 4 — the screen
One SwiftUI view:
- A **Cast button** (`GCKUICastButton`, wrapped in `UIViewRepresentable`). Tapping it shows the SDK's own device picker; picking the Nest starts a session. That picker is the whole connection UI — don't build one.
- A list of one or more hardcoded entries `{ title, url, contentType }`, e.g. `("Soft rain · 1 min", ".../soft-rain-1min.wav", "audio/wav")`.
- A **Play on speaker** button, enabled when `GCKCastContext.sharedInstance().sessionManager.currentCastSession != nil`.

Play:
```swift
let meta = GCKMediaMetadata(metadataType: .musicTrack)
meta.setString("Soft rain · 1 min", forKey: kGCKMetadataKeyTitle)
meta.setString("BackTrack", forKey: kGCKMetadataKeyArtist)

let b = GCKMediaInformationBuilder(contentURL: url)
b.streamType = .buffered
b.contentType = "audio/wav"
b.metadata = meta

let req = GCKMediaLoadRequestData()
req.mediaInformation = b.build()
req.autoplay = true
GCKCastContext.sharedInstance().sessionManager.currentCastSession?
    .remoteMediaClient?.loadMedia(with: req)
```
Also add the SDK's mini controller / expanded controller later if wanted (`GCKUIMiniMediaControlsViewController`); not needed for the MVP.

Observe session state with `GCKSessionManagerListener` (`sessionManager(_:didStart:)`, `didEnd`) to flip the button, and `GCKRemoteMediaClientListener` (`remoteMediaClient(_:didUpdate mediaStatus:)`) to show playing / idle. Keep the UI copy descriptive, as in BackTrack: the speaker's name and what's playing, nothing more.

## Step 5 — verify on the real speaker
1. Run on the iPhone (not the Simulator: no Bonjour discovery there in practice). Accept the local-network prompt.
2. Cast button → the Nest appears by its Home name → pick it → Play. The file plays on the Nest; the iPhone stays silent.
3. Noise loop: in the Google Home app, confirm the track ends cleanly after a minute (Default Media Receiver doesn't loop; repeating is a later feature via `GCKMediaQueue` with `repeatMode`).
4. Lock the iPhone: playback continues (it's the speaker's).
5. Note what the Nest's volume buttons / the iPhone's volume rocker do.

Record results in this file under **Verified**.

## Known unknowns
- Whether the Nest handles a 48 kHz WAV without underruns at 1.5 Mbps (fallback: 44.1 kHz or AAC, step 1.3).
- Whether the free personal signing team is enough for the local-network entitlement on a current iOS (it should be; if discovery finds nothing, check `NSBonjourServices` first, then Settings ▸ Privacy ▸ Local Network).
- The SDK's pod version at the time of install; the docs page is the source: https://developers.google.com/cast/docs/ios_sender

## Later (not now)
- A queue with repeat for the seamless Noise loops.
- Picking a BackTrack preset in the sender and resolving it to a file name: the files could be named by `presetString()` (e.g. `n-pink_e-6.-2.1.3.0.wav`), so a BackTrack `?p=` link maps straight to a URL.
- Shape B: BackTrack as a custom audio-only Web Receiver. First experiment there is whether the Web Audio API exists in the audio-device receiver runtime at all.

## Sources
- iOS sender setup: https://developers.google.com/cast/docs/ios_sender
- Audio-only devices (2 Mbps cap, 2 MB buffers): https://developers.google.com/cast/docs/audio
- Supported media: https://developers.google.com/cast/docs/media

## Status (2026-10-02)

Done by Claude, committed locally on `main` (two commits, repo not yet pushed):
- **Content**: the 84 Logic bounces in `~/Music/Logic/washer/Bounces/Wash with Drums`
  (7 tempos × 12 keys, 3 min, 48 kHz WAV, 34 MB each) are converted to AAC 192 kbps
  in `docs/audio/wash-<key>-<tempo>.m4a` (4.4 MB each, 375 MB total, `audio/mp4`).
  WAV was a non-starter: 2.9 GB total and GitHub Pages caps a site at ~1 GB.
  `docs/manifest.json` (from `docs/make-manifest.py`) lists them; `docs/index.html`
  is the "does the URL play" page.
- **App**: `BackTrackCast/` compiles against google-cast-sdk 4.8.6 (simulator build,
  unsigned). Tempo + key pickers, Cast button in the toolbar, Play / Pause / Resume /
  Stop, speaker name + player state. A **Repeat** toggle (on by default) loads the
  track as a one-item queue with `repeatMode = .all` since the Default Media Receiver
  doesn't loop a plain load. Project is generated by XcodeGen from `project.yml`;
  `pod install` needs `LANG=en_US.UTF-8` on this Mac or Ruby throws an encoding error.
- Deviation from step 4: the SDK's `GCKMediaLoadRequestData` is immutable in 4.8;
  use `GCKMediaLoadRequestDataBuilder` / `GCKMediaQueueDataBuilder`.

Done 2026-10-02 after the first pass: repo pushed to
https://github.com/harmonicsystems/google-cast, Pages enabled from `main` / `/docs`.
Checkpoint passed: https://harmonicsystems.github.io/google-cast/audio/wash-c-96.m4a
serves `audio/mp4` with `accept-ranges: bytes`; https://harmonicsystems.github.io/google-cast/
lists all 84 tracks.

Left for David:
1. **Sign and run**: open `BackTrackCast.xcworkspace`, Signing & Capabilities ▸ Team.
   `project.yml` has `DEVELOPMENT_TEAM: PFGM5X4HD6` (the team most of ~/Code uses),
   but the Mac has no signing cert for it yet, so Xcode must log in once. Run on the
   iPhone, accept the local-network prompt, then step 5 above.

## Verified (2026-10-02)
- First end-to-end success: BackTrack Cast on David's iPhone 13 Pro (iOS 26.6.1) → Nest Mini
  "Feed and Seed", playing a hosted AAC render from GitHub Pages. The iPhone stays silent.
- Still to note after more use: any stutter at 192 kbps AAC, whether the one-item queue
  repeat is seamless, what the iPhone volume rocker does.

### Discovery troubleshooting (the thing that cost the morning)
Symptom: Cast dialog says "No devices available"; app's "Speakers found" stays 0.
It was the network, not the app. Diagnosis trail, so it's quick next time:
- Mac on the same subnet saw the speakers fine (`dns-sd -B _googlecast._tcp local.`).
- The SDK log (now written to the app's `Documents/cast.log`; pull with
  `xcrun devicectl device copy from --domain-type appDataContainer --domain-identifier
  org.harmonic-systems.backtrackcast --source Documents/cast.log --destination cast.log`)
  showed the phone on the right subnet sending its mDNS query and getting zero replies.
- Google Home on the phone was flaky too; Spotify "working" proves nothing because it
  uses Spotify Connect via the cloud, not local discovery.
- Router is Spectrum Advanced WiFi (SAX2V1S) with two WiFi pods; no web UI, no
  multicast/isolation settings in the My Spectrum app. Fix was reboots: restart the
  router from the app, power-cycle the Nest Mini, forget + rejoin Wi-Fi on the phone.
- If it recurs: stand next to the Nest Mini (same pod) to confirm the mesh is at fault.

Other gotchas hit on the way:
- Xcode "No such module GoogleCast" = the `.xcodeproj` was open instead of the
  `.xcworkspace`, or the run destination was the Mac (SDK has no Mac slice; project now
  restricts destinations to iPhone).
- "Developer disk image could not be mounted" = phone was locked. Unlock it, rerun.
- Personal team signing needed the updated Program License Agreement accepted at
  developer.apple.com first.
- `GCKLogger` only calls its delegate once `loggingEnabled = true` and a
  `GCKLoggerFilter` with `minimumLevel = .verbose` is set (DEBUG builds do this).

## Rendering BackTrack noise for the speakers (2026-10-02)
BackTrack's noise lives in `~/Code/backtrack/js/noise.js` (`renderNoise(g, minutes, sr)`,
browser-only: OfflineAudioContext). To make hosted files that match the app exactly:
`python3 -m http.server 8766` in `~/Code/backtrack`, open it in a browser, and from the
console `import('/js/noise.js')` + `import('/js/rec.js')`: `renderNoise({...NDEFAULTS, ncolor,
neq, nwave, nswell}, 2, 48000)` → `mixWav(buf, name, from)` → PUT the File to a local
receiver that writes it to disk → ffmpeg to AAC → `docs/audio/noise-<id>.m4a` → add the
title to `NOISE_TITLES` in `docs/make-manifest.py`. Textures (`TEXTURES` in state.js) are
[id, label, color, eq, waves, depth]; colors white/pink/brown/grey/blue/violet; waves 6–16 s.
Whole buffer periods, so the files loop seamlessly under REPEAT_ALL.

## Long-form renders: Nap Time (2026-10-05)
`docs/audio/long-nap-time.m4a` is BackTrack's `?p=n-brown/e0.4.6.-6.-11/w6/s60/arain.w16.s50`
stretched to 150 minutes (brown surf arriving at soft rain, 16 s waves), ending in a 30 s fade.
- A single OfflineAudioContext can't hold 2.5 h (≈3.5 GB), so it was rendered as thirty 300 s
  segments in the BackTrack page: same `noiseBuffer`, `BANDS`/`eqLive`, `scheduleWaves`,
  with everything expressed in global time (buffer offset = A mod buffer length; EQ and the
  equal-power color crossfade evaluated at global position; waves scheduled on the original
  clock through a proxy that shifts times by the segment start) and 0.5 s of true pre-roll.
  Chunked vs single-piece differs by < 7e-5 at a 0.35 peak.
- Segments written at half gain, concatenated with ffmpeg (`volume=2,afade=t=out:st=8970:d=30`).
- GitHub's file cap is 100 MB, so this one is HE-AAC 80 kbps (`afconvert -f m4af -d aach
  -b 80000`), 85 MB. Everything else stays AAC-LC 192k. The Pages site is now ~610 MB of
  its ~1 GB allowance: a second 2.5 h file fits, a third doesn't. Past that, long files
  should move to GitHub Release assets (2 GB each) or another host.
- Manifest layer `long` marks tracks `once: true`; senders must not loop them.
