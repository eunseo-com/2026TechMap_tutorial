# Chapter 1 (ClosedWorld) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a real, buildable SwiftUI + SceneKit iOS app ("PiggyEscape") implementing the six ClosedWorld steps from the design spec, and author the matching DocC tutorial catalog (Chapter 1 only) that walks a reader through building it.

**Architecture:** A Tuist-generated Xcode project with two targets — `PiggyEscape` (app) and `PiggyEscapeTests` (XCTest, hosted by the app). All SceneKit scene-graph logic (room, pig, fake sofa, hide action, node inspection) is written as small, pure, unit-testable static functions/enums that build and return `SCNNode`/`SCNAction` values without touching the view layer, so they can be tested headlessly with XCTest — no rendering, no simulator screenshot needed for correctness. A thin `UIViewRepresentable` (`ClosedWorldSceneView`) wires these pieces into an `SCNView` and handles the one tap gesture. The DocC catalog is a separate `.docc` folder added to the same Xcode target, built with `xcodebuild docbuild`.

**Tech Stack:** Swift 6, SwiftUI, SceneKit, XCTest, Tuist 4 (project generation), DocC (tutorial catalog), xcodebuild + iOS Simulator (verification).

## Global Constraints

- Repository: `/Users/yang-eunseo/Downloads/SpatialComputing_TechMap` (`2026TechMap_tutorial` on GitHub, already has its own `.git` — do NOT touch the unrelated `.git` at `/Users/yang-eunseo/.git`).
- Deployment target: iOS 17.0.
- Simulator device for all build/test/run verification: `iPhone 17 Pro` (confirmed available via `xcrun simctl list devices available`).
- Assets copied verbatim from `/Users/yang-eunseo/Downloads/C3_Piggy/C3_Piggy/`: `Piggy.usdc`, `Ground_Color.usdc`, `Wood_Color.usdc`.
- `AssetLoader.swift` is adapted near-verbatim from `/Users/yang-eunseo/Downloads/C3_Piggy/C3_Piggy/Scene/AssetLoader.swift` (generic loader, no C3-specific logic — safe to reuse as-is).
- Walls are the one deliberate exception to "reuse C3 as-is": C3_Piggy has no wall asset (outdoor island), so walls are built with `SCNBox` directly — this is required by the spec's "room has an edge with nothing beyond it" narrative beat.
- No Co-Authored-By trailer in any commit (user's standing preference — see project memory `no-coauthor-trailer`). Commit messages: plain, no AI-authorship markers.
- Commit after every task, following `docs/superpowers/specs/2026-08-10-ch1-scenekit-closed-world-design.md` as the source of truth for *why* each piece exists.

---

## Task 1: Tuist project scaffold

**Files:**
- Create: `PiggyEscape/Project.swift`
- Create: `PiggyEscape/PiggyEscape/Sources/PiggyEscapeApp.swift`
- Create: `PiggyEscape/PiggyEscape/Sources/ContentView.swift`
- Create: `PiggyEscape/PiggyEscapeTests/PiggyEscapeTests.swift`

**Interfaces:**
- Produces: an Xcode project buildable and testable via `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`.

- [ ] **Step 1: Write the Tuist manifest**

`PiggyEscape/Project.swift`:

```swift
import ProjectDescription

let project = Project(
    name: "PiggyEscape",
    targets: [
        .target(
            name: "PiggyEscape",
            destinations: .iOS,
            product: .app,
            bundleId: "com.techmap.piggyescape",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .default,
            sources: ["PiggyEscape/Sources/**"],
            resources: ["PiggyEscape/Resources/**"]
        ),
        .target(
            name: "PiggyEscapeTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.techmap.piggyescape.tests",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .default,
            sources: ["PiggyEscapeTests/**"],
            dependencies: [.target(name: "PiggyEscape")]
        )
    ]
)
```

- [ ] **Step 2: Write a minimal app entry point and placeholder view**

`PiggyEscape/PiggyEscape/Sources/PiggyEscapeApp.swift`:

```swift
import SwiftUI

@main
struct PiggyEscapeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

`PiggyEscape/PiggyEscape/Sources/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("PiggyEscape")
    }
}
```

- [ ] **Step 3: Write a placeholder test so the test target compiles**

`PiggyEscape/PiggyEscapeTests/PiggyEscapeTests.swift`:

```swift
import XCTest

final class PiggyEscapeTests: XCTestCase {
    func test_placeholder() {
        XCTAssertTrue(true)
    }
}
```

- [ ] **Step 4: Create empty Resources folder placeholder**

Run: `mkdir -p "PiggyEscape/PiggyEscape/Resources"`

Git doesn't track empty directories, so add a `.gitkeep`:

Run: `touch "PiggyEscape/PiggyEscape/Resources/.gitkeep"`

- [ ] **Step 5: Generate the Xcode project**

Run: `cd PiggyEscape && tuist generate --no-open`

Expected: succeeds and produces `PiggyEscape/PiggyEscape.xcodeproj`. If it fails, read the error — it's almost always a manifest syntax mismatch for the installed Tuist version (`tuist version` was 4.200.5 when this plan was written) — fix `Project.swift` and rerun until it succeeds.

- [ ] **Step 6: Build for simulator**

Run: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: Run the placeholder test**

Run: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`

Expected: `Test Suite 'All tests' passed` including `test_placeholder`.

- [ ] **Step 8: Commit**

