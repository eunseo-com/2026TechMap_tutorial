# 초보 독자를 위한 네 장 편집 기록

> 독립 입문 실습의 작성 당시 검증 기록이다. 현재 공개 대상과 배포 결과는 [GitHub Pages 통합](2026-09-20-github-pages-reader.md)과 `WORK_LOG.md`를 우선한다.

2026-09-19. 기준 독자는 Xcode에서 새 앱을 만드는 과정부터 안내가 필요한 사람이다. 문장과 화면을 다시 편집하고, 그 경로의 기본 프로젝트 설정으로 코드도 확인했다.

## 편집 결정

- 제목은 화면에서 만들 결과로 쓴다. 예: “같은 자리에서 실제 물체의 가려짐을 비교해 보세요” → “상자 뒤에 돼지 숨기기”.
- 준비 과정은 파일 추가, 카메라 설명, 기기 연결, 서명, 실행으로 나눈다. 메뉴 위치·입력값·확인할 화면을 각각 적는다.
- 코드 붙여넣기는 편집 영역 선택과 `⌘A → ⌘V → ⌘S`까지 설명한다. `Answers`는 새 파일로 추가하지 않고 기존 파일의 내용을 바꾸는 데 쓴다.
- raycast·anchor·ECS는 행동과 결과를 먼저 본 뒤 필요한 자리에서 설명한다. 4장 시스템 내부 읽기는 선택 과정이다. 읽기 전용 코드에는 복사 버튼을 표시하지 않는다.
- 3장은 2장 앱을 이어 쓰는 한 경로로 안내한다. 상자 옆에서 뒤쪽 바닥에 배치하고, 정면으로 기기를 옮겨 비교하는 순서를 풀어 쓴다.
- 단계별 행동과 결과는 바로 보이게 두고, 오류 해결은 접어서 필요할 때 펼친다. 모바일 목차도 접힌 상태로 시작한다. 파일 안내 표는 모바일에서 파일 이름과 설명을 위아래로 배치한다.
- 내부 빌드 검증 문구는 독자의 실습 본문에서 빼고 검증 문서에 기록한다. 실물 기기 조건은 시작 전과 해당 실패 안내에 남긴다.

준비를 무리하게 한 단계에 묶지 않아 현재 단계 수는 1장 8개, 2장 9개, 3장 7개, 4장 8개다. 장마다 기본 코드 버전은 세 개, 수정하는 파일은 `ContentView.swift` 하나로 유지했다. 이 단계 수가 이전 기록의 “장별 7단계”를 대체한다.

## 새 프로젝트에서 발견한 실행 장애

설치된 Xcode 26.6의 App 템플릿은 `SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY=YES`, `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY=YES`를 사용한다. 템플릿의 `App Base.xctemplate/TemplateInfo.plist`와 `Base_ProjectSettings.xctemplate/TemplateInfo.plist`에서 확인했다.

기존 검사에는 마지막 설정이 빠져 있었다. 이를 켜자 2·3장의 `SpatialSupport.swift`에서 `@Published`와 `ObservableObject`의 Combine 멤버를 사용할 수 없다는 오류가 재현됐다. 해당 파일에 `import Combine`을 명시하고 두 ZIP을 다시 만들었다. 검증기와 임시 프로젝트 생성기도 새 앱의 설정을 반영했다. 독자가 프로젝트 설정을 낮추는 우회는 요구하지 않는다.

## 검증

- DocC를 경고를 오류로 처리해 변환했다. 코드·JSON·웹의 13개 코드 블록과 전체 5개 다운로드 일치를 검사한다.
- 기본 12개 코드 버전을 Swift 6와 새 앱의 MainActor·모듈 가시성 설정으로 검사했다. 2–4장의 9개는 시뮬레이터·기기 SDK 모두 통과했다. 기존 1장 선택 과정과 왕복 계산 7개 검사도 통과했다.
- 수정한 3장 ZIP에서 임시 앱을 만들고 위 설정을 적용해 iOS 시뮬레이터 빌드를 통과했다. 이번에는 실물 기기 설치·카메라 검증을 하지 않았다.
- 웹 빌드·서버 폴백, JavaScript 문법 검사를 통과했다.
- 1280px에서 읽기 흐름을 확인했다. 390px·320px에서 네 페이지 모두 가로 넘침이 없었다. 모바일 목차 이동, Enter 키로 오류 도움말 열기, 읽기 전용 코드의 복사 버튼 제거를 확인했다.
- 문장 안에 강조 문법 `**`가 그대로 노출되는 DocC 구문 문제를 수정하고, 재발 여부를 검증기에 추가했다.

실제 초보 독자의 무도움 완주와 소요 시간은 아직 측정하지 않았다. 실측 AR 확인 항목은 [2–4장 검증 기록](chapters-2-4-validation.md)을 따른다. 이 편집 이후 2026-09-20 기존 사이트 교체 요청에 따라 네 장과 다운로드를 소유자 전용 사이트에 게시했다.

## 참고

준비 안내는 설치된 Xcode 템플릿과 Apple의 [프로젝트 만들기](https://developer.apple.com/documentation/xcode/creating-an-xcode-project-for-an-app), [파일 추가](https://developer.apple.com/documentation/xcode/managing-files-and-folders-in-your-xcode-project), [기기에서 실행하기](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices)를 참고했다. 이전 가독성 조사와 실행 화면의 출처는 [피드백 대응 기록](tutorial-feedback-validation.md)에 남아 있다.
