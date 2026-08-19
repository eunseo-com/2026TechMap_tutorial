# C3 Reality Escape DocC Content Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish a four-chapter DocC tutorial that documents the verified C3-to-RealityKit escape flow and its remaining device-only checks.

**Architecture:** Keep the static GitHub Pages pipeline unchanged. Extend the existing `SceneKitToRealityKit.docc` catalog with three tutorial files and focused, display-only Swift excerpts copied from the verified C3 and RealityKit sources. Each chapter identifies whether the behavior is source-verified, device-observed, or still pending manual LiDAR validation.

**Tech Stack:** Swift DocC, SwiftUI, SceneKit, ARKit, RealityKit, GitHub Pages.

**Spec:** `docs/superpowers/specs/2026-08-19-c3-reality-escape-docc-content-design.md`

## Global Constraints

- Do not claim that Simulator tests prove physical mesh occlusion.
- Distinguish SceneKit's virtual `SCNCamera` from the device camera used by `ARView`.
- Keep code excerpts focused on one observable change per tutorial step.
- Preserve the existing GitHub Pages base path and root redirect.

---

### Task 1: Expand the catalog map and C3 closed-world chapter

**Files:**
- Modify: `Tutorials/SceneKitToRealityKit.docc/SceneKitToRealityKit.tutorial`
- Modify: `Tutorials/SceneKitToRealityKit.docc/Tutorials/01-ClosedWorld.tutorial`
- Create: `Tutorials/SceneKitToRealityKit.docc/Tutorials/Resources/01-C3ClosedWorld-07-01.swift`
- Create: `Tutorials/SceneKitToRealityKit.docc/Tutorials/Resources/01-C3ClosedWorld-07-02.swift`

- [x] Add all four chapter references and make the first chapter explain virtual camera, node hit testing, and C3 tree hiding.
- [x] Verify the catalog references four tutorial files.

### Task 2: Document camera permission and AR session startup

**Files:**
- Create: `Tutorials/SceneKitToRealityKit.docc/Tutorials/02-OpeningTheDoor.tutorial`
- Create: `Tutorials/SceneKitToRealityKit.docc/Tutorials/Resources/02-OpeningTheDoor-01-01.swift`
- Create: `Tutorials/SceneKitToRealityKit.docc/Tutorials/Resources/02-OpeningTheDoor-02-01.swift`

- [x] Explain the transition from virtual camera to device camera and the post-layout AR session gate.
- [x] Verify `docc convert` resolves both code excerpts.

### Task 3: Document real-object hiding and recovery

**Files:**
- Create: `Tutorials/SceneKitToRealityKit.docc/Tutorials/03-RealHideAndSeek.tutorial`
- Create: `Tutorials/SceneKitToRealityKit.docc/Tutorials/Resources/03-RealHideAndSeek-01-01.swift`
- Create: `Tutorials/SceneKitToRealityKit.docc/Tutorials/Resources/03-RealHideAndSeek-02-01.swift`
- Create: `Tutorials/SceneKitToRealityKit.docc/Tutorials/Resources/03-RealHideAndSeek-03-01.swift`

- [x] Explain mesh capability gating, vertical-side target selection, opposite-side placement, and the physical-device validation boundary.
- [x] Verify DocC renders the chapter without unresolved resource references.

### Task 4: Add the comparison chapter, update project context, and deploy

**Files:**
- Create: `Tutorials/SceneKitToRealityKit.docc/Tutorials/04-Comparison.tutorial`
- Create: `Tutorials/SceneKitToRealityKit.docc/Tutorials/Resources/04-Comparison-01-01.swift`
- Modify: `README.md`
- Modify: `docs/PROJECT_CONTEXT.md`

- [x] Compare C3's node-centered world with the RealityKit planner/controller/monitor split and the Pyro Panda Component/System sample.
- [x] Build the static archive with `bash scripts/build-docc-site.sh /tmp/SceneKitToRealityKit.full-content.doccarchive`.
- [x] Commit and push the catalog so the existing Pages workflow publishes it.