```bash
cd "/Users/yang-eunseo/Downloads/SpatialComputing_TechMap"
git add PiggyEscape/Project.swift "PiggyEscape/PiggyEscape/Sources" "PiggyEscape/PiggyEscape/Resources/.gitkeep" PiggyEscape/PiggyEscapeTests
git commit -m "Scaffold PiggyEscape Xcode project via Tuist"
```

(Do not commit the generated `PiggyEscape/PiggyEscape.xcodeproj` or `PiggyEscape/.build` — add them to `.gitignore` in this step: create/append `PiggyEscape/.gitignore` with `*.xcodeproj\n.build/\nDerivedData/\n`, then `git add PiggyEscape/.gitignore` before committing.)

---

## Task 2: Copy assets and add AssetLoader

**Files:**
- Create: `PiggyEscape/PiggyEscape/Resources/Piggy.usdc` (copied)
- Create: `PiggyEscape/PiggyEscape/Resources/Ground_Color.usdc` (copied)
- Create: `PiggyEscape/PiggyEscape/Resources/Wood_Color.usdc` (copied)
- Create: `PiggyEscape/PiggyEscape/Sources/ClosedWorld/AssetLoader.swift`
- Test: `PiggyEscape/PiggyEscapeTests/AssetLoaderTests.swift`

**Interfaces:**
- Produces:
  - `AssetLoader.object(named name: String) -> SCNNode?`
  - `AssetLoader.object(named name: String, fallback: @MainActor () -> SCNNode) -> SCNNode`
  - `AssetLoader.voxelBox(width: CGFloat, height: CGFloat, length: CGFloat, color: UIColor) -> SCNNode`

- [ ] **Step 1: Copy the three asset files**

Run:
```bash
cp "/Users/yang-eunseo/Downloads/C3_Piggy/C3_Piggy/Piggy.usdc" "PiggyEscape/PiggyEscape/Resources/Piggy.usdc"
cp "/Users/yang-eunseo/Downloads/C3_Piggy/C3_Piggy/Ground_Color.usdc" "PiggyEscape/PiggyEscape/Resources/Ground_Color.usdc"
cp "/Users/yang-eunseo/Downloads/C3_Piggy/C3_Piggy/Wood_Color.usdc" "PiggyEscape/PiggyEscape/Resources/Wood_Color.usdc"
```

- [ ] **Step 2: Write the failing test**

`PiggyEscape/PiggyEscapeTests/AssetLoaderTests.swift`:

```swift
import XCTest
import SceneKit
@testable import PiggyEscape

final class AssetLoaderTests: XCTestCase {
    @MainActor
    func test_object_named_loadsBundledPiggyModel() {
        let node = AssetLoader.object(named: "Piggy")
        XCTAssertNotNil(node)
        XCTAssertFalse(node?.childNodes.isEmpty ?? true)
    }

    @MainActor
    func test_object_named_returnsNilForMissingAsset() {
        let node = AssetLoader.object(named: "DoesNotExist")
        XCTAssertNil(node)
    }

    @MainActor
    func test_object_named_fallback_usesFallbackWhenMissing() {
        let node = AssetLoader.object(named: "DoesNotExist") {
            AssetLoader.voxelBox(width: 1, height: 1, length: 1, color: .red)
        }
        XCTAssertNotNil(node.geometry as? SCNBox)
    }

    func test_voxelBox_producesBoxGeometryWithGivenColor() {
        let node = AssetLoader.voxelBox(width: 2, height: 1, length: 3, color: .blue)
        guard let box = node.geometry as? SCNBox else {
            XCTFail("expected SCNBox geometry")
            return
        }
        XCTAssertEqual(box.width, 2 * 0.96, accuracy: 0.0001)
        XCTAssertEqual(box.height, 1 * 0.96, accuracy: 0.0001)
        XCTAssertEqual(box.length, 3 * 0.96, accuracy: 0.0001)
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`

Expected: FAIL to build — `AssetLoader` does not exist yet.

- [ ] **Step 4: Add AssetLoader.swift, adapted from C3_Piggy**

`PiggyEscape/PiggyEscape/Sources/ClosedWorld/AssetLoader.swift`:

```swift
import SceneKit
import UIKit

/// 3D 모델 파일(.usdz/.usdc/.usda/.obj)을 불러오는 도우미 모음.
/// 모델을 못 찾으면 단순한 정육면체(복셀) 박스로 대신 채운다("폴백").
enum AssetLoader {
    @MainActor
    static func object(named name: String, fallback: @MainActor () -> SCNNode) -> SCNNode {
        object(named: name) ?? fallback()
    }

    @MainActor
    static func object(named name: String) -> SCNNode? {
        for ext in ["usdz", "usdc", "usda"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext),
               let scene = try? SCNScene(url: url, options: nil) {
                return wrap(scene)
            }
        }
        if let url = Bundle.main.url(forResource: name, withExtension: "obj"),
           let scene = try? SCNScene(url: url, options: [
               .convertToYUp: true,
               .createNormalsIfAbsent: true
           ]) {
            return wrap(scene)
        }
        return nil
    }

    private static func wrap(_ scene: SCNScene) -> SCNNode {
        let node = SCNNode()
        scene.rootNode.childNodes.forEach { node.addChildNode($0.clone()) }
        return node
    }

    static func voxelBox(width: CGFloat, height: CGFloat, length: CGFloat,
                          color: UIColor) -> SCNNode {
        let box = SCNBox(width: width * 0.96,
                          height: height * 0.96,
                          length: length * 0.96,
                          chamferRadius: 0.02)
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.lightingModel = .blinn
        box.materials = [mat]
        return SCNNode(geometry: box)
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`

