# SyphonHue Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a macOS SwiftUI app that ingests a Syphon video feed, lets the user place 1–8 sample points, and streams sampled colors as MIDI CC messages to LightKey.

**Architecture:** SwiftUI macOS app (deployment target macOS 13). `SyphonMetalClient` from the vendored `Syphon.framework` feeds an `MTLTexture` into both a preview `MTKView` and a Metal compute kernel that averages 16×16 pixel tiles at each normalized sample point. Results go through `ColorMapper` (RGB→HSB + 0–127 normalization) and `MIDIOut` (CoreMIDI `MIDIEventListSendEvent`). A send-rate timer dispatches CC packets with a change-threshold diff. `PointStore` is persisted as JSON.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit interop (`NSViewRepresentable`), Metal, CoreMIDI, `Syphon.framework` (vendored). Project generated with XcodeGen. Tests via XCTest.

---

## File Structure

```
SyphonHue/
├── project.yml                         (XcodeGen spec)
├── build-syphon.sh                     (builds Syphon.framework from source)
├── README.md
├── Frameworks/
│   └── Syphon.framework/               (vendored, built from source once)
├── Sources/
│   ├── Info.plist
│   ├── SyphonHue-Bridging-Header.h     (imports Syphon umbrella header)
│   ├── App/
│   │   ├── SyphonHueApp.swift          (@main entry point)
│   │   └── AppViewModel.swift          (wires everything, owns send timer)
│   ├── Model/
│   │   ├── SamplePoint.swift           (SamplePoint + CCAssignment + ColorValue)
│   │   ├── PointStore.swift            (ObservableObject managing [SamplePoint])
│   │   └── ConfigStore.swift           (JSON persistence)
│   ├── Color/
│   │   └── ColorMapper.swift           (RGB↔HSB + MIDI normalization)
│   ├── MIDI/
│   │   └── MIDIOut.swift               (CoreMIDI destination enumeration + CC send)
│   ├── Syphon/
│   │   ├── SyphonController.swift      (wraps SyphonServerDirectory + SyphonMetalClient)
│   │   └── MetalContext.swift          (shared MTLDevice/commandQueue)
│   ├── Sampling/
│   │   ├── FrameSampler.swift          (CPU-readback sampler, single clear path)
│   │   └── Sampler.metal               (not used in v1 — CPU path is enough)
│   └── UI/
│       ├── ContentView.swift           (top-level layout)
│       ├── PreviewView.swift           (MTKView + point marker overlay)
│       ├── PointRowView.swift          (one row in the sidebar)
│       ├── SidebarView.swift           (scrollable list of point rows)
│       └── ToolbarView.swift           (server/destination dropdowns, rate slider)
└── Tests/
    ├── ColorMapperTests.swift
    ├── SamplePointTests.swift
    ├── ConfigStoreTests.swift
    └── MIDIOutTests.swift
```

---

## Task 1: Bootstrap repo structure

**Files:**
- Create: `.gitignore`
- Create: `README.md`

- [ ] **Step 1: Write `.gitignore`**

```
.build/
.DS_Store
DerivedData/
*.xcodeproj
*.xcworkspace
!Frameworks/*.xcodeproj
xcuserdata/
*.xcuserstate
build/
Syphon-Framework/
```

- [ ] **Step 2: Write `README.md`**

```markdown
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
```

- [ ] **Step 3: Commit**

```bash
git add .gitignore README.md
git commit -m "Bootstrap SyphonHue repo with README and gitignore"
```

---

## Task 2: Script for building Syphon.framework

**Files:**
- Create: `build-syphon.sh`

Syphon is an Objective-C BSD-licensed macOS framework published at https://github.com/Syphon/Syphon-Framework. We clone it, build Release, and copy the resulting `Syphon.framework` into `Frameworks/`.

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/Syphon-Framework"
OUT_DIR="$SCRIPT_DIR/Frameworks"

if [ -d "$OUT_DIR/Syphon.framework" ]; then
    echo "Syphon.framework already present in $OUT_DIR — skipping build."
    echo "Delete it to rebuild."
    exit 0
fi

if [ ! -d "$SRC_DIR" ]; then
    echo "Cloning Syphon-Framework…"
    git clone --depth 1 https://github.com/Syphon/Syphon-Framework.git "$SRC_DIR"
fi

echo "Building Syphon.framework (Release, universal)…"
cd "$SRC_DIR"
xcodebuild \
    -project Syphon.xcodeproj \
    -target Syphon \
    -configuration Release \
    -arch arm64 -arch x86_64 \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    BUILD_DIR="$SRC_DIR/build" \
    build

mkdir -p "$OUT_DIR"
cp -R "$SRC_DIR/build/Release/Syphon.framework" "$OUT_DIR/"
echo "Syphon.framework installed at $OUT_DIR/Syphon.framework"
```

- [ ] **Step 2: Make executable and run**

```bash
chmod +x build-syphon.sh
./build-syphon.sh
```

Expected: `Frameworks/Syphon.framework/` exists with `Syphon`, `Headers/`, `Resources/`, etc.

- [ ] **Step 3: Verify headers**

```bash
ls Frameworks/Syphon.framework/Headers/
```

Expected to include at least: `Syphon.h`, `SyphonServerDirectory.h`, `SyphonMetalClient.h`, `SyphonClient.h`, `SyphonServer.h`.

- [ ] **Step 4: Commit the framework**

```bash
git add build-syphon.sh Frameworks/Syphon.framework
git commit -m "Vendor Syphon.framework (built from Syphon/Syphon-Framework HEAD)"
```

---

## Task 3: XcodeGen project spec

**Files:**
- Create: `project.yml`
- Create: `Sources/Info.plist`
- Create: `Sources/SyphonHue-Bridging-Header.h`

- [ ] **Step 1: Write `Sources/Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>SyphonHue</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 2: Write `Sources/SyphonHue-Bridging-Header.h`**

```objc
#ifndef SyphonHue_Bridging_Header_h
#define SyphonHue_Bridging_Header_h

#import <Syphon/Syphon.h>

#endif
```

- [ ] **Step 3: Write `project.yml`**

