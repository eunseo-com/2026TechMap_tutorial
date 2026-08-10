# 실패와 학습 기록

> 구현 중 발생한 실패·예상 밖 동작·검증 한계는 해결 여부와 관계없이 이 문서에 남긴다. 같은 증상을 다시 만났을 때 대화 기록이 아니라 재현 가능한 근거부터 확인하기 위한 기록이다. 사람·도구·모델 이름과 비밀 정보는 쓰지 않는다.

## 기록 규칙

- 실패한 테스트, 빌드, 실행, API/에셋 실험, 실기기 검증은 원인 확인 또는 중단 결정 전에 한 항목으로 기록한다.
- 항목에는 실패를 재현한 명령 또는 사용자 동작, 실제 관찰값, 영향 범위, 확인한 원인 또는 가설, 해결/보류 결정, 재발 방지 검증을 적는다.
- 가설은 가설로 표시한다. 확인하지 않은 내용을 원인으로 단정하지 않는다.
- 해결된 항목도 삭제하지 않는다. 후속 변경으로 재발하면 기존 항목 번호를 참조해 새 항목을 추가한다.
- 사용자 기기·권한·LiDAR처럼 이 환경에서 실행할 수 없는 검증은 `실기기 대기`로 기록하며 자동 테스트 성공으로 대체하지 않는다.

## 항목 형식

```markdown
### L-YYYYMMDD-순번 — 짧은 증상 제목

- 상태: 조사 중 | 해결 | 보류 | 실기기 대기
- 발생 태스크: Task N — 이름
- 재현: 실행한 명령 또는 사용자 동작
- 관찰: 실제 오류·출력·화면 결과
- 영향: 사용자 경험·빌드·테스트·문서 중 영향 범위
- 원인/가설: 확인 근거와 함께 작성
- 조치: 적용한 수정 또는 보류 이유
- 검증: 수정 후 실행한 명령·결과, 또는 남은 수동 검증
- 배운 점: 다음 작업에서 먼저 확인할 조건
```

## 항목

### L-20260810-019 — Task 4 시작 순서의 프로젝트 맥락 문서가 작업 트리에 없음

- 상태: 보류
- 발생 태스크: Task 4 — SceneKit 나레이션·탭·가짜 숨기·카메라 발견
- 재현: `sed -n '1,260p' docs/PROJECT_CONTEXT.md`
- 관찰: `sed: docs/PROJECT_CONTEXT.md: No such file or directory`로 지정 문서를 읽지 못했고, 이어지는 시작 순서 명령은 실행되지 않았음
- 영향: 시작 순서의 프로젝트 맥락 문서를 현재 브랜치에서 직접 검토할 수 없음
- 원인/가설: L-20260810-010 및 L-20260810-004와 같이 이 연결 작업 트리에 해당 문서가 포함되지 않은 상태임
- 조치: 존재하는 `docs/WORK_LOG.md`, Reality escape 설계·구현 계획, Task 4 브리프를 대체 근거로 사용하며 범위를 넓히지 않음
- 검증: `rg --files -g 'PROJECT_CONTEXT.md' -g 'WORK_LOG.md' -g '*task-4*'`에서 `PROJECT_CONTEXT.md` 부재와 대체 문서 존재를 확인함
- 배운 점: 시작 필수 문서의 경로 부재는 명령이 중단된 태스크마다 재현·대체 근거를 남기고, 없는 문서를 추정하지 않는다.

### L-20260810-020 — Task 4 시작 전 원격 fetch가 연결 작업 트리 메타데이터 권한으로 중단됨

- 상태: 해결
- 발생 태스크: Task 4 — SceneKit 나레이션·탭·가짜 숨기·카메라 발견
- 재현: `git fetch --prune origin`
- 관찰: `error: cannot open '/Users/yang-eunseo/Downloads/SpatialComputing_TechMap/.git/worktrees/ch1-reality-escape/FETCH_HEAD': Operation not permitted`로 원격 참조 갱신 전에 종료됨
- 영향: 구현 전 원격 변경 동기화 상태를 현재 권한 범위에서 확정할 수 없음
- 원인/가설: L-20260810-009와 같은 연결 작업 트리 공용 Git 메타데이터 `FETCH_HEAD` 쓰기 경로 권한 제약으로 보임
- 조치: 공용 Git 메타데이터에 접근 가능한 권한으로 같은 명령을 한 번 재실행해 원격 상태를 확인함
- 검증: 권한 재실행 `git fetch --prune origin && git status --short`가 성공했고, Task 4 시작 시점의 추적 변경은 기록 문서와 사용자 소유 `.claude/`뿐임을 확인함
- 배운 점: 시작 순서의 fetch가 권한으로 중단되면 재시도 전에 실패를 기록하고, 성공 여부를 추정하지 않는다.

### L-20260810-021 — Task 4 RED 준비 중 Tuist 세션 상태 디렉터리 쓰기가 거부됨

- 상태: 해결
- 발생 태스크: Task 4 — SceneKit 나레이션·탭·가짜 숨기·카메라 발견
- 재현: `tuist generate --no-open`
- 관찰: `Fatal error: Error raised at top level: Permission denied: /Users/yang-eunseo/.local/state/tuist/sessions/14A284BC-B6AD-49F5-A6B3-B8BD8A84183D`로 생성이 XCTest 실행 전에 종료됨
- 영향: 새 Task 4 XCTest가 생성 프로젝트에 반영되지 않아 API 부재 RED를 아직 확인하지 못함
- 원인/가설: Tuist가 연결 작업 트리 밖의 사용자 세션 상태 경로에 쓰기를 시도하지만 현재 파일 권한 범위에 포함되지 않음
- 조치: 해당 상태 경로에 접근 가능한 권한으로 같은 생성 명령을 재실행한 뒤, 새 Task 4 focused XCTest를 실행함
- 검증: 권한 재실행 `tuist generate --no-open`가 `✔ Success`로 완료되어 새 Task 4 XCTest와 소스가 생성 프로젝트에 반영됨
- 배운 점: Tuist의 새 테스트 반영은 생성물 경로뿐 아니라 사용자 세션 상태 쓰기 권한을 먼저 충족해야 한다.

