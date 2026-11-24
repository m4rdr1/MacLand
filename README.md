# MacLand

A native macOS **Dynamic Island** that lives at the top of your screen: now-playing media, system volume, silent/ring alerts, your calendar, and a quick Spotify/YouTube search — all in one pill that expands when you hover it.

MacLand is the macOS port of **WinLand**, the original hand-written C++/Direct2D version for Windows. After I hackintoshed my PC I had an AI assistant convert it to Swift so it could run natively on macOS. The Windows app is still the reference implementation; MacLand is the port that grew its own macOS-shaped features.

<p align="left">
  <img alt="platform" src="https://img.shields.io/badge/platform-macOS%2012%2B-black">
  <img alt="language" src="https://img.shields.io/badge/Swift-5-orange">
  <img alt="dependencies" src="https://img.shields.io/badge/dependencies-none-brightgreen">
</p>

---

## Features

- **Hover to expand** — a compact pill shows the current track; hover it and it springs open into a full media card.
- **Now playing** — artwork, title, artist, elapsed/remaining time, and a seek bar you can drag.
- **Transport controls** — play/pause, previous, next, driven through the system-wide MediaRemote session (works with Music, Spotify, browsers, anything that publishes now-playing info).
- **Volume** — scroll anywhere over the island to change the output volume; click the speaker to mute. A volume pill slides out with a speaker and a fill bar.
- **Silent / Ring / Volume alerts** — the island morphs into a small status pill when the output is muted or hits zero (**Silent**), when it comes back up (**Ring**), or when the volume changes (**Volume**). Silent and Ring take priority, so a volume tweak never stomps on them.
- **Calendar** — today's weekday and date, the next event, and a one-line status for the rest of your day.
- **Search** — click the magnifier, type, then <kbd>Enter</kbd> for Spotify or <kbd>⌘</kbd><kbd>Enter</kbd> for YouTube. <kbd>Esc</kbd> cancels.
- **Physics, not keyframes** — every size, position, and alert transition is a damped spring, with motion blur and a rubber-band stretch while dragging.
- **Menu bar only** — no Dock icon, no window chrome, never steals focus. A capsule icon in the menu bar has previews for each alert style and a Quit item.
- **Offline renderer** — dump the island to a PNG from the command line, handy for docs and design checks.

---

## Requirements

| | |
|---|---|
| macOS | 12.0 Monterey or newer (built and used on Sequoia 15.8.3) |
| Toolchain | Xcode Command Line Tools (`swiftc`, `clang`) |
| Runtime | `/usr/bin/perl` (ships with macOS) |
| Permissions | Calendar access (prompted on first launch) |