```yaml
name: SyphonHue
options:
  bundleIdPrefix: com.syphonhue
  deploymentTarget:
    macOS: "13.0"
  createIntermediateGroups: true
settings:
  base:
    SWIFT_VERSION: "5.9"
    ENABLE_HARDENED_RUNTIME: YES
targets:
  SyphonHue:
    type: application
    platform: macOS
    sources:
      - path: Sources
        excludes:
          - SyphonHue-Bridging-Header.h
          - Info.plist
    dependencies:
      - framework: Frameworks/Syphon.framework
        embed: true
        codeSign: true
    info:
      path: Sources/Info.plist
      properties:
        CFBundleName: SyphonHue
        NSHighResolutionCapable: true
        LSMinimumSystemVersion: "13.0"
    settings:
      base:
        INFOPLIST_FILE: Sources/Info.plist
        PRODUCT_BUNDLE_IDENTIFIER: com.syphonhue.app
        PRODUCT_NAME: SyphonHue
        CODE_SIGN_IDENTITY: "-"
        CODE_SIGN_STYLE: Manual
        DEVELOPMENT_TEAM: ""
        FRAMEWORK_SEARCH_PATHS:
          - $(SRCROOT)/Frameworks
        SWIFT_OBJC_BRIDGING_HEADER: Sources/SyphonHue-Bridging-Header.h
        LD_RUNPATH_SEARCH_PATHS:
          - "@executable_path/../Frameworks"
        MACOSX_DEPLOYMENT_TARGET: "13.0"
        ENABLE_APP_SANDBOX: NO
  SyphonHueTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: Tests
    dependencies:
      - target: SyphonHue
    settings:
      base:
        BUNDLE_LOADER: $(TEST_HOST)
        TEST_HOST: $(BUILT_PRODUCTS_DIR)/SyphonHue.app/Contents/MacOS/SyphonHue
        MACOSX_DEPLOYMENT_TARGET: "13.0"
schemes:
  SyphonHue:
    build:
      targets:
        SyphonHue: all
        SyphonHueTests: [test]
    test:
      targets:
        - SyphonHueTests
    run:
      config: Debug
    archive:
      config: Release
```

- [ ] **Step 4: Generate project**

```bash
mkdir -p Sources/App Sources/Model Sources/Color Sources/MIDI Sources/Syphon Sources/Sampling Sources/UI Tests
touch Sources/App/.keep Sources/Model/.keep Tests/.keep
xcodegen generate
```

Expected: `SyphonHue.xcodeproj` appears. The `.keep` files prevent xcodegen from choking on empty dirs.

- [ ] **Step 5: Commit**

```bash
git add project.yml Sources/Info.plist Sources/SyphonHue-Bridging-Header.h Sources/*/.keep Tests/.keep
git commit -m "Add XcodeGen project spec and bridging header"
```

---

## Task 4: ColorMapper with TDD

**Files:**
- Create: `Sources/Color/ColorMapper.swift`
- Create: `Tests/ColorMapperTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Tests/ColorMapperTests.swift
import XCTest
@testable import SyphonHue

final class ColorMapperTests: XCTestCase {
    func testRGBToHSBPureRed() {
        let hsb = ColorMapper.rgbToHSB(r: 1.0, g: 0.0, b: 0.0)
        XCTAssertEqual(hsb.h, 0.0, accuracy: 0.001)
        XCTAssertEqual(hsb.s, 1.0, accuracy: 0.001)
        XCTAssertEqual(hsb.b, 1.0, accuracy: 0.001)
    }

    func testRGBToHSBPureGreen() {
        let hsb = ColorMapper.rgbToHSB(r: 0.0, g: 1.0, b: 0.0)
        XCTAssertEqual(hsb.h, 1.0/3.0, accuracy: 0.001)
        XCTAssertEqual(hsb.s, 1.0, accuracy: 0.001)
    }

    func testRGBToHSBPureBlue() {
        let hsb = ColorMapper.rgbToHSB(r: 0.0, g: 0.0, b: 1.0)
        XCTAssertEqual(hsb.h, 2.0/3.0, accuracy: 0.001)
    }

    func testRGBToHSBGrey() {
        let hsb = ColorMapper.rgbToHSB(r: 0.5, g: 0.5, b: 0.5)
        XCTAssertEqual(hsb.s, 0.0, accuracy: 0.001)
        XCTAssertEqual(hsb.b, 0.5, accuracy: 0.001)
    }

    func testToMIDIClampsLow() {
        XCTAssertEqual(ColorMapper.toMIDI(-0.1), 0)
    }

    func testToMIDIClampsHigh() {
        XCTAssertEqual(ColorMapper.toMIDI(1.5), 127)
    }

    func testToMIDIMidpoint() {
        XCTAssertEqual(ColorMapper.toMIDI(0.5), 63)
    }

    func testToMIDIOne() {
        XCTAssertEqual(ColorMapper.toMIDI(1.0), 127)
    }

    func testToMIDIZero() {
        XCTAssertEqual(ColorMapper.toMIDI(0.0), 0)
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

```bash
xcodegen generate
xcodebuild -scheme SyphonHue -destination 'platform=macOS' test 2>&1 | tail -30
```

Expected: fails to compile (`ColorMapper` not found).

- [ ] **Step 3: Write `Sources/Color/ColorMapper.swift`**

```swift
import Foundation
import CoreGraphics

struct HSB {
    var h: Double
    var s: Double
    var b: Double
}

struct RGB {
    var r: Double
    var g: Double
    var b: Double
}

enum ColorMapper {
    /// Convert linear 0–1 RGB to HSB with h,s,b in 0–1.
    static func rgbToHSB(r: Double, g: Double, b: Double) -> HSB {
        let maxV = max(r, max(g, b))
        let minV = min(r, min(g, b))
        let delta = maxV - minV

        var h: Double = 0
        if delta > 0 {
            if maxV == r {
                h = ((g - b) / delta).truncatingRemainder(dividingBy: 6.0)
            } else if maxV == g {
                h = (b - r) / delta + 2.0
            } else {
                h = (r - g) / delta + 4.0
            }
            h /= 6.0
            if h < 0 { h += 1.0 }
        }
        let s = maxV == 0 ? 0 : delta / maxV
        return HSB(h: h, s: s, b: maxV)
    }