### L-20260810-022 — Task 4 RED XCTest가 Simulator 서비스 접근 제한으로 중단됨

- 상태: 해결
- 발생 태스크: Task 4 — SceneKit 나레이션·탭·가짜 숨기·카메라 발견
- 재현: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/ClosedWorldEscapeTests -only-testing:PiggyEscapeTests/NarrationOverlaySceneTests test`
- 관찰: `CoreSimulatorService connection became invalid`와 `Error opening log file ... Operation not permitted`가 발생해 새 API 부재 컴파일 단계 전에 XCTest가 종료됨
- 영향: Task 4의 의도적인 RED가 환경 제약 때문에 아직 관찰되지 않음
- 원인/가설: Simulator 기기·로그·DerivedData 상태 경로가 현재 파일 권한 범위 밖에 있음
- 조치: Simulator 서비스와 Xcode 상태 경로에 접근 가능한 권한으로 같은 focused XCTest를 재실행해, 새 API 부재 RED를 확인함
- 검증: 권한 재실행에서 `C3ClosedWorld`의 `tapPig`, 내레이션·발견·놀람 API와 검사 상태 부재로 테스트 타깃 컴파일이 실패했으며, 상세는 L-20260810-023에 기록함
- 배운 점: Simulator 기반 RED는 API 부재와 환경 권한 실패를 분리해야 테스트 의도를 보존할 수 있다.

### L-20260810-023 — Task 4 RED XCTest가 새 가짜 숨기·발견 API 부재로 컴파일 실패함

- 상태: 해결
- 발생 태스크: Task 4 — SceneKit 나레이션·탭·가짜 숨기·카메라 발견
- 재현: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/ClosedWorldEscapeTests -only-testing:PiggyEscapeTests/NarrationOverlaySceneTests test`
- 관찰: `C3ClosedWorld`에서 `tapPig`, `completeOpeningNarration`, `finishTreeHideForTesting`, `isDiscoveredAfterCameraRotation`, `performSurpriseReaction` 및 검사 상태 `currentPose`, `lastCaption`, `surprisePeakScale`를 찾지 못해 테스트 타깃 컴파일이 중단됨
- 영향: 나레이션 게이트·나무 도착 뒤 카메라 발견·놀람 연출의 요구 계약이 아직 앱에 없음
- 원인/가설: Task 3 어댑터는 섬·돼지·카메라까지만 소유하며 Task 4의 상호작용 API와 SpriteKit 오버레이를 아직 구현하지 않았음
- 조치: 실제 씬의 `HideTree`를 필수로 요구하는 C3 월드 상태/액션과 C3 스타일 `NarrationOverlayScene`, 제스처 어댑터를 구현할 예정임
- 검증: 구현 뒤 같은 focused XCTest에서 새 API의 컴파일 및 행위 assertion을 확인하고, 전체 XCTest와 앱 빌드를 실행할 예정임
- 배운 점: SceneKit 타이밍은 XCTest에 직접 의존시키지 않고, 상태·도착 테스트 훅·발견 판정을 결정론적 API로 노출해야 한다.

### L-20260810-024 — Task 4 구현 패치가 기존 ContentView의 정확한 형식 불일치로 적용되지 않음

- 상태: 해결
- 발생 태스크: Task 4 — SceneKit 나레이션·탭·가짜 숨기·카메라 발견
- 재현: Task 4 소스·`ContentView.swift`를 함께 갱신하는 `apply_patch`
- 관찰: `ContentView`의 기존 `ClosedWorldSceneView()` 호출에 이미 `.ignoresSafeArea()` 체인이 있어, 예상한 한 줄 본문과 일치하지 않아 `apply_patch verification failed`로 전체 패치가 적용되지 않음
- 영향: 새 C3 나레이션·상호작용 소스는 쓰이지 않았고, RED 상태가 유지됨
- 원인/가설: 패치의 문맥이 기존 SwiftUI 체인을 완전하게 반영하지 못함
- 조치: 실제 `ContentView.swift`의 네 줄 본문을 확인했고, 정확한 체인을 기준으로 소스 패치를 다시 적용할 예정임
- 검증: 실패 직후 `test -e .../NarrationOverlayScene.swift`가 `1`을 반환하고 `git diff -- C3ClosedWorld.swift`가 비어 있어 생산 코드가 부분 적용되지 않았음을 확인함
- 배운 점: 여러 파일을 한 번에 바꿀 때는 SwiftUI modifier 체인까지 정확한 문맥으로 지정하고, 실패 뒤 부분 적용 여부를 확인한다.

### L-20260810-025 — Task 4 GREEN XCTest가 SceneKit 프러스텀 API 수신자 오류로 컴파일 실패함

- 상태: 해결
- 발생 태스크: Task 4 — SceneKit 나레이션·탭·가짜 숨기·카메라 발견
- 재현: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/ClosedWorldEscapeTests -only-testing:PiggyEscapeTests/NarrationOverlaySceneTests test`
- 관찰: `C3ClosedWorld.swift:78:28: error: value of type 'SCNNode' has no member 'isInsideFrustum'`로 앱 타깃 컴파일이 중단됨
- 영향: 나무 도착 뒤 프러스텀·yaw·한 번만 발견하는 GREEN 동작을 테스트할 수 없음
- 원인/가설: SceneKit의 프러스텀 판정은 돼지 노드가 아니라 카메라 노드에 호출해 검사 대상 노드를 전달하는 API로 선언된 것으로 보임
- 조치: 로컬 SceneKit Swift interface에서 메서드 선언을 확인한 뒤, 카메라 노드 수신자로 정확히 교체할 예정임
- 검증: 수정 후 같은 focused XCTest에서 컴파일·발견 assertion을 다시 확인할 예정임
- 배운 점: 요구 문장의 개념상 주어와 Swift API의 실제 메서드 수신자는 다를 수 있으므로, SceneKit 선언을 먼저 대조한다.

### L-20260810-026 — Task 4 GREEN XCTest가 탭 조상 순회의 optional shadowing 오류로 컴파일 실패함

- 상태: 해결
- 발생 태스크: Task 4 — SceneKit 나레이션·탭·가짜 숨기·카메라 발견
- 재현: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/ClosedWorldEscapeTests -only-testing:PiggyEscapeTests/NarrationOverlaySceneTests test`
- 관찰: `C3ClosedWorldSceneView.swift:110`에서 `current`가 `while let`로 shadow된 상수라 `current = current.parent`를 할 수 없고, optional `parent`도 대입되지 않아 앱 타깃 컴파일이 중단됨
- 영향: 실제 `EscapePig` 자손만 탭을 허용하는 제스처 경로를 포함한 focused XCTest가 실행되지 않음
- 원인/가설: optional 순회 변수와 unwrap 상수에 같은 식별자를 사용했음
- 조치: 순회 optional은 `current`, unwrap 상수는 `candidate`로 분리해 부모를 안전하게 대입할 예정임
- 검증: 수정 후 같은 focused XCTest에서 탭 게이트·나레이션·발견 assertion을 실행할 예정임
- 배운 점: SceneKit의 부모 체인을 순회할 때 optional 저장 변수와 현재 노드 상수의 이름을 분리하면 Swift shadowing 오류를 피할 수 있다.

