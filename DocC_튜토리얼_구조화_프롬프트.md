# DocC 튜토리얼 카탈로그 생성 프롬프트

SceneKit 프로젝트를 RealityKit으로 옮기며, 캐릭터가 갇힌 가짜 세계에서 벗어나 실제 공간에서 숨바꼭질하는 과정을 통해 두 프레임워크의 근본적 차이(가짜로 짓는 세계 SceneKit vs 진짜로 읽는 세계 RealityKit + ARKit)를 체험시키는 DocC 튜토리얼을 만들어줘.

## [앱 아키텍처]

- SwiftUI 앱, 1장은 SceneKit(`SCNView` 또는 `UIViewRepresentable`로 감싼 `SCNView`) 기반 프로젝트로 시작
- 2장부터 동일 프로젝트를 RealityKit(`RealityView` 또는 `ARView`)으로 마이그레이션
- (내용 채울 것: 캐릭터 모델/에셋 형태, Coordinator 구조, 상태 관리 방식 등)

## [개발 환경]

- Xcode (버전 명시 예정)
- iOS (버전 명시 예정), LiDAR 탑재 실기기 권장 (3장 occlusion 구현에 필요 여부 확인)
- (내용 채울 것: 필수 프레임워크, 최소 배포 타깃)

## [챕터 구성 - 4개]

**Project Setup (01-ClosedWorld.tutorial)**
갇힌 세계 만들기 — SceneKit으로 방과 캐릭터를 짓는다. `SCNBox`로 벽/바닥을 세우고 좌표 원점을 임의로 선언해, 이 세계가 개발자가 지은 가짜 세계임을 코드로 보여준다. "숨어봐"를 시도했을 때 실제 소파가 인식되지 않아 실패하는 지점을 의도적으로 남긴다.
(내용 채울 것: 구체적 스텝, 코드 스니펫)

**Opening the Door (02-OpeningTheDoor.tutorial)**
ARKit 세션을 시작하고 `AnchorEntity(.plane(.horizontal))`로 캐릭터를 실제 바닥/테이블에 앵커링한다. 개발자가 선언하지 않은 실세계 좌표(예: 테이블 실측 높이)에 캐릭터가 자연스럽게 자리잡는 과정을 단계별로 보여준다.
(내용 채울 것: 구체적 스텝, 코드 스니펫)

**Real Hide and Seek (03-RealHideAndSeek.tutorial)**
씬 지오메트리 기반 occlusion을 구현해 캐릭터가 실제 가구 뒤로 가려지도록 만든다. 이 튜토리얼의 클라이맥스로, SceneKit과 RealityKit의 차이가 "체험"으로 드러나는 장. 가려짐 전/후 스크린샷을 함께 배치.
(내용 채울 것: 구체적 스텝, 코드 스니펫, 필요한 이미지 목록)

**Comparison (04-Comparison.tutorial)**
지금까지의 실습을 되짚으며 "가짜로 짓는 세계(SceneKit) vs 진짜로 읽는 세계(RealityKit + ARKit)"라는 개념을 정리. 코드 나열이 아니라 앞서 겪은 체험을 개념으로 되짚는 회고형 구성.
(내용 채울 것: 정리 문단, 다음 학습 방향 제안)

## [파일/디렉토리 규칙]

- 루트: `SceneKitToRealityKit.tutorial` (전체 목차, `@Tutorials` 디렉티브. 인트로에서 "캐릭터가 갇혀 있다"는 문제 제기로 시작)
- `Tutorials/` 하위에 챕터별 `.tutorial` 파일 4개 작성
- `Tutorials/Resources/`에 스텝별 코드 스니펫 저장. 1장 코드 위에 2장이 앵커링 코드를, 3장이 occlusion 코드를 얹는 방식으로 누적되는 구조
- 3장은 가려짐 전/후 스크린샷 2장을 우선 배치, 이미지 placeholder 네이밍 및 `@Image(source:)` 참조 설정

## [내용 톤 지침]

- 기능을 나열하는 설명 금지. 각 장 도입부에 SceneKit/RealityKit이 세계를 대하는 방식의 차이를 한 문단으로 짚어줄 것
- 결과물 완성이 목적이 아니라 개념을 체험을 통해 학습시키는 것이 목적임을 각 장 서술에 반영할 것

## [출력 조건]

- 실제 DocC 문법(`@Tutorial`, `@Chapter`, `@TutorialSection`, `@Steps`, `@Code` 등) 적용
- GitHub Pages 정적 배포를 고려해 카탈로그 루트 이름과 base-path 일치 (`SceneKitToRealityKit`)
- Repository 이름: `2026TechMap_tutorial`