    /// Normalise a 0–1 value to a 0–127 integer, clamping out-of-range.
    static func toMIDI(_ value: Double) -> UInt8 {
        let clamped = min(max(value, 0.0), 1.0)
        return UInt8(round(clamped * 127.0))
    }
}
```

- [ ] **Step 4: Run tests — expect pass**

```bash
xcodebuild -scheme SyphonHue -destination 'platform=macOS' test 2>&1 | tail -20
```

Expected: all nine tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Color/ColorMapper.swift Tests/ColorMapperTests.swift
git rm -f Sources/Color/.keep 2>/dev/null || true
git commit -m "Add ColorMapper with RGB→HSB and MIDI normalization"
```

---

## Task 5: SamplePoint model with TDD

**Files:**
- Create: `Sources/Model/SamplePoint.swift`
- Create: `Tests/SamplePointTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Tests/SamplePointTests.swift
import XCTest
@testable import SyphonHue

final class SamplePointTests: XCTestCase {
    func testSamplePointCodableRoundTrip() throws {
        let p = SamplePoint(
            id: UUID(),
            position: CGPoint(x: 0.25, y: 0.75),
            assignments: [
                CCAssignment(source: .hue, cc: 20, channel: 1, enabled: true),
                CCAssignment(source: .saturation, cc: 21, channel: 1, enabled: false),
            ]
        )
        let data = try JSONEncoder().encode(p)
        let decoded = try JSONDecoder().decode(SamplePoint.self, from: data)
        XCTAssertEqual(decoded.id, p.id)
        XCTAssertEqual(decoded.position.x, 0.25)
        XCTAssertEqual(decoded.position.y, 0.75)
        XCTAssertEqual(decoded.assignments.count, 2)
        XCTAssertEqual(decoded.assignments[0].source, .hue)
        XCTAssertEqual(decoded.assignments[0].cc, 20)
        XCTAssertEqual(decoded.assignments[1].enabled, false)
    }

    func testCCAssignmentValidatesCCRange() {
        let a = CCAssignment(source: .hue, cc: 200, channel: 1, enabled: true)
        XCTAssertEqual(a.cc, 127, "CC should clamp to 0–127")
    }

    func testCCAssignmentValidatesChannelRange() {
        let a = CCAssignment(source: .hue, cc: 20, channel: 20, enabled: true)
        XCTAssertEqual(a.channel, 16, "Channel should clamp to 1–16")
    }

    func testColorValueRawValues() {
        XCTAssertEqual(ColorValue.hue.rawValue, "hue")
        XCTAssertEqual(ColorValue.red.rawValue, "red")
    }
}
```

- [ ] **Step 2: Write `Sources/Model/SamplePoint.swift`**

```swift
import Foundation
import CoreGraphics

enum ColorValue: String, Codable, CaseIterable, Identifiable {
    case hue, saturation, brightness, red, green, blue
    var id: String { rawValue }
    var label: String {
        switch self {
        case .hue: return "Hue"
        case .saturation: return "Sat"
        case .brightness: return "Bri"
        case .red: return "Red"
        case .green: return "Green"
        case .blue: return "Blue"
        }
    }
}

struct CCAssignment: Codable, Identifiable, Equatable {
    var id: UUID
    var source: ColorValue
    var cc: Int
    var channel: Int
    var enabled: Bool

    init(id: UUID = UUID(),
         source: ColorValue,
         cc: Int,
         channel: Int,
         enabled: Bool) {
        self.id = id
        self.source = source
        self.cc = max(0, min(127, cc))
        self.channel = max(1, min(16, channel))
        self.enabled = enabled
    }
}

struct SamplePoint: Codable, Identifiable, Equatable {
    var id: UUID
    /// Normalized 0–1 coordinates within the preview area.
    var position: CGPoint
    var assignments: [CCAssignment]

    init(id: UUID = UUID(),
         position: CGPoint,
         assignments: [CCAssignment] = []) {
        self.id = id
        self.position = position
        self.assignments = assignments
    }

    static func defaultAssignments(startingCC: Int, channel: Int = 1) -> [CCAssignment] {
        [
            CCAssignment(source: .hue, cc: startingCC, channel: channel, enabled: true),
            CCAssignment(source: .saturation, cc: startingCC + 1, channel: channel, enabled: false),
            CCAssignment(source: .brightness, cc: startingCC + 2, channel: channel, enabled: false),
        ]
    }
}
```

- [ ] **Step 3: Run tests — expect pass**

```bash
xcodegen generate && xcodebuild -scheme SyphonHue -destination 'platform=macOS' test 2>&1 | tail -20
```

Expected: all SamplePoint tests + prior tests pass.

- [ ] **Step 4: Commit**

```bash
git add Sources/Model/SamplePoint.swift Tests/SamplePointTests.swift
git rm -f Sources/Model/.keep 2>/dev/null || true
git commit -m "Add SamplePoint, CCAssignment, ColorValue models"
```

---

## Task 6: PointStore

**Files:**
- Create: `Sources/Model/PointStore.swift`

- [ ] **Step 1: Write `Sources/Model/PointStore.swift`**

```swift
import Foundation
import Combine
import CoreGraphics

final class PointStore: ObservableObject {
    @Published var points: [SamplePoint] = []
    static let maxPoints = 8

    func addPoint() {
        guard points.count < Self.maxPoints else { return }
        let startingCC = 20 + points.count * 3
        let p = SamplePoint(
            position: CGPoint(x: 0.5, y: 0.5),
            assignments: SamplePoint.defaultAssignments(startingCC: startingCC)
        )
        points.append(p)
    }

    func remove(id: UUID) {
        points.removeAll { $0.id == id }
    }

    func move(id: UUID, to position: CGPoint) {
        guard let idx = points.firstIndex(where: { $0.id == id }) else { return }
        points[idx].position = CGPoint(
            x: min(max(position.x, 0), 1),
            y: min(max(position.y, 0), 1)
        )
    }

    func updateAssignment(pointID: UUID, assignmentID: UUID, transform: (inout CCAssignment) -> Void) {
        guard let pi = points.firstIndex(where: { $0.id == pointID }) else { return }
        guard let ai = points[pi].assignments.firstIndex(where: { $0.id == assignmentID }) else { return }
        transform(&points[pi].assignments[ai])
    }
}
```

- [ ] **Step 2: Build to confirm compile**

```bash
xcodegen generate && xcodebuild -scheme SyphonHue -destination 'platform=macOS' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Sources/Model/PointStore.swift
git commit -m "Add PointStore ObservableObject"
```

---

## Task 7: ConfigStore with TDD