### L-20260810-027 — Task 4 GREEN XCTest에서 프러스텀 판정이 발견을 막음

- 상태: 해결
- 발생 태스크: Task 4 — SceneKit 나레이션·탭·가짜 숨기·카메라 발견
- 재현: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/ClosedWorldEscapeTests -only-testing:PiggyEscapeTests/NarrationOverlaySceneTests test`
- 관찰: 6개 focused XCTest 중 나레이션·탭·실제 `HideTree`·놀람·오버레이 5개는 통과했으나, `test_cameraDiscoveryNeedsYawChangeAndVisiblePig`에서 π/2 yaw 뒤 `isDiscoveredAfterCameraRotation()`이 `false`이고 포즈가 `idle`로 남아 2개 assertion이 실패함
- 영향: 돼지가 나무에 도착한 뒤 충분한 카메라 회전으로 발견되는 Task 4 핵심 흐름을 자동 검증하지 못함
- 원인/가설: renderer 없는 테스트용 직교 프러스텀 기하 판정에서 카메라 방향/좌표 변환 또는 허용 범위가 실제 SceneKit 렌더러와 다르게 계산된 것으로 보임. 실제 `SCNView.isNode(_:insideFrustumOf:)`는 화면이 연결될 때 별도 사용함
- 조치: 카메라 공간 돼지 좌표와 constraint 평가를 측정했고, renderer가 실제 프러스텀 결과를 주입하도록 단일 경계를 바꿈
- 검증: 후속 focused 6/6, 전체 44/44 XCTest, iOS Simulator build 성공. renderer 없는 문제의 진단·해결 근거는 L-20260810-028에 남김
- 배운 점: renderer 안전 단위 테스트의 프러스텀 대체 판정은 실제 화면 경로와 분리하되, 같은 카메라 변환·투영 경계를 수치로 검증해야 한다.

### L-20260810-028 — renderer 없는 프러스텀 진단이 카메라 LookAt 제약의 미평가를 확인함

- 상태: 해결
- 발생 태스크: Task 4 — SceneKit 나레이션·탭·가짜 숨기·카메라 발견
- 재현: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/ClosedWorldEscapeTests/test_cameraDiscoveryNeedsYawChangeAndVisiblePig test`
- 관찰: π/2 회전 뒤 카메라는 `(12.020815, 12.0, -12.020815)`, 돼지는 `(-4.2649684, 0.63528, -1.5202962)`였지만 `cameraEuler`는 `(0, 0, 0)`이었다. 단일 테스트는 같은 발견 assertion 2개로 계속 실패함
- 영향: SceneKit renderer 없이 `SCNLookAtConstraint` 결과를 전제로 한 카메라 공간 변환은 신뢰할 수 없음
- 원인/가설: `SCNLookAtConstraint`는 renderer/프레임 평가 중 적용되므로 XCTest의 독립 노드 그래프에서 카메라 방향이 갱신되지 않았음. 실제 화면에서는 `SCNView.isNode(_:insideFrustumOf:)`가 renderer의 프러스텀을 판정할 수 있음
- 조치: 월드의 발견 판정은 프러스텀 결과를 주입받아 fail-closed로 처리하고, C3 SceneKit view가 실제 `SCNView.isNode(_:insideFrustumOf:)` 결과를 제공하게 함. 단위 테스트는 명시적으로 보이는 상태를 주입해 yaw·도착·한 번만 조건을 결정론적으로 검증함
- 검증: 진단 `print`를 제거하고, 주입된 visible/actual SCNView 경로를 포함해 focused XCTest를 다시 실행할 예정임
- 배운 점: 렌더러가 소유하는 constraint·frustum 결과는 순수 상태 테스트에서 재계산하지 말고, 실제 어댑터에서 측정해 주입한다.

### L-20260810-029 — Task 4 전체 XCTest는 통과했지만 기존 Simulator 런타임 경고가 출력됨

