# Chapter 1 구현 트러블슈팅

> Chapter 1(`ClosedWorld`)을 구현하면서 실제로 막혔던 지점과 그 원인·해결을 기록한다. 결과 코드만 보면 사라지는 "왜 이렇게 짰는가"를 남기기 위한 문서다. 형식은 `🐞 증상 → 추적 → 원인 → 해결 → 주의`.

## 1. `PigPlacement.makePigNode()`가 실제 돼지 모델 대신 항상 핑크 박스를 반환함

**증상**: 빌드도 되고 테스트도 전부 통과하는데, 실제로 `makePigNode()`가 반환하는 노드는 항상 `Piggy.usdc`가 아니라 폴백용 분홍 박스였다.

**추적**: `AssetLoader.object(named: "Piggy") { fallback }`이 성공적으로 모델을 로드했는지 확인하려고 넣은 방어 코드가 원인이었다.

```swift
let hasGeometry = model.geometry != nil || model.childNodes.contains { $0.geometry != nil }
if !hasGeometry {
    model = AssetLoader.voxelBox(...)
}
```

**원인**: `Piggy.usdc`를 로드하면 노드 계층이 `wrapper → root → {body, eyes, tail}` 순으로 3단계이고, 실제 geometry는 `root`의 자식(2단계 아래)에 있다. 위 체크는 `model`의 **직계 자식**까지만 본다. 즉 실제로 잘 로드된 모델도 이 체크를 통과하지 못해서, "모델이 없다"고 오판하고 매번 폴백으로 덮어썼다. 겉으로는 아무 에러도 나지 않고, 심지어 같은 방식(얕은 체크)으로 짠 테스트도 이 상태를 "정상"으로 보고 통과시켰다.

**해결**: 방어 코드를 지우고, `AssetLoader.object(named:fallback:)`가 이미 "성공하면 실제 모델, 실패하면 폴백"을 보장한다는 계약을 그대로 신뢰했다. 대신 테스트를 `enumerateHierarchy`로 계층 전체를 훑는 깊은 탐색으로 바꾸고, "geometry를 가진 노드가 1개보다 많다"는 조건으로 실제 다중 메시 모델과 단일 박스 폴백을 구분하게 했다.

**주의**: USD/USDZ로 불러온 모델은 지오메트리가 몇 단계 아래에 있는지 파일마다 다를 수 있다. "노드 하나만 보고 있다/없다"를 판단하는 코드는 항상 의심할 것 — 특히 그 판단 결과로 무언가를 덮어쓰는 코드라면, 판단이 틀렸을 때 결과가 조용히 나빠진다(에러가 안 남).

## 2. 헤드리스 XCTest에서 `SCNAction`의 완료 핸들러가 발화하지 않음

**증상**: `pig.runAction(HideAction.makeMoveAction()) { expectation.fulfill() }`을 부르고 `wait(for:timeout:)`으로 기다리는 테스트가 항상 타임아웃됐다.

**추적**: `SCNAction`은 실제로 씬이 렌더링(정확히는 매 프레임 틱)되고 있어야 진행된다. 노드를 씬에 붙이지 않거나, 씬을 아무도 렌더링하지 않으면 액션 자체가 진행되지 않고 완료 핸들러도 영원히 안 불린다.

1차 시도: `SCNRenderer(device: nil, options: nil)`을 만들어 `render(atTime:)`을 수동으로 여러 번 호출해 시간을 흘려보내려 했다. → 이 시뮬레이터 런타임(iOS 26.5)에서 `[SceneKit] Assertion 'false' failed. Invalid pass parameter`로 크래시. `device: nil`이 요청하는 GLES 기반 렌더 경로가 더 이상 지원되지 않는 것으로 보인다.

2차 시도: 명시적 Metal 디바이스 + 오프스크린 텍스처로 렌더 패스를 직접 구성. → 크래시는 사라졌지만 돼지 위치가 전혀 안 바뀜(원인 미확정 — Metal 렌더 패스 구성이 실제 화면 렌더링과 뭔가 다른 전제를 요구하는 것으로 추정되나 끝까지 규명하지는 못했다).

**해결**: 실제 `UIWindow` + `SCNView`(`isPlaying = true`)를 만들어 씬에 노드를 붙이고, 시스템의 진짜 디스플레이 링크가 프레임을 틱하게 했다. 이러면 `SCNAction`이 정상적으로 진행되고 완료 핸들러도 예정대로 불린다. 테스트가 끝나면 `defer`로 `isPlaying = false`, `window.isHidden = true`, `window.resignKey()`를 확실히 정리한다.

**주의**:
- 이 방식은 실제 시간이 흐르는 것에 의존한다(0.5초짜리 액션에 2초 타임아웃을 줌 — 4배 여유). CI 환경에서 시뮬레이터가 여러 개 동시에 도는 등 부하가 크면 이론적으로는 느려질 수 있으니, 나중에 이 테스트가 가끔 실패하기 시작하면 여기부터 의심할 것.
- `window.makeKeyAndVisible()`을 `windowScene` 없이 부르면 콘솔에 경고가 뜬다. 테스트 전용 오프스크린 윈도우라 의도된 것이지만, 나중에 iOS 버전이 올라가면 동작이 바뀔 수 있다.
- `SCNAction`을 다루는 테스트를 새로 짤 때는 처음부터 "이 액션을 실제로 누가 틱하는가"부터 확인하고 시작하면 위 두 번의 실패한 시도를 반복하지 않아도 된다.