**Files:**
- Create: `Sources/Model/ConfigStore.swift`
- Create: `Tests/ConfigStoreTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Tests/ConfigStoreTests.swift
import XCTest
@testable import SyphonHue

final class ConfigStoreTests: XCTestCase {
    var tmpURL: URL!

    override func setUp() {
        super.setUp()
        tmpURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("syphonhue-test-\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmpURL)
        super.tearDown()
    }

    func testSaveAndLoadRoundTrip() throws {
        let store = ConfigStore(fileURL: tmpURL)
        let config = AppConfig(
            points: [SamplePoint(position: .init(x: 0.1, y: 0.2))],
            syphonServer: "ProPresenter",
            midiDestination: "IAC Bus 1",
            sendRateHz: 30
        )
        try store.save(config)
        let loaded = try store.load()
        XCTAssertEqual(loaded.points.count, 1)
        XCTAssertEqual(loaded.syphonServer, "ProPresenter")
        XCTAssertEqual(loaded.midiDestination, "IAC Bus 1")
        XCTAssertEqual(loaded.sendRateHz, 30)
    }

    func testLoadMissingFileReturnsDefault() throws {
        let store = ConfigStore(fileURL: tmpURL)
        let loaded = try store.load()
        XCTAssertTrue(loaded.points.isEmpty)
        XCTAssertNil(loaded.syphonServer)
        XCTAssertNil(loaded.midiDestination)
        XCTAssertEqual(loaded.sendRateHz, 30)
    }
}
```

- [ ] **Step 2: Write `Sources/Model/ConfigStore.swift`**

```swift
import Foundation

struct AppConfig: Codable {
    var points: [SamplePoint]
    var syphonServer: String?
    var midiDestination: String?
    var sendRateHz: Int

    static let `default` = AppConfig(points: [], syphonServer: nil, midiDestination: nil, sendRateHz: 30)
}

final class ConfigStore {
    let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    static func defaultURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("SyphonHue", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("config.json")
    }

    func save(_ config: AppConfig) throws {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try enc.encode(config)
        try data.write(to: fileURL, options: .atomic)
    }

    func load() throws -> AppConfig {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .default
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(AppConfig.self, from: data)
    }
}
```

- [ ] **Step 3: Run tests — expect pass**

```bash
xcodegen generate && xcodebuild -scheme SyphonHue -destination 'platform=macOS' test 2>&1 | tail -15
```

Expected: both ConfigStore tests pass.

- [ ] **Step 4: Commit**

```bash
git add Sources/Model/ConfigStore.swift Tests/ConfigStoreTests.swift
git commit -m "Add AppConfig and ConfigStore with JSON persistence"
```

---

## Task 8: MIDIOut with TDD (packet format)

**Files:**
- Create: `Sources/MIDI/MIDIOut.swift`
- Create: `Tests/MIDIOutTests.swift`

- [ ] **Step 1: Write failing tests (we unit-test the byte builder, not the CoreMIDI send)**

```swift
// Tests/MIDIOutTests.swift
import XCTest
@testable import SyphonHue

final class MIDIOutTests: XCTestCase {
    func testCCBytesChannel1() {
        let bytes = MIDIOut.ccBytes(channel: 1, cc: 20, value: 64)
        XCTAssertEqual(bytes, [0xB0, 20, 64])
    }

    func testCCBytesChannel16() {
        let bytes = MIDIOut.ccBytes(channel: 16, cc: 7, value: 127)
        XCTAssertEqual(bytes, [0xBF, 7, 127])
    }

    func testCCBytesClampsValue() {
        let bytes = MIDIOut.ccBytes(channel: 1, cc: 0, value: 200)
        XCTAssertEqual(bytes, [0xB0, 0, 127])
    }

    func testCCBytesClampsChannel() {
        let bytes = MIDIOut.ccBytes(channel: 0, cc: 0, value: 0)
        XCTAssertEqual(bytes, [0xB0, 0, 0], "Channel 0 clamps to 1")
    }
}
```

- [ ] **Step 2: Write `Sources/MIDI/MIDIOut.swift`**

```swift
import Foundation
import CoreMIDI

/// Describes a visible MIDI destination endpoint.
struct MIDIDestination: Identifiable, Hashable {
    var id: MIDIUniqueID
    var name: String
    var endpointRef: MIDIEndpointRef
}

final class MIDIOut {
    private var client: MIDIClientRef = 0
    private var outputPort: MIDIPortRef = 0
    private(set) var destinations: [MIDIDestination] = []
    private(set) var selected: MIDIDestination?

    init() {
        MIDIClientCreateWithBlock("SyphonHue" as CFString, &client) { _ in }
        MIDIOutputPortCreate(client, "SyphonHue Out" as CFString, &outputPort)
        refreshDestinations()
    }

    deinit {
        if outputPort != 0 { MIDIPortDispose(outputPort) }
        if client != 0 { MIDIClientDispose(client) }
    }

    func refreshDestinations() {
        let count = MIDIGetNumberOfDestinations()
        var result: [MIDIDestination] = []
        for i in 0..<count {
            let endpoint = MIDIGetDestination(i)
            var name: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &name)
            var uniqueID: MIDIUniqueID = 0
            MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &uniqueID)
            let n = (name?.takeRetainedValue() as String?) ?? "Unknown"
            result.append(MIDIDestination(id: uniqueID, name: n, endpointRef: endpoint))
        }
        destinations = result
        if let sel = selected, !destinations.contains(where: { $0.id == sel.id }) {
            selected = nil
        }
    }

    func select(_ dest: MIDIDestination?) {
        selected = dest
    }

    func selectByName(_ name: String) -> Bool {
        if let match = destinations.first(where: { $0.name == name }) {
            selected = match
            return true
        }
        return false
    }

    /// Build the three bytes of a Control Change message.
    static func ccBytes(channel: Int, cc: Int, value: Int) -> [UInt8] {
        let ch = max(1, min(16, channel)) - 1
        let status: UInt8 = 0xB0 | UInt8(ch)
        let controller = UInt8(max(0, min(127, cc)))
        let v = UInt8(max(0, min(127, value)))
        return [status, controller, v]
    }

    func sendCC(channel: Int, cc: Int, value: Int) {
        guard let dest = selected else { return }
        let bytes = Self.ccBytes(channel: channel, cc: cc, value: value)
        var packetList = MIDIPacketList()
        let packet = MIDIPacketListInit(&packetList)
        _ = MIDIPacketListAdd(&packetList, MemoryLayout<MIDIPacketList>.size, packet, 0, bytes.count, bytes)
        MIDISend(outputPort, dest.endpointRef, &packetList)
    }
}
```