- 상태: 보류
- 발생 태스크: Task 4 — SceneKit 나레이션·탭·가짜 숨기·카메라 발견
- 재현: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`
- 관찰: 44개 XCTest와 `** TEST SUCCEEDED **`는 확인했지만, `Metadata extraction skipped. No AppIntents.framework dependency found`, `TBB Global TLS count is not == 1`, `UIFocus` 캐시 제한, `UIAccessibilityLoaderWebShared` 중복 구현 경고가 함께 출력됨
- 영향: Task 4의 C3 숨기·발견 회귀 assertion은 실패하지 않았지만 XCTest 출력이 경고 없이 깨끗하다는 조건은 충족하지 못함
- 원인/가설: AppIntents 의존성이 없는 앱 타깃과 iOS Simulator 26.5의 기존 런타임 진단으로, Task 4 소스의 컴파일 또는 XCTest assertion 실패는 없음
- 조치: Task 4 범위 밖의 기존 앱 타깃·Simulator 런타임을 변경하지 않고, 경고를 보류한 채 focused·전체 XCTest의 통과 결과를 유지함
- 검증: focused `ClosedWorldEscapeTests`/`NarrationOverlaySceneTests` 6/6과 전체 XCTest 44/44가 통과했으며, 새 C3 프러스텀 경로는 `SCNView.isNode(_:insideFrustumOf:)`로 연결됨
- 배운 점: SceneKit 상호작용 회귀와 Simulator/AppIntents 런타임 경고를 분리해 기록하고, 태스크 범위 밖 경고를 해결하려고 앱 구조를 바꾸지 않는다.

### L-20260810-030 — Task 4의 실제 손가락 제스처·프러스텀 시각 확인은 자동 빌드로 대체할 수 없음

- 상태: 보류
- 발생 태스크: Task 4 — SceneKit 나레이션·탭·가짜 숨기·카메라 발견
- 재현: iPhone 17 Pro Simulator에서 C3 섬을 표시한 뒤, 나레이션 종료 후 돼지 모델 자손을 탭하고 화면 폭의 약 1/2를 팬해 발견 자막·확대를 관찰하는 수동 절차
- 관찰: 이 작업에서는 focused 6/6, 전체 44/44 XCTest와 iOS Simulator `xcodebuild build` 성공을 확인했지만, 터치 좌표의 실제 hitTest·렌더러 프러스텀·SpriteKit 프레임 완료를 수동 조작으로 촬영하지는 않았음
- 영향: 자동 검증은 상태·액션 키·카피·실제 `SCNView.isNode(_:insideFrustumOf:)` 연결을 증명하지만, 실제 화면에서 돼지가 나무 뒤에 가려졌다가 팬으로 보이는 연출의 시각 품질은 확정하지 못함
- 원인/가설: SceneKit constraint·renderer 프러스텀·SpriteKit 액션은 테스트용 독립 노드 그래프와 달리 표시 중인 `SCNView` 프레임에서 평가됨
- 조치: Task 4 범위의 자동 검증을 완료 근거로 유지하고, 후속 검토 또는 수동 Simulator 세션에서 위 절차를 별도로 확인함. RealityKit·권한 전환은 시작하지 않음
- 검증: `C3ClosedWorldSceneView`는 실제 뷰의 `isNode(_:insideFrustumOf:)` 결과를 발견 조건에 주입하고, renderer 없는 XCTest는 visible 결과를 명시 주입해 yaw·도착·한 번만 조건을 44개 전체 회귀 안에서 검증함
- 배운 점: 렌더러 의존 연출은 결정론적 상태 단위 테스트와 실제 화면 수동 확인을 모두 필요로 하며, 전자를 후자로 오인하지 않는다.

### L-20260810-018 — Task 3 커밋 준비가 연결 작업 트리 index 잠금 권한으로 중단됨

- 상태: 해결
- 발생 태스크: Task 3 — C3 섬, 돼지 모델, 궤도 카메라 어댑터
- 재현: `git add PiggyEscape/PiggyEscape/Sources/C3World PiggyEscape/PiggyEscapeTests/C3IslandBuilderTests.swift PiggyEscape/PiggyEscapeTests/C3PigModelFactoryTests.swift PiggyEscape/PiggyEscapeTests/C3ClosedWorldTests.swift docs/WORK_LOG.md docs/LEARNING_LOG.md`
- 관찰: `fatal: Unable to create '/Users/yang-eunseo/Downloads/SpatialComputing_TechMap/.git/worktrees/ch1-reality-escape/index.lock': Operation not permitted`로 index 갱신 전에 중단됨
- 영향: 검증된 Task 3 변경을 태스크 단위 커밋으로 기록하지 못함
- 원인/가설: 연결 작업 트리의 공용 Git 메타데이터 index 잠금 경로가 현재 권한 범위 밖에 있음
- 조치: 공용 Git 메타데이터에 쓸 수 있는 권한으로 같은 명시적 Task 3 파일 목록만 stage와 commit할 예정임
- 검증: 공용 Git 메타데이터 접근 권한으로 같은 명시적 파일 목록을 stage했고, 커밋 후 `git show --stat --oneline HEAD`와 `git status --short`로 Task 3 파일만 포함됐는지 확인함
- 배운 점: 연결 작업 트리에서는 작업 트리 파일 쓰기 권한과 별도로 공용 Git index 잠금 경로 쓰기 권한이 필요하다.

### L-20260810-017 — 내부 돼지 모델이 아니라 그 하위 아트 노드가 USD 축 보정을 소유함

- 상태: 해결
- 발생 태스크: Task 3 — C3 섬, 돼지 모델, 궤도 카메라 어댑터
- 재현: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/C3PigModelFactoryTests/test_innerModelOwnsUsdAxisCorrectionAndFloorNormalization test`
- 관찰: 새 실제 SceneKit 노드 테스트에서 `PigModel_idle.eulerAngles.x`와 `.z`가 각각 `0.0`으로 관찰되어 기대한 `Float.pi / 2`, `Float.pi`와 일치하지 않았고 2개 assertion이 실패함
- 영향: 외부 `EscapePig`와 이름 있는 내부 `PigModel_*`의 변환 책임 경계가 명세보다 한 단계 더 깊게 분산됨
- 원인/가설: `loadNormalizedModel`이 `PigModel_*`의 하위 `art` 노드에 축 보정을 적용하고, 내부 모델 컨테이너에는 정규화만 적용했음
- 조치: `PigModel_*` 자체가 축 보정·균일 스케일·바닥 정렬을 모두 소유하도록 측정용 임시 루트에서 변환 반영 경계를 계산할 예정임
- 검증: `PigModel_*`을 측정용 임시 루트에서 회전·스케일·바닥 정렬하도록 수정한 뒤 같은 단일 XCTest를 재실행해 1/1 통과와 `** TEST SUCCEEDED **`를 확인함. 이어서 focused·전체 suite를 다시 실행함.
- 배운 점: 외부 애니메이션·확대 대상과 내부 USD 변환 대상의 경계는 이름 있는 노드의 실제 `eulerAngles`와 변환된 바운딩 박스로 회귀 테스트한다.

