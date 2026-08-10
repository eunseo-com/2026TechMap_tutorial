# 작업 인수인계 기록

> 다음 작업을 시작하기 전에 **현재 인수인계**를 먼저 읽는다. 의미 있는 작업 단위가 끝나면 결과물과 같은 커밋에 이 문서를 갱신한다. 사용한 도구나 모델 이름은 쓰지 않는다.

## 현재 인수인계

- 상태: Task 7 보수 2차 — 명시적 Settings 복귀 1회 조회 구현 완료, 독립 검토 대기
- 진행 중 범위: 앱 진입점은 `EscapeRootView` 하나다. C3 발견 callback은 놀란 상태를 기록하고 0.70초 페이드가 끝난 뒤에만 카메라 권한을 한 번 요청한다. 허용 시 `RealityHideARView`를 자동으로 열고 스캔 준비·타깃 수락·돼지 도착·재발견·오류 callback을 상태 순서로 연결한다. 사용자가 `설정 열기`를 탭해 Settings 복귀 대기를 남긴 경우에만 다음 active가 현재 권한을 한 번 읽고, 허용이면 요청·Settings 재열기 없이 한 번 AR 스캔으로 전환한다. Settings를 열지 않은 active와 대기 소비 뒤의 active는 거부·제한 상태에서도 조회하지 않으며, 두 번째 명시적 Settings 탭은 새 1회 조회를 허용한다. AR 외부 callback은 다음 MainActor turn의 취소 가능한 relay를 거쳐 SwiftUI 생성·갱신 중 루트 상태를 바꾸지 않으며, AR 화면 해제 뒤 예약된 callback은 폐기한다. 현실 재발견에는 `ARView` 컨테이너 1.12→1.0 확대가 추가됐고 실제 AR camera transform은 변경하지 않으며 Reduce Motion에서는 화면 확대를 생략한다. DocC는 같은 흐름을 C3 섬·카메라 발견·권한 전환·실제 메쉬·물리적 재발견의 다섯 장면으로 설명한다.
- 실패 기록: `docs/LEARNING_LOG.md`에 실패·검증 한계의 재현 조건·원인/가설·조치·재발 방지 근거를 기록한다.
- 마지막 완료 범위: Task 7 보수 2차 — 명시적 Settings 복귀 1회 조회.
- 마지막 검증: `xcodebuild -project PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/piggyescape-task7-repair2-green -only-testing:PiggyEscapeTests/EscapeRootCoordinatorTests test`가 16/16, 0 failures 및 `** TEST SUCCEEDED **`; 이어 `/tmp/piggyescape-task7-repair2-tests test`가 전체 87/87, 0 failures 및 `** TEST SUCCEEDED **`; 같은 destination의 `/tmp/piggyescape-task7-repair2-build build`가 `** BUILD SUCCEEDED **`로 완료됐다.
- 다음 시작점: 이 보수를 독립 검토한 뒤 LiDAR 지원 실기기에서 아래 수용 목록을 관찰해 결과·기기·OS를 기록한다. AR 세션 시작과 실제 공간 재구성 준비를 구분하는 L-20260811-076은 별도 RealityKit 보수 태스크로 설계한다.
- 차단 요소: 실제 카메라 권한 UI·0.70초 전환·Settings 복귀·1.12 화면 확대·LiDAR 메쉬·물리 오클루전은 관찰 전까지 `실기기 대기`다. `onScanningReady`는 세션 시작만 뜻하며 실제 mesh/frame 준비 기준은 L-20260811-076으로 보류한다. DocC는 새 이미지 에셋을 추가하지 않는 제약 때문에 Chapter Image 경고 1건을 남긴다.

### 실기기 수용 목록 — 실기기 대기

- [ ] C3 섬·기존 나무·초기 나레이션이 보인다.
- [ ] 초기 나레이션이 끝나기 전 돼지 탭은 무시된다.
- [ ] 탭 뒤 걷는 돼지가 현재 카메라 반대편 나무 뒤로 이동한다.
- [ ] 카메라를 0.70 rad 이상 돌려 돼지가 보일 때 놀란 모델·자막·1.5배 확대 후 복귀가 한 번 실행된다.
- [ ] 페이드 뒤 시스템 카메라 권한 문구가 보이고, 허용 뒤 AR 스캔 안내가 열린다.
- [ ] 권한 거부·제한과 Settings 복구를 각각 관찰한다.
- [ ] 실제 물체의 수직 옆면을 탭하면 돼지가 반대편 바닥으로 걸어간다.
- [ ] 초기 시점에서 실제 물체의 LiDAR 메쉬가 돼지를 가린다.
- [ ] 사용자가 옆으로 이동해 다시 볼 때 놀란 모델·자막·1.5배 돼지 확대·1.12배 화면 확대가 한 번 실행되고 복귀한다.
- [ ] LiDAR 미지원, 수평면 탭, 너무 가까운 탭, 바닥 추적 부족, 돼지 에셋 로드 실패 안내와 재시도 경로를 관찰한다.

### Task 7에서 해결한 항목

1. **RoomBuilder 바닥 방향** — `Ground_Color`을 X축으로 -90° 회전하고, 변환된 경계를 재서 4×4×0.1m에 맞춘 뒤 바닥면을 y=0에 정렬했다. 회전 전 원본 경계로 스케일하는 실수를 회귀 테스트로 막는다.
2. **돼지 좌표계·바닥 정렬** — `Piggy`도 Blender Z-up 모델이므로 내부 모델에서 Y-up 회전·균일 스케일·바닥 정렬을 수행하고, 바깥 노드는 위치와 액션만 맡게 분리했다.
3. **초기 프레이밍** — 카메라와 너무 가까워 화면 밖으로 밀리던 돼지의 임의 하드코딩 z 좌표를 1에서 0으로 조정했다. 카메라 설정과 `allowsCameraControl`은 계획값을 유지한다.

## 작업 이력

| 날짜 | 작업 범위 | 결과 | 검증 | 다음 시작점 |
| --- | --- | --- | --- | --- |
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