Expected: all `AssetLoaderTests` pass. If `test_object_named_loadsBundledPiggyModel` fails to find the resource, confirm `Piggy.usdc` is listed under the `PiggyEscape` target's "Copy Bundle Resources" build phase (Tuist's `resources: ["PiggyEscape/Resources/**"]` glob should have already included it — rerun `tuist generate` if the file was added after the last generate).

- [ ] **Step 6: Commit**

```bash
git add PiggyEscape/PiggyEscape/Resources/Piggy.usdc PiggyEscape/PiggyEscape/Resources/Ground_Color.usdc PiggyEscape/PiggyEscape/Resources/Wood_Color.usdc PiggyEscape/PiggyEscape/Sources/ClosedWorld/AssetLoader.swift PiggyEscape/PiggyEscapeTests/AssetLoaderTests.swift
git commit -m "Add C3_Piggy assets and AssetLoader"
```

---

## Task 3: RoomBuilder

**Files:**
- Create: `PiggyEscape/PiggyEscape/Sources/ClosedWorld/RoomBuilder.swift`
- Test: `PiggyEscape/PiggyEscapeTests/RoomBuilderTests.swift`

**Interfaces:**
- Consumes: `AssetLoader.object(named:fallback:) -> SCNNode` (Task 2), `AssetLoader.voxelBox(width:height:length:color:) -> SCNNode` (Task 2)
- Produces: `RoomBuilder.build() -> SCNNode` — a node named `"Room"` with children named `"Floor"` and `"Wall_0"`...`"Wall_3"` (4 walls).

- [ ] **Step 1: Write the failing test**

`PiggyEscape/PiggyEscapeTests/RoomBuilderTests.swift`:

```swift
import XCTest
import SceneKit
@testable import PiggyEscape

final class RoomBuilderTests: XCTestCase {
    @MainActor
    func test_build_returnsRoomWithFloorAndFourWalls() {
        let room = RoomBuilder.build()
        XCTAssertEqual(room.name, "Room")

        let floor = room.childNode(withName: "Floor", recursively: false)
        XCTAssertNotNil(floor)

        let walls = (0..<4).compactMap { room.childNode(withName: "Wall_\($0)", recursively: false) }
        XCTAssertEqual(walls.count, 4)
    }

    @MainActor
    func test_build_wallsAreDeclaredBoxGeometry() {
        let room = RoomBuilder.build()
        for i in 0..<4 {
            let wall = room.childNode(withName: "Wall_\(i)", recursively: false)
            XCTAssertTrue(wall?.geometry is SCNBox, "Wall_\(i) should be a plain SCNBox — C3_Piggy has no wall asset")
        }
    }

    @MainActor
    func test_build_originIsDeclaredAtRoomCenter() {
        let room = RoomBuilder.build()
        XCTAssertEqual(room.position.x, 0, accuracy: 0.0001)
        XCTAssertEqual(room.position.y, 0, accuracy: 0.0001)
        XCTAssertEqual(room.position.z, 0, accuracy: 0.0001)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`

Expected: FAIL to build — `RoomBuilder` does not exist yet.

- [ ] **Step 3: Write RoomBuilder**

`PiggyEscape/PiggyEscape/Sources/ClosedWorld/RoomBuilder.swift`:

```swift
import SceneKit
import UIKit

/// 방을 짓는 빌더. 이 세계에 있는 모든 것 — 벽이든 바닥이든 —은
/// 여기 코드로 써넣은 것만 존재한다. 좌표 원점(0,0,0)도 개발자가 임의로 선언한 것.
enum RoomBuilder {
    static let roomWidth: Float = 4
    static let roomDepth: Float = 4
    static let wallHeight: Float = 2.5
    private static let wallThickness: Float = 0.1

    @MainActor
    static func build() -> SCNNode {
        let room = SCNNode()
        room.name = "Room"
        room.position = SCNVector3(0, 0, 0)   // 좌표 원점을 여기서 임의로 선언한다

        let floor = AssetLoader.object(named: "Ground_Color") {
            AssetLoader.voxelBox(width: CGFloat(roomWidth), height: 0.1, length: CGFloat(roomDepth),
                                  color: UIColor(white: 0.8, alpha: 1))
        }
        floor.name = "Floor"
        floor.position = SCNVector3(0, 0, 0)
        room.addChildNode(floor)

        let wallSpecs: [(name: String, position: SCNVector3, eulerY: Float, width: Float)] = [
            ("Wall_0", SCNVector3(0, wallHeight / 2, -roomDepth / 2), 0, roomWidth),
            ("Wall_1", SCNVector3(0, wallHeight / 2, roomDepth / 2), 0, roomWidth),
            ("Wall_2", SCNVector3(-roomWidth / 2, wallHeight / 2, 0), .pi / 2, roomDepth),
            ("Wall_3", SCNVector3(roomWidth / 2, wallHeight / 2, 0), .pi / 2, roomDepth)
        ]
        for spec in wallSpecs {
            let wall = AssetLoader.voxelBox(width: CGFloat(spec.width), height: CGFloat(wallHeight),
                                             length: CGFloat(wallThickness), color: UIColor(white: 0.95, alpha: 1))
            wall.name = spec.name
            wall.position = spec.position
            wall.eulerAngles = SCNVector3(0, spec.eulerY, 0)
            room.addChildNode(wall)
        }

        return room
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`

Expected: all `RoomBuilderTests` pass.

- [ ] **Step 5: Commit**