### L-20260810-016 — Task 3 전체 XCTest는 통과했지만 기존 Simulator 런타임 경고가 출력됨

- 상태: 보류
- 발생 태스크: Task 3 — C3 섬, 돼지 모델, 궤도 카메라 어댑터
- 재현: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`
- 관찰: 최종 38개 XCTest는 모두 통과했지만 `Metadata extraction skipped. No AppIntents.framework dependency found`, `UIFocus` 캐시 제한, `TBB Global TLS count is not == 1`, Simulator 런타임의 `UIAccessibilityLoaderWebShared` 중복 구현 경고가 출력됨
- 영향: Task 3의 C3 노드·카메라 자동 검증에는 실패가 없지만 XCTest 출력이 경고 없이 깨끗하다는 조건은 충족하지 못함
- 원인/가설: AppIntents 의존성이 없는 기존 앱 타깃의 메타데이터 처리와 iOS Simulator 26.5의 UI·접근성 런타임 진단이며, 새 C3 소스의 컴파일·XCTest assertion 실패는 없음
- 조치: Task 3 범위 밖의 앱 타깃과 Simulator 런타임 설정을 변경하지 않고, focused 및 전체 XCTest 통과를 기록함
- 검증: 최종 focused C3 XCTest 8/8, 전체 XCTest 38/38 통과와 `** TEST SUCCEEDED **`를 확인함
- 배운 점: SceneKit 단위 테스트의 통과 결과와 기존 Simulator 런타임 경고를 분리해 기록하고, 범위 밖 경고를 해결하려고 기존 앱 구조를 변경하지 않는다.

### L-20260810-015 — Task 3 XCTest가 앱 모듈 import 누락으로 C3 월드 타입을 찾지 못함

- 상태: 해결
- 발생 태스크: Task 3 — C3 섬, 돼지 모델, 궤도 카메라 어댑터
- 재현: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/C3IslandBuilderTests -only-testing:PiggyEscapeTests/C3PigModelFactoryTests -only-testing:PiggyEscapeTests/C3ClosedWorldTests test`
- 관찰: 앱 타깃의 C3 소스 컴파일 후 `C3ClosedWorldTests.swift`에서 `cannot find 'C3ClosedWorld' in scope` 3건으로 테스트 타깃 컴파일이 중단됨
- 영향: 실제 SceneKit C3 월드 동작 assertion을 실행하지 못함
- 원인/가설: 새 테스트 세 파일에 기존 XCTest 파일의 `@testable import PiggyEscape`가 누락되어 앱 타깃 심볼이 테스트 모듈에 노출되지 않음
- 조치: 세 C3 XCTest 파일에 `@testable import PiggyEscape`를 추가할 예정임
- 검증: 세 C3 XCTest 파일에 `@testable import PiggyEscape`를 추가한 뒤 같은 focused XCTest를 재실행해 7개 테스트가 모두 통과하고 `** TEST SUCCEEDED **`를 확인함.
- 배운 점: 별도 XCTest 타깃의 새 테스트는 기존 테스트 파일의 모듈 import 계약을 먼저 따르고, 타입 부재 RED와 import 누락을 구분한다.

### L-20260810-014 — Task 3 재시도 XCTest가 초기화 순서와 π 타입 추론 오류로 중단됨

- 상태: 해결
- 발생 태스크: Task 3 — C3 섬, 돼지 모델, 궤도 카메라 어댑터
- 재현: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/C3IslandBuilderTests -only-testing:PiggyEscapeTests/C3PigModelFactoryTests -only-testing:PiggyEscapeTests/C3ClosedWorldTests test`
- 관찰: `setupCamera`·`setupLighting` 호출 시 `pigContainer`와 `hideTree`가 초기화되기 전의 `self` 사용 오류 2건, `C3PigModelFactory`의 `.pi` 모호성 2건으로 컴파일이 중단됨
- 영향: focused C3 XCTest가 실행되지 못함
- 원인/가설: Swift의 non-optional `let` 저장 프로퍼티 초기화 규칙과 `Float`/`CGFloat`/`Double` 간 문맥 없는 `.pi` 선택 규칙을 충족하지 못함
- 조치: 섬에서 얻은 숨기 나무·돼지를 먼저 저장 프로퍼티에 할당한 뒤 카메라·조명을 구성하고, 돼지 각도에 `Float.pi`를 명시할 예정임
- 검증: 초기화 순서를 수정하고 `Float.pi`를 명시한 뒤 같은 focused XCTest를 재실행했으며, 이 항목의 4개 진단은 사라졌다. 이어진 테스트 타깃 import 오류는 L-20260810-015에 기록했다.
- 배운 점: SceneKit 월드 생성자는 노드 그래프를 만들기 전에 모든 non-optional 저장 프로퍼티를 초기화하고, 벡터 각도는 `Float` 상수를 명시한다.

### L-20260810-013 — Task 3 GREEN XCTest가 C3 어댑터의 Swift 컴파일 오류로 실패함

- 상태: 해결
- 발생 태스크: Task 3 — C3 섬, 돼지 모델, 궤도 카메라 어댑터
- 재현: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/C3IslandBuilderTests -only-testing:PiggyEscapeTests/C3PigModelFactoryTests -only-testing:PiggyEscapeTests/C3ClosedWorldTests test`
- 관찰: `Decoration` 멤버와이즈 초기화의 인자 레이블 9건 누락, `SCNVector3.zero` 미정의, `SCNScene.pointOfView` 미정의로 앱 타깃 컴파일이 중단됨
- 영향: 새 C3 노드 동작 XCTest를 실행하지 못함
- 원인/가설: 구현에서 Swift 구조체의 기본 이니셜라이저 호출 규칙과 SceneKit API 소유 타입을 잘못 적용함. `pointOfView`는 `SCNView`의 속성임
- 조치: C3 장식 명세에 무레이블 이니셜라이저를 명시하고, 영 벡터는 `SCNVector3(0, 0, 0)`으로, 잘못된 scene 카메라 할당은 제거함
- 검증: 무레이블 `Decoration` 이니셜라이저를 추가하고, 영 벡터·잘못된 `SCNScene.pointOfView` 할당을 수정한 뒤 같은 focused XCTest를 재실행했으며, 이 항목의 11개 진단은 사라졌다. 다음 컴파일 오류는 L-20260810-014에 기록했다.
- 배운 점: 새 SceneKit 어댑터에서는 구조체 초기화 레이블과 `SCNScene`/`SCNView` 책임 경계를 컴파일 전 원본 API와 대조한다.