## 3. `git worktree` 생성용 내장 도구가 "Failed to resolve base branch 'HEAD'"로 실패

**증상**: 격리된 작업 공간을 만드는 내장 도구로 새 worktree를 만들려 했더니 `HEAD`를 못 찾는다는 에러가 났다. 정작 프로젝트 폴더에서 `git rev-parse HEAD`는 멀쩡히 커밋 해시를 반환했다.

**추적**: 사용자 홈 디렉토리(`/Users/yang-eunseo`) 바로 밑에 커밋이 하나도 없는 별도의 `.git`이 이미 존재했다(아마 실수로 홈 디렉토리에서 `git init`이 실행된 것으로 보인다). 어떤 경로 해석이 프로젝트 폴더가 아니라 이 커밋 0개짜리 저장소를 대상으로 삼았을 가능성이 크다 — 커밋이 없는 저장소에서는 `HEAD`가 정말로 해석되지 않는다(`fatal: ambiguous argument 'HEAD'`).

**해결**: 내장 도구 대신 `git worktree add .worktrees/<name> -b <branch>`를 프로젝트 폴더 경로를 명시해 직접 실행했다. 문제없이 생성됐다.

**주의**: `/Users/yang-eunseo/.git`은 지우지 않고 그대로 남겨뒀다(사용자 확인 없이 삭제할 만한 일이 아니라서). 이 프로젝트 관련 git 작업은 항상 프로젝트 폴더 안의 `.git`을 명시적으로 대상 삼을 것 — 상위 디렉토리로 `cd`하거나 상대 경로로 git 명령을 실행하면 의도치 않게 엉뚱한 저장소를 건드릴 수 있다.

## 4. 같은 구현 계획을 다른 세션이 동시에 진행 중이었음

**증상**: 격리된 worktree에서 Task 1~6까지 다 끝낸 뒤 `main`을 다시 보니, 그 사이 다른 세션이 `main`에 직접 커밋을 쌓아 `AGENTS.md`/`docs/PROJECT_CONTEXT.md`/`docs/WORK_LOG.md`라는 인수인계 체계를 새로 만들어 두었고, 거기에 "Task 1 진행 중 — 다른 세션에서 다시 시작하지 말 것"이라고 적혀 있었다.

**추적**: 실제 `PiggyEscape/` 구현 코드는 `main`에 전혀 없었다 — 그쪽 세션은 조율 문서만 만든 상태였다. 그래서 코드 충돌은 없었지만, 진행 상태 기록이 완전히 어긋나 있었다.

**해결**: 격리된 worktree 쪽 작업이 이미 더 앞서 있었으므로 그걸 기준으로 계속 진행하고, 작업이 끝나는 시점에 `docs/WORK_LOG.md`와 `docs/PROJECT_CONTEXT.md`를 실제 상태에 맞게 갱신해서 `main`에 반영하기로 했다.

**주의**: 여러 세션이 같은 저장소를 동시에 건드릴 수 있는 환경이라면, 작업을 시작하기 전에 `docs/WORK_LOG.md`(또는 이에 준하는 인수인계 문서)의 "현재 인수인계"를 먼저 확인하는 습관이 필요하다. 격리된 작업 공간(worktree)은 코드 충돌은 막아주지만, 기록 차원의 조율까지 자동으로 막아주지는 않는다.

## 5. 편집 직후 뜨는 에디터 진단이 실제 빌드 실패와 다름

**증상**: 파일을 새로 만들거나 수정한 직후 "No such module 'XCTest'", "Cannot find 'AssetLoader' in scope" 같은 에러가 표시됐다. 그런데 실제 `xcodebuild ... test`는 매번 정상적으로 통과했다.

**원인**: Tuist로 프로젝트를 다시 생성(`tuist generate`)하기 전까지는 에디터의 코드 인덱스가 새 파일/새 타깃 구성을 모른다. 실제 컴파일러(`xcodebuild`)가 아니라 에디터 쪽 인덱싱이 뒤처진 것뿐이다.

**해결**: 파일을 추가·수정한 뒤에는 반드시 `tuist generate`로 프로젝트를 재생성하고, 최종 판단은 항상 `xcodebuild` 빌드/테스트 결과로 내렸다. 에디터 진단은 참고만 하고 그 자체로 실패 신호로 취급하지 않았다.

**주의**: 딱 한 번, 진짜 컴파일 에러일 수도 있는 진단(`Binary operator '/' cannot be applied to operands of type 'Float' and 'CGFloat'`)이 섞여 나온 적이 있었다. 무시하기 전에 해당 코드를 직접 열어 타입을 확인했고, 실제로는 문제가 없었다(SceneKit의 `SCNVector3` 구성 요소는 이 플랫폼에서 전부 `Float`). 에디터 진단을 무시하는 습관을 들이더라도, 평소와 다른 종류의 에러(모듈을 못 찾는다는 것과 타입이 안 맞는다는 것은 성격이 다르다)가 섞이면 한 번은 직접 눈으로 확인하는 편이 안전하다.
