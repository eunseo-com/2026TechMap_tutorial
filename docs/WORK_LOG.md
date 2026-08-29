# 작업 인수인계 기록

> 다음 작업을 시작하기 전에 **현재 인수인계**를 먼저 읽는다. 의미 있는 작업 단위가 끝나면 결과물과 같은 커밋에 이 문서를 갱신한다. 사용한 도구나 모델 이름은 쓰지 않는다.

## 현재 인수인계

- 상태: 사용자가 기존 Chapter 1 제한을 해제하고 Chapter 2–4와 공개 DocC까지 완성하는 [4개 챕터 완성 설계](superpowers/specs/2026-08-29-four-chapter-experience-and-docc-design.md)를 승인했다. [4개 챕터 실행 계획](superpowers/plans/2026-08-29-four-chapter-experience-and-docc-implementation.md)은 앱 TDD 8개 단계, UI·Swift 6 준비, DocC 단일 원본·시각 자료·접근성·Pages, 최종 실기기·배포의 13개 태스크로 고정했다. Task 2는 네 챕터 상태·이벤트·오류 reason 보존과 상태 기반 chapter derivation, 별도 callback generation gate를 추가했다.
- 진행 중 범위: 실행 앱은 C3 섬을 Chapter 1, 카메라 권한·AR 준비를 Chapter 2, 실제 물체 뒤 숨기·물리적 재발견을 Chapter 3, SceneKit/RealityKit 비교·완료를 Chapter 4로 분리한다. Chapter 2–3은 같은 `ARView`·session을 유지한다. Chapter 3은 0.18m 돼지, 0.90m 최소 거리, 현재 camera view 기준 중심·상·하·좌·우 5점, 중심 포함 4/5의 서로 다른 AR frame 연속 두 관찰 가림, 0.15m 또는 15° 이동 이력 뒤 중심 포함 3/5의 연속 두 관찰 재발견을 기준으로 한다. 정보 overlay는 AR 탭을 막지 않으며 발견 뒤 다시 숨기기와 Chapter 4 진행을 제공한다.
- 문서 범위: Task 1에서 `origin/main`의 공개 네 챕터 DocC·Pages 기준선을 기능 worktree에 통합하고, 이어 AGENTS·CLAUDE·README의 이전 Chapter 1 전용 지침을 승인된 4개 챕터 설계와 13개 태스크로 정정했다. Task 10에서 저장소 루트 `Tutorials/SceneKitToRealityKit.docc`를 유일한 공개·검증 원본으로 확정하고 앱 경로의 한 챕터 복사본을 제거한다. 공개 사이트는 고유 챕터 이미지, 실제 Chapter 3 전·후 증거, 정상 링크·한국어 접근성·desktop/mobile 렌더링을 검증한다.
- 기준선 관찰: 현재 앱은 높이 0.35m·최소 거리 0.45m이고, 가림 판정이 돼지 중심 한 점뿐이며 첫 mesh 또는 floor 중 하나만 관찰해도 준비 완료가 되어 화면을 크게 가리거나 충분한 공간 정보 없이 찾기 단계가 시작될 수 있다. 최신 HEAD의 전체 XCTest 112개는 통과하지만 Swift 6 strict concurrency build는 알려진 actor 격리 오류로 실패한다. 공개 DocC는 네 챕터가 열리지만 동일 아이콘 반복, Chapter 3 실제 전·후 이미지 부재, 미해결 링크·localization placeholder·접근성 문제가 있다.
- 마지막 검증: Task 1 병합 뒤 `bash scripts/build-docc-site.sh /tmp/piggyescape-public-base.doccarchive`가 성공하고 `data/tutorials/scenekittorealitykit.json` 존재를 확인했다. iPhone 17 Pro iOS 26.5 Simulator의 전체 XCTest는 112/112·0 failures와 `** TEST SUCCEEDED **`로 완료됐으며, 결과 bundle은 `/tmp/piggyescape-task1-tests/Logs/Test/Test-PiggyEscape-2026.08.30_00-03-08-+0900.xcresult`다. iPhone 16 Pro의 AR 카메라 배경 정상 관찰도 유지한다.
- 다음 시작점: Task 3에서 mesh와 분류된 floor가 모두 관찰될 때만 준비 완료로 만드는 `RealityEnvironmentReadiness`와 Chapter 2의 tap lock을 TDD로 분리한다.
- 차단 요소: LiDAR 실기기 두 대가 현재 unavailable이므로 실제 크기·메시 가림·물리적 재발견·Chapter 3 증거 이미지는 기기 연결 전까지 `실기기 대기`다. 이 제약은 자동 구현과 문서 구조 개선을 막지 않는다.