```bash
git add PiggyEscape/PiggyEscape/Sources/ClosedWorld/RoomBuilder.swift PiggyEscape/PiggyEscapeTests/RoomBuilderTests.swift
git commit -m "Add RoomBuilder: SCNBox walls + reused Ground_Color floor"
```

---

## Task 4: PigPlacement and FakeSofa

**Files:**
- Create: `PiggyEscape/PiggyEscape/Sources/ClosedWorld/PigPlacement.swift`
- Create: `PiggyEscape/PiggyEscape/Sources/ClosedWorld/FakeSofa.swift`
- Test: `PiggyEscape/PiggyEscapeTests/PigPlacementTests.swift`
- Test: `PiggyEscape/PiggyEscapeTests/FakeSofaTests.swift`

**Interfaces:**
- Consumes: `AssetLoader.object(named:fallback:) -> SCNNode` (Task 2)
- Produces:
  - `PigPlacement.hardcodedPosition: SCNVector3`
  - `PigPlacement.makePigNode() -> SCNNode` (named `"Piggy"`, positioned at `hardcodedPosition`)
  - `FakeSofa.hardcodedPosition: SCNVector3`
  - `FakeSofa.makeSofaNode() -> SCNNode` (named `"FakeSofa"`, positioned at `hardcodedPosition`)

- [ ] **Step 1: Write the failing tests**

`PiggyEscape/PiggyEscapeTests/PigPlacementTests.swift`:

```swift
import XCTest
import SceneKit
@testable import PiggyEscape

final class PigPlacementTests: XCTestCase {
    @MainActor
    func test_makePigNode_isNamedPiggy() {
        let pig = PigPlacement.makePigNode()
        XCTAssertEqual(pig.name, "Piggy")
    }

    @MainActor
    func test_makePigNode_isPlacedAtHardcodedPosition() {
        let pig = PigPlacement.makePigNode()
        XCTAssertEqual(pig.position.x, PigPlacement.hardcodedPosition.x, accuracy: 0.0001)
        XCTAssertEqual(pig.position.y, PigPlacement.hardcodedPosition.y, accuracy: 0.0001)
        XCTAssertEqual(pig.position.z, PigPlacement.hardcodedPosition.z, accuracy: 0.0001)
    }

    @MainActor
    func test_makePigNode_hasGeometryOrChildGeometry() {
        let pig = PigPlacement.makePigNode()
        let hasGeometry = pig.geometry != nil || pig.childNodes.contains { $0.geometry != nil }
        XCTAssertTrue(hasGeometry)
    }
}
```

`PiggyEscape/PiggyEscapeTests/FakeSofaTests.swift`:

```swift
import XCTest
import SceneKit
@testable import PiggyEscape

final class FakeSofaTests: XCTestCase {
    @MainActor
    func test_makeSofaNode_isNamedFakeSofa() {
        let sofa = FakeSofa.makeSofaNode()
        XCTAssertEqual(sofa.name, "FakeSofa")
    }

    @MainActor
    func test_makeSofaNode_isPlacedAtHardcodedPosition() {
        let sofa = FakeSofa.makeSofaNode()
        XCTAssertEqual(sofa.position.x, FakeSofa.hardcodedPosition.x, accuracy: 0.0001)
        XCTAssertEqual(sofa.position.z, FakeSofa.hardcodedPosition.z, accuracy: 0.0001)
    }

    func test_hardcodedPosition_isInsideRoomBounds() {
        // "가짜 소파"도 방 안 좌표일 뿐 — 실제 소파 위치와는 무관하다는 걸 좌표 자체로 보여준다.
        XCTAssertLessThan(abs(FakeSofa.hardcodedPosition.x), RoomBuilder.roomWidth / 2)
        XCTAssertLessThan(abs(FakeSofa.hardcodedPosition.z), RoomBuilder.roomDepth / 2)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`

Expected: FAIL to build — `PigPlacement` and `FakeSofa` don't exist yet.

- [ ] **Step 3: Write PigPlacement**

`PiggyEscape/PiggyEscape/Sources/ClosedWorld/PigPlacement.swift`:

```swift
import SceneKit

/// 돼지를 하드코딩된 좌표에 배치한다. 이 좌표는 개발자가 정한 것일 뿐,
/// 방 안의 어떤 실제 기준(가구 위치 등)과도 연결되어 있지 않다.
enum PigPlacement {
    static let hardcodedPosition = SCNVector3(0, 0, 1)
    private static let standardHeight: Float = 0.6

    @MainActor
    static func makePigNode() -> SCNNode {
        let model = AssetLoader.object(named: "Piggy") {
            AssetLoader.voxelBox(width: 0.4, height: 0.4, length: 0.6, color: .systemPink)
        }
        normalize(model, toHeight: standardHeight)
        model.name = "Piggy"
        model.position = hardcodedPosition
        return model
    }

    @MainActor
    private static func normalize(_ node: SCNNode, toHeight targetHeight: Float) {
        let (lo, hi) = boundingBox(of: node)
        let height = hi.y - lo.y
        guard height > 0.0001 else { return }
        let scale = targetHeight / height
        node.scale = SCNVector3(scale, scale, scale)
    }

    private static func boundingBox(of node: SCNNode) -> (SCNVector3, SCNVector3) {
        var lo = SCNVector3(Float.greatestFiniteMagnitude, .greatestFiniteMagnitude, .greatestFiniteMagnitude)
        var hi = SCNVector3(-Float.greatestFiniteMagnitude, -.greatestFiniteMagnitude, -.greatestFiniteMagnitude)
        node.enumerateHierarchy { child, _ in
            guard let geometry = child.geometry else { return }
            let (minB, maxB) = geometry.boundingBox
            for x in [minB.x, maxB.x] {
                for y in [minB.y, maxB.y] {
                    for z in [minB.z, maxB.z] {
                        let p = child.convertPosition(SCNVector3(x, y, z), to: node)
                        lo = SCNVector3(min(lo.x, p.x), min(lo.y, p.y), min(lo.z, p.z))
                        hi = SCNVector3(max(hi.x, p.x), max(hi.y, p.y), max(hi.z, p.z))
                    }
                }
            }
        }
        return (lo, hi)
    }
}
```

