# SyphonHue — Design

**Date:** 2026-04-14
**Target:** macOS 13+ (Swift, SwiftUI, Metal, CoreMIDI)

## Goal

A macOS app that receives a Syphon video feed (e.g. from ProPresenter), lets the user place 1–8 sample points on the feed, and continuously sends the sampled color values as MIDI CC messages to LightKey's assignable external controls.

## User flow

1. Start the app.
2. Pick a Syphon server from the dropdown (lists all publishers currently on the system).
3. Pick a MIDI destination from the dropdown (lists all current CoreMIDI destinations).
4. Add points; drag them on the video preview to position.
5. For each point, configure up to three CC assignments: which value (H, S, B, R, G, or B2 = blue), the CC number (0–127), and the MIDI channel (1–16).
6. Adjust the send-rate slider (5–60 Hz).
7. In LightKey, learn the CCs onto external controls.

## Components

- **`SyphonController`** — wraps `SyphonMetalClient`. Observes Syphon server directory. Exposes available server list and the current `MTLTexture` frame.
- **`PreviewRenderer`** — `MTKView`-backed view that draws the incoming Syphon texture. SwiftUI overlay draws numbered, draggable circular markers per sample point.
- **`FrameSampler`** — given a frame texture + point list + 16×16 radius (in source-texture pixels), returns averaged `RGBA` per point. Implemented with a Metal compute kernel writing to a small result buffer; falls back to CPU readback if compute is unavailable.
- **`ColorMapper`** — RGB → HSB; normalizes 0–1 to 0–127 for MIDI.
- **`MIDIOut`** — CoreMIDI: enumerates destinations, opens output port, sends CC (`0xB0 | channel`, controller, value). Uses `MIDIEventListSendEvent` (modern API on macOS 13+).
- **`PointStore`** (`ObservableObject`) — `[SamplePoint]`. Each `SamplePoint`:
  - `id: UUID`
  - `position: CGPoint` (normalized 0–1)
  - `assignments: [CCAssignment]` (1–3 entries). Each:
    - `source: ColorValue` (`.hue`, `.saturation`, `.brightness`, `.red`, `.green`, `.blue`)
    - `cc: Int` (0–127)
    - `channel: Int` (1–16)
    - `enabled: Bool`
- **`AppViewModel`** — owns the send timer and change-threshold state (last-sent value per assignment). Only sends a CC when its integer value differs from the last-sent value.
- **`ConfigStore`** — serializes `PointStore` + selected server name + selected destination name to `~/Library/Application Support/SyphonHue/config.json` on change, restores on launch.

## UI layout

- Top toolbar: Syphon server menu · MIDI destination menu · send-rate slider · "Add point" / "Remove" buttons.
- Main area (split): left 70% = video preview with overlay markers; right 30% = scrollable list of points. Each point row shows normalized x/y, live color swatch + RGB/HSB readout, and up to three CC assignment rows (source / cc# stepper / channel stepper / enabled toggle).
- Footer: status line ("Syphon: connected to X · MIDI: Y · N points active").

## Data flow

```
SyphonClient ──frame───► PreviewRenderer (display)
                    └─► FrameSampler (send-timer tick)
                              │
                              ▼
                        ColorMapper
                              │
                              ▼
                       diff vs last sent
                              │
                              ▼
                          MIDIOut ──► macOS CoreMIDI ──► LightKey
```

## Dependencies (vendored)

- `Syphon.framework` — built from https://github.com/Syphon/Syphon-Framework (BSD-licensed), committed into `Frameworks/Syphon.framework` and embedded in the app bundle.
- Everything else is system-provided: CoreMIDI, Metal, SwiftUI, AppKit, IOSurface.

## Error handling

- No Syphon servers available → preview shows empty state with instructions.
- Syphon server disappears mid-session → controller clears texture, preview shows "server lost", user can pick another.
- MIDI destination disappears → `MIDIOut` disables sending, status line shows red indicator, user can reselect.
- Metal device unavailable (extremely unusual) → app shows fatal error alert on startup.

## Testing plan

1. Launch app.
2. Launch ProPresenter with Syphon output enabled. Verify it appears in the Syphon dropdown and preview shows the feed.
3. Add 2 points. Drop one on a known red region, one on a known blue region. Verify the color swatches match.
4. Configure CC1 = Hue of point 0, CC2 = Hue of point 1, both channel 1.
5. Open LightKey, select SyphonHue's MIDI destination as input, map external controls to CC1 and CC2.
6. Change ProPresenter content; confirm LightKey's hue values track.
7. Kill/restart ProPresenter; confirm app recovers cleanly.
8. Quit and relaunch; confirm points and CC config persisted.

## Non-goals (YAGNI)

- No OSC, no Art-Net, no DMX.
- No preset library beyond the single persisted config.
- No scripting, no MIDI learn from LightKey's side.
- No color correction or gamma adjustment — raw sampled color is sent.
- No recording/playback of CC streams.