No package manager, no third-party frameworks, no network calls. Media info comes from the private `MediaRemote` framework, which macOS exposes without entitlements — that is also the one thing Apple could change out from under this app (see [Notes](#notes--limitations)).

---

## Build

```bash
cd MacLand
bash build.sh
open MacLand.app
```

`build.sh` produces `MacLand.app` in place:

1. compiles all of `Sources/*.swift` with `swiftc -O` for the host architecture, targeting macOS 12;
2. builds `MacLandMedia.dylib` from `Sources/MediaBridge.c` with `clang`;
3. copies `Resources/macland-media.pl` into the bundle;
4. ad-hoc signs the dylib and the app.

There is nothing to install. To rebuild after editing sources, run `bash build.sh` again and **relaunch the app** — a running instance keeps the old binary loaded.

The build is architecture-native: Intel machines get `x86_64`, Apple Silicon gets `arm64`.

---

## Usage

| Action | Result |
|---|---|
| Hover the pill | Expands to the media card |
| Move away | Collapses back to the compact pill |
| Scroll over the island | Volume ±4% per notch (trackpad: fine-grained) |
| Click the speaker | Mute / unmute |
| Click play/pause | Toggle playback |
| Drag the progress bar | Seek |
| Drag the capsule sideways | Rubber-band stretch |
| Click the magnifier | Open search |
| <kbd>Esc</kbd> / <kbd>Enter</kbd> / <kbd>⌘</kbd><kbd>Enter</kbd> | Cancel search / Spotify / YouTube |
| Right-click the island | Preview Ring, Silent, and Volume alerts; Quit |
| Menu bar capsule | Same previews, plus Quit |

The island only accepts mouse events while the pointer is over it, so it never blocks clicks on the menu bar or your windows.

---

## How it works

### Frame loop

`AppDelegate` owns a borderless, non-activating `NSPanel` (720×460) pinned to the top center of the main screen. A 120 Hz `Timer` advances the simulation; drawing is capped at ~62 fps and skipped entirely when nothing is moving. Every animated value is a damped `Spring` (see `Spring.swift`) integrated at up to 240 Hz sub-steps, so motion is stable regardless of frame timing.

### Island states

`Island` is a small state machine with four modes — `idle`, `compact`, `alert`, `expanded` — plus independent spring targets for width, height, and expansion. Hover, alert expiry, and media presence decide the next mode; the springs do the rest. Layout is recomputed each frame in `ComputeLayout`, which is what lets the pill stretch and squash while keeping its contents attached.

### Media pipeline

Now-playing data comes from MediaRemote in two layers:

1. `NowPlaying` calls `MRMediaRemoteGetNowPlayingInfo` directly via `dlopen`/`dlsym` every 0.5 s.
2. If the private symbols are unavailable, a bundled helper (`macland-media.pl` + `MacLandMedia.dylib`) runs as a child process and streams length-prefixed plist frames instead — no polling, no XPC, and no fragile Swift bridging.

Playback state is only trusted when the frame actually carries `kMRMediaRemoteNowPlayingInfoPlaybackRate`. Without that guard, a paused track reports no rate and the UI keeps extrapolating from the last timestamp, which makes the progress bar and waveform crawl while paused.

### Volume

`VolumeControl` talks to CoreAudio's default output device. Built-in outputs often expose **no master volume element**, only per-channel elements, so reads and writes walk every element the device advertises. Writing a single channel on a stereo device changes one side only — that is exactly the bug that made volume feel broken in early builds.

`Island.pollVolume()` watches the device every 120 ms and classifies changes:

- mute or ≤ 0.5% → **Silent** alert, and raising it again → **Ring**;
- any other change → **Volume** pill, but only while no Silent/Ring alert is on screen;
- local scrolls are held briefly (`volHoldUntil`) so the poll does not re-trigger on its own writes.

### Calendar

`CalendarService` reads the user's EventKit store, refreshes every 60 seconds and on `EKEventStoreChanged`, and publishes a compact `CalendarInfo` (weekday, day, next event, free/busy line) that the idle island renders.

---

## Snapshots

Render the island without running the app:

```bash
MacLand.app/Contents/MacOS/MacLand --snapshot island.png
MacLand.app/Contents/MacOS/MacLand --snapshot-media media.png
```

The first renders the calendar/idle state, the second renders the expanded media card with sample data. Both write a 500×268 PNG at 2× scale.

---

## Project layout

```
MacLand/
├── build.sh                 # compile, bundle, ad-hoc sign
├── Info.plist               # LSUIElement, calendar usage strings, macOS 12 minimum
├── Sources/
│   ├── main.swift           # entry point + snapshot flags
│   ├── App.swift            # panel, view, status item, 120 Hz tick
│   ├── Island.swift         # state machine, layout, input, alerts, volume
│   ├── Draw.swift           # CoreGraphics/CoreText rendering
│   ├── Media.swift          # MediaRemote bridge, volume control, calendar
│   ├── MediaBridge.c        # dylib used by the perl helper
│   └── Spring.swift         # damped spring integrator
└── Resources/
    └── macland-media.pl     # helper that streams now-playing plist frames
```

---

## Notes & limitations

- **Private API.** MediaRemote is not public API. It has been stable for years, but a macOS update can rename or remove symbols. The perl helper exists as a fallback for that reason; if both fail, the island simply shows the calendar.
- **Ad-hoc signed.** The app is signed with `-` (ad-hoc), not a Developer ID. If you copy it to another Mac and Gatekeeper complains, right-click → **Open** once, or clear the quarantine attribute.
- **Not sandboxed, not notarized, not on the App Store.** It needs to touch the private framework, system audio, and your calendar, which rules out sandboxing.
- **Single display.** The island is placed on `NSScreen.main` at launch and does not follow display changes.
- **No login item.** Launch it yourself, or add it in System Settings → General → Login Items.
- **Hackintosh friendly.** Developed on an Intel Hackintosh (Alder Lake i3-1215U, macOS Sequoia) — no Metal requirements, only CoreGraphics, so it runs on any Mac that meets the macOS minimum.

---

## Origin

**WinLand** — the original Windows Dynamic Island — is hand-written C++ in `../WindowsLand`. It targets Win32, Direct2D, and the WASAPI endpoint volume API, and it is the design and behaviour reference for everything here.

**MacLand** is that app reimplemented in Swift for macOS, converted with an AI assistant after I moved my desktop to a hackintoshed macOS install. If something looks off compared to the Windows version, it is a porting bug, not a design decision — open an issue with the WinLand behaviour you expected.

No license file is included in this repository.
