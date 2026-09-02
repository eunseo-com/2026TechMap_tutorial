# SceneKit 심화 — C3 섬의 노드 트리와 입력 경계

Chapter 1의 C3 island는 개발자가 에셋과 코드로 구성한 SceneKit 세계다. 이 문서는 `HideTree`, `EscapePig`, orbit camera, node hit-test와 취소 가능한 자동 발견이 어떻게 이어지는지 설명한다.

## 세계의 출처: `SCNScene`과 노드 트리

`SCNScene`의 `rootNode` 아래에는 섬 타일, 나무, 돼지, 조명과 `SCNCamera` 노드가 부모·자식 관계로 배치된다. 부모의 position·rotation·scale은 자식에게 이어지므로, 돼지 모델의 축 보정과 장면 안 위치를 서로 다른 노드가 맡으면 좌표를 읽고 교체하기 쉽다.

이 구조가 “닫힌 세계”인 이유는 SceneKit의 한계 때문이 아니라 이 앱의 Chapter 1이 현실 관찰 입력을 연결하지 않았기 때문이다. SceneKit은 필요하면 ARKit과 함께 사용할 수 있다. 첫 장은 두 번째 장과의 차이를 체감하도록 선언된 C3 장면만 사용한다.

## 좌표와 orbit camera

같은 점도 어느 노드를 기준으로 읽는지에 따라 값이 달라진다.

| 하고 싶은 일 | SceneKit 경계 |
| --- | --- |
| 자식의 local position을 scene 전체 좌표로 바꾸기 | `node.convertPosition(_:to: nil)` |
| world position을 특정 노드의 local 좌표로 바꾸기 | `node.convertPosition(_:from: nil)` |
| 섬을 중심으로 camera를 돌리기 | yaw에서 orbit position을 직접 계산하고 `SCNLookAtConstraint`로 섬을 바라보기 |

팬 제스처가 바꾸는 값은 이 orbit camera의 yaw다. 기기 카메라 pose나 실제 방의 좌표는 바뀌지 않는다.

## `SCNView.hitTest`로 돼지만 선택하기

화면 tap은 `SCNView.hitTest`로 장면 geometry를 찾는다. 결과 노드 자체가 돼지의 최상위 노드일 필요는 없으므로, 부모를 따라 올라가 `EscapePig`의 descendant인지 확인한다. 다른 장식이나 바닥을 누르면 이동을 시작하지 않는다.

필수 숨을 곳은 이름이 `HideTree`인 기존 나무다. 나무가 없을 때 임의 좌표로 돼지를 보내면 장면의 계약이 깨지므로 `C3ClosedWorld` 초기화에서 `preconditionFailure`로 구성 오류를 즉시 드러낸다.

## 노드에 모이는 책임

| 요소 | SceneKit에서 맡는 일 |
| --- | --- |
| `geometry`, `materials` | 보이는 형태와 표면 |
| `camera`, `light` | 장면을 보는 시점과 조명 |
| `physicsBody` | 충돌과 물리 참여 |
| `SCNAction` | 시간에 따른 이동·회전·scale |
| 부모·자식 관계 | 변환 상속과 장면 구조 |

한 `SCNNode`가 여러 책임을 함께 가질 수 있다는 점은 Chapter 4에서 RealityKit의 Entity·Component·System 책임과 비교하는 기준이 된다.

## 취소 가능한 자동 발견

돼지가 나무 뒤에 도착한 순간은 animation 완료일 뿐, 발견 완료가 아니다. Chapter 1은 다음 순서를 지킨다.

1. narration이 끝난 뒤의 유효한 pig tap만 받는다.
2. 돼지가 `HideTree` 뒤 목적지까지 이동한다.
3. 도착 뒤 취소 가능한 0.40초 예약을 건다.
4. 예약이 살아 있고 상태가 `hiddenInClosedWorld`, `hasDiscovered == false`이면 카메라 조작과 무관하게 놀란 포즈·자막·`1.5배 → 1.0배` 반응을 한 번 실행한다.
5. callback을 받은 root view의 별도 0.70초 fade task가 끝나면 Chapter 2로 진행한다.

SceneKit view 해제에서는 자동 발견 예약을 취소하고 root view 해제에서는 fade task를 취소한다. 상태 guard와 one-shot flag가 중복 발견을 막는다.

## 디버깅 질문

| 증상 | 먼저 확인할 경계 |
| --- | --- |
| 섬이나 돼지가 보이지 않음 | camera frustum, model bounds, 부모 transform |
| 돼지를 눌러도 반응 없음 | narration 상태, hit node가 `EscapePig` descendant인지 |
| 엉뚱한 곳으로 이동 | `HideTree` 존재, local/world 좌표 변환 |
| 발견이 두 번 실행 | one-shot guard와 예약 취소 |
| reset 뒤 반응이 남음 | 자동 발견·fade task 취소와 view teardown |

## Chapter 1 확인 목록

- [ ] C3 island의 필수 노드와 `HideTree`가 존재한다.
- [ ] `SCNCamera`와 pan은 가상 camera yaw만 바꾼다.
- [ ] `SCNView.hitTest`는 `EscapePig` descendant만 입력으로 수용한다.
- [ ] narration 전 tap과 잘못된 순서의 event는 상태를 바꾸지 않는다.
- [ ] 나무 도착 뒤 0.40초 자동 발견과 0.70초 handoff가 취소 가능하다.

## 관련 문서

- <doc:01-ClosedWorld>
- <doc:02-OpeningTheDoor>
- <doc:RealityKitECS>
- <doc:MigrationWorksheet>
