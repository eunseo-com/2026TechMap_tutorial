# 작업 인수인계 기록

> 다음 작업을 시작하기 전에 **현재 인수인계**를 먼저 읽는다. 의미 있는 작업 단위가 끝나면 결과물과 같은 커밋에 이 문서를 갱신한다. 사용한 도구나 모델 이름은 쓰지 않는다.

## 현재 인수인계

- 상태: Task 3 — C3 섬·돼지 모델·궤도 카메라 어댑터 완료
- 진행 중 범위: C3의 비금융 섬 타일·장식·USD 돼지 포즈·궤도 카메라·조명을 SceneKit 어댑터로 추가했다. 숨김 상호작용·나레이션·현실 전환은 구현하지 않았다.
- 실패 기록: `docs/LEARNING_LOG.md`에 실패·검증 한계의 재현 조건·원인/가설·조치·재발 방지 근거를 기록한다.
- 마지막 완료 범위: Task 3 — C3 섬·돼지 모델·궤도 카메라 어댑터.
- 마지막 검증: `tuist generate --no-open` 성공. focused `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/C3IslandBuilderTests -only-testing:PiggyEscapeTests/C3PigModelFactoryTests -only-testing:PiggyEscapeTests/C3ClosedWorldTests test`가 8/8을 통과했고, 전체 `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`가 38/38을 통과했다. Simulator/AppIntents 런타임 경고는 `docs/LEARNING_LOG.md`의 L-20260810-016에 기록했다.
- 다음 시작점: `docs/superpowers/plans/2026-08-10-ch1-reality-escape-implementation.md`의 Task 4 — C3 씬 뷰와 숨김 상호작용.
- 차단 요소: 원격 `git fetch`의 공용 Git 메타데이터 쓰기 권한과 시작 순서의 누락 문서는 `docs/LEARNING_LOG.md`에 보류 항목으로 기록했다.

### Task 7에서 해결한 항목

1. **RoomBuilder 바닥 방향** — `Ground_Color`을 X축으로 -90° 회전하고, 변환된 경계를 재서 4×4×0.1m에 맞춘 뒤 바닥면을 y=0에 정렬했다. 회전 전 원본 경계로 스케일하는 실수를 회귀 테스트로 막는다.
2. **돼지 좌표계·바닥 정렬** — `Piggy`도 Blender Z-up 모델이므로 내부 모델에서 Y-up 회전·균일 스케일·바닥 정렬을 수행하고, 바깥 노드는 위치와 액션만 맡게 분리했다.
3. **초기 프레이밍** — 카메라와 너무 가까워 화면 밖으로 밀리던 돼지의 임의 하드코딩 z 좌표를 1에서 0으로 조정했다. 카메라 설정과 `allowsCameraControl`은 계획값을 유지한다.

## 작업 이력

| 날짜 | 작업 범위 | 결과 | 검증 | 다음 시작점 |
| --- | --- | --- | --- | --- |
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
