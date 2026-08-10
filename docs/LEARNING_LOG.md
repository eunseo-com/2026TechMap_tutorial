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
