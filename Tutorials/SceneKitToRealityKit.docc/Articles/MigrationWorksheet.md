# 비교와 마이그레이션 — API 치환이 아니라 세계관 번역

@Metadata {
    @TechnologyRoot
}

Chapter 4에서 다룬 비교를 참고용 표와 워크시트로 확장한다.

## 먼저 결론

기존 SceneKit 앱을 오늘 당장 다시 써야 하는 것은 아니다. 핵심 질문은 하나다: **이 앱이 미리 만든 3D 세계를 보여주는가, 아니면 실제 공간의 데이터를 읽고 반응하는가?** 전자는 SceneKit으로 충분히 유지할 수 있고, 후자는 RealityKit·ARKit 조합이 필요하다.

## 같은 장면을 보는 네 가지 관점

| 관점 | SceneKit | RealityKit |
| --- | --- | --- |
| 장면의 중심 | `SCNScene`과 `SCNNode` 트리 | `Entity` 계층과 `Scene` |
| 눈에 보이는 모델 | `SCNGeometry` + `SCNMaterial` | `ModelComponent` |
| 물리·충돌 | `SCNPhysicsBody` | `PhysicsBodyComponent` + `CollisionComponent` |
| 행동 | `SCNAction` | Component에 데이터, System에 규칙 |
| 실제 공간과의 연결 | 없음(별도로 ARKit을 함께 써야 함) | `AnchorEntity`로 기본 내장 |
| 에셋 파이프라인 | `.scn`, USD | USD 중심, RealityKit Composer 지원 |

## 가장 짧은 대조 코드

```swift
// SceneKit: 노드에 붙이고 실행한다
let node = SCNNode(geometry: SCNSphere(radius: 0.1))
node.runAction(.move(to: destination, duration: 0.5))

// RealityKit: 앵커 아래 Entity를 조합한다
let entity = ModelEntity(mesh: .generateSphere(radius: 0.1))
anchor.addChild(entity)
```

## SceneKit 개념을 번역하는 표

| SceneKit | RealityKit 대응 | 마이그레이션 주의점 |
| --- | --- | --- |
| `SCNNode` 컨테이너 | `Entity` + 자식 | 계층 구조는 유지되지만, 트랜스폼 기준을 다시 확인해야 한다 |
| geometry + material | `ModelComponent`/`ModelEntity` | 외형과 충돌 형상이 분리된 데이터라는 점을 놓치기 쉽다 |
| `physicsBody` | Physics·Collision·Motion Component | 이동을 물리로 제어할지 직접 제어할지 먼저 정해야 한다 |
| `SCNAction` | 애니메이션/액션 또는 Component + System | 하나의 대상만 다루는 연출인지, 여러 대상에 적용할 규칙인지 구분한다 |

## 언제 SceneKit을 유지하고, 언제 RealityKit을 검토할까

- 기존 앱이 안정적으로 동작하고 새 AR 기능 계획이 없다면 SceneKit 유지가 합리적이다.
- 신규 3D 경험, 실제 공간과의 상호작용, visionOS 대응이 필요하다면 RealityKit을 검토한다.
- 큰 업데이트를 준비 중이라면, 전체 재작성보다 새 기능부터 RealityKit으로 시작하는 점진적 전환을 고려한다.

## 단계별 마이그레이션 워크시트

1. **현재 씬 인벤토리 작성** — 모델·물리·행동·공간 의존성별로 노드를 분류한다.
2. **목표 표시 환경 정의** — iOS AR(`ARView`)인지 visionOS(`RealityView`)인지 정한다.
3. **Entity/Component 경계 설정** — 공간 계층, 표현, 상호작용, 물리, 상태/규칙을 분리한다.
4. **좌표 원점 전환** — 하드코딩 좌표에서 감지된 평면·레이캐스트 결과·트래킹 앵커로 옮긴다.
5. **에셋 개별 검증** — 스케일(미터 단위)·축 정렬·재질·충돌 형상을 확인한다.
6. **자동 테스트와 실기기 테스트 분리** — 구조는 단위 테스트로, 평면 감지·오클루전은 실기기로 확인한다.

## 이 프로젝트의 단계적 적용

| Chapter | 유지한 것 | 새로 배운 것 | 의도적으로 미룬 것 |
| --- | --- | --- | --- |
| 1 | `SCNNode` 트리, 가상 카메라 | 씬 그래프 좌표 읽기 | 실제 공간 인식 |
| 2 | 없음(전환점) | 카메라 권한, AR 세션 시작 순서 | 오클루전 |
| 3 | 없음 | LiDAR 메쉬, occlusion, hitTest | 게임 규칙 확장 |
| 4 | 두 구현 모두 | ECS와 노드 트리의 책임 배치 비교 | 전체 앱 통합 마이그레이션 |

## 마이그레이션 전에 답할 마지막 질문

1. 이 기능이 실제로 공간 인식이 필요한가, 아니면 화면 안 3D 표현으로 충분한가?
2. 좌표를 코드로 선언할 것인가, 관찰된 앵커에서 얻을 것인가?
3. 행동을 Entity 하나의 연출로 볼 것인가, 여러 Entity에 적용할 규칙(System)으로 볼 것인가?
4. 자동 테스트로 검증할 범위와 실기기에서만 확인 가능한 범위를 나눴는가?
5. 기존 SceneKit 코드를 점진적으로 옮길 것인가, 새 기능만 RealityKit으로 병행할 것인가?

## 관련 문서

- <doc:04-Comparison>
- <doc:SceneGraphDeepDive>
- <doc:RealityKitECS>