- [ ] **Step 4: Write FakeSofa**

`PiggyEscape/PiggyEscape/Sources/ClosedWorld/FakeSofa.swift`:

```swift
import SceneKit
import UIKit

/// "가짜 소파" — 개발자가 코드로 선언한 숨는 지점. 실제 방의 진짜 소파와는
/// 아무 관계가 없다. 스텝 5의 "숨어봐" 인터랙션이 이동시키는 목적지가 바로 이 좌표다.
enum FakeSofa {
    static let hardcodedPosition = SCNVector3(1.2, 0, -1.2)

    @MainActor
    static func makeSofaNode() -> SCNNode {
        let model = AssetLoader.object(named: "Wood_Color") {
            AssetLoader.voxelBox(width: 0.8, height: 0.4, length: 0.5, color: .brown)
        }
        model.name = "FakeSofa"
        model.position = hardcodedPosition
        return model
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`

Expected: all `PigPlacementTests` and `FakeSofaTests` pass.

- [ ] **Step 6: Commit**

```bash
git add PiggyEscape/PiggyEscape/Sources/ClosedWorld/PigPlacement.swift PiggyEscape/PiggyEscape/Sources/ClosedWorld/FakeSofa.swift PiggyEscape/PiggyEscapeTests/PigPlacementTests.swift PiggyEscape/PiggyEscapeTests/FakeSofaTests.swift
git commit -m "Place Piggy and the fake sofa at hardcoded coordinates"
```

---

## Task 5: NodeInspector (node-tree vs ECS setup step)

**Files:**
- Create: `PiggyEscape/PiggyEscape/Sources/ClosedWorld/NodeInspector.swift`
- Test: `PiggyEscape/PiggyEscapeTests/NodeInspectorTests.swift`

**Interfaces:**
- Produces: `NodeInspector.describe(_ node: SCNNode) -> [String]` — one line per aspect (geometry / physicsBody / running actions) found bundled on the given node.

- [ ] **Step 1: Write the failing test**

`PiggyEscape/PiggyEscapeTests/NodeInspectorTests.swift`:

```swift
import XCTest
import SceneKit
@testable import PiggyEscape

final class NodeInspectorTests: XCTestCase {
    @MainActor
    func test_describe_reportsGeometryPhysicsAndActionOnSameNode() {
        // 의도적으로 geometry·physicsBody·action을 전부 SCNNode 하나에 붙인다 —
        // SceneKit이 이 셋을 분리하지 않는다는 걸 테스트로 증명하기 위해.
        let node = SCNNode(geometry: SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0))
        node.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        node.runAction(.moveBy(x: 1, y: 0, z: 0, duration: 1), forKey: "demo.move")

        let lines = NodeInspector.describe(node)

        XCTAssertTrue(lines.contains { $0.contains("geometry") })
        XCTAssertTrue(lines.contains { $0.contains("physicsBody") })
        XCTAssertTrue(lines.contains { $0.contains("demo.move") })
    }

    @MainActor
    func test_describe_omitsAspectsNotPresent() {
        let node = SCNNode()
        let lines = NodeInspector.describe(node)
        XCTAssertFalse(lines.contains { $0.contains("geometry") })
        XCTAssertFalse(lines.contains { $0.contains("physicsBody") })
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`

Expected: FAIL to build — `NodeInspector` doesn't exist yet.

- [ ] **Step 3: Write NodeInspector**

`PiggyEscape/PiggyEscape/Sources/ClosedWorld/NodeInspector.swift`:

```swift
import SceneKit

/// 노드 하나를 들여다보고, 생김새(geometry)·물리(physicsBody)·행동(action)이
/// 전부 같은 SCNNode 객체 위에 얹혀 있다는 걸 텍스트로 보여준다.
/// RealityKit의 ECS는 이 세 가지를 각각 다른 Component로 분리하지만,
/// SceneKit은 분리하지 않는다 — 이걸 실행 결과로 확인하기 위한 디버그 도구.
enum NodeInspector {
    static func describe(_ node: SCNNode) -> [String] {
        var lines: [String] = []

        if let geometry = node.geometry {
            lines.append("geometry: \(type(of: geometry))")
        }
        if let physicsBody = node.physicsBody {
            lines.append("physicsBody: type=\(physicsBody.type.rawValue)")
        }
        for key in node.actionKeys {
            lines.append("action[\(key)]: \(node.action(forKey: key).map(String.init(describing:)) ?? "nil")")
        }

        return lines
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`

Expected: all `NodeInspectorTests` pass.

- [ ] **Step 5: Commit**

```bash
git add PiggyEscape/PiggyEscape/Sources/ClosedWorld/NodeInspector.swift PiggyEscape/PiggyEscapeTests/NodeInspectorTests.swift
git commit -m "Add NodeInspector demonstrating SceneKit's node-bundled structure"
```

---

## Task 6: HideAction

**Files:**
- Create: `PiggyEscape/PiggyEscape/Sources/ClosedWorld/HideAction.swift`
- Test: `PiggyEscape/PiggyEscapeTests/HideActionTests.swift`