- [ ] **Step 3: Run tests — expect pass**

```bash
xcodegen generate && xcodebuild -scheme SyphonHue -destination 'platform=macOS' test 2>&1 | tail -15
```

Expected: all four MIDIOut byte tests pass.

- [ ] **Step 4: Commit**

```bash
git add Sources/MIDI/MIDIOut.swift Tests/MIDIOutTests.swift
git commit -m "Add MIDIOut with CoreMIDI destination enumeration and CC send"
```

---

## Task 9: MetalContext

**Files:**
- Create: `Sources/Syphon/MetalContext.swift`

- [ ] **Step 1: Write `Sources/Syphon/MetalContext.swift`**

```swift
import Metal

final class MetalContext {
    static let shared = MetalContext()

    let device: MTLDevice
    let commandQueue: MTLCommandQueue

    private init() {
        guard let d = MTLCreateSystemDefaultDevice(),
              let q = d.makeCommandQueue() else {
            fatalError("Metal not available on this system — SyphonHue requires a Metal-capable GPU.")
        }
        self.device = d
        self.commandQueue = q
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodegen generate && xcodebuild -scheme SyphonHue -destination 'platform=macOS' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Sources/Syphon/MetalContext.swift
git commit -m "Add shared MetalContext"
```

---

## Task 10: SyphonController

**Files:**
- Create: `Sources/Syphon/SyphonController.swift`

`SyphonServerDirectory` posts Notification Center notifications when servers appear/disappear. `SyphonMetalClient` accepts a server description (dictionary) and a Metal device and delivers frames to a handler block.

- [ ] **Step 1: Write `Sources/Syphon/SyphonController.swift`**

```swift
import Foundation
import Metal
import Combine

struct SyphonServerInfo: Identifiable, Hashable {
    /// The `SyphonServerDescriptionUUIDKey` string.
    var id: String
    var name: String
    var appName: String
    /// Underlying description dict used to construct SyphonMetalClient.
    var description: [String: Any]

    static func == (lhs: SyphonServerInfo, rhs: SyphonServerInfo) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

final class SyphonController: ObservableObject {
    @Published private(set) var servers: [SyphonServerInfo] = []
    @Published private(set) var currentTexture: MTLTexture?
    @Published private(set) var selected: SyphonServerInfo?

    private let directory = SyphonServerDirectory.shared()
    private var client: SyphonMetalClient?
    private var observers: [NSObjectProtocol] = []

    init() {
        refreshServers()
        let nc = NotificationCenter.default
        observers.append(nc.addObserver(forName: .init("SyphonServerAnnounceNotification"),
                                        object: nil, queue: .main) { [weak self] _ in
            self?.refreshServers()
        })
        observers.append(nc.addObserver(forName: .init("SyphonServerRetireNotification"),
                                        object: nil, queue: .main) { [weak self] _ in
            self?.refreshServers()
        })
        observers.append(nc.addObserver(forName: .init("SyphonServerUpdateNotification"),
                                        object: nil, queue: .main) { [weak self] _ in
            self?.refreshServers()
        })
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        client?.stop()
    }

    func refreshServers() {
        let raw = directory?.servers as? [[String: Any]] ?? []
        servers = raw.compactMap { d in
            guard let uuid = d["SyphonServerDescriptionUUIDKey"] as? String else { return nil }
            let name = (d["SyphonServerDescriptionNameKey"] as? String) ?? ""
            let app = (d["SyphonServerDescriptionAppNameKey"] as? String) ?? ""
            return SyphonServerInfo(id: uuid, name: name, appName: app, description: d)
        }
        if let sel = selected, !servers.contains(where: { $0.id == sel.id }) {
            disconnect()
        }
    }

    func connect(to info: SyphonServerInfo) {
        disconnect()
        selected = info
        let device = MetalContext.shared.device
        client = SyphonMetalClient(serverDescription: info.description,
                                   device: device,
                                   options: nil,
                                   newFrameHandler: { [weak self] c in
            guard let self, let tex = c?.newFrameImage() else { return }
            DispatchQueue.main.async {
                self.currentTexture = tex
            }
        })
    }

    func disconnect() {
        client?.stop()
        client = nil
        currentTexture = nil
        selected = nil
    }

    func selectByName(app: String, name: String) -> Bool {
        if let match = servers.first(where: { $0.appName == app && $0.name == name }) {
            connect(to: match)
            return true
        }
        return false
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodegen generate && xcodebuild -scheme SyphonHue -destination 'platform=macOS' build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`. If Syphon symbols don't resolve, inspect `Sources/SyphonHue-Bridging-Header.h` and confirm the framework search path.

- [ ] **Step 3: Commit**

```bash
git add Sources/Syphon/SyphonController.swift
git commit -m "Add SyphonController: server discovery + metal client"
```

---

## Task 11: FrameSampler

**Files:**
- Create: `Sources/Sampling/FrameSampler.swift`

Read an average RGBA for each normalized point by copying a 16×16 region from the Metal texture to a CPU-visible `MTLBuffer`, then averaging. 8 points × 16×16 × 4 bytes = 8 KB per tick, trivial.

- [ ] **Step 1: Write `Sources/Sampling/FrameSampler.swift`**

