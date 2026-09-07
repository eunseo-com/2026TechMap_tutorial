# RealityKit 심화 — 관찰, Entity와 cycle의 책임

Chapter 2·3은 ARKit이 관찰한 현실 공간을 RealityKit 표현과 게임 규칙에 연결한다. “RealityKit이 현실을 자동으로 안다”라고 뭉뚱그리지 않고, 센서 관찰·렌더링·순수 정책·수명 관리의 책임을 나누어 읽어야 한다.

## ARKit과 RealityKit의 역할 분담

| 계층 | 이 프로젝트에서 맡는 일 |
| --- | --- |
| ARKit | camera frame·pose, plane anchor, `ARMeshAnchor`, tracking과 session 상태를 만든다 |
| RealityKit | `ARView`에서 Entity를 렌더링하고 `convexCast` collision·occlusion·scene-understanding 결과를 사용한다 |
| 순수 정책 | floor region, scale, 다섯 sample, hide/reveal 판정을 프레임워크 호출 없이 계산한다 |
| coordinator | session, 입력 mode, hide cycle, deadline, callback generation을 연결하고 정리한다 |

ARKit의 mesh classification도 관찰 결과일 뿐, 앱이 보지 않은 물체 종류를 발명하지 않는다. Chapter 2의 화면은 실제 mesh 삼각형에서 투영한 채움 없는 선과 mesh/floor 현재 상태만 표시하며 관찰에서 오지 않은 사각 외곽선이나 물체 이름을 만들지 않는다.

요약하면 ARKit은 camera, plane, mesh observation을 만들고 RealityKit은 그 결과를 표시와 상호작용에 사용한다.

## Entity, Component, System

RealityKit의 Entity는 계층 안의 대상이고, Component는 그 대상의 데이터와 능력을 조합한다. System은 특정 Component 조건을 만족하는 Entity를 scene update마다 처리한다.

```swift
import RealityKit

struct RunAwayComponent: Component {
    var speed: Float
}

struct RunAwaySystem: System {
    static let query = EntityQuery(where: .has(RunAwayComponent.self))

    init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        for entity in context.scene.performQuery(Self.query) {
            guard let runAway = entity.components[RunAwayComponent.self] else { continue }
            entity.position.z -= runAway.speed * Float(context.deltaTime)
        }
    }
}
```

이 예제는 실제 Component/System 경계다. 반면 앱의 `RealityHidePlanner`, `StableHideMonitor`, `RealityRevealMonitor`는 테스트 가능한 Swift 정책 타입이고 RealityKit `System`이 아니다. coordinator가 scene update에서 observation을 전달한다고 해서 정책 타입의 정체가 System으로 바뀌지는 않는다.

## 준비 완료와 anchor 부착을 분리하기

Chapter 2에서 session을 시작했다고 돼지를 바로 붙이지 않는다.

1. 내부 `ARView`가 window와 유효한 bounds를 얻은 뒤 session을 한 번 시작한다.
2. 최소 한 mesh와 최소 한 classified horizontal floor를 관찰해 mesh AND floor readiness를 만족한다.
3. 첫 준비 완료를 한 번 알리고 “숨바꼭질 시작” CTA를 연다.
4. CTA 뒤에도 같은 `ARView`와 같은 AR session을 유지하며 Chapter 3의 target selection으로 바꾼다.
5. Chapter 3에서 유효한 target을 수락한 뒤에만 그 hide cycle의 새 pig anchor를 scene에 정확히 한 번 attach한다.

따라서 scanning 중에는 pig anchor가 없다. 지원 판정, session 시작, mesh+floor readiness, valid target acceptance는 서로 다른 사건이다.

최초 mesh+floor 준비를 기억하는 readiness latch도 현재 telemetry와 다른 사건이다. 최신 telemetry는 mesh·floor 수와 tracking을 최대 4 Hz로 갱신하고 긴급 tracking 변화는 즉시 전달한다. 따라서 한 번 ready가 됐어도 현재 tracking이 불안정하거나 mesh/floor가 사라지면 CTA를 잠근다. 영역 수는 물체 수나 완료율이 아니다.