**Interfaces:**
- Consumes: `FakeSofa.hardcodedPosition: SCNVector3` (Task 4)
- Produces: `HideAction.makeMoveAction() -> SCNAction`

- [ ] **Step 1: Write the failing test**

`PiggyEscape/PiggyEscapeTests/HideActionTests.swift`:

```swift
import XCTest
import SceneKit
@testable import PiggyEscape

final class HideActionTests: XCTestCase {
    @MainActor
    func test_makeMoveAction_movesNodeToFakeSofaPosition() {
        let pig = PigPlacement.makePigNode()
        let expectation = expectation(description: "pig reaches fake sofa position")

        pig.runAction(HideAction.makeMoveAction()) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(pig.position.x, FakeSofa.hardcodedPosition.x, accuracy: 0.01)
        XCTAssertEqual(pig.position.y, FakeSofa.hardcodedPosition.y, accuracy: 0.01)
        XCTAssertEqual(pig.position.z, FakeSofa.hardcodedPosition.z, accuracy: 0.01)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`

Expected: FAIL to build — `HideAction` doesn't exist yet. (Note: for `SCNAction` completion handlers to actually fire in a unit test, the node must be attached to a scene being rendered by an `SCNRenderer`/`SCNView`, OR you can drive it manually. If Step 2's test hangs/times out after `HideAction` is implemented, switch the test to attach `pig` to an `SCNScene` and pump it with `SCNRenderer(device: nil, options: nil)` calling `renderer.render(atTime:)` in a loop instead of relying on `wait(for:)` — fix forward once you see the actual failure mode, this is the one step in the plan with real execution-environment uncertainty.)

- [ ] **Step 3: Write HideAction**

`PiggyEscape/PiggyEscape/Sources/ClosedWorld/HideAction.swift`:

```swift
import SceneKit

/// "숨어봐" 인터랙션의 핵심: 하드코딩된 가짜 소파 좌표로 이동하는 액션 하나.
/// 이 액션은 실제 방에 있는 진짜 소파가 어디 있든 상관하지 않는다 —
/// 목적지는 오직 FakeSofa.hardcodedPosition, 즉 개발자가 선언한 좌표뿐이다.
enum HideAction {
    static func makeMoveAction() -> SCNAction {
        .move(to: FakeSofa.hardcodedPosition, duration: 0.5)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`

Expected: `HideActionTests` passes. If the completion-handler timing issue from Step 2 appears, apply the fix described there.

- [ ] **Step 5: Commit**

```bash
git add PiggyEscape/PiggyEscape/Sources/ClosedWorld/HideAction.swift PiggyEscape/PiggyEscapeTests/HideActionTests.swift
git commit -m "Add HideAction: tap-to-hide moves the pig to the fake sofa"
```

---

## Task 7: ClosedWorldSceneView (wire it all into the app)

**Files:**
- Create: `PiggyEscape/PiggyEscape/Sources/ClosedWorld/ClosedWorldSceneView.swift`
- Modify: `PiggyEscape/PiggyEscape/Sources/ContentView.swift`

**Interfaces:**
- Consumes: `RoomBuilder.build()` (Task 3), `PigPlacement.makePigNode()` (Task 4), `FakeSofa.makeSofaNode()` (Task 4), `HideAction.makeMoveAction()` (Task 6)
- Produces: `ClosedWorldSceneView: UIViewRepresentable` for `ContentView` to host.

- [ ] **Step 1: Write ClosedWorldSceneView**

`PiggyEscape/PiggyEscape/Sources/ClosedWorld/ClosedWorldSceneView.swift`:

```swift
import SwiftUI
import SceneKit

/// SwiftUI ↔ SceneKit(SCNView)을 잇는 다리. 방·돼지·가짜 소파를 씬에 담고,
/// 탭하면 돼지가 가짜 소파로 "숨는" 하나의 인터랙션만 처리한다.
struct ClosedWorldSceneView: UIViewRepresentable {
    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()

        scene.rootNode.addChildNode(RoomBuilder.build())
        let pig = PigPlacement.makePigNode()
        scene.rootNode.addChildNode(pig)
        scene.rootNode.addChildNode(FakeSofa.makeSofaNode())

        // 카메라는 방 안쪽(roomDepth/2 = 2보다 작은 z)에 둔다 — 방 밖에 두면
        // Wall_1(z=+2)에 가려 내부가 전혀 보이지 않는다.
        let camera = SCNCamera()
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 2, 1.7)
        cameraNode.look(at: SCNVector3(0, 0.3, -0.5))
        scene.rootNode.addChildNode(cameraNode)

        let light = SCNNode()
        light.light = SCNLight()
        light.light?.type = .omni
        light.position = SCNVector3(0, 3, 2)
        scene.rootNode.addChildNode(light)

        view.scene = scene
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true

        context.coordinator.pigNode = pig
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        view.addGestureRecognizer(tap)

        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        var pigNode: SCNNode?

        @objc func handleTap() {
            pigNode?.runAction(HideAction.makeMoveAction())
        }
    }
}
```

- [ ] **Step 2: Host it from ContentView**

`PiggyEscape/PiggyEscape/Sources/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        ClosedWorldSceneView()
            .ignoresSafeArea()
    }
}
```

- [ ] **Step 3: Build for simulator**

Run: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Run all unit tests once more (regression check)**

