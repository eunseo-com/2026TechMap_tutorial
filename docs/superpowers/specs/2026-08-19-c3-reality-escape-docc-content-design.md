# C3 Reality Escape DocC 콘텐츠 설계

## 목적

GitHub Pages에서 제공하는 DocC 카탈로그를, 첫 번째 방·가짜 소파 초안이 아니라 실제로 진행한 C3 월드에서 RealityKit 현실 공간으로 탈출하는 학습 흐름으로 확장한다. 초심자가 **가상 카메라**, **실제 기기 카메라**, **SceneKit의 노드 hit test**, **현실 메쉬 raycast**를 혼동하지 않도록 각 장의 입력과 관찰 결과를 구분한다.

## 확인한 근거

- `C3ClosedWorldSceneView`와 `C3ClosedWorld`는 `SCNCamera`를 장면에 두고, 탭으로 선언된 돼지 노드만 찾으며 팬으로 가상 카메라 yaw를 회전한다.
- `EscapeRootView`는 C3 장면의 발견 뒤에만 시스템 카메라 권한을 요청하고 `RealityHideARView`로 전환한다.
- `RealityHideARView`는 내부 `ARView`가 창과 유효한 크기를 얻은 뒤 AR 세션을 시작한다. LiDAR 지원 기기에서는 수평·수직 평면, 분류된 장면 메쉬, RealityKit의 occlusion·collision을 요청한다.
- `RealityHidePlanner`는 실제 메쉬의 수직 면을 탭한 위치, 카메라 위치, 검증된 바닥 평면으로 돼지의 반대편 목적지를 계산한다. `RealityRevealMonitor`는 가림을 한 번 관찰한 뒤 사용자가 실제로 이동하거나 시점을 바꾸고 두 프레임 연속 가림이 사라졌을 때만 재발견을 알린다.
- Xcode에 포함한 Apple의 Pyro Panda SceneKit/RealityKit 샘플은 노드·GamePlayKit 결합 구조와 Component·System 분리 구조를 나란히 읽는 비교 근거다.

## 정보 구조

1. **Chapter 1 — C3의 닫힌 세계**: 가상 카메라와 `SCNView.hitTest`는 코드로 만든 씬 안의 노드만 다룬다.
2. **Chapter 2 — 문 열기**: 카메라 권한과 AR 세션을 시작하며, ARView가 실제 화면 크기를 얻은 뒤 스캔을 시작하는 이유를 설명한다.
3. **Chapter 3 — 실제 물체 뒤 숨기**: LiDAR 메쉬를 깊이·충돌 입력으로 쓰고, 사용자가 물체의 수직 옆면을 탭해 반대편 바닥으로 돼지를 이동시킨다.
4. **Chapter 4 — 돌아보기**: 세계의 사실을 얻는 출처와 책임을 배치하는 구조를 C3 코드와 Pyro Panda 샘플을 통해 비교한다.

## 상태 표기

코드와 자동 테스트로 검증된 흐름은 현재형으로 설명한다. 카메라 권한과 AR 카메라 배경은 실기기에서 확인되었지만, LiDAR 실기기에서의 실제 가구 가림·재발견은 계속 수동 검증이 필요하므로 Chapter 3에 **실기기 확인 필요**로 분명히 표시한다. 플레이스홀더 이미지를 실제 성공 화면처럼 사용하지 않는다.
