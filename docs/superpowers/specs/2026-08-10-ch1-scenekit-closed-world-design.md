# Chapter 1 (01-ClosedWorld) 설계

## 배경

TechMap 과정 제출용 DocC 튜토리얼 "씬킷에서 리얼리티킷으로 — 도망친 캐릭터 이야기"의 첫 챕터 설계. 전체 프로젝트 컨셉은 `씬킷에서_리얼리티킷으로_컨셉노트.md`, 4챕터 구조 개요는 `DocC_튜토리얼_구조화_프롬프트.md`에 있다.

튜토리얼 전체 목표는 SceneKit/RealityKit의 기능을 나열하는 게 아니라, 갇힌 세계를 벗어나 진짜 세계에서 숨바꼭질하는 캐릭터를 지켜보는 체험 안에 두 프레임워크의 근본적 차이를 자연스럽게 녹이는 것. Chapter 1은 이 체험의 첫 단계로, "갇힌 세계"인 SceneKit을 직접 짓고 그 한계를 실패로 체감시킨다.

## 핵심 주제

SceneKit 세계는 두 가지 의미에서 닫혀 있다.

1. **존재 범위** — 이 세계에 있는 모든 것은 개발자가 코드로 선언한 것의 총합이다. 그 바깥은 아예 없다(렌더링 안 된 어둠). 실제 방에 진짜 소파가 있어도, 코드로 선언하지 않았다면 이 세계엔 존재하지 않는다.
2. **구조 방식** — SceneKit은 노드(`SCNNode`) 하나에 생김새(geometry)·물리(physicsBody)·행동(action)을 전부 욱여넣는 트리 구조다. 책임이 분리되지 않는다.

이 두 가지를 "설명"이 아니라 캐릭터가 직접 실패를 겪는 과정으로 체감시키는 게 이 챕터의 목적이다. 결과물 완성이 아니라 개념 체험이 목적이므로, 각 스텝은 "이게 왜 이렇게 동작하는가"를 짚는 문단을 동반한다.

## 에셋 및 재사용 코드

사용자의 다른 프로젝트 `/Users/yang-eunseo/Downloads/C3_Piggy/C3_Piggy/`에서 에셋과 재사용 가능한 코드를 최대한 그대로 가져온다 (재사용 승인됨).

**에셋 (그대로 복사)**
- `Piggy.usdc` — 기본 상태. Chapter 1 전체에서 사용.
- `Piggy_running.usdz` — 도망 애니메이션. Chapter 2 이후(균열을 넘어 도망치는 장면)에 사용.
- `Piggy_surprised.usdz` — 놀란/들킨 포즈. Chapter 3 이후(개발자 시선에 들켰을 때)에 사용.
- `Ground_Color.usdc` — 방 바닥. 밋밋한 `SCNBox` 바닥 대신 이 타일 에셋을 재사용한다.
- `Wood_Color.usdc` — "가짜 소파"(스텝 5, 숨는 지점) 자리에 재사용. 색 박스보다 실제 가구처럼 보이는 에셋을 씀.

**벽은 예외적으로 새로 만든다** — C3_Piggy는 야외 섬 배경이라 벽 개념 자체가 없다. "방 끝에 아무것도 없다"는 스텝 2의 핵심 서사에 벽이 반드시 필요하므로, 벽만 `SCNBox`로 직접 짓는다.

**재사용 코드 (패턴만 가져와 축소 재작성, 통째 복사 아님)**
- `AssetLoader.swift`(`C3_Piggy/C3_Piggy/Scene/AssetLoader.swift`) — usdz/usdc/usda/obj 순서로 로드를 시도하고 실패하면 박스로 폴백하는 범용 유틸리티. C3 전용 로직이 없어 **거의 그대로** 복사해 쓴다.
- `PigController.loadPigModel(named:ext:)`의 정규화 패턴(바운딩 박스 기준으로 표준 높이에 맞춰 스케일하고 바닥을 y=0에 정렬하는 방식, Blender Z-up → SceneKit Y-up 보정 회전)을 참고해 우리 프로젝트용으로 훨씬 작게 새로 짠다. `PigController` 전체(목표 달성률 기반 스케일링, 점프 squash&stretch, 드래그 흡수 애니메이션 등)는 우리 이야기와 무관하므로 가져오지 않는다.
- `SceneContainerView.swift`의 `UIViewRepresentable` + `Coordinator` + `SCNView` 세팅 골격(`makeUIView`/`updateUIView`/`makeCoordinator`, 탭 제스처 등록)은 패턴만 참고한다. 드래그·롱프레스·핀치·이체 상태머신 등 돼지 저금통 앱 전용 로직은 전부 제외하고, 우리는 탭 제스처 하나만 쓰는 훨씬 단순한 버전으로 새로 짠다.
- `IslandBuilder.swift`는 육각 타일 배치·장식물 배치표 등 이 프로젝트 특화 로직이 대부분이라 코드는 가져오지 않고, "에셋 있으면 실제 모델, 없으면 폴백"이라는 설계 철학만 유지한다.