Run: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`

Expected: all tests from Tasks 1–6 still pass.

- [ ] **Step 5: Visual verification in the Simulator**

Use `mcp__Claude_Code_iOS_Simulator__build` (`action: build`, then `build_status`) to build the app, then `mcp__Claude_Code_iOS_Simulator__control` (`action: attach`, then `launch`) to install and launch it on `iPhone 17 Pro`. Take a `screenshot` and confirm: a room with 4 walls and a floor is visible, the pig is standing in it, and a fake-sofa-shaped object sits off to one side. Then `tap` the pig's on-screen position and take a second `screenshot` — confirm the pig has moved to the fake sofa. This step has no automated assertion; it's a manual visual check the plan executor reports on.

- [ ] **Step 6: Commit**

```bash
git add PiggyEscape/PiggyEscape/Sources/ClosedWorld/ClosedWorldSceneView.swift PiggyEscape/PiggyEscape/Sources/ContentView.swift
git commit -m "Wire RoomBuilder, PigPlacement, FakeSofa, and HideAction into the app"
```

---

## Task 8: DocC tutorial catalog for Chapter 1

**Files:**
- Create: `PiggyEscape/PiggyEscape/Tutorials/SceneKitToRealityKit.docc/SceneKitToRealityKit.tutorial`
- Create: `PiggyEscape/PiggyEscape/Tutorials/SceneKitToRealityKit.docc/Tutorials/01-ClosedWorld.tutorial`
- Modify: `PiggyEscape/Project.swift` (add the `.docc` folder to the app target's sources so Xcode recognizes it as a Documentation Catalog)

**Interfaces:**
- Produces: a `.doccarchive` buildable via `xcodebuild docbuild`.

- [ ] **Step 1: Add the .docc catalog to the Tuist manifest**

Edit `PiggyEscape/Project.swift`, change the `PiggyEscape` target's `sources` to also glob the catalog:

```swift
sources: ["PiggyEscape/Sources/**", "PiggyEscape/Tutorials/**"],
```

- [ ] **Step 2: Write the root tutorial catalog file**

`PiggyEscape/PiggyEscape/Tutorials/SceneKitToRealityKit.docc/SceneKitToRealityKit.tutorial`:

```
@Tutorials(name: "씬킷에서 리얼리티킷으로") {
    @Intro(title: "갇힌 캐릭터의 탈출") {
        개발자가 만든 가짜 세계에 갇혀 살던 돼지가 균열을 뚫고 진짜 세계로 도망친다.
        이 튜토리얼은 그 탈출과 술래잡기를 직접 만들어보며,
        SceneKit이 가짜로 짓는 세계와 RealityKit이 진짜로 읽는 세계의 차이를 체험한다.
    }

    @Chapter(name: "Chapter 1: 갇힌 세계") {
        SceneKit만으로 방을 짓고 돼지를 그 안에 가둔다.
        이 세계에 있는 모든 것은 코드로 선언한 것의 총합일 뿐이라는 걸,
        "숨어봐"가 실패하는 순간으로 직접 확인한다.

        @Image(source: "closed-world-chapter-icon.png", alt: "갇힌 세계 챕터 아이콘")

        @TutorialReference(tutorial: "doc:01-ClosedWorld")
    }
}
```

- [ ] **Step 3: Write the Chapter 1 tutorial file**

`PiggyEscape/PiggyEscape/Tutorials/SceneKitToRealityKit.docc/Tutorials/01-ClosedWorld.tutorial`:

```
@Tutorial(time: 20) {
    @Intro(title: "갇힌 세계 짓기") {
        SceneKit 세계는 두 가지 의미에서 닫혀 있다. 이 세계에 있는 모든 것은
        개발자가 코드로 선언한 것의 총합이고, 그 존재 방식조차 SCNNode 하나가
        생김새·물리·행동을 전부 짊어지는 구조다. 이 장에서는 그걸 설명이 아니라
        캐릭터가 실패를 겪는 과정으로 직접 확인한다.
    }

    @Section(title: "프로젝트 세팅") {
        @ContentAndMedia {
            SwiftUI 앱에서 SceneKit의 SCNView를 UIViewRepresentable로 감싸는
            껍데기를 만든다. 이 단계는 서사적 의미 없는 빌드 준비다.
        }

        @Steps {
            @Step {
                `ClosedWorldSceneView`를 만들어 SwiftUI에서 SceneKit 씬을 호스팅할
                준비를 한다.

                @Code(name: "ClosedWorldSceneView.swift", file: "01-ClosedWorld-01-01.swift")
            }
        }
    }

    @Section(title: "방 짓기") {
        @ContentAndMedia {
            `SCNBox`로 벽을 세우고, `Ground_Color.usdc`를 바닥으로 재사용한다.
            좌표 원점(0,0,0)도 여기서 임의로 선언한다. 이 세계에 있는 모든 것 —
            벽이든 바닥이든 — 은 지금 이 코드로 써넣은 것만 존재한다.
        }

        @Steps {
            @Step {
                `RoomBuilder`를 만들어 방을 짓는다. 벽 4개는 `SCNBox`로, 바닥은
                `AssetLoader`로 `Ground_Color` 에셋을 불러와 만든다.

                @Code(name: "RoomBuilder.swift", file: "01-ClosedWorld-02-01.swift")
            }
        }
    }

    @Section(title: "돼지 배치") {
        @ContentAndMedia {
            하드코딩된 좌표에 돼지를 놓는다. 이 좌표는 방 안 어떤 실제 기준과도
            연결되어 있지 않다 — 그냥 숫자다.
        }

        @Steps {
            @Step {
                `PigPlacement`가 `Piggy.usdc`를 불러와 표준 높이로 정규화하고
                하드코딩된 위치에 놓는다.

                @Code(name: "PigPlacement.swift", file: "01-ClosedWorld-03-01.swift")
            }
        }
    }

    @Section(title: "노드 구조 탐구") {
        @ContentAndMedia {
            지금까지 만든 노드를 들여다보면, 생김새(geometry)·물리(physicsBody)·
            행동(action)이 전부 SCNNode 하나에 붙어있다는 걸 확인할 수 있다.
            책임이 분리되지 않는 구조다. RealityKit의 ECS는 이걸 쪼갠다 —
            자세한 대비는 4장에서 다룬다.
        }

        @Steps {
            @Step {
                `NodeInspector`로 노드 하나에 얹힌 geometry·physicsBody·action을
                모두 출력해 확인한다.

                @Code(name: "NodeInspector.swift", file: "01-ClosedWorld-04-01.swift")
            }
        }
    }

    @Section(title: "\"숨어봐\" 시도") {
        @ContentAndMedia {
            `Wood_Color.usdc`를 가짜 소파로 미리 놓아두고, 탭하면 돼지가 그
            좌표로 이동하는 액션을 실행한다. 진짜 소파가 화면 반대편(실제 방)에
            있어도 이 동작은 그와 전혀 무관하게 실행된다 — 내가 선언한 가짜
            소파로는 이동되지만, 진짜 소파는 이 세계에 아예 존재하지 않는다.
        }

        @Steps {
            @Step {
                `FakeSofa`와 `HideAction`을 추가하고, 탭 제스처로 돼지를
                가짜 소파 위치까지 이동시킨다.

                @Code(name: "HideAction.swift", file: "01-ClosedWorld-05-01.swift")
            }
        }
    }

    @Section(title: "다음 장 예고") {
        @ContentAndMedia {
            이 세계는 지금까지 내가 만든 것만으로 이루어져 있었다. 다음 장부터
            이 세계는 더 이상 내가 만든 것만으로 이루어지지 않는다 — 균열
            사이로 진짜 빛이 새어 든다.
        }
    }
}
```

- [ ] **Step 4: Extract the step code snippets into Resources**

Copy the finished source files into the catalog's snippet folder (these are what `@Code(file:)` above references):

```bash
mkdir -p "PiggyEscape/PiggyEscape/Tutorials/SceneKitToRealityKit.docc/Tutorials/Resources"
cp "PiggyEscape/PiggyEscape/Sources/ClosedWorld/ClosedWorldSceneView.swift" \
   "PiggyEscape/PiggyEscape/Tutorials/SceneKitToRealityKit.docc/Tutorials/Resources/01-ClosedWorld-01-01.swift"
