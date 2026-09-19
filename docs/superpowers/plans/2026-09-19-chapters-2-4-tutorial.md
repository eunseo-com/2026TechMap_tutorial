# Chapter 2–4 Tutorial Implementation Plan

> 아래는 2026-09-19 독립 입문 실습의 설계·구현 기록이다. 본편 앱의 현재 상태는 `docs/PROJECT_CONTEXT.md`, GitHub Pages 통합은 `docs/2026-09-20-github-pages-reader.md`를 따른다.

**Goal:** Chapter 2–4의 실행 가능한 다운로드 코드와 읽기 페이지를 완성한다.
**Architecture:** 공통 준비 코드가 기기·권한·세션을 맡고 독자는 장마다 ContentView.swift의 작은 변화를 만든다. DocC에서 네 읽기 페이지를 생성한다.
**Tech Stack:** Swift 6, SwiftUI, RealityKit, ARKit, iOS 17, DocC, Python.
**Spec:** `docs/superpowers/specs/2026-09-19-chapters-2-4-tutorial-design.md`

## Global Constraints

- 최소 iOS 17, Swift 6. 독자에게 Tuist를 요구하지 않는다.
- 장별 Starter/Answers ZIP. 준비 코드와 원문 코드가 다운로드와 일치해야 한다.
- AR 실기기 검증과 시뮬레이터 검증을 구분한다.
- 기존 사용자 파일, 본편 Task 6–7, 외부 게시 상태를 건드리지 않는다.
- 기존 가독성·코드 복사·모바일 동작을 유지한다.

## Task 1: Swift 실습과 다운로드

Files: DocC `Tutorials/Resources/`의 SpatialSupport, TutorialPig, ECSSceneSupport, PatrolSystem, PatrolMotion 및 9개 ContentView; `tools/tutorial_site/package_lab.py`, `prepare_rehearsal.py`, `verify.py`, `tests/`.

- [x] PatrolMotion 경계·정지·긴 프레임·시간 분할 검사를 먼저 정의한다.
- [x] AR 상태·권한·탭 배치·가려짐과 비 AR ECS 장면을 구현한다.
- [x] 세 단계 ContentView를 각 장에 작성하고 두 SDK에서 검사한다.
- [x] ZIP과 임시 빌드 프로젝트 생성기를 확장한다.
- [x] ZIP에서 새 앱을 빌드하고 실행 결과를 기록한다. 2·3장은 시뮬레이터의 미지원 안내까지, 4장은 이동·정지·재개까지 확인했다. 실제 AR 검증은 별도다.

계약 예: `SpatialLessonView(configuration: configuration) { anchor in anchor.addChild(TutorialPig.make()) }`. 3장의 `enableOcclusion` 변경은 UIView 갱신만 하며 session.run을 다시 호출하지 않는다.

## Task 2: DocC 세 장

Files: `02-OpeningTheDoor.tutorial`, `03-RealHideAndSeek.tutorial`, `04-Comparison.tutorial`, 카탈로그와 Chapter 1의 다음 장 연결.

- [x] 설계의 코드 파일명을 @Code로 연결한다. 한 Step당 코드 하나를 사용한다.
- [x] 준비·행동·기대 결과·복구 안내, 실기기 설정을 작성한다.
- [x] 지식 비교는 실제 코드에서 책임을 찾는 순서로 쓴다.
- [x] 공식 출처와 검증 한계를 표시하고 DocC를 경고 없이 변환한다.

## Task 3: 네 장 탐색과 검증

Files: `tools/tutorial_site/render.py`, `reader.css`, `verify.py`, `docc-site/public` 생성물.

- [x] 네 경로를 생성하며 모든 장의 목차·다운로드·이전/다음을 연결한다.
- [x] 렌더된 전체 코드와 원문, 모든 페이지의 링크·자산을 검사한다.
- [x] 데스크톱·모바일·복사 버튼을 브라우저에서 확인한다. 새 코드의 자동 붙여넣기는 이전 클립보드 문자열이 입력되어 종단 검증에서 제외했다.
- [x] 웹 빌드·서버 폴백, git diff --check를 수행한다.
- [x] 컨텍스트·WORK_LOG·검증 기록을 갱신하고 로컬 커밋한다.

## 진행 기록

- 시작: 작업 브랜치 `codex/chapters-2-4`, 원격 fetch 완료. 기존 미추적 사이트와 이미지 보존.
- 인터페이스 검토: Task 1의 파일명·Swift API를 Task 2가 사용하고, Task 2의 DocC 식별자를 Task 3이 렌더한다. 각 소스의 편집 담당을 나눠 중복 수정을 방지한다.
- 구현 허가: 사용자의 “다음 챕터들까지 다 구현” 요청에 따라 2–4장 실행 자료를 진행한다. 외부 전송 승인을 의미하지 않는다.

## 검증 인수인계

구현과 로컬 검증은 완료했다. 실제 AR 평면·메시 가려짐, 초보 독자 완주 관찰과 Xcode 붙여넣기는 `docs/chapters-2-4-validation.md`의 남은 항목을 따른다. 시뮬레이터·SDK 통과를 실물 환경 통과로 표기하지 않는다. 2026-09-20 후속 게시 요청에 따라 기존 소유자 전용 사이트를 최신 네 장과 다운로드로 갱신했다. 게시 검증과 버전은 `docs/WORK_LOG.md`에 기록했다.
