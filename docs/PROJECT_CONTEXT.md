# 프로젝트 공통 컨텍스트

> 이 문서는 Claude와 Codex가 공유하는 작업 시작점이다. 중요한 결정을 바꾸면 관련 설계·계획 문서와 함께 갱신한다.

## 프로젝트 목표

`2026TechMap_tutorial`은 SceneKit에서 RealityKit으로 넘어가는 이유를 기능 목록이 아니라 이야기형 DocC 튜토리얼로 체험하게 하는 프로젝트다. 개발자가 만든 닫힌 SceneKit 세계에 갇힌 돼지 캐릭터가 현실 공간으로 탈출해 숨바꼭질하는 과정으로, **선언한 것만 존재하는 가짜 세계**와 **실측한 공간을 읽는 세계**의 차이를 보여준다.

## 읽기 우선순위

1. 이 문서 — 현재 범위, 환경, 협업 규칙
2. `씬킷에서_리얼리티킷으로_컨셉노트.md` — 전체 이야기와 기술적 의도
3. `DocC_튜토리얼_구조화_프롬프트.md` — 4개 챕터의 DocC 구조
4. `docs/superpowers/specs/2026-08-10-ch1-scenekit-closed-world-design.md` — Chapter 1의 승인된 설계
5. `docs/superpowers/plans/2026-08-10-ch1-closed-world-implementation.md` — Chapter 1의 구현·검증·커밋 순서

서로 상충하면 더 구체적이고 최근인 설계/계획 문서를 우선하고, 판단이 필요한 변경은 문서로 남긴다.

## 현재 진행 상태

- GitHub 기본 브랜치 `main`을 기준으로 작업한다. 시작할 때마다 원격 변경을 가져와 최신 커밋을 확인한다.
- Chapter 1의 설계와 8개 태스크 구현 계획은 커밋되어 있다.
- iOS 앱, Tuist 매니페스트, 에셋 복사는 아직 시작하지 않았다. 사용자 요청에 따라 Chapter 1 DocC 카탈로그는 먼저 원본으로 관리하고 GitHub Pages용 정적 아카이브로 배포했다: `https://eunseo-com.github.io/2026TechMap_tutorial/`. 실제 앱 소스가 생기면 카탈로그의 코드 스니펫을 해당 소스와 동기화한다.
- Chapter 2(Opening the Door), Chapter 3(Real Hide and Seek), Chapter 4(Comparison)는 상세 설계 전이다.

## Chapter 1: ClosedWorld

목표는 SceneKit의 두 가지 ‘닫힘’을 설명보다 체험으로 보여주는 것이다.

1. 존재 범위: 코드로 선언한 방·바닥·가짜 소파만 있고, 실제 방의 물체는 이 세계에 존재하지 않는다.
2. 구조 방식: 생김새·물리·행동이 `SCNNode` 트리에 함께 붙는 구조를 살펴본다.

구현은 SwiftUI의 `UIViewRepresentable` 안에 `SCNView`를 배치한다. Tuist 프로젝트에는 앱과 XCTest 타깃을 두고, 방·돼지·가짜 소파·이동 액션·노드 탐구 코드는 뷰와 분리해 단위 테스트한다. 마지막에는 Chapter 1용 DocC 카탈로그를 같은 타깃에 추가한다.

재사용이 승인된 로컬 원본은 `C3_Piggy` 프로젝트의 `Piggy.usdc`, `Ground_Color.usdc`, `Wood_Color.usdc` 및 로더 패턴이다. 이 자산을 실제 프로젝트에 복사하는 정확한 시점과 방법은 Chapter 1 구현 계획의 Task 2를 따른다. 벽은 의도적으로 `SCNBox`로 직접 만든다.

## 확인된 개발 환경

| 항목 | 확인값 |
| --- | --- |
| Xcode | 26.6 (17F113) |
| Swift | 6.3.3 |
| Tuist | 4.200.5 |
| iOS 배포 타깃 | 17.0 |
| 검증 대상 | iPhone 17 Pro Simulator |

Simulator에는 `iPhone 17 Pro` 기기가 설치되어 있다. ARKit 기반 Chapter 3의 실제 오클루전 검증은 LiDAR 탑재 실기기가 추가로 필요할 수 있으므로, 현 단계에서 시뮬레이터 통과를 실기기 검증으로 간주하지 않는다.

## GitHub 중심 협업 방식

- 다음 작업자가 알아야 할 목표, 결정, 제약, 진행 상태는 이 저장소의 Markdown으로 남긴다.
- 작업을 시작할 때 `git fetch --prune origin`, `git status --short`를 실행한다. 현재 작업과 무관한 변경은 보존한다.
- 구현은 Chapter 1 계획의 Task 1부터 순서대로 진행하며, 각 태스크에서 테스트/빌드 증거를 확인한 뒤 별도 커밋한다.
- 커밋 메시지에는 AI 생성 표기와 `Co-Authored-By` 트레일러를 넣지 않는다.
- Apple 샘플 사본, 브라우저 저장본, `.claude/` 활동 로그는 로컬 참고물이라 커밋하지 않는다. 거기서 확인한 내용이 프로젝트 의사결정에 영향을 주면 이 문서나 설계 문서에 요약한다.

## 다음 시작점

Chapter 1 구현을 요청받으면 `docs/superpowers/plans/2026-08-10-ch1-closed-world-implementation.md`의 **Task 1: Tuist project scaffold**부터 시작한다. Task 1이 완료되기 전에는 에셋, SceneKit 로직, DocC 본문을 추가하지 않는다.
