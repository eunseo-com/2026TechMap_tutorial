# 숨기 경로 거절 보수 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** 실제 통로가 있는 물체도 고정 출발점과 거친 후보 간격 때문에 모두 거절하는 경로 탐색을 보수하고, 바닥 부족·카메라 근접·충돌을 구분한다.

**Architecture:** 현재 bounded side-route 구조를 유지한다. 클릭 당시 camera pose를 plan에 보존하고, 최초 모델 배치 전에 안전한 출발점을 함께 검색한다. 실제 scene-understanding 몸통 검사와 이동 중 재검사를 유지한다.

**Tech Stack:** Swift 5, ARKit/RealityKit, XCTest, generic iPhoneOS 및 physical iPhone. Simulator 금지.

**Spec:** `docs/superpowers/specs/2026-09-07-ar-usability-polish.md`, 2026-09-08 사용자 실기기 “돌아갈 길이 없다” 보고.

## Global Constraints

- 높이 0.18m·물체 선택 최소 거리 0.90m·다섯 점/두 frame 가림·이동 재발견 계약 유지.
- 인식한 바닥과 실제 몸통 충돌 검사는 우회하지 않는다. 카메라와 0.90m 미만인 새 출발점은 사용하지 않는다.
- 임의의 fallback teleport, 물체 통과, 가짜 숨김 성공은 금지한다. 경로 확정 전에는 돼지를 배치하지 않는다.
- 사용자 물체/실제 frame 데이터가 없는 한 재현한 코드 결함을 해당 실환경의 유일 원인으로 단정하지 않는다.

## Task 1: 출발점·좁은 우회로와 거절 원인의 경계 보수

**Files:** `RealityHidePlanner.swift`, `RealityWalkRoute.swift`, `RealityHideARView.swift`, `RealityWalkRouteTests.swift` (모두 `PiggyEscape` 하위 기존 경로). 관련 문서: `docs/LEARNING_LOG.md`, `docs/WORK_LOG.md`, DocC Chapter 3 및 연결 예제.

**Interfaces:** `RealityHidePlan`에 선택 당시 `cameraPosition: SIMD3<Float>?`를 보존한다. `RealityWalkRoutePlanner.route(for:onFailure:isSegmentClear:)`는 기존 optional route 반환을 유지하고 동기 실패 원인을 전달한다. camera 없는 이전 고정 plan에는 출발점 확장을 하지 않는다. 성공한 `route.points.first`를 실제 배치 시작점으로 전달한다.

- [ ] 실제 production planner로 만든 plan과 독립적인 segment-vs-expanded-box 검사로 아래 RED를 재현한다.

```swift
// 탭은 높은 등받이, 바닥 높이의 몸통은 앞으로 돌출된 가구.
// 실제 장애물 x=-0.50...0.50, z=-0.55...0.40, 반경0.20으로 확장.
// 기존 start.z=0.28은 막히지만 z=0.73, 측면x=0.80, 뒤z=-0.83은 열린 경로다.
XCTAssertNotNil(RealityWalkRoutePlanner.route(for: sofaPlan, isSegmentClear: clearOfExpandedSofa))
// 폭1.65m 바닥의 열린 x=0.50 통로: 기존0.40은 충돌,0.70은 바닥 밖이다.
XCTAssertNotNil(RealityWalkRoutePlanner.route(for: corridorPlan, isSegmentClear: clearOfNarrowObstacle))
```

- [ ] `bash scripts/test-reality-policies.sh`로 의도한 nil-route assertion 실패를 확인한다. 컴파일 오류나 가짜 callback 성공을 RED로 세지 않는다.
- [ ] 최소 구현: 출발 추가 거리 `[0, 0.15, 0.30, 0.45, 0.60]`, 측면 `[0.40, 0.50, 0.60, 0.70, 0.80, 1.0, 1.2, 1.4]`, 기존 네 깊이/양방향을 bounded 검색한다. floor footprint와 camera distance를 통과한 후보만 검사하며 동일 segment의 충돌 결과를 한 탐색 안에서 캐시한다.

```swift
let start = plan.start - retreat * startExtra
let points = [start, start + sideOffset, destination + sideOffset, destination]
// floor projection/footprint, camera clearance, actual body sweep를 모두 통과해야 반환.
```

- [ ] camera 근접, 모든 방향 충돌, 바닥 부족, camera 없는 legacy plan, non-finite 입력의 회귀를 추가한다. 동기 `onFailure`는 실패 때만 한 번 호출한다.
- [ ] handleTap에서 `route.points.first/last`를 사용해 실제 시작/도착을 전달한다. 바닥 부족·카메라 근접·충돌 안내를 구분하고 가림/발견 전이는 그대로 보존한다.
- [ ] host policy GREEN, generic iPhoneOS Swift 5/6 strict build, 사용 가능한 physical iPhone 테스트, 독립 코드 검토를 진행한다. 사용자 실제 물체 재시도는 별도 확인한다.
- [ ] 변경한 후보·출발점·실패 의미를 Chapter 3 설명/예제에 동기화하고 DocC content 및 렌더 검증 후 기존 승인된 Pages에 반영한다. WORK_LOG에 검증과 남은 실기기 범위를 같은 코드 커밋으로 남긴다.

## 실행 방식

기존 사용자 구현 승인에 따라 같은 작업에서 실행한다. 경로 코드·회귀 테스트는 하나의 구현 작업으로 맡기고, 주 작업은 DocC 동기화·기기 검증·기록을 진행한다. 파일 소유권을 나누고 검증 기록을 포함해 함께 커밋한 뒤 태스크 및 최종 독립 검토를 진행한다. 별도 기능·Simulator·새 프로젝트는 만들지 않는다.