```swift
import Metal
import CoreGraphics

struct SampledColor {
    var r: Double
    var g: Double
    var b: Double
}

final class FrameSampler {
    static let tileSize = 16

    /// Sample `points` (normalized 0–1) from `texture`, returning average RGB per point.
    func sample(texture: MTLTexture, at points: [CGPoint]) -> [SampledColor] {
        let w = texture.width
        let h = texture.height
        guard w > 0, h > 0, !points.isEmpty else { return [] }

        // Allocate a scratch buffer large enough for the largest tile.
        let tile = Self.tileSize
        let bytesPerPixel = 4
        var buffer = [UInt8](repeating: 0, count: tile * tile * bytesPerPixel)

        return points.map { p in
            let cx = Int((p.x * CGFloat(w)).rounded())
            let cy = Int((p.y * CGFloat(h)).rounded())
            let x0 = max(0, min(w - tile, cx - tile / 2))
            let y0 = max(0, min(h - tile, cy - tile / 2))
            let region = MTLRegionMake2D(x0, y0, tile, tile)
            buffer.withUnsafeMutableBytes { raw in
                texture.getBytes(raw.baseAddress!,
                                 bytesPerRow: tile * bytesPerPixel,
                                 from: region,
                                 mipmapLevel: 0)
            }

            var rSum: UInt64 = 0, gSum: UInt64 = 0, bSum: UInt64 = 0
            let pixels = tile * tile
            // Syphon textures are BGRA8Unorm by default.
            for i in 0..<pixels {
                let o = i * 4
                bSum += UInt64(buffer[o])
                gSum += UInt64(buffer[o + 1])
                rSum += UInt64(buffer[o + 2])
            }
            let n = Double(pixels) * 255.0
            return SampledColor(r: Double(rSum) / n,
                                g: Double(gSum) / n,
                                b: Double(bSum) / n)
        }
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodegen generate && xcodebuild -scheme SyphonHue -destination 'platform=macOS' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Sources/Sampling/FrameSampler.swift
git commit -m "Add FrameSampler with CPU readback of 16x16 tiles"
```

---

## Task 12: AppViewModel

**Files:**
- Create: `Sources/App/AppViewModel.swift`

- [ ] **Step 1: Write `Sources/App/AppViewModel.swift`**

```swift
import Foundation
import SwiftUI
import Combine
import CoreGraphics

@MainActor
final class AppViewModel: ObservableObject {
    let pointStore = PointStore()
    let syphon = SyphonController()
    let midi = MIDIOut()
    let sampler = FrameSampler()
    private let configStore = ConfigStore(fileURL: ConfigStore.defaultURL())

    @Published var sendRateHz: Int = 30 { didSet { restartTimer(); persist() } }
    @Published var lastSampled: [UUID: SampledColor] = [:]

    private var timer: DispatchSourceTimer?
    private var lastSent: [UUID: UInt8] = [:]   // keyed by CCAssignment.id
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadConfig()
        restartTimer()
        pointStore.$points
            .dropFirst()
            .sink { [weak self] _ in self?.persist() }
            .store(in: &cancellables)
        syphon.$selected
            .dropFirst()
            .sink { [weak self] _ in self?.persist() }
            .store(in: &cancellables)
    }

    func refreshEndpoints() {
        syphon.refreshServers()
        midi.refreshDestinations()
    }

    func selectMIDI(_ dest: MIDIDestination?) {
        midi.select(dest)
        persist()
    }

    private func loadConfig() {
        let cfg = (try? configStore.load()) ?? .default
        pointStore.points = cfg.points
        sendRateHz = cfg.sendRateHz
        if let sname = cfg.syphonServer {
            // format: "AppName::ServerName"
            let parts = sname.components(separatedBy: "::")
            if parts.count == 2 { _ = syphon.selectByName(app: parts[0], name: parts[1]) }
        }
        if let mname = cfg.midiDestination {
            _ = midi.selectByName(mname)
        }
    }

    private func persist() {
        let serverTag: String? = {
            guard let s = syphon.selected else { return nil }
            return "\(s.appName)::\(s.name)"
        }()
        let cfg = AppConfig(
            points: pointStore.points,
            syphonServer: serverTag,
            midiDestination: midi.selected?.name,
            sendRateHz: sendRateHz
        )
        try? configStore.save(cfg)
    }

    private func restartTimer() {
        timer?.cancel()
        let hz = max(1, min(120, sendRateHz))
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + .milliseconds(10),
                   repeating: .milliseconds(Int(1000.0 / Double(hz))))
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
    }

    private func tick() {
        guard let tex = syphon.currentTexture else { return }
        let points = pointStore.points
        guard !points.isEmpty else { return }
        let samples = sampler.sample(texture: tex, at: points.map { $0.position })
        guard samples.count == points.count else { return }

        var nextSampled: [UUID: SampledColor] = [:]
        for (i, point) in points.enumerated() {
            let rgb = samples[i]
            nextSampled[point.id] = rgb
            let hsb = ColorMapper.rgbToHSB(r: rgb.r, g: rgb.g, b: rgb.b)
            for a in point.assignments where a.enabled {
                let value01: Double
                switch a.source {
                case .hue: value01 = hsb.h
                case .saturation: value01 = hsb.s
                case .brightness: value01 = hsb.b
                case .red: value01 = rgb.r
                case .green: value01 = rgb.g
                case .blue: value01 = rgb.b
                }
                let midiVal = ColorMapper.toMIDI(value01)
                if lastSent[a.id] != midiVal {
                    lastSent[a.id] = midiVal
                    midi.sendCC(channel: a.channel, cc: a.cc, value: Int(midiVal))
                }
            }
        }
        lastSampled = nextSampled
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodegen generate && xcodebuild -scheme SyphonHue -destination 'platform=macOS' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Sources/App/AppViewModel.swift
git commit -m "Add AppViewModel wiring Syphon + sampler + MIDI + persistence"
```

---

## Task 13: PreviewView (MTKView + overlay)

**Files:**
- Create: `Sources/UI/PreviewView.swift`

- [ ] **Step 1: Write `Sources/UI/PreviewView.swift`**