### L-20260810-012 — Task 3 RED XCTest가 Simulator 서비스 접근 제한으로 중단됨

- 상태: 해결
- 발생 태스크: Task 3 — C3 섬, 돼지 모델, 궤도 카메라 어댑터
- 재현: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/C3IslandBuilderTests -only-testing:PiggyEscapeTests/C3PigModelFactoryTests -only-testing:PiggyEscapeTests/C3ClosedWorldTests test`
- 관찰: `CoreSimulatorService connection became invalid`와 `Error opening log file ... Operation not permitted`가 발생해 XCTest가 새 타입의 컴파일 단계에 도달하기 전에 종료됨
- 영향: C3 타입 부재를 보여야 하는 RED를 현재 권한 범위에서 확인하지 못함
- 원인/가설: Simulator의 기기·로그·서비스 상태 경로가 현재 파일 권한 범위 밖에 있음
- 조치: Simulator 서비스와 Xcode 상태 경로에 접근 가능한 권한으로 같은 focused XCTest 명령을 재실행할 예정임
- 검증: Simulator 서비스와 Xcode 상태 경로 접근 권한으로 focused XCTest를 재실행했고, `C3ClosedWorldTests.swift`에서 `cannot find 'C3ClosedWorld' in scope` 3건으로 테스트 타깃 컴파일이 중단됨을 확인함. 첫 컴파일 오류에서 중단되어 나머지 C3 타입의 진단은 생성되지 않았음.
- 배운 점: iOS Simulator XCTest는 생성 프로젝트만으로 동작하지 않으며, Simulator 서비스·로그 상태 경로 접근이 필요하다.

### L-20260810-011 — Task 3 RED 준비 중 Tuist 세션 상태 디렉터리 쓰기가 거부됨

- 상태: 해결
- 발생 태스크: Task 3 — C3 섬, 돼지 모델, 궤도 카메라 어댑터
- 재현: `cd PiggyEscape && tuist generate --no-open`
- 관찰: `Fatal error: Error raised at top level: Permission denied: /Users/yang-eunseo/.local/state/tuist/sessions/F7174714-4104-4318-A365-0F8648073706`로 생성이 테스트 실행 전에 종료됨
- 영향: 새 XCTest 소스가 생성 프로젝트에 반영되지 않아 C3 타입 부재 RED를 아직 관찰하지 못함
- 원인/가설: Tuist가 작업 트리 밖의 사용자 세션 상태 디렉터리에 쓸 수 없어 생성 과정이 중단됨
- 조치: 해당 상태 경로에 접근 가능한 권한으로 동일 명령을 재실행해, 생성 성공 뒤 RED 컴파일 실패를 확인할 예정임
- 검증: 사용자 세션 상태 경로 접근 권한으로 같은 `tuist generate --no-open`을 재실행했고 `✔ Success`를 확인함. 이어서 지정된 C3 focused XCTest로 타입 부재 RED를 확인함.
- 배운 점: 새 Swift XCTest의 유효한 RED는 Tuist가 테스트 타깃 파일 목록을 다시 생성한 뒤에만 관찰할 수 있다.

### L-20260810-009 — Task 3 시작 전 원격 fetch가 연결 작업 트리 메타데이터 권한으로 중단됨

- 상태: 보류
- 발생 태스크: Task 3 — C3 섬, 돼지 모델, 궤도 카메라 어댑터
- 재현: `git fetch --prune origin`
- 관찰: `error: cannot open '/Users/yang-eunseo/Downloads/SpatialComputing_TechMap/.git/worktrees/ch1-reality-escape/FETCH_HEAD': Operation not permitted`로 원격 참조 갱신 전에 종료됨
- 영향: 구현 전 원격 변경 동기화 상태를 이 작업 트리에서 확정할 수 없음
- 원인/가설: 연결 작업 트리의 Git 메타데이터 `FETCH_HEAD` 쓰기 경로가 현재 파일 권한 범위 밖에 있음
- 조치: 기존 L-20260810-001과 같은 제약으로 기록하고, 작업 트리 내부의 읽기 전용 상태와 지정된 Task 3 명세로 범위를 확인함
- 검증: 후속 `git status --short`와 브랜치 확인을 별도 실행할 예정이며, 원격 fetch는 권한 확보 전까지 미검증으로 유지함
- 배운 점: 동일한 환경 제약이 후속 태스크에서도 재현되면 새 항목으로 명령·영향을 남기고 원격 상태를 추정하지 않는다.

### L-20260810-010 — Task 3 시작 순서의 프로젝트 맥락 문서가 작업 트리에 없음

- 상태: 보류
- 발생 태스크: Task 3 — C3 섬, 돼지 모델, 궤도 카메라 어댑터
- 재현: `sed -n '1,260p' docs/PROJECT_CONTEXT.md`
- 관찰: `sed: docs/PROJECT_CONTEXT.md: No such file or directory`로 지정 문서를 읽지 못함
- 영향: 시작 순서의 프로젝트 맥락 문서를 현재 브랜치에서 검토할 수 없음
- 원인/가설: 기존 L-20260810-004와 동일하게, 이 연결 작업 트리의 문서 구조에 해당 경로가 아직 포함되지 않은 것으로 보임
- 조치: 존재하는 `docs/WORK_LOG.md`, Reality escape 설계·계획, Task 3 브리프를 대체 근거로 사용함
- 검증: `rg --files`로 경로 부재와 대체 문서 존재를 확인할 예정임
- 배운 점: 시작 필수 문서가 반복적으로 부재하면 이전 기록을 참조하되, 현재 태스크의 재현 명령과 대체 근거를 별도 기록한다.

### L-20260810-008 — Task 2 커밋 준비가 연결 작업 트리 index 잠금 권한으로 중단됨

- 상태: 해결
- 발생 태스크: Task 2 — 경험 상태와 숨기 좌표를 순수 로직으로 만든다
- 재현: `git add PiggyEscape/PiggyEscape/Sources/Escape/EscapeExperienceState.swift PiggyEscape/PiggyEscape/Sources/Escape/HidePlanning.swift PiggyEscape/PiggyEscapeTests/EscapeExperienceStateTests.swift PiggyEscape/PiggyEscapeTests/HidePlanningTests.swift docs/WORK_LOG.md docs/LEARNING_LOG.md && git commit -m 'Add escape state and hide planning'`
- 관찰: `fatal: Unable to create '/Users/yang-eunseo/Downloads/SpatialComputing_TechMap/.git/worktrees/ch1-reality-escape/index.lock': Operation not permitted`로 index 갱신 전에 중단됨
- 영향: 검증된 Task 2 변경을 태스크 단위 커밋으로 기록하지 못함
- 원인/가설: 연결 작업 트리의 공용 Git 메타데이터 index 잠금 경로가 현재 권한 범위 밖에 있음
- 조치: 공용 Git 메타데이터에 쓸 수 있는 권한으로 같은 명시적 파일 목록을 stage 및 commit함
- 검증: 커밋 후 `git show --stat --oneline HEAD`와 `git status --short`로 Task 2 파일만 커밋되었고 사용자 소유의 `.claude/`만 남았는지 확인함
- 배운 점: 연결 작업 트리에서는 작업 트리 파일 쓰기 권한과 별도로 공용 Git index 잠금 경로 쓰기 권한이 필요하다.

### L-20260810-007 — 전체 XCTest 성공 중 기존 Simulator 런타임 경고가 출력됨

- 상태: 보류
- 발생 태스크: Task 2 — 경험 상태와 숨기 좌표를 순수 로직으로 만든다
- 재현: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`
- 관찰: 30개 XCTest는 모두 통과했지만 `Metadata extraction skipped. No AppIntents.framework dependency found`, `UIFocus` 캐시 제한, Simulator 런타임의 `UIAccessibilityLoaderWebShared` 중복 구현 경고가 출력됨
- 영향: Task 2의 순수 로직 테스트 결과에는 실패가 없지만 XCTest 출력이 경고 없이 깨끗하다는 조건은 충족하지 못함
- 원인/가설: AppIntents 의존성이 없는 기존 앱 타깃의 메타데이터 처리와 iOS Simulator 26.5의 UI/접근성 런타임 진단이며, Task 2의 두 순수 소스는 UIKit·SceneKit·ARKit·RealityKit을 import하지 않음
- 조치: Task 2 범위 밖의 앱 타깃·Simulator 런타임 설정은 변경하지 않고, focused 및 전체 XCTest의 통과 결과를 기록함
- 검증: focused XCTest 3/3, 전체 XCTest 30/30 통과. `rg -n '^(import (UIKit|SceneKit|ARKit|RealityKit))' PiggyEscape/PiggyEscape/Sources/Escape`로 금지 프레임워크 import가 없음을 확인함
- 배운 점: 순수 로직 변경의 회귀 검증과 기존 Simulator 런타임 경고를 분리해 기록하고, 범위 밖 경고를 해결하려고 앱 구조를 변경하지 않는다.