실제 파일을 프로젝트에 복사해 넣는 작업과 코드 재작성은 구현 단계(스텝 1)에서 처리한다.

## 앱 아키텍처

- SwiftUI 앱, `SCNView`를 `UIViewRepresentable`로 감싸서 사용
- Coordinator 구조로 SceneKit 델리게이트/상태를 관리 (2장 이후 RealityKit `RealityView`/`ARView`로 마이그레이션할 때 대비한 구조)

## 스텝 구성 (6단계)

### 스텝 1 — 프로젝트 세팅
`SCNView`를 `UIViewRepresentable`로 감싼 껍데기와 Coordinator를 짧게 세팅한다. 이 단계는 빌드 준비이며 서사적 의미는 없다.

### 스텝 2 — 방 짓기
바닥은 `Ground_Color.usdc`(AssetLoader로 로드, 실패 시 SCNBox 폴백)를, 벽은 `SCNBox`로 직접 세우고 좌표 원점을 임의로 선언한다. "이 세계에 있는 모든 것 — 벽이든 소파든 — 은 내가 코드로 써넣은 것만 존재한다"는 걸 코드로 직접 확인시킨다.

### 스텝 3 — 돼지 배치
하드코딩된 좌표에 `Piggy.usdc`를 `SCNNode`로 추가한다.

### 스텝 4 — 노드 구조 탐구 (독립 스텝)
지금까지 만든 씬 그래프를 들여다본다. `node.geometry`, `node.physicsBody`, `node.runAction(...)`이 전부 같은 `SCNNode` 객체 하나에 붙어있다는 걸 코드로 확인시키고, "생김새·물리·행동이 분리되지 않고 한 노드에 다 얹힌다"는 구조적 특징과 한계(깊은 중첩, 책임 미분리)를 짚는다. "RealityKit에서는 이걸 쪼갠다"는 짧은 예고만 하고 깊게 들어가지 않는다 — 본격 대비는 4장(Comparison)에서.

### 스텝 5 — "숨어봐" 시도 (인터랙션 버전)
`Wood_Color.usdc`를 "가짜 소파"로 방 안 하드코딩된 좌표에 미리 배치해둔다. 탭 제스처를 만들고, 누르면 `SCNAction`으로 그 가짜 소파 좌표까지 돼지가 이동하는 애니메이션이 실행된다.

```swift
@IBAction func hideButtonTapped() {
    let sofaSpot = SCNVector3(x: 1.5, y: 0, z: -2.0) // 그냥 숫자일 뿐, 진짜 소파와 무관
    pigNode.runAction(.move(to: sofaSpot, duration: 0.5))
}
```

진짜 소파가 화면 반대편(실제 방)에 있어도 이 동작은 그와 무관하게 실행된다. "내가 선언한 가짜 소파(`Wood_Color.usdc`)로는 이동되지만, 진짜 소파는 이 세계에 아예 존재하지 않는다"를 몸으로 증명하는 장면.

### 스텝 6 — 다음 장 예고
"이 세계는 더 이상 내가 만든 것만으로 이루어지지 않는다"는 톤으로 마무리한다. 균열 사이로 빛이 새어 든다는 서사와 함께 2장(Opening the Door)으로 자연스럽게 연결한다.

## 4장(Comparison)과의 연결

Chapter 1에서 심어둔 두 축은 4장에서 정식으로 대비된다.

| 축 | SceneKit (1장) | RealityKit (2~3장에서 체감) |
|---|---|---|
| 세계를 대하는 방식 | 가짜로 짓는 세계 — 선언한 것만 존재 | 진짜로 읽는 세계 — ARKit이 실측한 공간이 그대로 세계의 일부 |
| 구조 방식 | 노드 트리 — 한 노드가 생김새·물리·행동을 다 짊어짐 | ECS — Entity는 ID일 뿐, Component로 데이터/행동이 분리되어 붙음 |

## 미결 사항 (다음 챕터에서 다룰 것)

- Chapter 2(Opening the Door): ARKit 세션 시작, `AnchorEntity(.plane(.horizontal))` 앵커링. 아직 스텝 단위로 설계 안 됨.
- Chapter 3(Real Hide and Seek): occlusion 구현, 전/후 스크린샷. 아직 설계 안 됨.
- Chapter 4(Comparison): 위 표를 포함해 회고형으로 정리. 아직 설계 안 됨.
- Piggy 에셋을 실제로 어떻게 프로젝트에 복사/임포트할지 구체적 절차는 구현 단계에서 확정.