```swift
import SwiftUI
import MetalKit

struct PreviewView: View {
    @ObservedObject var pointStore: PointStore
    var texture: MTLTexture?
    var lastSampled: [UUID: SampledColor]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black
                MetalTextureView(texture: texture)
                    .aspectRatio(contentMode: .fit)
                ForEach(pointStore.points.indices, id: \.self) { idx in
                    let point = pointStore.points[idx]
                    PointMarker(
                        index: idx + 1,
                        color: uiColor(for: point.id),
                        normalizedPosition: point.position,
                        viewSize: geo.size,
                        onDrag: { newPos in
                            pointStore.move(id: point.id, to: newPos)
                        }
                    )
                }
            }
        }
    }

    private func uiColor(for id: UUID) -> Color {
        guard let s = lastSampled[id] else { return .white }
        return Color(red: s.r, green: s.g, blue: s.b)
    }
}

struct PointMarker: View {
    let index: Int
    let color: Color
    let normalizedPosition: CGPoint
    let viewSize: CGSize
    let onDrag: (CGPoint) -> Void

    var body: some View {
        let x = normalizedPosition.x * viewSize.width
        let y = normalizedPosition.y * viewSize.height
        ZStack {
            Circle().fill(color).frame(width: 26, height: 26)
            Circle().stroke(Color.white, lineWidth: 2).frame(width: 26, height: 26)
            Text("\(index)").font(.caption).bold().foregroundColor(.black)
        }
        .position(x: x, y: y)
        .gesture(DragGesture().onChanged { value in
            let nx = value.location.x / max(1, viewSize.width)
            let ny = value.location.y / max(1, viewSize.height)
            onDrag(CGPoint(x: nx, y: ny))
        })
    }
}

struct MetalTextureView: NSViewRepresentable {
    var texture: MTLTexture?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> MTKView {
        let v = MTKView(frame: .zero, device: MetalContext.shared.device)
        v.framebufferOnly = false
        v.enableSetNeedsDisplay = false
        v.isPaused = false
        v.colorPixelFormat = .bgra8Unorm
        v.delegate = context.coordinator
        context.coordinator.commandQueue = MetalContext.shared.commandQueue
        return v
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.texture = texture
    }

    final class Coordinator: NSObject, MTKViewDelegate {
        var texture: MTLTexture?
        var commandQueue: MTLCommandQueue?

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard let src = texture,
                  let drawable = view.currentDrawable,
                  let cq = commandQueue,
                  let cmd = cq.makeCommandBuffer(),
                  let blit = cmd.makeBlitCommandEncoder() else {
                view.currentDrawable?.present()
                return
            }
            let dst = drawable.texture
            let srcW = src.width, srcH = src.height
            let dstW = dst.width, dstH = dst.height
            // Best-effort scale-to-fit by copying min region. For v1 we center-copy
            // at 1:1 or stretch via a compute; blit requires equal sizes, so if sizes
            // differ, fall back to presenting a solid color. Simplest correct path:
            // use an identity copy when sizes match, otherwise skip the copy so the
            // aspect-ratio'd container handles layout. For 1:1 Syphon + preview,
            // sizes match and this path works.
            if srcW == dstW && srcH == dstH {
                blit.copy(from: src,
                          sourceSlice: 0, sourceLevel: 0,
                          sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                          sourceSize: MTLSize(width: srcW, height: srcH, depth: 1),
                          to: dst,
                          destinationSlice: 0, destinationLevel: 0,
                          destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
            } else {
                let minW = min(srcW, dstW)
                let minH = min(srcH, dstH)
                blit.copy(from: src,
                          sourceSlice: 0, sourceLevel: 0,
                          sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                          sourceSize: MTLSize(width: minW, height: minH, depth: 1),
                          to: dst,
                          destinationSlice: 0, destinationLevel: 0,
                          destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
            }
            blit.endEncoding()
            cmd.present(drawable)
            cmd.commit()
        }
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodegen generate && xcodebuild -scheme SyphonHue -destination 'platform=macOS' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Sources/UI/PreviewView.swift
git commit -m "Add PreviewView with Metal texture blit and draggable markers"
```

---

## Task 14: Sidebar (point list + row editor)

**Files:**
- Create: `Sources/UI/PointRowView.swift`
- Create: `Sources/UI/SidebarView.swift`

- [ ] **Step 1: Write `Sources/UI/PointRowView.swift`**

```swift
import SwiftUI

struct PointRowView: View {
    let index: Int
    @Binding var point: SamplePoint
    var lastSampled: SampledColor?
    var onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Point \(index)").font(.headline)
                Spacer()
                if let s = lastSampled {
                    Rectangle()
                        .fill(Color(red: s.r, green: s.g, blue: s.b))
                        .frame(width: 28, height: 16)
                        .overlay(Rectangle().stroke(Color.secondary, lineWidth: 0.5))
                }
                Button(action: onRemove) { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
            }
            HStack {
                Text(String(format: "x %.2f", point.position.x))
                Text(String(format: "y %.2f", point.position.y))
                if let s = lastSampled {
                    Text(String(format: "RGB %.2f %.2f %.2f", s.r, s.g, s.b))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }.font(.caption)
            ForEach($point.assignments) { $a in
                AssignmentRow(assignment: $a)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color(NSColor.controlBackgroundColor)))
    }
}

private struct AssignmentRow: View {
    @Binding var assignment: CCAssignment

    var body: some View {
        HStack(spacing: 6) {
            Toggle("", isOn: $assignment.enabled).labelsHidden()
            Picker("", selection: $assignment.source) {
                ForEach(ColorValue.allCases) { cv in
                    Text(cv.label).tag(cv)
                }
            }.labelsHidden().frame(width: 70)
            Text("CC")
            Stepper(value: $assignment.cc, in: 0...127) {
                Text("\(assignment.cc)").frame(width: 28, alignment: .trailing)
                    .font(.system(.body, design: .monospaced))
            }.labelsHidden()
            Text("Ch")
            Stepper(value: $assignment.channel, in: 1...16) {
                Text("\(assignment.channel)").frame(width: 24, alignment: .trailing)
                    .font(.system(.body, design: .monospaced))
            }.labelsHidden()
        }
        .font(.caption)
    }
}
```

- [ ] **Step 2: Write `Sources/UI/SidebarView.swift`**

```swift
import SwiftUI

struct SidebarView: View {
    @ObservedObject var pointStore: PointStore
    var lastSampled: [UUID: SampledColor]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Sample Points").font(.title3)
                    Spacer()
                    Button {
                        pointStore.addPoint()
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .disabled(pointStore.points.count >= PointStore.maxPoints)
                }
                if pointStore.points.isEmpty {
                    Text("No points yet. Click Add to create one.")
                        .foregroundColor(.secondary)
                        .padding(.vertical, 40)
                        .frame(maxWidth: .infinity)
                }
                ForEach(pointStore.points.indices, id: \.self) { idx in
                    PointRowView(
                        index: idx + 1,
                        point: $pointStore.points[idx],
                        lastSampled: lastSampled[pointStore.points[idx].id],
                        onRemove: { pointStore.remove(id: pointStore.points[idx].id) }
                    )
                }
            }
            .padding(10)
        }
    }
}
```

- [ ] **Step 3: Build**

```bash
xcodegen generate && xcodebuild -scheme SyphonHue -destination 'platform=macOS' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add Sources/UI/PointRowView.swift Sources/UI/SidebarView.swift
git commit -m "Add SidebarView and PointRowView for per-point CC editing"
```

---

## Task 15: ToolbarView