### L-20260810-006 — Task 2 RED XCTest가 Simulator 서비스 접근 제한으로 중단됨

- 상태: 해결
- 발생 태스크: Task 2 — 경험 상태와 숨기 좌표를 순수 로직으로 만든다
- 재현: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/EscapeExperienceStateTests -only-testing:PiggyEscapeTests/HidePlanningTests test`
- 관찰: `CoreSimulatorService connection became invalid`와 `Error opening log file ... Operation not permitted`가 발생해 컴파일 단계 전에 Simulator 서비스를 초기화하지 못함
- 영향: 새 타입 부재를 보여야 하는 RED XCTest가 실제 컴파일 오류까지 도달하지 못함
- 원인/가설: Simulator의 기기·로그·서비스 상태 경로가 현재 권한 범위 밖에 있음
- 조치: Simulator 서비스와 Xcode 상태 경로에 접근 가능한 권한으로 동일한 명령을 재실행함
- 검증: 재실행에서 `EscapeExperienceMachine` 미발견 컴파일 실패를 확인함. 테스트 타깃이 첫 컴파일 오류에서 중단되어 `TreeHidePlanner` 진단은 생성되지 않았음
- 배운 점: iOS Simulator XCTest는 프로젝트 파일만으로 동작하지 않으며, Simulator 서비스와 Xcode 로그 상태에 접근할 수 있어야 한다.

### L-20260810-005 — Task 2 RED 준비 중 Tuist 세션 상태 디렉터리 쓰기가 거부됨

- 상태: 해결
- 발생 태스크: Task 2 — 경험 상태와 숨기 좌표를 순수 로직으로 만든다
- 재현: `cd PiggyEscape && tuist generate --no-open`
- 관찰: `Fatal error: Error raised at top level: Permission denied: /Users/yang-eunseo/.local/state/tuist/sessions/AC8F4B22-C54F-4CF0-8096-E18EF5C09C3D`로 프로젝트 생성이 테스트 실행 전에 종료됨
- 영향: 새 XCTest 파일을 기존 생성 프로젝트에 반영하지 못해 타입 부재 RED를 아직 관찰할 수 없음
- 원인/가설: Tuist가 작업 트리 밖의 사용자 세션 상태 디렉터리에 쓰기를 시도하지만 현재 권한 범위에 포함되지 않음
- 조치: 해당 상태 경로에 쓸 수 있는 권한으로 같은 생성 명령을 재실행함
- 검증: 권한 확보 후 프로젝트를 다시 생성하고, 지정한 두 테스트를 실행해 `EscapeExperienceMachine` 부재 컴파일 실패를 확인함. 컴파일이 첫 오류에서 중단되어 `TreeHidePlanner` 미발견 진단은 생성되지 않았음
- 배운 점: 새 Swift 소스의 RED는 생성 프로젝트에 소스 글로브가 반영된 뒤에만 의미가 있으므로, 먼저 Tuist 세션 상태 쓰기 권한을 확인한다.

### L-20260810-002 — Tuist 생성이 세션 상태 디렉터리 권한으로 중단됨

- 상태: 해결
- 발생 태스크: Task 1 — C3 에셋과 카메라 권한을 앱 타깃에 등록한다
- 재현: `cd PiggyEscape && tuist generate --no-open && xcodebuild -project PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/AssetLoaderTests/test_c3EscapeAssets_loadFromTheAppBundle test`
- 관찰: Tuist가 `Fatal error: Error raised at top level: Permission denied: /Users/yang-eunseo/.local/state/tuist/sessions/BB509A80-33DE-4668-A2F8-BF6CBB5F6FDA`로 종료되어 XCTest 실행 전 중단됨
- 영향: RED 단계의 번들 로딩 실패를 아직 확인하지 못함
- 원인/가설: Tuist가 작업 트리 밖의 사용자 세션 상태 디렉터리에 쓰기를 시도하지만 현재 권한 범위에 포함되지 않음
- 조치: 해당 Tuist 상태 경로에 쓸 수 있는 권한으로 같은 명령을 재실행함
- 검증: Tuist 생성은 성공했고, `AssetLoaderTests.test_c3EscapeAssets_loadFromTheAppBundle`가 새 C3 에셋 부재로 16개 assertion 실패함
- 배운 점: Tuist 기반 검증은 프로젝트 생성물 경로뿐 아니라 사용자 세션 상태 경로의 쓰기 권한도 필요하다.

### L-20260810-003 — C3 에셋 번들 로딩 회귀 테스트가 새 에셋 누락으로 실패함

- 상태: 해결
- 발생 태스크: Task 1 — C3 에셋과 카메라 권한을 앱 타깃에 등록한다
- 재현: `cd PiggyEscape && tuist generate --no-open && xcodebuild -project PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/AssetLoaderTests/test_c3EscapeAssets_loadFromTheAppBundle test`
- 관찰: `Piggy_running`, `Piggy_surprised`, 두 `Cylinder_Tree`, `Manger_Color`, `Stone_Color`, `Coin_Color`, `Warehouse_Color`가 `expected bundled C3 asset` assertion에서 nil이었고, 총 16개 assertion이 실패함
- 영향: C3 월드 어댑터가 필요한 걷기·놀람·나무·섬 장식 리소스를 앱 번들에서 찾을 수 없음
- 원인/가설: 8개 C3 원본 에셋이 앱 리소스 디렉터리에 아직 복사되지 않았음
- 조치: 지정한 11개 C3 원본을 바이트 변경 없이 앱 리소스에 복사하고, 카메라 권한 Info.plist 항목을 추가함
- 검증: 11개 원본/대상 쌍의 `cmp -s`와 SHA-256 값이 일치했고, `xcodebuild ... -only-testing:PiggyEscapeTests/AssetLoaderTests test`가 5개 테스트를 통과했으며, 생성된 Info.plist에서 고정 목적 문구를 추출함
- 배운 점: 앱 번들 리소스 계약은 확장자 없는 로더 호출을 실제 앱 번들에서 실행하는 회귀 테스트로 보호한다.

### L-20260810-004 — 시작 순서에 지정된 두 문서가 작업 트리에 없음

- 상태: 보류
- 발생 태스크: Task 1 — C3 에셋과 카메라 권한을 앱 타깃에 등록한다
- 재현: `sed -n '1,240p' docs/PROJECT_CONTEXT.md` 및 `sed -n '1,260p' 씬킷에서_리얼리티킷으로_컨셉노트.md`
- 관찰: `docs/PROJECT_CONTEXT.md: No such file or directory`로 명령이 중단되었고, 파일 목록에도 두 경로가 없음
- 영향: 시작 순서의 일부 문서를 현재 작업 트리에서 검토할 수 없음
- 원인/가설: 현재 브랜치의 문서 구조가 공통 작업 지침보다 이전이거나, 해당 문서가 아직 이 브랜치에 추가되지 않음
- 조치: 현존하는 Reality escape 설계 명세·구현 계획·작업 인수인계와 태스크 브리프를 기준으로 Task 1 범위를 구현함
- 검증: `rg --files`로 해당 두 경로의 부재와 관련 설계/계획 문서의 존재를 확인함
- 배운 점: 작업 시작 문서가 없을 때는 경로 부재와 대체한 저장소 내 근거를 기록하고, 범위를 확장하지 않는다.

### L-20260810-001 — 작업 트리에서 원격 fetch의 FETCH_HEAD를 쓸 수 없음

- 상태: 보류
- 발생 태스크: Task 1 — C3 에셋과 카메라 권한을 앱 타깃에 등록한다
- 재현: `git fetch --prune origin`
- 관찰: `error: cannot open '/Users/yang-eunseo/Downloads/SpatialComputing_TechMap/.git/worktrees/ch1-reality-escape/FETCH_HEAD': Operation not permitted`
- 영향: 원격 변경 확인이 완료되지 않아 시작 전 원격 동기화 상태를 확정할 수 없음
- 원인/가설: 작업 트리의 공용 Git 메타데이터 쓰기 경로가 현재 권한 범위 밖에 있음
- 조치: 현재 작업 트리의 `git status --short`와 브랜치 정보를 확인하고, 원격 fetch 재시도는 권한이 확보될 때까지 보류함
- 검증: `git status --short`에서 사용자 소유의 추적되지 않은 `.claude/`만 확인됨; 원격 fetch는 미검증 상태로 남음
- 배운 점: 연결 작업 트리에서는 원격 확인 전에 공용 Git 메타데이터의 쓰기 권한을 먼저 확인한다.
