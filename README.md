# SyphonHue

macOS app that takes a Syphon video feed and sends sampled pixel colors as MIDI CC messages — for driving LightKey's assignable external controls (hue/saturation/brightness) from ProPresenter's visual output.

## Build

```
./build-syphon.sh         # clones + builds Syphon.framework into Frameworks/
xcodegen generate         # produces SyphonHue.xcodeproj
open SyphonHue.xcodeproj  # build & run in Xcode (or: xcodebuild -scheme SyphonHue)
```

## Prerequisites

- macOS 13+
- Xcode 15+ with Command Line Tools
- `xcodegen` (`brew install xcodegen`)

## Use

1. Launch SyphonHue.
2. Pick a Syphon server (e.g. ProPresenter's output).
3. Pick a MIDI destination (e.g. an IAC bus, or a virtual port LightKey listens on).
4. Add sample points; drag them on the preview.
5. For each point, assign up to three CC messages (source = H/S/B/R/G/B, CC#, channel).
6. In LightKey, MIDI-learn external controls from those CCs.
