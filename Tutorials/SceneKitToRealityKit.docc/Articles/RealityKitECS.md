# RealityKit 심화 — ECS, 앵커, 실제 환경의 기준

@Metadata {
    @TechnologyRoot
}

Chapter 2·3에서 사용한 Entity-Component-System 구조와 앵커링을 참고용으로 자세히 정리한다.

## RealityKit을 한 문장으로 읽기

RealityKit은 애니메이션·물리·오디오·상호작용을 가진 모델을 렌더링하되, 그 구성을 Entity-Component-System(ECS) 패턴으로 조립하고, ARKit이 관찰한 실제 공간에 결과를 고정하는 엔진이다.

## Entity, Component, System을 구분하기

| 개념 | 역할 | 흔한 오해 |
| --- | --- | --- |
| `Entity` | 씬에 존재하는 대상 그 자체. 이름·자식 계층만 가질 뿐 기능은 없다 | Entity 자체에 로직이 있다고 생각하기 쉽지만, 로직은 System에 있다 |
| `Component` | Entity에 붙는 데이터 조각(위치, 모델, 충돌 형태 등) | Component가 스스로 행동한다고 착각하기 쉽지만, Component는 데이터만 들고 있다 |
| `System` | 특정 Component 조합을 가진 모든 Entity를 매 프레임 순회하며 규칙을 적용 | System이 한 Entity에만 묶여 있다고 생각하기 쉽지만, System은 조건에 맞는 모든 대상에 동시에 작동한다 |

## Component로 기능을 조합하는 예시

```swift
let pig = ModelEntity(mesh: .generateBox(size: 0.1))
pig.components.set(CollisionComponent(shapes: [.generateBox(size: [0.1, 0.1, 0.1])]))
pig.components.set(PhysicsBodyComponent(massProperties: .default, material: nil, mode: .dynamic))
```

같은 `ModelEntity`에 `CollisionComponent`와 `PhysicsBodyComponent`를 각각 붙이면, 모양·충돌·물리가 서로 독립된 데이터로 존재한다. 하나를 빼도 나머지는 그대로 남는다 — SceneKit의 `SCNNode`가 모든 것을 한 번에 들고 있는 것과 대비된다.

## System: 여러 대상에 같은 규칙을 적용하기

Xcode의 Apple Pyro Panda RealityKit 샘플이 보여주는 패턴처럼, "이 대상이 특정 행동을 할 수 있다"는 사실은 Component에 데이터로 남기고, 그 데이터를 가진 모든 Entity를 매 프레임 갱신하는 일은 System이 맡는다.

```swift
struct RunAwayComponent: Component {
    var targetDistance: Float
}

struct RunAwaySystem: System {
    static let query = EntityQuery(where: .has(RunAwayComponent.self))

    func update(context: SceneUpdateContext) {
        context.scene.performQuery(Self.query).forEach { entity in
            // targetDistance를 읽어 매 프레임 위치를 갱신한다
        }
    }
}
```

Entity는 "달릴 수 있다"는 데이터만 가지고, System은 그 데이터를 가진 모든 대상을 한 번에 처리한다. 이 프로젝트의 `RealityRevealMonitor`가 가림 상태를 관찰하는 방식도 같은 원리를 따른다 — 하나의 거대한 객체가 모든 일을 직접 처리하지 않는다.

## 앵커: 가상 좌표계를 실제 환경의 기준에 붙이기

`AnchorEntity`는 가상 콘텐츠의 원점을 실제 공간의 특정 기준(평면, 이미지, 얼굴, 월드 원점 등)에 붙인다.

```swift
let anchor = AnchorEntity(.plane(.horizontal, classification: .floor,
                                  minimumBounds: SIMD2<Float>(0.2, 0.2)))
anchor.addChild(pig)
```

| 앵커 종류 | 기준 |
| --- | --- |
| 월드 원점 | 세션 시작 시점의 기기 위치 |
| 평면 감지 | 수평·수직 평면 |
| 트래킹 결과 | 이미지·얼굴·바디 등 인식된 대상 |
| 장면 재구성 | LiDAR가 만든 메쉬 표면 |

Chapter 2에서 돼지를 앵커의 자식으로 추가하는 순간, 돼지의 좌표는 더 이상 개발자가 선언한 임의의 숫자가 아니라 실제로 관찰된 바닥을 기준으로 삼는다.

## RealityKit과 ARKit의 역할 분담

기기 센서(카메라·LiDAR)의 원시 데이터는 ARKit이 처리해 평면·메쉬·트래킹 상태를 만들고, RealityKit은 그 결과를 받아 렌더링·충돌·오클루전에 반영한다. `RealityHideARView`가 ARView의 세션을 시작하는 시점을 조정하는 이유는, 이 파이프라인의 입력(카메라 프레임)이 준비되기 전에 콘텐츠를 먼저 결합하면 검은 화면이 발생하기 때문이다 (자세한 진단 과정은 <doc:DeviceCameraDiagnostics> 참고).

## 어떤 표시 뷰를 쓸까

| 뷰 | 특징 |
| --- | --- |
| `ARView` | UIKit 기반, iOS에서 세밀한 세션 설정에 적합. 이 프로젝트가 사용 |
| `RealityView` | SwiftUI 기반, visionOS·iOS 최신 API에서 선언적으로 구성 |
| Scene/Entity 직접 구성 | AR 세션 없이 RealityKit만 사용할 때 |

## 실기기 검증 체크리스트

- [ ] 카메라 권한 승인 후 실제 영상이 배경에 보인다.
- [ ] 수평 평면이 감지되어 바닥 높이를 얻는다.
- [ ] 수직 면 탭이 유효한 목적지를 계산한다.
- [ ] LiDAR 메쉬가 돼지보다 앞에 있을 때 실제로 가려진다.
- [ ] 사용자가 이동하면 다시 발견된다.
- [ ] 메쉬가 불완전할 때도 앱이 잘못된 상태로 멈추지 않는다.

## 관련 문서

- <doc:02-OpeningTheDoor>
- <doc:03-RealHideAndSeek>
- <doc:DeviceCameraDiagnostics>
- <doc:MigrationWorksheet>