cp "PiggyEscape/PiggyEscape/Sources/ClosedWorld/RoomBuilder.swift" \
   "PiggyEscape/PiggyEscape/Tutorials/SceneKitToRealityKit.docc/Tutorials/Resources/01-ClosedWorld-02-01.swift"
cp "PiggyEscape/PiggyEscape/Sources/ClosedWorld/PigPlacement.swift" \
   "PiggyEscape/PiggyEscape/Tutorials/SceneKitToRealityKit.docc/Tutorials/Resources/01-ClosedWorld-03-01.swift"
cp "PiggyEscape/PiggyEscape/Sources/ClosedWorld/NodeInspector.swift" \
   "PiggyEscape/PiggyEscape/Tutorials/SceneKitToRealityKit.docc/Tutorials/Resources/01-ClosedWorld-04-01.swift"
cp "PiggyEscape/PiggyEscape/Sources/ClosedWorld/HideAction.swift" \
   "PiggyEscape/PiggyEscape/Tutorials/SceneKitToRealityKit.docc/Tutorials/Resources/01-ClosedWorld-05-01.swift"
```

Note: `@Image(source: "closed-world-chapter-icon.png", ...)` in `SceneKitToRealityKit.tutorial` references an image that doesn't exist yet. Remove that `@Image` line for now (it's not required for the catalog to build) — producing the chapter icon image is out of scope for this plan and should be a follow-up task.

- [ ] **Step 5: Remove the not-yet-available chapter icon reference**

Edit `SceneKitToRealityKit.tutorial` from Step 2: delete the line `@Image(source: "closed-world-chapter-icon.png", alt: "갇힌 세계 챕터 아이콘")`.

- [ ] **Step 6: Regenerate the Xcode project so it picks up the new catalog**

Run: `cd PiggyEscape && tuist generate --no-open`

- [ ] **Step 7: Build the documentation**

Run: `xcodebuild docbuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/piggyescape-docbuild`

Expected: `** BUILD SUCCEEDED **` and a `.doccarchive` under `/tmp/piggyescape-docbuild`. If it fails with a DocC-specific error (broken `@Step`/`@Code` reference, unknown directive), read the exact error — it names the file and line — and fix the `.tutorial` file or the snippet file it points to, then rerun this step.

- [ ] **Step 8: Commit**

```bash
git add PiggyEscape/Project.swift "PiggyEscape/PiggyEscape/Tutorials"
git commit -m "Add Chapter 1 DocC tutorial catalog"
```

---

## Not covered by this plan

- Chapters 2–4 (design and implementation).
- GitHub Pages deployment (`docc convert --hosting-base-path ...`, publishing to `gh-pages` or `docs/`) — deliberately deferred; base-path questions depend on how the site is actually served and should get their own short design pass first.
- The `closed-world-chapter-icon.png` chapter image.
- Cleaning up the stray `.git` at `/Users/yang-eunseo/.git` — flagged to the user, not touched here.
