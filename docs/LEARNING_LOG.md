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