Chapter 2와 Chapter 3은 같은 AR session을 유지한다.

## hide cycle이 소유하는 것

각 cycle은 새 anchor, 새 visual controller, 가림·재발견 monitor, deadline과 generation을 소유한다. 유효한 surface와 같은 immutable floor region에서 start·destination을 계산한 뒤에만 Entity를 붙인다.

재시도·다시 숨기기·화면 해제에서는 다음을 함께 정리한다.

- cancellable deadline과 scene update subscription
- 진행 중인 model load와 movement completion
- 현재 pig anchor와 반응 상태
- 이전 cycle generation으로 도착한 callback

정상적인 Chapter 3 다시 숨기기는 AR session을 유지한다. 반면 scan timeout, session failure, LiDAR unavailable, Chapter 4 진입 또는 Reality 화면 제거에서는 AR subtree를 내리고 session까지 정리한다.

## 물체를 통과하지 않는 이동 책임

계획은 물체 양옆의 bounded route 후보를 짧은 순으로 만든다. floor footprint 안의 점만 남기고, 설치된 돼지 몸통 크기로 각 segment에 `.sceneUnderstanding` `convexCast`를 수행한다. 통과한 route가 없으면 직선으로 물체를 뚫는 fallback을 만들지 않고 target selection으로 복구한다. 측정하지 못한 공간의 안전은 보장하지 않는다.

선택된 route에서는 돼지가 제자리에서 다음 segment를 향해 회전한 뒤 `SceneEvents.Update`의 scene-time으로 0.45m/s 이동한다. 이동 중 새 mesh가 나타나 몸통 여유가 사라지면 즉시 취소하고 선택 단계로 돌아간다. wall-clock 완료 추정이나 코너를 둥글게 잘라 장애물 안으로 들어가는 보간은 사용하지 않는다.

## observation과 occlusion

한 observation은 하나의 `ARFrame`에서 읽은 timestamp, camera pose, 돼지의 다섯 world sample, projection과 mesh hit 결과를 묶는다. RealityKit은 실제 mesh를 렌더링 occlusion에 사용할 수 있고, 앱 정책은 같은 관찰을 사용해 hide의 center+4/5와 reveal의 center+3/5를 판정한다.

이 분리는 화면에 가려져 보이는 현상과 게임 상태를 바꾸는 안정 조건을 같은 것으로 착각하지 않게 한다. 걷기 완료나 한 번의 center ray만으로 `hiddenInReality`가 되지 않는다.

tracking이 normal이 아니면 다섯 sample 전체를 invalid로 만들고 camera pose를 전달하지 않는다. 그 frame은 0.15m/15° 시점 변화 이력에 포함되지 않으며, tracking이 복구된 뒤 서로 다른 정상 frame 두 개를 새로 요구한다.

## 실기기 대기 체크리스트

- [ ] 실제 채움 없는 mesh 선과 현재 mesh/floor telemetry가 관찰 상태와 일치한다.
- [ ] scanning 중 pig anchor가 없고 accepted target 뒤 cycle anchor가 한 번 붙는다.
- [ ] 0.18m 돼지, floor plan과 측면 `convexCast` route·0.45m/s 이동이 실제 공간에서 자연스럽다.
- [ ] 실제 mesh의 4/5×두 frame hide와 0.15m/15° 이후 3/5×두 frame reveal이 일치한다.
- [ ] 다시 숨기기와 Chapter 4 전환 뒤 이전 anchor·callback이 남지 않는다.

위 항목은 모두 실기기 대기다. source type-check나 generic build는 실제 LiDAR 관찰을 대신하지 않는다.

## 관련 문서

- <doc:02-OpeningTheDoor>
- <doc:03-RealHideAndSeek>
- <doc:04-Comparison>
- <doc:DeviceCameraDiagnostics>
- <doc:MigrationWorksheet>