**Files:**
- Create: `Sources/UI/ToolbarView.swift`

- [ ] **Step 1: Write `Sources/UI/ToolbarView.swift`**

```swift
import SwiftUI

struct ToolbarView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        HStack(spacing: 12) {
            Text("Syphon:")
            Menu(viewModel.syphon.selected.map { "\($0.appName) — \($0.name)" } ?? "Select…") {
                Button("Refresh") { viewModel.refreshEndpoints() }
                Divider()
                if viewModel.syphon.servers.isEmpty {
                    Text("No servers running").foregroundColor(.secondary)
                }
                ForEach(viewModel.syphon.servers) { s in
                    Button("\(s.appName) — \(s.name)") { viewModel.syphon.connect(to: s) }
                }
            }
            .frame(minWidth: 200)

            Text("MIDI:")
            Menu(viewModel.midi.selected?.name ?? "Select…") {
                Button("Refresh") { viewModel.refreshEndpoints() }
                Divider()
                if viewModel.midi.destinations.isEmpty {
                    Text("No destinations").foregroundColor(.secondary)
                }
                ForEach(viewModel.midi.destinations) { d in
                    Button(d.name) { viewModel.selectMIDI(d) }
                }
            }
            .frame(minWidth: 180)

            Text("Rate:")
            Slider(value: Binding(
                get: { Double(viewModel.sendRateHz) },
                set: { viewModel.sendRateHz = Int($0) }
            ), in: 5...60, step: 1)
            .frame(width: 120)
            Text("\(viewModel.sendRateHz) Hz").font(.system(.body, design: .monospaced)).frame(width: 50)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodegen generate && xcodebuild -scheme SyphonHue -destination 'platform=macOS' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Sources/UI/ToolbarView.swift
git commit -m "Add ToolbarView with Syphon/MIDI dropdowns and rate slider"
```

---

## Task 16: ContentView + App entry point

**Files:**
- Create: `Sources/UI/ContentView.swift`
- Create: `Sources/App/SyphonHueApp.swift`

- [ ] **Step 1: Write `Sources/UI/ContentView.swift`**

```swift
import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = AppViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ToolbarView(viewModel: viewModel)
            Divider()
            HSplitView {
                PreviewView(
                    pointStore: viewModel.pointStore,
                    texture: viewModel.syphon.currentTexture,
                    lastSampled: viewModel.lastSampled
                )
                .frame(minWidth: 400)

                SidebarView(
                    pointStore: viewModel.pointStore,
                    lastSampled: viewModel.lastSampled
                )
                .frame(minWidth: 320, idealWidth: 360)
            }
            Divider()
            HStack {
                Text(statusLine)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    private var statusLine: String {
        let syph = viewModel.syphon.selected.map { "\($0.appName) — \($0.name)" } ?? "none"
        let midi = viewModel.midi.selected?.name ?? "none"
        let n = viewModel.pointStore.points.count
        return "Syphon: \(syph) · MIDI: \(midi) · Points: \(n)"
    }
}
```

- [ ] **Step 2: Write `Sources/App/SyphonHueApp.swift`**

```swift
import SwiftUI

@main
struct SyphonHueApp: App {
    var body: some Scene {
        WindowGroup("SyphonHue") {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
    }
}
```

- [ ] **Step 3: Build**

```bash
xcodegen generate && xcodebuild -scheme SyphonHue -destination 'platform=macOS' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add Sources/UI/ContentView.swift Sources/App/SyphonHueApp.swift
git rm -f Sources/App/.keep Sources/UI/.keep Sources/Sampling/.keep Sources/MIDI/.keep Sources/Syphon/.keep 2>/dev/null || true
git commit -m "Add ContentView and SyphonHueApp entry point"
```

---

## Task 17: Full test run + build verification

- [ ] **Step 1: Run full test suite**

```bash
xcodegen generate && xcodebuild -scheme SyphonHue -destination 'platform=macOS' test 2>&1 | tail -40
```

Expected: **TEST SUCCEEDED** and ≥18 tests passing (ColorMapper 9, SamplePoint 4, ConfigStore 2, MIDIOut 4; counts are floor values — add more if new tests arrive).

- [ ] **Step 2: Build Release**

```bash
xcodebuild -scheme SyphonHue -destination 'platform=macOS' -configuration Release build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Locate the .app**

```bash
find ~/Library/Developer/Xcode/DerivedData -name 'SyphonHue.app' -path '*/Release/*' | head -1
```

Record the path for manual testing.

---

## Task 18: Manual integration test

Follow the spec's testing plan. These steps are manual — no assertions, the user watches and judges.

- [ ] **Step 1: Launch**

```bash
open "$(find ~/Library/Developer/Xcode/DerivedData -name 'SyphonHue.app' -path '*/Release/*' | head -1)"
```

- [ ] **Step 2: Start ProPresenter with Syphon output enabled**

(In ProPresenter preferences enable the Syphon output. Then start a presentation.)

- [ ] **Step 3: In SyphonHue, pick the ProPresenter server** — preview should show the feed.

- [ ] **Step 4: Add two points.** Drag one onto a red region, one onto a blue region. Confirm swatches in the sidebar match.

- [ ] **Step 5: Pick a MIDI destination.** If no IAC bus is visible, open Audio MIDI Setup and enable the IAC Driver bus.

- [ ] **Step 6: Configure CCs.** On point 1 enable Hue → CC 20, ch 1. On point 2 enable Hue → CC 21, ch 1.

- [ ] **Step 7: Watch LightKey.** In LightKey, add an external-control Hue parameter, MIDI-learn CC 20. Repeat with CC 21 for a second fixture. Confirm changing ProPresenter's slide content moves LightKey's hue.

- [ ] **Step 8: Quit and relaunch.** Confirm the points, selected Syphon server, MIDI destination, and rate persisted.

- [ ] **Step 9: Report results back in chat.** If any step fails, capture the failure mode and we debug.

---

## Notes on TDD coverage in this plan

TDD is applied to pure-logic components where tests constitute real verification: `ColorMapper` (color math), `SamplePoint`/`CCAssignment` (codable + clamping), `ConfigStore` (file round-trip), `MIDIOut.ccBytes` (packet format). UI, Syphon discovery, and live MIDI transmission rely on the manual integration test in Task 18 — these are boundaries with external systems that cannot be reliably unit-tested from within this project.