### 실기기 수용 목록 — 실기기 대기

- [ ] C3 섬·기존 나무·초기 나레이션이 보인다.
- [ ] 초기 나레이션이 끝나기 전 돼지 탭은 무시된다.
- [ ] 탭 뒤 걷는 돼지가 현재 카메라 반대편 나무 뒤로 이동한다.
- [ ] 나무 도착 0.40초 뒤 카메라 조작 없이 놀란 모델·자막·1.5배 확대 후 복귀가 한 번 실행된다.
- [x] 페이드 뒤 시스템 카메라 권한 문구가 보이고, 허용 뒤 AR 카메라 배경이 열린다. 스캔 안내와 LiDAR 준비 상태의 일치는 별도 확인한다.
- [ ] 권한 거부·제한과 Settings 복구를 각각 관찰한다.
- [ ] Chapter 2의 공간 준비 CTA 전에는 AR 화면 탭이 타깃을 만들지 않고, CTA 뒤 같은 session에서 Chapter 3으로 이어진다.
- [ ] 카메라에서 0.90m 이상 떨어진 실제 물체의 수직 옆면을 탭하면 0.18m 돼지가 카메라 쪽 바닥에서 반대편 바닥으로 걸어가며 화면을 과도하게 가리지 않는다.
- [ ] 현재 camera view 기준 중심·상·하·좌·우가 모두 화면 안에서 유효하고, 중심 포함 4/5를 실제 LiDAR mesh가 서로 다른 AR frame의 연속 두 관찰에서 가린 뒤에만 찾기 안내가 나타난다.
- [ ] “옆으로 움직이거나 카메라 방향을 바꿔 피기를 찾아봐.” 정보 패널이 물체 선택·카메라 조작을 가로채지 않는다.
- [ ] 가려진 채로 0.15m 이상 이동하거나 15° 이상 회전한 이력을 만든 뒤 중심 포함 3/5가 서로 다른 AR frame의 연속 두 유효 관찰에서 보일 때만 한 번 발견된다.
- [ ] 발견 때 놀란 모델·자막·1.5배 돼지 확대·1.12배 화면 확대가 한 번 실행되고 복귀한다.
- [ ] 돼지가 화면 밖·카메라 뒤로 잠시 벗어난 뒤 다시 보이면, 그 전후 관찰을 합쳐 조기 발견하지 않고 복귀 뒤 두 유효 관찰을 새로 요구한다.
- [ ] “다시 숨기기”를 연속 두 번 사용해도 이전 anchor·callback이 남지 않고, “차이 돌아보기”가 Chapter 4로 이어진다.
- [ ] LiDAR 미지원, 수평면 탭, 너무 가까운 탭, 바닥 추적 부족, 돼지 에셋 로드 실패 안내와 재시도 경로를 관찰한다.

### Task 7에서 해결한 항목

1. **RoomBuilder 바닥 방향** — `Ground_Color`을 X축으로 -90° 회전하고, 변환된 경계를 재서 4×4×0.1m에 맞춘 뒤 바닥면을 y=0에 정렬했다. 회전 전 원본 경계로 스케일하는 실수를 회귀 테스트로 막는다.
2. **돼지 좌표계·바닥 정렬** — `Piggy`도 Blender Z-up 모델이므로 내부 모델에서 Y-up 회전·균일 스케일·바닥 정렬을 수행하고, 바깥 노드는 위치와 액션만 맡게 분리했다.
3. **초기 프레이밍** — 카메라와 너무 가까워 화면 밖으로 밀리던 돼지의 임의 하드코딩 z 좌표를 1에서 0으로 조정했다. 카메라 설정과 `allowsCameraControl`은 계획값을 유지한다.

### Task 6 최종 통합 리뷰에서 해결한 항목

1. **바닥 footprint** — floor anchor 중심 대신 선택 지점을 local footprint와 비교한다. 큰 바닥의 유효 지점은 수용하고, 중심 근처라도 footprint 밖인 지점은 거절한다. iOS 16 이후 `planeExtent`의 width·height·Y축 회전을 반영하며, 가장자리 2cm만 tracking jitter 여유로 둔다.
2. **물리적 재발견** — 한 frame의 mesh hit 누락만으로는 발견되지 않는다. 이전 block camera pose에서 0.15m 이동 또는 15° 회전 뒤 두 frame 연속 nonblocking일 때만 한 번 재발견하며, 중간 block은 안정 관찰을 초기화한다.
3. **스캔 준비 시점** — AR 세션 시작 성공이 아니라 첫 mesh 또는 분류된 수평 floor 관찰을 스캔 준비로 정의했다. readiness callback은 한 번만 전달하고 view stop 시 관찰 subscription을 취소한다.
4. **재발견 cycle 기준** — 최초 실제 block의 camera pose를 hide cycle 동안 latch한다. 후속 block과 invalid projection은 visible 안정 count만 초기화하므로, 이미 가려진 상태에서 사용자가 한 이동과 최초 block 기준을 잃지 않으면서도 끊긴 frame을 연속 관찰로 세지 않는다.

## 작업 이력

| 날짜 | 작업 범위 | 결과 | 검증 | 다음 시작점 |
| --- | --- | --- | --- | --- |
| 2026-08-30 | Task 2 — 단일 4개 챕터 상태 기계와 파생 챕터 | `EscapeExperienceMachine`을 Chapter 1–4의 상태·전이·오류 reason 보존·Settings 재확인·reset/retry/replay 흐름으로 확장했다. chapter는 상태에서만 파생하며, `EscapeExperienceLifetime`이 experience/reality/hide-cycle generation token과 stale callback gate를 분리해 소유한다. 기존 coordinator를 Task 7 전까지 유지할 수 있도록 이전 callback event만 호환 경로로 남겼다. | 새 case·event·type 부재의 RED compiler failure를 확인했다. 자체 검토 RED 3개 assertion 뒤 active hide interruption 및 asset-failure session failure 경계를 보수했다. iPhone 17 Pro iOS 26.5에서 상태·chapter·lifetime 및 기존 coordinator focused 30/30·0 failures, `TEST SUCCEEDED`; 결과 bundle은 `/tmp/piggyescape-task2-final/Logs/Test/Test-PiggyEscape-2026.08.30_00-26-13-+0900.xcresult`. | Task 3 — complete room readiness와 tap lock |
| 2026-08-30 | Task 1 검토 보수 — 활성 작업 지침 | `AGENTS.md`, `CLAUDE.md`, `README.md`가 이전 Chapter 1 전용 범위를 지시하던 충돌을 해소했다. 세 진입 문서는 승인된 4개 챕터 설계·13개 태스크 계획을 가리키며, 미추적 파일 보존·태스크 단위 검증·생성물 제외 규칙을 유지한다. | `git diff --check` 통과. 세 문서에서 이전 Chapter 1 전용 지시·계획 경로가 남지 않았고, 승인된 design·plan 경로와 root DocC catalog 경로가 모두 존재함을 확인했다. | Task 2 — 4개 챕터 상태 기계 RED 테스트 |
| 2026-08-30 | Task 1 — 공개 DocC 기준선 통합 | 최신 `origin/main`을 기능 worktree에 no-ff 병합하고, `PROJECT_CONTEXT` 충돌은 승인된 4장 범위·현재 검증 경계를 유지하면서 root DocC build·Pages 경로 설명을 통합했다. 공개 root catalog, Pages workflow, build script, site entry와 관련 문서 이력이 같은 브랜치에 들어왔다. | `git diff --check`와 cached check 통과. `bash scripts/build-docc-site.sh /tmp/piggyescape-public-base.doccarchive` 성공 및 tutorial JSON 존재 확인. iPhone 17 Pro iOS 26.5 Simulator 전체 XCTest 112/112·0 failures, `TEST SUCCEEDED`; result bundle은 `/tmp/piggyescape-task1-tests/Logs/Test/Test-PiggyEscape-2026.08.30_00-03-08-+0900.xcresult`. | Task 2 — 4개 챕터 상태 기계 RED 테스트 |
| 2026-08-29 | 4개 챕터 설계 승인·실행 계획·전체 기준선 | 승인된 설계를 상태 기계, readiness, 18cm/floor region, view-space 5점, cycle 수명, Chapter UI, DocC/Pages와 최종 검증의 13개 TDD 태스크로 분해했다. | 원격 fetch 뒤 iPhone 17 Pro iOS 26.5 Simulator에서 현재 HEAD 전체 XCTest 112/112·0 failures와 `TEST SUCCEEDED`를 확인했다. Debug/Release generic build는 통과, Swift 6 strict와 실기기는 알려진 대기 경계를 유지한다. | Task 1 — 공개 DocC 기준선 merge |
| 2026-08-29 | Chapter 1–4 앱·DocC 완성 설계 | 기존 한 흐름을 C3 닫힌 세계, Reality 준비, 0.18m 돼지의 5점 실제 숨기·이동 재발견, 비교·완료로 분리했다. Chapter 2–3 동일 AR session, replay 수명, 공개 DocC 단일 원본·접근성·증거·배포 게이트를 고정했다. | 앱 소스·상태·테스트 112개 정적 집계, public DocC 네 장 렌더링·desktop/mobile, DocC source·배포 pipeline, 일반/Swift 6 build 경계를 읽기 전용 감사했다. production code는 변경하지 않았다. | 사용자 설계 검토 뒤 실행 계획 작성 |
| 2026-08-19 | 실제 물체 뒤 숨기 검증 — 카메라 초기화·메쉬 가림 게이트 | iPhone 16 Pro에서 정규화된 돼지 anchor를 타깃 전부터 붙일 때 검은 카메라가 나던 경계를 분리해 session 시작과 anchor 부착 시점을 늦췄다. 이후 container만 화면에 붙은 `didMoveToWindow`가 세션을 시작할 수 있던 경계를 제거하고, 내부 ARView의 실제 layout 뒤에만 시작하게 고정했다. 돼지 도착 뒤 mesh hit가 돼지보다 3cm 이상 앞일 때만 숨김 완료를 알리고, 그렇지 않으면 18cm씩 최대 두 번 더 반대편으로 걷은 뒤 타깃 선택으로 복귀하게 했다. 진단 launch mode는 제거했다. | 새 session-start gate API RED compiler failure 뒤 focused coordinator XCTest 17/17·0 failures, iPhone 16 Pro signed build·install·launch 성공. 최신 설치에서 AR 카메라 배경 정상 표시를 관찰했다. 물체 뒤 걷기·mesh occlusion·재시도·재발견은 `실기기 대기`. | 세로 물체 탭→보이는 걷기→가림 뒤 안내 전환→실패 복귀를 관찰 |
| 2026-08-18 | C3 자동 진행 최종 보수 — 문서·예약 수명 | PROJECT_CONTEXT와 DocC를 현재 자동 흐름으로 정합화하고, 주입 가능한 scheduler로 실제 Coordinator callback 설치·나무 도착 지연·한 번 큐잉·dismantle 취소·팬 비진행을 wall-clock sleep 없이 검증함 | scheduler seam 부재 RED 뒤 focused C3 XCTest 12/12, 전체 XCTest 101/101·0 failures, iPhone 17 Pro Simulator build 성공. macOS arm64 destination에서 `CODE_SIGNING_ALLOWED=NO docbuild` 성공. 보수 범위 독립 재검토 승인. 경로·Simulator·signing 검증 한계와 해소는 L-20260818-091~092, 095~101 | LiDAR 지원 실기기에서 자동 진행·0.40초 체감·카메라 권한 전환과 기존 RealityKit 수용 목록 관찰 |
| 2026-08-18 | C3 자동 진행 — 나무 도착 뒤 발견 | 나레이션 뒤 탭한 돼지가 기존 나무에 도착하면 0.40초 뒤 카메라 yaw·프러스텀 조건 없이 한 번만 놀란 모델·자막·확대 반응을 실행하도록 변경함. 장면 coordinator가 약한 참조의 취소 가능한 예약을 소유하고 장면 해제 시 취소함 | API 부재 RED를 확인한 뒤 C3 focused XCTest 7/7, 전체 XCTest 97/97·0 failures, iPhone 17 Pro Simulator build 성공. 실제 나무 도착·0.40초 체감·카메라 권한 UI 전환은 `실기기 대기` | LiDAR 지원 실기기에서 자동 진행·권한 전환과 기존 RealityKit 수용 목록 관찰 |
| 2026-08-11 | Task 6 최종 monitor 보수 2차 — 최초 block pose·invalid 관찰 | 최초 실제 block pose를 cycle 기준으로 latch하고, 후속 block은 visible 안정성만 reset하도록 수정함. camera transform 부재·projection 실패·명시 invalid 관찰도 기준 pose를 보존하면서 안정 count만 초기화함 | RED focused 28개 중 3 assertion failures, latch만 적용한 중간 실행에서 invalid 2 failures만 남는 것을 확인한 뒤 focused 28/28, 전체 XCTest 99/99·0 failures, iPhone 17 Pro Simulator build 성공. worktree 루트의 프로젝트 경로 오류는 테스트 시작 전 중단됐으며, 올바른 디렉터리에서 전체 검증을 다시 성공시킴. L-20260811-085~087 | 독립 검토 후 LiDAR 지원 실기기에서 최초 block 기준 이동·시야 이탈 reset을 포함한 수용 목록 관찰 |
| 2026-08-11 | Task 6 최종 통합 리뷰 보수 — floor footprint·물리적 재발견·scan readiness | AR floor를 anchor 중심이 아닌 회전된 local footprint로 판정하고 선택 XZ를 floor Y에 투영함. actual camera position/forward 기반으로 0.15m 또는 15° 이동 뒤 두 frame 연속 visible일 때만 재발견하며, 첫 mesh/floor 관찰 뒤에만 스캔 준비를 알림 | 타입 부재 RED와 compiler type-check·Simulator 접근 실패를 학습 기록으로 남긴 뒤 focused 26/26, 전체 XCTest 97/97·0 failures, iPhone 17 Pro Simulator build 성공. L-20260811-080~084 | 독립 검토 후 LiDAR 지원 실기기에서 floor footprint·mesh occlusion·재발견 임계값을 관찰 |
| 2026-08-11 | Task 7 보수 2차 — 명시적 Settings 복귀 1회 조회 | 기존 `.cameraDenied`만으로 active마다 권한을 조회하던 회귀를 수정함. `설정 열기`의 명시적 탭에서만 1회 복귀 대기를 만들고, 다음 active가 이를 조회 전에 소비한다. Settings 미탭·소비 후 active는 무조회이며, 두 번째 탭은 새 1회 조회를 허용함 | focused RED 16개 중 3 failures 뒤 `EscapeRootCoordinatorTests` focused 16/16, 전체 XCTest 87/87·0 failures, iPhone 17 Pro Simulator build 성공. 원인·기존 잘못된 테스트 기대값·수정 근거는 L-20260811-079 | 보수 2차 독립 검토 후 L-20260811-076 RealityKit readiness 설계 및 실기기 수용 목록 관찰 |
| 2026-08-11 | Task 7 보수 — Settings 권한 복귀와 AR 외부 callback 수명 | Settings에서 카메라를 허용한 뒤 active로 돌아오면 현재 권한만 다시 읽어 한 번 AR 스캔으로 전환하고, 권한 미변경·제한·이미 AR 상태에서는 요청·Settings 재열기·중복 전환을 하지 않게 함. `UIViewRepresentable`에서 온 모든 AR callback은 다음 MainActor turn의 취소 가능한 relay로 보내고 화면 해제 뒤 stale callback을 버림 | type 부재 RED 뒤 `EscapeRootCoordinatorTests` focused 14/14, 전체 XCTest 85/85·0 failures, iPhone 17 Pro Simulator build 성공. 실패·해결·실제 mesh 준비 한계는 L-20260811-073~076 | 보수 독립 검토 후 L-20260811-076 RealityKit readiness 설계 및 실기기 수용 목록 관찰 |
| 2026-08-11 | Task 8 — 전체 회귀·실기기 검증과 DocC·인수인계 | 방·가짜 소파 중심 DocC를 C3 섬·나무 뒤 숨기·카메라 발견·권한 전환·실제 메쉬 오클루전·물리적 재발견의 다섯 장면으로 교체하고, `PROJECT_CONTEXT`·트러블슈팅·실기기 수용 목록을 추가함. 실기기 항목은 관찰하지 않아 모두 `실기기 대기`로 유지함 | `tuist generate --no-open` 성공, 명시적 전체 XCTest 79/79·0 failures, iPhone 17 Pro Simulator build 성공, DocC archive 생성·documentation build 성공. 연결 worktree fetch·Simulator 권한 재시도와 Chapter Image 경고 1건은 L-20260811-067~070 | LiDAR 지원 실기기 수용 목록 관찰 후 전체 독립 검토 |
| 2026-08-11 | Task 7 — 자동 SceneKit→RealityKit 전환과 C3 스타일 안내 | C3 발견 뒤 0.70초 페이드 완료 시점에만 시스템 카메라 권한을 한 번 요청하고, 허용 시 AR 화면을 자동으로 열어 Task 6의 스캔·선택·도착·재발견·오류 callback을 상태 기계에 연결함. 거부·제한 안내와 명시적 Settings 복구, C3 스타일 material 패널, AR 화면 1.12→1.0 확대와 Reduce Motion 대안을 추가하고 `ContentView`를 새 루트로 교체함 | 루트 전환 TDD RED 뒤 focused 8/8, 명시적 Xcode scheme 전체 XCTest 79/79, iOS Simulator build 성공. 실패·환경·접근성 학습은 L-20260811-058~066, 실제 기기 대기는 L-20260811-065 | Task 7 독립 검토 후 Task 8 |
| 2026-08-11 | Task 6 독립 리뷰 2차 수정 | running·idle·surprised 에셋 실패를 `Result`로 종결해 대기 또는 숨김 상태로 복구하고 Task 7용 `onError`·고정 한국어 메시지를 추가함. 고정 카메라 전방 시작점 대신 선택 면의 카메라 쪽 0.28m·정확한 바닥 Y에서 시작해 반대편 목적지로 걷도록 함 | 결함별 focused RED 뒤 coordinator 10/10, visual 3/3, 전체 XCTest 71/71 및 iOS Simulator build 성공. 원인·학습은 L-20260811-055~057 | Task 6 재검토 후 Task 7 |
| 2026-08-11 | Task 6 독립 리뷰 수정 | 화면 밖·카메라 뒤 관찰을 재발견 입력에서 제외하고, 놀란 모델 설치 뒤에만 확대·발견 콜백을 실행함. 타깃 수락과 돼지 도착 이벤트를 분리하고 도착 전 발견을 막았으며, 유효한 바닥 Y·카메라 전방 시작 위치가 생기기 전 돼지를 비활성화함 | 결함별 RED 확인 후 visual focused 3/3, coordinator focused 7/7, 전체 XCTest 68/68 및 iOS Simulator build 성공. 원인·학습은 L-20260811-050~054 | Task 6 재검토 후 Task 7 |
| 2026-08-10 | Task 6 — RealityKit 돼지 포즈와 실제 메쉬 뒤 숨기 | 실제 C3 돼지 3종의 비동기 포즈 교체·높이 정규화·걷기·1.5→1.0 놀람 확대를 안정 바깥 엔티티에 구현하고, LiDAR 지원 guard·수동 AR 세션·scene understanding 4종 옵션·실제 메쉬 세로 면 탭·분류된 바닥·숨기 이동·blocked→visible 1회 재발견을 ARView에 연결함. 카메라/렌즈 transform은 변경하지 않음 | RED에서 두 Task 6 타입 부재를 확인한 뒤 focused 5/5·전체 63/63 XCTest와 iOS Simulator build 성공. 환경·SDK 실패는 L-20260810-039~046, 실제 LiDAR 검증은 L-20260810-047 `실기기 대기` | Task 7 — 자동 SceneKit→RealityKit 전환과 C3 스타일 안내 |
| 2026-08-10 | Task 5 — 실제 물체 숨기 계획과 LiDAR 지원 판정 | 세로 면·카메라 거리·근접 바닥을 검증해 카메라 반대편의 정확한 바닥 Y 숨기 위치를 계산하는 순수 계획, 0.03m 허용오차의 1회 재발견 감시, ARKit 호출을 시스템 구현 하나에 한정한 LiDAR 지원 주입 경계와 안내 문자열을 추가함. ARView·RealityKit 렌더링·권한·UI 전환은 추가하지 않음 | RED에서 Reality 계획·지원 타입 부재를 확인한 뒤 focused 8/8·전체 58/58 XCTest 및 iOS Simulator build 성공. 기존 Simulator/AppIntents 경고와 실제 LiDAR·물리 오클루전 실기기 한계는 L-20260810-036~037에 기록 | Task 6 — RealityKit 돼지 포즈와 실제 메쉬 뒤 숨기 |
| 2026-08-10 | Task 4 — C3 SceneKit 나레이션·탭·가짜 숨기·카메라 발견 | `NarrationOverlayScene`의 C3 스타일 자막, 실제 `HideTree`가 필수인 나무 뒤 달리기, 0.70rad wrapped yaw·실제 `SCNView` 프러스텀·1회 가드 발견, `Piggy_surprised` 1.5→1.0 확대를 추가하고 C3 제스처 뷰를 앱 진입점에 연결함. 리뷰 보완으로 확대 action을 외부 콜백보다 먼저 등록하고, world callback의 Coordinator 캡처를 약하게 바꾸며 도착 전·frustum false·yaw 경계·1회 가드를 회귀 테스트로 확장함 | 리뷰 RED 2건 뒤 focused 12/12·전체 50/50 XCTest 및 iOS Simulator build 성공. 기존 런타임 경고와 수동 시각 확인 한계는 L-20260810-029~030, 리뷰 수정 근거는 L-20260810-031에 기록 | Task 5 — C3 발견 뒤 카메라 권한 전환 |
| 2026-08-10 | Task 3 — C3 섬·돼지 모델·궤도 카메라 어댑터 | `C3Island`의 7개 `Ground_Color` 타일과 C3 장식 배치, 실제 `HideTree`·`BigPigSpawn`, `EscapePig`의 idle/running/surprised 내부 USD 보정·정규화, C3 궤도 카메라·그라데이션·조명을 추가함 | RED에서 `C3ClosedWorld` 부재 컴파일 실패와 내부 USD 보정 소유 노드 오류를 확인한 뒤 focused 8/8·전체 38/38 XCTest 통과. Simulator/AppIntents 런타임 경고는 L-20260810-016에 기록 | Task 4 — C3 씬 뷰와 숨김 상호작용 |
| 2026-08-10 | Task 2 — 경험 상태와 숨기 좌표 순수 로직 | 상태 기계의 합법 전이와 XZ 카메라 반대편 나무 숨기 좌표를 프레임워크 독립 순수 Swift 타입으로 추가함 | RED에서 `EscapeExperienceMachine` 부재 컴파일 실패 확인 후 focused 3/3·전체 30/30 XCTest 통과. 기존 Simulator/AppIntents 경고는 L-20260810-007에 기록 | Task 3 — C3 섬 어댑터와 자동 전환 |
| 2026-08-10 | Task 1 — C3 에셋과 카메라 권한 | C3 원본 11개를 바이트 변경 없이 앱 리소스에 등록하고, 고정 카메라 목적 문구와 실제 앱 번들 로딩 회귀 테스트를 추가함 | RED에서 새 에셋 8개가 누락되어 16개 assertion 실패 확인 후, `AssetLoaderTests` 5/5 통과·11개 `cmp -s` 일치·생성 Info.plist 목적 문구 확인 | Task 2 — 경험 상태와 숨기 좌표 순수 로직 |
| 2026-08-10 | 실패·학습 기록 운영 | 실패한 테스트·빌드·실행·실기기 검증 한계를 재현 가능한 항목으로 남기는 별도 기록을 추가함 | 기록 형식·상태·필수 근거를 설계 문서와 대조 | Task 1 실행 |
| 2026-08-10 | Chapter 1 C3 월드→RealityKit 구현 계획 | C3 에셋·상태 기계·섬 어댑터·가짜 숨기·LiDAR 실제 숨기·자동 전환·DocC/실기기 검증을 8개 독립 태스크로 분해함 | 설계 명세·C3 원본 코드·현재 프로젝트/테스트 구조·Apple ARKit/RealityKit 공식 API 대조 | 실행 방식 선택 후 Task 1 |
| 2026-08-10 | Chapter 1 C3 월드·현실 숨기 재설계 | C3 SceneKit 월드에서 나무 뒤로 숨었다가 카메라 회전에 들키면 놀란 돼지 모델·자막·강한 확대 반응을 보이고, RealityKit의 실제 메쉬 뒤에서 다시 들킬 때는 같은 반응과 화면 확대를 보이는 흐름을 설계함. 금융·저장·Watch 범위는 제외 | 설계 문서 검토 대기 | 구현 계획 작성 |
| 2026-08-10 | Chapter 1 최종 검토 | 가짜 소파 바닥 정렬, 실제 노드 구조 탐구 실행, DocC 단계 완결성, 공통 인수인계 문서 통합의 보완 필요를 확인 | 전체 변경·문서·검증 근거 검토 | 보완 커밋과 재검토 |
| 2026-08-10 | Chapter 1 Task 8 | Chapter 1 DocC 튜토리얼 카탈로그와 현재 구현을 반영한 5개 코드 스니펫을 추가하고 앱 타깃에 등록함 | `tuist generate --no-open` 성공, `xcodebuild docbuild`가 `.doccarchive`를 생성하고 성공으로 완료 | Chapter 1 결과물 검토 또는 다음 챕터 설계 |
| 2026-08-10 | Chapter 1 Task 7 최종 재검토 | 구현·변환·카메라·인터랙션 회귀 검토를 마침. 생성물 제외 규칙과 테스트 추적 상태를 보완함 | 26/26 테스트 통과 결과와 변경 내용을 재검토 | Task 8 |
| 2026-08-10 | Chapter 1 Task 7 보정·재검증 | Blender 좌표계 보정으로 바닥·돼지를 방 바닥에 맞추고, 초기 프레임에 돼지를 표시. Task 7 탭 연결 테스트 추가 | `tuist generate --no-open`, `xcodebuild ... build` 성공, `xcodebuild ... test` 26/26 통과, Simulator 장면 확인 | Task 7 최종 재검토·커밋 후 Task 8 |
| 2026-08-10 | Chapter 1 Task 1~6 | Tuist 스캐폴드부터 HideAction까지 완료, 태스크마다 검토·필요 시 수정 라운드 거침 | 각 태스크 `xcodebuild test` 통과, 태스크별 검토 승인 | Task 7 |
| 2026-08-10 | Chapter 1 Task 7 (진행 중) | SwiftUI 화면 연결, 가짜 소파 스케일 버그와 `pointOfView` 누락 버그 발견·수정, 공용 지오메트리 헬퍼 분리 | `xcodebuild test` 23/23 통과. 위 3개 미해결 항목은 미검증 | 미해결 항목 처리 후 Task 7 완료, 이어서 Task 8 |

## 기록 형식

새 항목은 작업 이력 표의 첫 행에 추가한다. 각 항목에는 아래 정보만 기록한다.

- 날짜
- 작업 범위
- 결과
- 검증 근거
- 다음 시작점

기록에 사람·도구·모델 이름, 대화 내용, 비밀 정보는 넣지 않는다.
