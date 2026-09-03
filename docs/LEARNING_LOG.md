# 실패와 학습 기록

> 구현 중 발생한 실패·예상 밖 동작·검증 한계는 해결 여부와 관계없이 이 문서에 남긴다. 같은 증상을 다시 만났을 때 대화 기록이 아니라 재현 가능한 근거부터 확인하기 위한 기록이다. 사람·도구·모델 이름과 비밀 정보는 쓰지 않는다.

## 기록 규칙

- 실패한 테스트, 빌드, 실행, API/에셋 실험, 실기기 검증은 원인 확인 또는 중단 결정 전에 한 항목으로 기록한다.
- 항목에는 실패를 재현한 명령 또는 사용자 동작, 실제 관찰값, 영향 범위, 확인한 원인 또는 가설, 해결/보류 결정, 재발 방지 검증을 적는다.
- 가설은 가설로 표시한다. 확인하지 않은 내용을 원인으로 단정하지 않는다.
- 해결된 항목도 삭제하지 않는다. 후속 변경으로 재발하면 기존 항목 번호를 참조해 새 항목을 추가한다.
- 사용자 기기·권한·LiDAR처럼 이 환경에서 실행할 수 없는 검증은 `실기기 대기`로 기록하며 자동 테스트 성공으로 대체하지 않는다.

## 항목 형식

```markdown
### L-YYYYMMDD-순번 — 짧은 증상 제목

- 상태: 조사 중 | 해결 | 보류 | 실기기 대기
- 발생 태스크: Task N — 이름
- 재현: 실행한 명령 또는 사용자 동작
- 관찰: 실제 오류·출력·화면 결과
- 영향: 사용자 경험·빌드·테스트·문서 중 영향 범위
- 원인/가설: 확인 근거와 함께 작성
- 조치: 적용한 수정 또는 보류 이유
- 검증: 수정 후 실행한 명령·결과, 또는 남은 수동 검증
- 배운 점: 다음 작업에서 먼저 확인할 조건
```

## 항목

### L-20260903-159 — 성공한 Pages run에 공식 Actions Node 20 deprecation이 남음

- 상태: 해결
- 발생 태스크: 공개 DocC Pages 배포 후 workflow 정리
- 재현: PR #2 merge 뒤 `Deploy DocC` run `33708120700`의 annotation을 확인한다.
- 관찰: content·build·static·browser·deploy는 모두 성공했지만 checkout, configure-pages, setup-node와 upload-pages-artifact의 내부 upload action이 Node.js 20 기반이라 runner가 Node.js 24로 강제 실행한다는 deprecation 1건이 남았다.
- 영향: 이번 배포 결과는 유효하지만 향후 runner가 Node 20 action 호환 경로를 제거하면 동일 workflow가 실패할 수 있고, major tag만 사용하면 실행 코드가 가변적이다.
- 원인/가설: workflow가 현재 공식 release보다 이전 major인 checkout v4, configure-pages v5, setup-node v4, upload-pages-artifact v4, deploy-pages v4를 사용했다.
- 조치: 2026-09-03 공식 release API로 확인한 checkout v7.0.1, setup-node v7.0.0, configure-pages v6.0.0, upload-pages-artifact v5.0.0, deploy-pages v5.0.1의 commit SHA를 immutable하게 지정하고 verifier runtime을 Node 24로 올렸다.
- 검증: PR #3 merge commit `8315243`의 Pages run `33709409875`가 Node 24에서 content·build·static·browser·deploy를 모두 통과했고 build/deploy annotation은 각각 0건이다. 공개 11 route와 보정 script는 모두 HTTP 200, 공개 이미지 hash는 8/8 승인값과 일치하며 Chapter 3의 고지·컨셉 이미지·연결 코드를 desktop 1440×900과 mobile 390×844에서 확인했다.
- 배운 점: workflow 성공 여부와 action runtime deprecation은 분리해 확인하고, 공식 최신 major를 사용하더라도 release tag가 아닌 검증한 commit SHA로 고정한다.

### L-20260903-158 — 공통 h1 렌더만으로는 잘못된 route와 SPA 링크를 검출하지 못함

- 상태: 해결
- 발생 태스크: 공개 DocC 앱 화면 예시 보강 — rendered-browser gate 재검토
- 재현: 서로 다른 URL이 같은 h1을 렌더하는 fixture, 잘못된 root 목적지, 존재하지 않는 내부 route·fragment와 slash 없는 디렉터리 링크를 기존 browser verifier에 입력한다. dark profile에서만 console·network·접근성 오류가 나는 fixture도 실행한다.
- 관찰: 기존 verifier는 모두 같은 페이지를 보여 주거나 root가 overview로 이동하지 않아도 통과했고 rendered link를 검사하지 않았다. slash 없는 정상 디렉터리는 로컬 server에서 404였으며 light profile만 검사해 dark 전용 오류 세 종류도 놓쳤다.
- 영향: 정적 asset이 온전해도 공개 URL별 내용이 뒤바뀌거나 SPA 탐색 링크가 끊긴 상태, dark theme 회귀가 Pages에 배포될 수 있었다.
- 원인/가설: route 존재와 임의의 visible h1만 검사했고 route별 의미 계약, browser가 조립한 anchor/DOM fragment, Pages의 directory canonicalization과 색상 모드를 모델링하지 않았다.
- 조치: 고정 11 route와 정확한 h1, root 최종 pathname을 manifest로 검사한다. 렌더 뒤 same-origin anchor의 HTTP target·route·file·fragment를 수집하고 slash 없는 directory를 canonical URL로 301 이동시킨다. desktop/mobile×light/dark 네 profile에 같은 console·page·network·axe gate를 적용한다.
- 검증: 추가 계약의 RED를 각각 확인한 뒤 전체 contract 13/13, fresh archive 11 route×4 profile=44회, same-origin link 97개와 no-slash redirect 10개가 통과했다. 첫 확장 실행이 찾은 `#리소스`와 실제 `id="resources"` 불일치 4건도 산출물 보정 후 fragment 오류 0건으로 닫았다.
- 배운 점: 정적 route inventory 뒤에도 URL별 고유 heading, 실제 redirect, 렌더된 내부 link·fragment와 지원 theme를 브라우저 수준에서 별도로 검증한다.

### L-20260903-157 — 기본 격리 환경이 브라우저 검증기의 loopback listen을 거부함

- 상태: 해결
- 발생 태스크: 공개 DocC 앱 화면 예시 보강 — 최종 rendered-browser 검증
- 재현: 기본 격리 환경에서 `npm run test:docc-browser`를 실행한다.
- 관찰: 일곱 계약 테스트가 모두 `listen EPERM: operation not permitted 127.0.0.1`로 시작 전에 실패했다. fixture assertion이나 browser 결과에 도달하지 못했다.
- 영향: 구현 회귀와 무관한 로컬 socket 권한 때문에 rendered-browser gate의 최종 근거를 수집할 수 없었다.
- 원인/가설: 검증기가 임의 loopback port에 정적 서버를 열어야 하지만 기본 실행 권한은 local listen을 허용하지 않는다.
- 조치: 동일한 명령에 loopback listen과 headless browser 실행 권한만 허용해 다시 실행했다. CI runner에는 이 격리 제한이 없다.
- 검증: 재실행한 contract 13/13과 fresh archive 11 route×4 profile=44회가 모두 exit 0이다.
- 배운 점: browser gate가 fixture assertion 전에 전부 같은 listen 오류로 실패하면 제품 결함과 분리하고, 최소 local socket 권한으로 같은 명령을 재실행한다.

### L-20260903-156 — 정적 Pages 검사만으로 렌더링·접근성 회귀를 막지 못함

- 상태: 해결
- 발생 태스크: 공개 DocC 앱 화면 예시 보강 — Pages 배포 gate 최종 리뷰
- 재현: fresh DocC archive를 1440×900과 390×844에서 모든 공개 HTML route로 렌더링하고 console·page error·network response와 axe serious/critical 결과를 수집한다.
- 관찰: 정적 content·site verifier가 모두 통과한 산출물에서도 DocC Render가 만든 이름 없는 toggle·checkbox, `aria-label`을 지원하지 않는 기본 role, 키보드 초점을 받지 않는 스크롤 표, 일부 text contrast를 합쳐 보정 전 27건을 검출했다.
- 영향: 기존 workflow는 HTML·JSON·asset 존재만 확인하므로 runtime route 실패, 모바일 전용 console 오류와 심각한 접근성 위반을 그대로 배포할 수 있었다.
- 원인/가설: 정적 verifier는 브라우저가 JavaScript로 조립한 DOM·computed style·네트워크 수명과 접근성 tree를 실행하지 않는다. 일부 문제는 현재 Swift-DocC Render가 생성한 markup과 theme 조합에서만 나타난다.
- 조치: lockfile에 고정된 headless browser와 접근성 engine으로 정상·console·page error·HTTP·request failure·serious/critical 계약 테스트를 만들었다. 빌드 산출물에는 필요한 role·label·table focus·contrast만 결정론적으로 보정하는 script를 주입하고, artifact upload 전에 11 route를 desktop/mobile×light/dark에서 모두 검사한다.
- 검증: 계약 테스트 13/13, fresh archive 11 route×4 profile=44회가 통과했다. console warning/error·page error·request failure·HTTP 4xx/5xx와 axe serious/critical은 0건이고 dependency audit 취약점도 0건이다.
- 배운 점: 정적 DocC 구조 검증과 실제 browser 접근성 검증은 서로 대체할 수 없으므로 배포 전에 둘 다 실행한다.

### L-20260903-155 — 크기와 IHDR만 검사하면 다른 이미지와 손상 PNG를 승인함

- 상태: 해결
- 발생 태스크: 공개 DocC 앱 화면 예시 보강 — 이미지 무결성 최종 리뷰
- 재현: 승인 hero를 같은 크기로 다시 인코딩하거나, PNG signature와 IHDR 크기만 남긴 24-byte 파일로 바꿔 기존 image validator를 실행한다. compiled archive의 이미지 하나만 다른 유효 PNG로 바꿔 site verifier도 실행한다.
- 관찰: 세 변형 모두 기존 gate를 exit 0으로 통과했다. 파일명·IHDR 크기·서로 다른 bytes만 검사했기 때문에 승인된 시각 자료인지와 실제 전체 decode 가능 여부, source와 compiled copy의 동일성을 증명하지 못했다.
- 영향: 사용자가 지정한 네 hero와 승인된 네 앱 화면이 같은 크기의 다른 파일로 바뀌거나 손상돼도 Pages 배포를 막지 못했다.
- 원인/가설: 이미지 계약을 파일 목록과 header metadata로만 표현하고 승인된 content digest와 decoder 결과를 포함하지 않았다.
- 조치: 정확한 8개 PNG의 SHA-256을 content·site gate에 고정하고 전체 PNG decode를 필수화했다. site gate는 source와 compiled asset 양쪽의 승인 digest 및 byte identity까지 검사한다.
- 검증: 재인코딩 이미지, header-only PNG, source와 다른 compiled asset이 각각 새 gate에서 거절됐다. 원본 content verifier는 snippet 12/12와 함께 통과했고 기존 archive site verifier도 승인 digest·decode·byte identity를 통과했다.
- 배운 점: 고정된 시각 자산의 무결성은 경로·크기만으로 확인하지 말고 승인 digest, 완전 decode, 배포 산출물 동일성을 함께 검사한다.

### L-20260903-154 — 추가 shell 정적 분석 도구가 환경에 없음

- 상태: 해결
- 발생 태스크: 공개 DocC 앱 화면 예시 보강
- 재현: `shellcheck scripts/build-docc-site.sh scripts/verify-docc-content.sh scripts/verify-docc-site.sh`를 실행한다.
- 관찰: `shellcheck: command not found`로 exit 127이었다. 앞에 실행된 `git diff --check`는 출력 없이 통과했다.
- 영향: 선택적 shell lint 결과는 얻지 못했지만 실제 content/build/site gate 실행에는 영향이 없다.
- 원인/가설: 현재 작업 환경에 shellcheck 실행 파일이 설치되어 있지 않다.
- 조치: 범위를 넓혀 도구를 설치하지 않고 세 script의 `bash -n`, 실제 RED/GREEN 실행과 `git diff --check`로 대체 검증했다.
- 검증: `bash -n`과 `git diff --check`가 각각 exit 0이고 content verifier·DocC build·site verifier도 exit 0이다.
- 배운 점: 선택적 lint 의존성이 없는 저장소에서는 syntax 검사와 실제 gate 실행을 필수 기준으로 유지하고, lint 부재를 성공처럼 기록하지 않는다.

### L-20260903-153 — Chapter CTA와 현재 섹션 라벨의 DocC 현지화 누락

- 상태: 해결
- 발생 태스크: 공개 DocC 앱 화면 예시 보강
- 재현: 새 archive의 Chapter 3을 브라우저에서 열고 다음 CTA와 상단 현재 섹션 라벨을 읽는다.
- 관찰: 다음 CTA는 `Get started`, 상단은 `현재 {number}섹션`으로 렌더링됐다. 처음 `{number}섹션`을 정적 `섹션`으로 바꾼 시도는 네 section link까지 모두 같은 `섹션`으로 만들어 채택하지 않았다.
- 영향: 한국어 튜토리얼의 핵심 이동 동작과 현재 위치를 VoiceOver·시각 사용자 모두 부정확하게 읽는다.
- 원인/가설: build 후처리가 overview JSON 하나만 번역해 chapter call-to-action JSON을 놓쳤다. Swift-DocC Render의 한국어 `현재 {thing}`은 내부에서 다시 넘긴 `{number}섹션`을 중첩 보간하지 않는다.
- 조치: 모든 tutorial JSON의 compiler action title을 한국어로 바꾸고, 번호를 만드는 `{number}섹션`은 유지한 채 현재 상태 형식만 정적 `현재 섹션`으로 바꿨다. site verifier가 두 회귀를 함께 거부한다.
- 검증: 새 archive에서 site verifier가 exit 0이다. 1440×900과 390×844 브라우저에서 section link `1섹션`–`4섹션`, English CTA 0, 한국어 `시작하기`, AI 고지·이미지·관련 코드 연결을 확인했고 console warning/error는 0건이다.
- 배운 점: 중첩 번역 placeholder를 고칠 때 하위 label의 정보까지 제거하지 말고, 조합하는 상위 label만 정적으로 만들어야 한다.

### L-20260903-152 — Chapter 2의 정상 footer를 이미지 카드 중복으로 오인함

- 상태: 해결
- 발생 태스크: 공개 DocC 앱 화면 예시 보강
- 재현: 새 archive에서 `bash scripts/verify-docc-site.sh <archive>`를 실행한다.
- 관찰: DocC build는 warning 없이 성공했고 네 앱 화면 reference도 모두 생성됐지만, site verifier만 Chapter 2 `contentSection` 길이가 2라며 실패했다.
- 영향: 올바른 Chapter 2 문서가 배포 gate에서 거절됐다.
- 원인/가설: target task의 `contentSection` 전체가 앱 화면 카드 하나여야 한다고 가정했지만, `@Steps` 뒤의 `실기기 대기`와 이전·다음 링크는 별도 `fullWidth` block으로 컴파일된다.
- 조치: 전체 block 수가 아니라 `kind == contentAndMedia`인 block이 정확히 하나이고 기대 media를 가리키는지 검사한다. 후속 `fullWidth`는 보존한다.
- 검증: 같은 archive에 site verifier를 다시 실행해 5 documentation route, 5 tutorial route, 8 visual image, `ko-KR`, link·alt·asset 검사를 exit 0으로 통과했다.
- 배운 점: DocC task의 후속 설명은 별도 `fullWidth`가 될 수 있으므로 semantic 계약은 목적이 같은 block kind를 세고 무관한 정상 block을 금지하지 않는다.

### L-20260903-151 — 공개 DocC에 앱 화면 예시와 생성 이미지 고지가 없음

- 상태: 해결
- 발생 태스크: 공개 DocC 앱 화면 예시 보강
- 재현: 앱 화면 자산·고지·배치 계약을 verifier에 먼저 추가한 뒤 `bash scripts/verify-docc-content.sh`와 기존 archive 대상 `bash scripts/verify-docc-site.sh /tmp/piggyescape-final-docc-site-20260903`을 실행한다.
- 관찰: content verifier는 앱 화면 PNG 4장 부재, legacy icon 1장 잔존, 네 챕터 고지·image-before-code 부재를 합쳐 14 errors로 exit 1이었다. 기존 archive verifier도 네 앱 화면의 compiled/source asset·alt·고지가 없어 exit 1이었다. 기존 12개 snippet type-check는 12/12로 유지됐다.
- 영향: 공개 페이지는 챕터 개념 이미지만 보여 주고 실제 앱에서 무엇이 보이는지 코드와 연결해 설명하지 못한다.
- 원인/가설: 이전 Task 11은 챕터 대표 구조 도식 네 장만 계약으로 삼았고, 튜토리얼 본문용 앱 화면 예시는 자산·markup·배포 검증 대상이 아니었다.
- 조치: 첨부한 네 장을 대표 이미지로 보존하고, 실제 UI source를 근거로 한 세로형 앱 화면 예시 네 장을 생성한다. 각 튜토리얼에서 생성 이미지임을 명시하고 관련 `@Code`보다 먼저 배치한다. legacy icon은 제거한다.
- 검증: 새 source의 content verifier에서 8개 image asset, 네 앱 화면의 target section·related code 연결, 고유 alt와 12/12 snippet type-check를 exit 0으로 확인했다. 새 DocC archive도 8개 compiled image, 고지, route/link와 `ko-KR`을 site verifier로 확인했다.
- 배운 점: 대표 concept art와 화면 동작 예시는 목적이 다르므로 별도 자산·alt·provenance·compiler output 계약으로 관리한다.

### L-20260903-150 — 화면 구조 탐색에서 존재하지 않는 파일명을 사용함

- 상태: 해결
- 발생 태스크: 공개 DocC 앱 화면 예시 보강
- 재현: 실제 화면 구성을 읽기 위해 `PiggyEscape/PiggyEscape/Sources/Escape/ComparisonChapterView.swift`를 `sed`로 열려고 한다.
- 관찰: 해당 경로가 없어 `No such file or directory`가 출력됐고 앞서 지정한 다른 파일 읽기만 완료됐다.
- 영향: 소스나 산출물은 변경되지 않았지만 Chapter 4 화면 예시의 근거 파일을 아직 읽지 못했다.
- 원인/가설: 파일 목록에는 `ComparisonView.swift`가 있는데 화면 역할을 보고 존재하지 않는 이름을 추정했다.
- 조치: `rg --files` 결과의 실제 `ComparisonView.swift`만 사용하고 추정 경로를 다시 사용하지 않는다.
- 검증: 실제 파일을 읽어 Chapter 4 이미지와 설명을 현재 UI 구조에 맞춘다.
- 배운 점: 화면 이름을 추정하지 말고 파일 목록에서 확인한 경로를 그대로 사용한다.

### L-20260903-149 — Swift 6 strict test compile에 RealityKit 헬퍼 격리 경고가 남음

- 상태: 해결
- 발생 태스크: Task 9 Swift 6 준비 — test helper isolation 정리
- 재현: `xcodebuild -quiet -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'generic/platform=iOS' -derivedDataPath /tmp/piggyescape-task9-controller-swift6-20260903 CODE_SIGNING_ALLOWED=NO SWIFT_VERSION=6 SWIFT_STRICT_CONCURRENCY=complete build-for-testing`을 실행한다.
- 관찰: build-for-testing은 exit 0이었지만 `RealityPigVisualControllerTests.swift`의 `makeFiniteCrossAxisOverflowModel`, `makeLargeFiniteAnisotropicTransformModel`, `completePoseLoad`가 RealityKit의 main actor-isolated 생성·프로퍼티·메서드를 nonisolated 전역 함수에서 사용한다는 경고를 출력했다.
- 영향: production 동작과 strict gate 성공에는 영향이 없지만 테스트 bundle이 Swift 6에서 경고 없이 준비됐다고 말할 수 없다.
- 원인/가설: 테스트 클래스와 호출 지점은 `@MainActor`인데 세 전역 helper만 격리 표기가 빠져 호출 대상 RealityKit API의 actor 계약이 함수 시그니처에 보존되지 않았다.
- 조치: 세 helper에 `@MainActor`를 명시하고 production 코드나 테스트 의미는 변경하지 않는다.
- 검증: 서로 다른 새 DerivedData에서 Swift 6 strict와 Swift 5 generic iPhoneOS `build-for-testing`이 모두 exit 0이었다. 세 helper의 actor-isolation 경고는 다시 출력되지 않았고, 남은 출력은 Xcode가 목적지 선택과 무관하게 초기화하는 CoreSimulator service 및 로컬 provisioning profile 환경 진단뿐이었다.
- 배운 점: actor-isolated 테스트 클래스 밖으로 RealityKit fixture 생성을 분리할 때 helper 자체에도 같은 격리 계약을 표기한다.

### L-20260903-148 — paired·DDI-ready 실기기도 현재 passcodeRequired면 XCTest를 시작하지 않음

- 상태: 실기기 대기
- 발생 태스크: Task 9 Swift 6 준비 — C3 cancellation lifetime
- 재현: `xcrun devicectl device info details --device 00008140-0008385214C0801C`와 `xcrun devicectl device info lockState --device 00008140-0008385214C0801C`를 read-only로 실행한다.
- 관찰: 제한된 details 조회는 CoreDeviceService 초기화 timeout으로 exit 1이었다. 승인된 read-only 재확인은 paired physical iPhone 16 Pro, iOS 26.6, Developer Mode enabled, DDI available, tunnel connected를 확인했고 lock state는 `unlockedSinceBoot: true`, `passcodeRequired: true`였다.
- 영향: 새 Sendable/deinit 회귀와 기존 Reduce Motion 회귀의 physical assertion runtime을 이번 범위에서 실행할 수 없다. production·test bundle compile 결과와 runtime 결과를 분리해야 한다.
- 원인/가설: 기기는 연결·개발 준비 상태지만 현재 잠겨 있다. source, signing 또는 destination 부재가 원인이 아니다.
- 조치: 잠금 우회, Simulator 대체, 무기한 대기 없이 physical focused 실행을 생략했다. UI target·fixture·XCUITest도 명시적 no-Simulator 범위에 따라 계속 보류한다.
- 검증: 이번 Task 9 physical runtime은 0건이다. 잠금 해제 뒤 `C3ClosedWorldSceneViewOwnershipTests` focused 9개와 full 190개 suite를 새 DerivedData로 실행한다.
- 배운 점: `paired`, DDI usable, tunnel connected만으로 테스트 실행 가능성을 판단하지 말고 바로 전 read-only `lockState`의 `passcodeRequired`를 gate로 사용한다.

### L-20260903-147 — cancellation existential의 Sendable 소거가 nonisolated deinit을 막음

- 상태: 해결
- 발생 태스크: Task 9 Swift 6 준비 — C3 cancellation lifetime
- 재현: compile-time Sendable 계약과 실제 coordinator deinit 취소 회귀를 먼저 추가한 뒤 `xcodebuild -quiet -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'generic/platform=iOS' -derivedDataPath /tmp/piggyescape-task9-red-swift6-20260903 CODE_SIGNING_ALLOWED=NO SWIFT_VERSION=6 SWIFT_STRICT_CONCURRENCY=complete build-for-testing`을 실행한다.
- 관찰: fresh app compile이 `C3ClosedWorldSceneView.swift:135:30`의 `cannot access property 'autoDiscoveryTask' with a non-Sendable type '(any C3AutoDiscoveryCancellable)?' from nonisolated deinit`로 exit 65, `TEST BUILD FAILED`가 됐다. note는 cancellation 프로토콜이 `Sendable`이 아님을 직접 가리켰다.
- 영향: Swift 5 production 동작과 별개로 Swift 6 strict preparation gate가 막혔고, coordinator 파괴 시 pending 예약을 취소하는 필수 cleanup을 제거해서는 해결할 수 없었다.
- 원인/가설: `@MainActor Coordinator`가 실제로는 immutable `Task<Void, Never>` wrapper를 보관하지만, 이를 `Sendable`을 보장하지 않는 프로토콜 existential로 지워 nonisolated deinit에서 안전한 storage임을 compiler가 증명할 수 없었다. 프로토콜에 checked `Sendable` 계약 한 줄만 추가한 뒤 같은 경계가 통과해 가설을 확인했다.
- 조치: production `C3AutoDiscoveryCancellable`을 `AnyObject & Sendable` 계약으로 만들고 immutable Task wrapper의 compiler-checked conformance를 사용했다. deinit과 dismantle cleanup, MainActor scheduling/callback, Reduce Motion 동작은 유지했다. mutable test double만 `@unchecked Sendable`이며 생성·보관·취소·fire와 coordinator release가 모두 `@MainActor` test/scheduler 안에서 일어난다는 제한을 코드에 명시했다.
- 검증: production 변경 뒤 fresh generic iPhoneOS Swift 6 strict `build-for-testing`이 exit 0으로 app·unit-test target을 compile/link했고, fresh Swift 5 generic iPhoneOS `build-for-testing`도 exit 0이었다. test source는 compile-time Sendable 계약, 반복 dismantle과 실제 coordinator deinit의 정확히 한 번 취소를 포함한다. 물리 runtime은 L-20260903-148의 잠금 때문에 0건이다.
- 배운 점: actor-isolated owner의 deinit cleanup은 구체 storage를 non-Sendable existential로 지우지 않아야 한다. 실제 immutable Sendable 자원은 checked 프로토콜 계약으로 보존하고, cleanup 제거나 unsafe isolation suppression으로 compiler만 침묵시키지 않는다.

### L-20260903-146 — 연결 worktree의 기본 권한은 Git index lock 생성을 막음

- 상태: 해결
- 발생 태스크: Task 13 최종 리뷰 보수 commit
- 재현: 수정 범위 15개 파일을 명시한 `git add`를 worktree 기본 권한으로 실행한다.
- 관찰: 공용 metadata의 `.git/worktrees/ch1-reality-escape/index.lock` 생성이 `Operation not permitted`로 실패해 exit 128이었다. working tree 파일에는 변화가 없었다.
- 영향: 검증된 수정이 아직 index에 올라가지 않았고 commit을 만들 수 없다.
- 원인/가설: 연결 worktree의 Git metadata가 작업 디렉터리 바깥 공용 `.git` 아래 있어 기본 filesystem sandbox의 쓰기 범위를 벗어난다.
- 조치: 같은 명시적 파일 목록의 `git add`와 이후 commit만 승인된 권한으로 재실행한다. 다른 파일·브랜치·원격은 건드리지 않는다.
- 검증: 승인 실행 뒤 staged 목록을 `git diff --cached --name-only`로 확인하고 commit 후 worktree 상태를 재확인한다.
- 배운 점: source 수정 권한과 연결 worktree의 index/commit 권한은 분리되므로 staging failure를 source failure로 해석하지 않는다.

### L-20260903-145 — 로컬 Ruby가 `Array#filter_map`을 지원하지 않음

- 상태: 해결
- 발생 태스크: Task 13 최종 리뷰 보수 — Pages workflow gate 검증
- 재현: Ruby로 workflow의 run step 순서를 파싱하면서 `steps.filter_map { ... }`을 호출한다.
- 관찰: YAML parse와 step 출력은 성공했지만 semantic assertion one-liner가 `undefined method 'filter_map' for Array`로 exit 1이었다.
- 영향: workflow 자체 오류가 아니라 로컬 Ruby 호환성 때문에 gate-order assertion이 실행되지 않았다.
- 원인/가설: 이 호스트의 Ruby는 `Array#filter_map` 도입 전 버전이다.
- 조치: 같은 YAML 구조 검사를 `map { ... }.compact`로 다시 작성한다.
- 검증: `map { ... }.compact` 호환 one-liner가 content→build→site 순서와 `scripts/verify-docc-content.sh` path filter를 확인하고 exit 0으로 끝났다.
- 배운 점: 저장소 검증용 임시 명령도 macOS 기본 Ruby 버전을 가정하지 말고 오래 지원된 collection API를 사용한다.

### L-20260903-144 — available 실기기도 잠금 상태면 XCTest 실행 직전에 멈춤

- 상태: 보류
- 발생 태스크: Task 13 최종 리뷰 보수 — Chapter 1 Reduce Motion
- 재현: `cd PiggyEscape && xcodebuild -project PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS,id=00008140-0008385214C0801C' -derivedDataPath /tmp/piggyescape-reduce-motion-focused-20260903 -only-testing:PiggyEscapeTests/C3ClosedWorldSceneViewOwnershipTests DEVELOPMENT_TEAM=GMLPV8QDSK CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates test`
- 관찰: read-only CoreDevice 목록은 iPhone을 `available (paired)`로 표시했고 app·test bundle arm64 compile, provisioning, signing까지 성공했다. 실행 직전 Xcode가 `Unlock YES iPhone to Continue`로 대기해 60초 뒤 수동 중단했으며 exit 75, 실행 테스트 0건이었다.
- 영향: 기준 commit의 physical unit suite 186/186은 유효하지만, 새 Reduce Motion 2개를 포함한 현재 정적 188개 전체 runtime green은 아직 주장할 수 없다.
- 원인/가설: signing이나 source 문제가 아니라 테스트 시작 시점의 device lock 상태다. `available`은 `unlocked`를 보장하지 않는다.
- 조치: 잠금 우회나 기기 설정 변경 없이 대기 실행을 중단했다. 기기가 unlocked 상태일 때 새 DerivedData로 focused 2개와 전체 188개를 다시 실행한다.
- 검증: 같은 변경의 generic iPhoneOS `build-for-testing`은 exit 0이고, 실제 기기용 app·test bundle도 compile·sign까지 완료했다. assertion runtime은 잠금 해제 뒤 재검증 대기다.
- 배운 점: physical XCTest 전에는 paired availability뿐 아니라 현재 unlock 상태도 확인하고, compile/sign 근거와 assertion 실행 근거를 분리한다.

### L-20260903-142 — Swift 6 strict diagnostic은 cancellation handle 격리에서 계속 중단됨

- 상태: 보류
- 발생 태스크: Task 13 — 전체 회귀·실기기·공개 배포
- 재현: `cd PiggyEscape && xcodebuild -project PiggyEscape.xcodeproj -scheme PiggyEscape -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/piggyescape-task13-swift6-20260903 SWIFT_VERSION=6 SWIFT_STRICT_CONCURRENCY=complete CODE_SIGNING_ALLOWED=NO build`
- 관찰: 최신 보수 뒤 fresh generic iPhoneOS arm64 compile도 `C3ClosedWorldSceneView.swift:135:30`에서 `cannot access property 'autoDiscoveryTask' with a non-Sendable type '(any C3AutoDiscoveryCancellable)?' from nonisolated deinit` 오류로 exit 65, `** BUILD FAILED **`가 됐다.
- 영향: Swift 5 설정의 앱·unit-test bundle compile/link 성공과 별개로 Swift 6 strict concurrency 지원을 주장할 수 없다. Task 9에서 요구한 ownership test와 UI fixture도 아직 없다.
- 원인/가설: `Coordinator`의 nonisolated `deinit`이 `Sendable`이 아닌 취소 handle을 직접 접근한다는 compiler 진단이 L-20260829-109의 보류 원인과 일치한다.
- 조치: Task 13 범위를 넘는 Swift 6 concurrency 보수나 UI fixture 구현은 하지 않고, 별도 Task 9 범위로 보류한다.
- 검증: Reduce Motion 보수까지 포함한 같은 worktree의 Swift 5 generic iPhoneOS Release build와 `build-for-testing`은 각각 exit 0이었다. strict diagnostic 재실행은 동일 경계에서 exit 65였다.
- 배운 점: language-mode preparation gate의 fresh failure는 production Swift 5 build 성공과 분리해 기록하고, Task 9 계약이 없는 상태에서 임의로 동시성 수명을 바꾸지 않는다.

### L-20260903-143 — 실기기 XCTest는 bootstrap·assertion·후속 연결 상태를 구분해야 함

- 상태: 해결
- 발생 태스크: Task 13 — 전체 회귀·실기기·공개 배포
- 관찰: ready device의 첫 full `PiggyEscapeTests`는 test runner가 code 0으로 종료해 bootstrap system failure 1개(total 1, passed 0, failed 1)로 끝났다. 새 DerivedData rerun은 185개 중 182개 통과·3개 assertion failure를 분리했다. cycle anchor의 `ObjectIdentifier` 재사용, retry exhaustion의 scan 안내 누락, 실제 RealityKit의 large finite post-scale bounds와 다른 fixture 기대가 각각 원인이었다. 보수 뒤 physical focused 3/3은 exit 0으로 통과했다.
- 영향: focused green만으로 full green을 주장할 수 없었고, 당시 final rerun은 device unavailable timeout으로 시작 전 끝났다. 후속 read-only check에서 device가 available·DDI usable로 복귀한 뒤, reviewed root message contract를 포함한 fresh full suite는 186/186, exit 0으로 통과했다.
- 조치: cycle UUID, low-level message 제거, root-owned approved sentence, large-finite fixture characterization을 source/test에 반영했다. 기기 설정·data는 바꾸지 않았다.
- 검증: RED physical run은 2 tests/3 assertion failures였고, corrected focused run 4/4와 final full `PiggyEscapeTests` 186/186은 exit 0, `TEST SUCCEEDED`였다. 종료 후 partial `devicectl diagnose` warning은 assertion result와 분리한다.
- 배운 점: XCTest bootstrap failure, 실제 assertion failure, post-run diagnostic warning, device connectivity timeout은 서로 다른 근거이며 서로 대체할 수 없다.

### L-20260903-141 — 제한된 CoreDevice 조회 실패는 실기기 부재의 증거가 아니었음

- 상태: 해결
- 발생 태스크: Task 13 — 전체 회귀·실기기·공개 배포
- 재현: `xcrun devicectl list devices`
- 관찰: 제한된 최초 조회는 `Timed out waiting for CoreDeviceService to fully initialize`로 exit 1이었다. 후속 승인된 read-only `devicectl list devices`는 paired physical iPhone 16 Pro(iPhone17,1)를, `device info details`는 iOS 26.6, booted, `unlockedSinceBoot: true`, `passcodeRequired: false`, Developer Mode enabled, DDI `isUsable: true`, tunnel connected를 확인했다.
- 영향: signed app install·launch와 physical XCTest가 안전 범위에서 가능해졌다. 다만 final rerun 시 device는 별도로 unavailable로 전이했다(L-20260903-143).
- 조치: 기기 설정·data는 바꾸지 않았고 documented signing override로만 app/test bundle을 실행했다.
- 검증: app install와 process launch는 exit 0이고 지속 process를 확인했다. visual/LiDAR acceptance는 사용자 상호작용·capture가 없어 관찰하지 않았다.
- 배운 점: 제한된 환경의 CoreDevice 초기화 오류는 transient host condition일 수 있으므로, 승인된 read-only 재확인 결과로 device availability 판단을 정정해야 한다.

### L-20260903-140 — 연결 worktree의 제한된 fetch 실패는 승인된 원격 확인으로 해소됨

- 상태: 해결
- 발생 태스크: Task 13 — 전체 회귀·실기기·공개 배포
- 재현: `git fetch --prune origin`
- 관찰: `/Users/yang-eunseo/Downloads/SpatialComputing_TechMap/.git/worktrees/ch1-reality-escape/FETCH_HEAD`를 열 수 없어 `Operation not permitted`로 종료했다. 이어 `git status --short`에는 tracked 또는 untracked 변경이 없었다.
- 영향: 이 기본 권한 실행만으로는 원격 참조를 갱신할 수 없었지만, remote freshness 자체가 미확정이라는 결론은 유지되지 않는다.
- 원인/가설: L-20260901-131과 같은 연결 worktree 공용 Git metadata 쓰기 제약이다.
- 조치: controller의 승인된 `git fetch --prune origin`이 exit 0으로 완료했다. 이는 remote 내용을 작업 트리에 merge하거나 push하지 않는 fetch-only 확인이다.
- 검증: Task 13 최초 commit 전 `origin/main...HEAD`는 behind 0/ahead 69이고 `origin/main`은 ancestor였으며, `origin/ch1-reality-escape...HEAD`는 behind 0/ahead 34였다.
- 배운 점: fetch 권한 실패는 source/build failure와 분리하되, 후속 승인된 fetch가 성공하면 이전 remote-unknown 기록을 정확한 topology로 정정한다.

### L-20260903-139 — DocC compile 성공만으로 브라우저 문구와 hosting 경로를 보장할 수 없음

- 상태: 해결
- 발생 태스크: Task 12 — DocC 접근성·Pages build/verify·브라우저 검증
- 재현: hosting base path를 붙여 DocC archive를 정적 사이트로 만든 뒤 overview를 desktop·mobile 브라우저에서 연다.
- 관찰: compiler는 성공했지만 render runtime의 영어 기본 locale과 복수형 placeholder가 화면에 남을 수 있었고, 문서 링크에 hosting base path가 중복될 여지도 있었다.
- 영향: 정적 파일 존재 검사만 통과하고도 공개 화면에 `{count}` 같은 placeholder가 보이거나 문서 링크가 404가 될 수 있었다.
- 원인/가설: compiler가 생성한 navigation JSON과 browser runtime의 locale·pluralization·base-path 처리는 서로 다른 검증 경계다.
- 조치: build 단계에서 locale과 알려진 plural template을 결정적으로 보정하고, JSON 제목·`doc:` 링크·route·asset을 별도 verifier로 검사했다. 마지막으로 desktop·mobile 브라우저에서 실제 동작 이름, 링크, 이미지, console과 요청 상태를 확인했다.
- 검증: overview·Chapter 1·2 모바일 렌더링과 desktop overview가 정상이고, `ko-KR`, 한국어 동작 제목, 미해결 `doc:` 0건, console 오류·경고 0건, 전체 정적 요청 200을 확인했다.
- 배운 점: DocC 공개 품질은 compiler exit뿐 아니라 archive 의미 검사, hosting base path를 포함한 정적 사이트 검사, 실제 브라우저 렌더링의 세 경계로 나눠 확인한다.

### L-20260903-138 — launch screen 선언 누락이 현대 iPhone에서도 legacy 호환 viewport를 만들 수 있음

- 상태: 해결
- 발생 태스크: Task 8 통합 보수 — 화면 비율과 safe area
- 재현: 기존 앱을 세로 iPhone 화면에서 열어 카메라·SceneKit content가 화면 중앙의 약 3:2 영역에만 보이고 상하가 검게 남는지 확인한다.
- 관찰: SwiftUI의 safe-area 처리만으로 설명하기 어려운 레터박스가 첨부 화면에 있었고, 생성 Info.plist에는 launch storyboard와 `UILaunchScreen` 선언이 모두 없었다.
- 영향: 돼지가 실제 크기보다 훨씬 크게 보이고 AR 화면의 유효 영역이 줄어, 물체를 탭하고 옆으로 이동해 찾는 행동 자체가 어려웠다.
- 원인/가설: launch screen 메타데이터가 없는 앱이 legacy compatibility viewport로 시작한 것이 첨부 화면과 가장 일치했다.
- 조치: Tuist target Info.plist에 빈 `UILaunchScreen` dictionary를 추가하고, 전체 화면을 무조건 확장하던 root safe-area modifier는 제거해 C3·AR 배경 계층에서만 확장하도록 분리했다.
- 검증: Tuist 재생성 뒤 생성 Info.plist에 `UILaunchScreen` dictionary가 포함됐고 최신 generic iPhoneOS build가 exit 0이었다. 실제 화면 비율은 Simulator를 실행하지 않았으므로 `실기기 대기`다.
- 배운 점: 현대 SwiftUI 레이아웃의 레터박스처럼 보여도 먼저 생성된 앱 메타데이터의 launch-screen 계약과 compatibility mode를 확인한다.

### L-20260903-137 — accepted marker의 cylinder 생성 API가 배포 하한보다 높음

- 상태: 해결
- 발생 태스크: Task 7 — 실제 스캔 피드백과 Chapter 2–3 root routing
- 재현: `xcodebuild -workspace PiggyEscape.xcworkspace -scheme PiggyEscape -destination 'generic/platform=iOS' -derivedDataPath /tmp/piggyescape-task7-compile-20260903 CODE_SIGNING_ALLOWED=NO build-for-testing -quiet`
- 관찰: `MeshResource.generateCylinder(height:radius:)`가 iOS 18 이상에서만 제공되어 iOS 17 deployment target의 `RealityAcceptedSurfaceMarker.swift` compile이 실패했다.
- 영향: 실제 인식 지점 marker를 추가한 앱 타깃과 test bundle이 link되지 않았다.
- 원인/가설: marker의 얇은 원판 형태를 만들 때 배포 하한에서 사용할 수 없는 최신 RealityKit convenience API를 선택했다.
- 조치: iOS 17에서 제공되는 sphere mesh를 Y축 0.08 배율로 납작하게 만들고, pulse도 같은 축 비율을 유지하도록 바꿨다.
- 검증: 같은 generic iPhoneOS arm64 `build-for-testing` 재실행이 exit 0으로 끝났다. Simulator와 XCTest runtime은 실행하지 않았고 실제 marker 위치·normal 정렬·pulse는 `실기기 대기`다.
- 배운 점: RealityKit primitive convenience API도 deployment availability를 먼저 확인하고, 낮은 배포 하한에서는 기존 primitive와 transform 조합을 우선한다.

### L-20260901-136 — Task 6 RED 준비의 Tuist 세션 기록이 권한으로 중단됨

- 상태: 해결
- 발생 태스크: Task 6 — AR coordinator를 cycle별 5점 관찰과 bounded retry에 연결
- 재현: `cd PiggyEscape && tuist generate --no-open`
- 관찰: 새 provider 테스트를 추가한 뒤 Tuist가 `/Users/yang-eunseo/.local/state/tuist/sessions/A6E52E37-7CFE-41F4-B8D3-E2749E005EB2`에 쓸 수 없어 exit 133과 `Permission denied`로 종료됐다.
- 영향: 최초 실행에서는 새 테스트 파일이 생성 Xcode project에 반영되지 않아 provider 타입 부재 compile RED 관찰이 지연됐다.
- 원인/가설: 이전 L-20260901-128·133과 같은 작업 트리 밖 Tuist session 상태 경로 쓰기 제한이다.
- 조치: 같은 `tuist generate --no-open` 명령을 session 상태 쓰기 권한으로 재실행해 프로젝트를 생성했다.
- 검증: 프로젝트 생성 성공 뒤 provider 타입 부재 상태의 fresh generic iOS `build-for-testing`이 exit 65로 실패했고, Task 6 구현·테스트 정리 뒤 `/tmp/piggyescape-task6-compile-20260901`의 같은 기기 대상 compile/link가 exit 0으로 성공했다. Simulator와 XCTest runtime은 실행하지 않았다.
- 배운 점: 새 source/test glob을 반영하는 Tuist 생성은 환경 준비 단계이며, 그 실패를 제품 RED로 세지 않는다.

### L-20260901-135 — exact 15° forward 정규화가 cosine보다 한 Float ULP 커짐

- 상태: 해결
- 발생 태스크: Task 5 검토 보수 2차 — exact 15° Float 경계
- 재현: `angle = Float.pi / 12`로 `(sin(angle), 0, -cos(angle))` forward를 만들고 monitor와 같이 정규화한 뒤 reference forward와 dot을 비교한다.
- 관찰: 정규화된 dot bit pattern은 `0x3f7746eb`, `cos(minimumRotation)`은 `0x3f7746ea`여서 수학적으로 exact 15°인 기존 fixture가 strict `<= cos` 비교에서는 거절된다. 반면 15°보다 0.000002rad 작은 fixture는 이 한 ULP 상한보다도 크다.
- 영향: 문서 계약상 포함돼야 하는 exact 15° 회전이 movement latch를 만들지 못할 수 있었다.
- 원인/가설: Float 삼각함수 결과로 만든 벡터를 다시 정규화하면서 발생한 한 representable-step 반올림 차이다.
- 조치: 비교 상한만 `cos(Self.minimumRotation).nextUp`으로 바꿨다. 이전 임의 `0.000001` 허용오차는 복원하지 않았다.
- 검증: 기존 `test_exactFifteenDegreeRotationLatchesMovement`와 `test_rotationTwoMillionthsOfARadianBelowThresholdDoesNotLatch`를 그대로 유지했다. RED 상태 `/tmp/piggyescape-task5-fix2-red-compile-20260901`와 수정 뒤 fresh `/tmp/piggyescape-task5-fix2-green-20260901`에서 전체 source+test bundle이 각각 exit 0, `** TEST BUILD SUCCEEDED **`였다. 사용자 지시에 따라 assertion runtime은 실행하지 않았다.
- 배운 점: 각도 경계의 Float 보정은 임의 epsilon이 아니라 fixture 계산에서 필요한 최소 representable step으로 제한한다.

### L-20260901-134 — Task 5 검토 regression은 compile되지만 runtime assertion은 보류됨

- 상태: 보류
- 발생 태스크: Task 5 검토 보수 1차 — 실제 3D corner·정확한 3cm/15° 경계
- 재현: production 수정 전 새 `/tmp/piggyescape-task5-fix1-red-compile-20260901`에서 generic iOS Simulator `build-for-testing`을 실행한다.
- 관찰: 새 regression을 포함한 앱·테스트 bundle은 arm64·x86_64로 compile/link되어 exit 0, `** TEST BUILD SUCCEEDED **`로 끝났다. compile-only 명령은 assertion을 실행하지 않으므로 실패 개수를 만들지 않는다.
- 영향: 네 테스트가 현재 구현에 대해 갖는 RED 조건은 fixture의 정확한 Float 비교와 source 분기로 정적으로 확인했지만, 현재 최종 diff의 focused 35개·전체 158개 assertion runtime 성공은 증명되지 않았다.
- 원인/가설: 사용자가 Simulator 실행을 금지하고 DocC를 우선하도록 지정했기 때문에 Simulator를 부팅하거나 XCTest `test` action을 실행하지 않았다.
- 조치: RED 상태 compile과 GREEN 상태 fresh compile을 각각 보존하고, 테스트 실행 결과와 혼동하지 않는다. runtime assertion은 허용된 실행 destination이 생길 때까지 `실행 검증 대기`로 둔다.
- 검증: 수정 뒤 새 `/tmp/piggyescape-task5-fix1-green-20260901`의 동일한 `build-for-testing`도 exit 0, `** TEST BUILD SUCCEEDED **`였고 앱·test bundle 두 architecture가 link됐다.
- 배운 점: 기존 interface의 의미 보수는 테스트가 compile되는 RED일 수 있으므로, 실행 금지 환경에서는 정적 반례와 compile 건전성을 분리해 보고해야 한다.

### L-20260901-133 — Task 5 검토 첫 compile이 생성 프로젝트 경로 부재로 무효 종료됨

- 상태: 해결
- 발생 태스크: Task 5 검토 보수 1차 — 실제 3D corner·정확한 3cm/15° 경계
- 재현: 저장소 worktree 루트에서 `xcodebuild -project PiggyEscape.xcodeproj ... build-for-testing`을 실행한다.
- 관찰: 루트에 생성물 `PiggyEscape.xcodeproj`가 없어 exit 66과 `xcodebuild: error: 'PiggyEscape.xcodeproj' does not exist.`로 종료됐다. 이어 `PiggyEscape`에서 기본 권한으로 실행한 `tuist generate --no-open`은 사용자 session 상태 경로의 `Permission denied`로 exit 133이었다.
- 영향: 두 실행 모두 Swift source나 test를 compile하지 않아 RED 또는 GREEN 근거가 아니다.
- 원인/가설: 생성 Xcode project는 추적하지 않으며 `PiggyEscape` 하위에서 다시 생성해야 하고, Tuist session은 worktree 밖 사용자 상태 경로 쓰기를 요구한다.
- 조치: `PiggyEscape`에서 session 상태를 쓸 수 있는 권한으로 같은 Tuist 명령을 재실행한 뒤, 생성 project가 있는 같은 디렉터리에서 xcodebuild를 실행했다.
- 검증: Tuist 재실행은 exit 0, `Project generated`, `✔ Success`였고 후속 RED 상태·GREEN 상태 compile은 모두 source와 test bundle을 끝까지 link했다.
- 배운 점: compile evidence를 수집하기 전에 현재 디렉터리와 ignored 생성 project 존재를 확인하고, 환경 준비 실패를 제품 RED로 세지 않는다.

### L-20260901-132 — AABB·덧셈·각도 허용오차가 경계 계약을 바꿈

- 상태: 해결
- 발생 태스크: Task 5 검토 보수 1차 — 실제 3D corner·정확한 3cm/15° 경계
- 재현: production 수정 전에 world 세 축 AABB는 모두 양수지만 affine rank가 2인 여덟 unique corner, 하나를 복제한 3D box corner, `mesh=Float(bitPattern: 0x3e99999a)`·`pig=Float(bitPattern: 0x3ea8f5c3)`, 그리고 15°보다 0.000002rad 작은 forward를 regression으로 고정한다.
- 관찰: 기존 sampler는 앞의 두 corner 집합을 허용했다. Float fixture는 `pig > mesh + margin`이 false지만 `pig - mesh > margin`은 true이고, 기존 cosine의 `+0.000001`은 가까운 subthreshold 회전을 movement로 latch하는 분기였다.
- 영향: 평면/손상 bounds가 유효 silhouette로 사용되거나 정확히 3cm·15°인 사용자 계약이 계산 순서와 임의 허용오차 때문에 달라질 수 있었다.
- 원인/가설: world AABB의 세 component 크기는 affine rank를 증명하지 않으며, 부동소수점 덧셈과 뺄셈은 경계에서 같은 비교가 아니다. cosine 허용오차도 명시 threshold보다 작은 회전을 수용했다.
- 조치: 여덟 corner 유일성 및 Double normalized triple product 기반 rank 3을 요구하고, finite `pigDistance - meshDistance > margin`을 사용하며, cosine 비교에서 허용오차를 제거했다. nonfinite 거리 차는 `.invalid`로 방어한다.
- 검증: 네 regression source가 먼저 추가됐고 수정 뒤 전체 source+test bundle이 fresh generic compile/link에 성공했다. runtime assertion은 L-20260901-134의 실행 제한에 따라 보류한다.
- 배운 점: 회전된 geometry는 축별 extent가 아니라 affine 독립성을 검증하고, 물리 threshold는 명세에 적힌 산술 순서와 부등호를 그대로 구현한다.

### L-20260901-131 — Task 5 시작 fetch가 연결 worktree metadata 권한에서 중단됨

- 상태: 해결
- 발생 태스크: Task 5 — view-space 5점 가림·재발견 순수 정책
- 재현: 구현 전 `git fetch --prune origin`을 기본 권한으로 실행한다.
- 관찰: 공용 `.git/worktrees/ch1-reality-escape/FETCH_HEAD`를 열 수 없다는 `Operation not permitted`로 원격 참조 갱신 전에 종료됐다.
- 영향: 기본 권한 실행만으로는 Task 5 시작 시점의 원격 변경 여부를 확정할 수 없었다. tracked worktree는 base `6a3a94d`에서 깨끗했다.
- 원인/가설: L-20260830-117과 같은 연결 worktree 공용 Git metadata 쓰기 제약이다.
- 조치: 동일한 fetch 명령만 공용 metadata에 쓸 수 있는 권한으로 재실행했다.
- 검증: 권한 있는 재실행은 출력 없이 exit 0으로 완료됐고, 이후 구현은 갱신된 원격 참조와 clean base에서 시작했다.
- 배운 점: 태스크 시작 fetch 실패는 반복 환경 제약이어도 현재 base와 재시도 성공을 독립적으로 남긴다.

### L-20260901-130 — Task 5 정책 assertion은 Simulator 제외 요청으로 실행하지 않음

- 상태: 보류
- 발생 태스크: Task 5 — view-space 5점 가림·재발견 순수 정책
- 재현: `xcodebuild -project PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/piggyescape-task5-final-compile-20260901 CODE_SIGNING_ALLOWED=NO build-for-testing`
- 관찰: 앱과 전체 테스트 bundle이 arm64·x86_64로 컴파일되어 exit 0, `** TEST BUILD SUCCEEDED **`로 끝났다. 정책·planner focused 테스트는 정적으로 31개이고 전체 테스트는 정적으로 154개지만, generic destination은 assertion을 실행하지 않는다.
- 영향: 새 타입·모든 테스트 소스·기존 coordinator 호환 경계의 컴파일 건전성은 확인했으나 5점·3cm·unique timestamp·60 frame·deadline·movement latch assertion의 runtime 성공은 아직 증명되지 않았다.
- 원인/가설: 사용자가 Simulator를 사용하지 않고 DocC를 우선하도록 명시했으므로 Simulator를 부팅하거나 test action을 실행하지 않았다.
- 조치: compile-only 결과와 runtime gate를 분리한다. Task 5 테스트 assertion은 사용자가 허용한 실기기 또는 Simulator 실행 환경에서 focused 31개와 전체 suite를 실제 실행할 때까지 `실행 검증 대기`로 유지한다.
- 검증: build product와 test bundle은 모두 x86_64·arm64 fat binary이며, 생성된 두 architecture의 Swift file list에 `RealityOcclusionPolicy.swift`와 `RealityOcclusionPolicyTests.swift`가 포함됐다. 이 근거를 `TEST SUCCEEDED` 또는 LiDAR 실동작 근거로 표현하지 않는다.
- 배운 점: generic `build-for-testing`은 테스트 계약이 두 architecture에서 type-check·link된다는 근거이지 assertion 실행 근거가 아니다.

### L-20260901-129 — Task 5 첫 GREEN에서 corner fixture 표현식 type-check가 중단됨

- 상태: 해결
- 발생 태스크: Task 5 — view-space 5점 가림·재발견 순수 정책
- 재현: 새 production 정책을 추가한 뒤 fresh `/tmp/piggyescape-task5-green-20260901`에서 generic iOS Simulator 전체 `build-for-testing`을 실행한다.
- 관찰: test helper가 세 겹 `flatMap`과 SIMD 산술을 한 식에 결합해 `the compiler is unable to type-check this expression in reasonable time`를 냈고 exit 65, `** TEST BUILD FAILED **`로 끝났다. production 정책 진단은 없었다.
- 영향: 앱 소스는 컴파일됐지만 새 테스트 bundle을 끝까지 컴파일·link하지 못해 GREEN 근거가 아니었다.
- 원인/가설: 여덟 corner fixture 생성에서 generic collection closure와 SIMD operator 추론을 한 표현식에 중첩한 것이 compiler 진단으로 확인된 원인이다.
- 조치: 동일한 여덟 literal sign 조합과 기대값을 유지하면서 명시적 세 loop, 축별 offset 지역 값, append로 test helper만 분리했다. assertion과 production 동작은 바꾸지 않았다.
- 검증: 같은 DerivedData와 같은 전체 `build-for-testing` 재실행이 exit 0, `** TEST BUILD SUCCEEDED **`로 끝났다.
- 배운 점: SIMD fixture도 중첩 higher-order expression보다 명시적 단계로 쓰면 테스트 의도를 유지하면서 Swift type checker의 추론 부담을 줄일 수 있다.

### L-20260901-128 — Task 5 RED 준비의 Tuist 생성이 세션 상태 권한에서 중단됨

- 상태: 해결
- 발생 태스크: Task 5 — view-space 5점 가림·재발견 순수 정책
- 재현: 새 `RealityOcclusionPolicyTests.swift`를 추가한 뒤 `PiggyEscape`에서 `tuist generate --no-open`을 기본 권한으로 실행한다.
- 관찰: 사용자 상태 경로 `/Users/yang-eunseo/.local/state/tuist/sessions/...` 쓰기가 `Permission denied`로 거부되어 새 test source를 생성 프로젝트에 포함하기 전에 중단됐다.
- 영향: 이 실행은 Swift compile과 assertion에 도달하지 않아 Task 5 RED 근거가 아니었다.
- 원인/가설: L-20260830-118과 같은 프로젝트 밖 Tuist session 경로 권한 제약이다.
- 조치: 같은 명령만 해당 세션 상태에 쓸 수 있는 권한으로 재실행했다.
- 검증: 재실행은 `Project generated`와 `✔ Success`로 끝났고, 후속 RED compiler command가 새 테스트 파일과 새 타입 부재를 실제로 보고했다. production 파일 추가 뒤에도 같은 생성 명령을 다시 성공해 새 source를 두 architecture file list에 포함했다.
- 배운 점: 신규 glob 파일을 쓰는 Task 5도 Tuist 환경 실패와 새 계약의 compiler RED를 별도 근거로 남긴다.

### L-20260901-127 — Task 5 새 5점 정책 타입 부재가 compile RED를 만듦

- 상태: 해결
- 발생 태스크: Task 5 — view-space 5점 가림·재발견 순수 정책
- 재현: 모든 Task 5 테스트를 먼저 작성하고, 새 `/tmp/piggyescape-task5-red-20260901`에서 `xcodebuild -project PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/piggyescape-task5-red-20260901 CODE_SIGNING_ALLOWED=NO build-for-testing`을 실행한다.
- 관찰: 테스트 target이 `RealityOcclusionObservation`, `PigOcclusionSampleID`, `OcclusionSampleState`를 찾지 못해 exit 65, `** TEST BUILD FAILED **`로 끝났다. 앱 target은 컴파일됐고, 실패는 새 테스트가 요구한 순수 계약 부재에서 발생했다.
- 영향: 기존 중심 ray 구현에는 회전된 silhouette 5점, strict unique frame 안정성, 60 frame/deadline, 두 번째 hide pose 기반 movement-latched reveal 계약이 없음을 compile 단계에서 확인했다.
- 원인/가설: Task 4 기준선에는 해당 타입과 interface가 아직 없으며 Task 5가 처음 추가하는 범위다.
- 조치: `RealityOcclusionPolicy.swift`에 5점 sampler·sample classifier·same-frame observation·stable hide·확장 reveal monitor를 구현하고, 기존 planner의 camera pose/reveal 타입을 새 순수 정책 파일로 이동했다. Task 6 전까지 기존 coordinator가 컴파일되도록 한 점 adapter만 명시적으로 격리했다.
- 검증: 최종 전체 source+test compile 결과는 L-20260901-130에 기록한다. runtime assertion은 별도 대기다.
- 배운 점: 센서 입력을 coordinator에 바로 넣기 전에 view-space sampling·frame identity·aggregate stability·movement history를 순수 값과 상태로 분리하면 하드웨어 없이도 계약을 컴파일 가능한 테스트로 고정할 수 있다.

### L-20260830-126 — finite visual bounds가 균일 스케일 뒤 다른 축에서 overflow함

- 상태: 해결
- 발생 태스크: Task 4 검토 보수 2차 — scaled·normalized bounds 계약
- 재현: 높이 0.09m, X축 min/max가 각각 `±Float.greatestFiniteMagnitude * 0.75`인 finite bounds와 같은 경계를 가진 pose 후보를 만들고, policy rejection 및 기존 모델 보존 typed failure를 실제 iPhone에서 확인한다.
- 관찰: 첫 RED test fixture는 `Result<Void, ...>`를 `XCTAssertEqual`로 비교해 `Type 'Void' cannot conform to 'Equatable'` compile error가 났다. assertion을 failure pattern match로 고친 test-only 재실행은 `uniformScale`이 throw하지 않고 controller도 후보를 설치해, 11 tests·2 failures, exit 65, `** TEST FAILED **`로 의도한 결함을 재현했다.
- 영향: 입력 min/max와 계산 scale이 각각 finite여도 다른 축의 scaled min/max가 infinity가 될 수 있고, 실제 post-scale bounds를 검증하지 않은 설치가 non-finite transform을 성공 상태로 남길 수 있었다.
- 원인/가설: policy는 height와 division 결과만 검증하고 scaled bounds 전체를 검증하지 않았다. controller도 `model.scale` 변경 뒤 얻은 `normalizedBounds.center`와 `min.y`를 검증 없이 position에 적용했다.
- 조치: policy가 반환 전 모든 scaled min/max의 finite·축 순서·positive height·0.18m 일치를 검증한다. controller도 RealityKit에서 다시 잰 실제 normalized bounds에 같은 계약을 적용한 뒤에만 최종 position 정렬과 기존 모델 교체를 수행한다. 실패 후보만 제거하므로 현재 모델과 pose는 보존된다.
- 검증: 잘못된 fixture compile RED bundle은 `/tmp/piggyescape-task4-review2-red/Logs/Test/Test-PiggyEscape-2026.08.30_03-17-34-+0900.xcresult`, 유효 RED bundle은 `/tmp/piggyescape-task4-review2-red-2/Logs/Test/Test-PiggyEscape-2026.08.30_03-18-07-+0900.xcresult`다. 보수 도중의 source는 실제 iPhone 16 Pro iOS 26.6에서 policy·visual focused 11/11·전체 140/140 runtime GREEN이었다. bundle은 각각 `/tmp/piggyescape-task4-review2-focused-green-device/Logs/Test/Test-PiggyEscape-2026.08.30_03-21-43-+0900.xcresult`, `/tmp/piggyescape-task4-review2-full-green-device/Logs/Test/Test-PiggyEscape-2026.08.30_03-22-04-+0900.xcresult`다. 이후 최종 source·test가 다시 수정됐으므로 이 runtime 결과를 현재 diff의 성공 근거로 사용하지 않는다. 최종 diff는 새 `/tmp/piggyescape-task4-fix2-fresh-build`에서 generic iOS Simulator 전체 `build-for-testing`이 exit 0, `** TEST BUILD SUCCEEDED **`였고, 이는 compile-only 근거다. 현재 diff의 assertion 실행은 사용자의 Simulator 제외·DocC 우선 요청에 따라 보류한다. 기본 권한의 첫 물리 GREEN 시도 exit 70과 종료 후 partial `devicectl diagnose` 경고는 각각 환경 제약과 L-20260830-124로 분리한다.
- 배운 점: 부동소수점 transform 정책은 입력과 scalar만이 아니라 변환된 모든 경계 성분과 프레임워크가 실제로 반환한 post-transform bounds를 함께 검증해야 한다.

### L-20260830-125 — near-zero visual height가 infinite 돼지 scale로 성공 처리됨

- 상태: 해결
- 발생 태스크: Task 4 검토 보수 1차 — 유한한 18cm scale 계약
- 재현: `Float.leastNonzeroMagnitude`를 visual bounds height로 주고 `PigScalePolicy.uniformScale`이 기존 typed `invalidVisualBounds`를 throw하는지 실제 iPhone의 `PigScalePolicyTests`로 확인한다.
- 관찰: 높이는 finite·positive guard를 통과했지만 `0.18 / height`는 infinity가 됐고, 새 테스트는 `XCTAssertThrowsError failed: did not throw an error`로 실패했다. RED는 3 tests·1 failure, exit 65, `** TEST FAILED **`였다.
- 영향: 극단적으로 작은 finite bounds가 invalid install failure 대신 infinite scale로 성공해 화면을 채우거나 transform을 오염시킬 수 있었다.
- 원인/가설: 기존 policy가 입력 height만 finite·positive인지 확인하고 division 결과 scale의 finite·positive 계약은 검증하지 않았다.
- 조치: `targetHeight / height`를 로컬 scale로 계산한 뒤 `scale.isFinite && scale > 0`인 경우에만 반환하고, 그 외에는 `PigScalePolicyError.invalidVisualBounds`를 throw한다.
- 검증: RED bundle은 `/tmp/piggyescape-task4-review1-red/Logs/Test/Test-PiggyEscape-2026.08.30_03-07-47-+0900.xcresult`다. 실제 iPhone 16 Pro iOS 26.6에서 policy·visual focused 9/9·0 failures, 전체 `PiggyEscapeTests` 138/138·0 failures가 모두 exit 0, `** TEST SUCCEEDED **`로 완료됐다. GREEN bundle은 각각 `/tmp/piggyescape-task4-review1-focused-green/Logs/Test/Test-PiggyEscape-2026.08.30_03-08-20-+0900.xcresult`, `/tmp/piggyescape-task4-review1-full-green/Logs/Test/Test-PiggyEscape-2026.08.30_03-08-43-+0900.xcresult`다.
- 배운 점: 부동소수점 계산 입력이 유한하다고 결과까지 유한한 것은 아니므로, 물리 transform에 적용할 값은 division 후 결과 계약까지 검증한다.

### L-20260830-124 — 실제 iPhone XCTest 성공 후 devicectl 진단 수집이 부분 bundle로 끝남

- 상태: 보류
- 발생 태스크: Task 4 — 18cm 크기와 안전한 floor region 배치
- 재현: development team 명령행 override로 실제 `YES iPhone` focused·전체 XCTest를 실행한다.
- 관찰: focused 45개와 전체 137개가 모두 0 failures, `** TEST SUCCEEDED **`로 완료된 뒤 `IDETestOperationsObserverDebug: Failure collecting diagnostics from devices` 및 `CoreDeviceCLISupport.DiagnoseError` 경고가 발생했다. Xcode는 각 xcresult의 `Diagnostics/devicectl_diagnostics.zip`에 부분 진단 bundle을 남겼다.
- 영향: test assertion count·pass/failure·result bundle은 정상 생성되었고 xcodebuild exit는 0이다. 기기 진단 추가 수집만 완전하지 않았다.
- 원인/가설: XCTest 종료 후 Xcode가 실행한 선택적 `devicectl diagnose`가 CoreDevice 진단 아카이브를 완전히 수집하지 못했다. Task 4 source·assertion 실패 근거는 없다.
- 조치: Task 4 범위 밖의 기기 진단 수집 환경은 변경하지 않고, 테스트 성공 결과와 후속 진단 경고를 분리해 기록한다.
- 검증: focused bundle은 `/tmp/piggyescape-task4-device-focused-signed/Logs/Test/Test-PiggyEscape-2026.08.30_02-57-27-+0900.xcresult`, 전체 bundle은 `/tmp/piggyescape-task4-device-full-signed/Logs/Test/Test-PiggyEscape-2026.08.30_02-58-01-+0900.xcresult`이며 xcodebuild는 각각 exit 0이다. `xcresulttool` summary도 실제 iPhone 16 Pro iOS 26.6(arm64)에서 각각 total 45·passed 45·failed 0, total 137·passed 137·failed 0, `result: Passed`를 반환했다.
- 배운 점: XCTest assertion 결과와 종료 후 추가 진단 수집 경고를 분리해, 성공을 과장하지 않고 잔여 환경 경고도 보존한다.

### L-20260830-123 — 잠금 해제 후 실제 iPhone focused build가 development team 미설정으로 중단됨

- 상태: 해결
- 발생 태스크: Task 4 — 18cm 크기와 안전한 floor region 배치
- 재현: `xcodebuild -project PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS,id=00008140-0008385214C0801C' -derivedDataPath /tmp/piggyescape-task4-device-focused-unlocked -only-testing:PiggyEscapeTests/PigScalePolicyTests -only-testing:PiggyEscapeTests/RealityPigVisualControllerTests -only-testing:PiggyEscapeTests/RealityHidePlannerTests -only-testing:PiggyEscapeTests/RealityHideARViewCoordinatorTests test`
- 관찰: 기기 destination·DDI 준비를 통과해 dependency graph·provisioning input 단계에 도달했지만 `Signing for "PiggyEscapeTests" requires a development team.`과 `Signing for "PiggyEscape" requires a development team.` 두 오류로 exit 65, `** TEST FAILED **`가 발생했다.
- 영향: focused 45개는 compile·install·assertion 실행 전에 중단됐다. focused 성공이 없으므로 실제 iPhone 전체 suite는 시작하지 않았다.
- 원인/가설: generated project의 `PiggyEscape`·`PiggyEscapeTests` 타겟에 실제 기기 서명에 필요한 development team이 설정되지 않은 것이 Xcode 오류로 확인됐다. Task 4 source·test assertion 실패 근거는 없다.
- 조치: 저장소 signing 설정은 변경하지 않고, 사용자가 확인한 기존 로컬 development team `GMLPV8QDSK`를 `DEVELOPMENT_TEAM=GMLPV8QDSK CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates`로 명령행에만 override했다.
- 검증: 실패 result bundle은 `/tmp/piggyescape-task4-device-focused-unlocked/Logs/Test/Test-PiggyEscape-2026.08.30_02-54-53-+0900.xcresult`다. override 후 새 DerivedData에서 실제 iPhone 16 Pro iOS 26.6 focused 45/45·0 failures, 전체 137/137·0 failures가 모두 exit 0, `** TEST SUCCEEDED **`로 완료됐다. 결과 bundle은 각각 `/tmp/piggyescape-task4-device-focused-signed/Logs/Test/Test-PiggyEscape-2026.08.30_02-57-27-+0900.xcresult`, `/tmp/piggyescape-task4-device-full-signed/Logs/Test/Test-PiggyEscape-2026.08.30_02-58-01-+0900.xcresult`다.
- 배운 점: generic Simulator compile은 code signing을 필요로 하지 않으므로 실제 iPhone XCTest의 development team·provisioning 게이트를 대체하지 않는다.

### L-20260830-122 — 실제 iPhone focused XCTest가 developer disk image mount 실패로 시작하지 못함

- 상태: 해결
- 발생 태스크: Task 4 — 18cm 크기와 안전한 floor region 배치
- 재현: `xcodebuild -project PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS,id=00008140-0008385214C0801C' -derivedDataPath /tmp/piggyescape-task4-device-focused-2 -only-testing:PiggyEscapeTests/PigScalePolicyTests -only-testing:PiggyEscapeTests/RealityPigVisualControllerTests -only-testing:PiggyEscapeTests/RealityHidePlannerTests -only-testing:PiggyEscapeTests/RealityHideARViewCoordinatorTests test`
- 관찰: Xcode는 `YES iPhone` UDID를 available destination으로 인식했지만 `Timed out waiting for all destinations ...` 및 `The developer disk image could not be mounted on this device.`로 exit 70을 반환했다. 첫 name 포함 명령은 Xcode가 표시한 기기 이름 끝 공백과 맞지 않아 destination 불일치로 끝났고, 고유 UDID만 사용한 재실행에서 DDI 오류를 확인했다. 후속 `devicectl device info ddiServices`는 `kAMDMobileImageMounterDeviceLocked`, error `0xe80000e2`, `The device is locked`를 반환했다.
- 영향: Task 4 focused 45개는 컴파일·설치·assertion 실행 전에 중단됐고, focused 성공이 없으므로 실제 iPhone 전체 suite는 시작하지 않았다.
- 원인/가설: 기기 잠금이 확정 원인이다. `devicectl` error가 Mobile Image Mounter의 device-locked 상태를 명시했다. DDI host `update --no-clean`은 성공했지만 installed set이 equivalent였으므로 host image 부재·노후화가 원인이 아니다.
- 조치: DDI를 무리하게 우회하지 않고 실행을 중단했다. 사용자가 `YES iPhone`을 잠금 해제하고 잠금 해제 상태를 유지한 뒤 같은 UDID·focused 명령을 새 `/tmp` DerivedData로 재실행한다.
- 검증: 이 실행의 assertion count는 0이며 `TEST SUCCEEDED` 또는 정상 xcresult bundle은 생성되지 않았다. 기기 잠금 해제 후 같은 UDID focused 재실행은 DDI 오류 없이 provisioning input 단계에 도달했고, 후속 signing blocker는 L-20260830-123에 분리했다.
- 배운 점: available destination에 실제 기기가 표시되는 것과 잠금 해제된 기기에 test runtime을 mount해 실행 가능한 것은 별도 게이트이며, device-locked DDI mount 실패를 앱 컴파일·test assertion 실패로 해석하지 않는다.

### L-20260830-121 — self-review 뒤 focused 재실행이 Simulator Busy로 시작하지 못함

- 상태: 보류
- 발생 태스크: Task 4 — 18cm 크기와 안전한 floor region 배치
- 재현: self-review에서 reveal 회귀와 start/retry 경계를 보강한 뒤 새 `/tmp/piggyescape-task4-final-focused` DerivedData로 네 focused suite를 실행한다.
- 관찰: app과 test bundle compile·install 단계 뒤 Simulator가 `Application failed preflight checks: Busy`로 test runner launch를 거부해 assertion 실행 수 없이 exit 65로 끝났다.
- 영향: 새로 보강한 경계를 포함한 최종 focused pass count를 이 실행으로 확인할 수 없다. 직전 변경 전 suite는 42/42였다.
- 원인/가설: source·test assertion이 아니라 Simulator SpringBoard preflight의 일시적 busy 상태로 오류 domain과 reason에서 확인됐다.
- 조치: 같은 project·scheme·destination·focused test 조건을 새 DerivedData에서 재시도했으나 같은 Busy가 반복됐다. 확인 시점의 iPhone 17 Pro iOS 26.5 Simulator는 `Shutdown`이었으므로 사용자가 부팅한 뒤 실행 검증을 재개한다. 대기 중 source를 바꾸지 않고 generic iOS Simulator destination에서 전체 `build-for-testing`을 실행했다.
- 검증: 첫 결과 bundle은 `/tmp/piggyescape-task4-final-focused/Logs/Test/Test-PiggyEscape-2026.08.30_01-25-50-+0900.xcresult`, 반복 결과는 `/tmp/piggyescape-task4-final-focused-retry/Logs/Test/Test-PiggyEscape-2026.08.30_01-26-50-+0900.xcresult`다. 새 `/tmp/piggyescape-task4-build-for-testing` DerivedData와 `generic/platform=iOS Simulator`, `CODE_SIGNING_ALLOWED=NO`로 실행한 `build-for-testing`은 app·test bundle의 arm64·x86_64 compile 후 `** TEST BUILD SUCCEEDED **`로 완료됐다. 이 결과는 XCTest assertion 실행을 대체하지 않으며, Simulator 부팅 뒤 focused·전체 실행 count를 후속 검증에 기록한다.
- 배운 점: compile 뒤 test runner preflight가 막힌 결과도 assertion 실패와 분리하고, generic `build-for-testing`은 전체 소스·테스트 타겟 컴파일 건전성만 확인한다.

### L-20260830-120 — 첫 Task 4 GREEN에서 synchronous test loader가 두 test process를 종료함

- 상태: 해결
- 발생 태스크: Task 4 — 18cm 크기와 안전한 floor region 배치
- 재현: scale·visual·planner·coordinator focused test를 새 `/tmp/piggyescape-task4-green` DerivedData에서 실행한다.
- 관찰: production과 test bundle compile은 성공했고 planner 등 실행된 assertion은 통과했지만, pose baseline test는 pending load 배열을 `inout`으로 수정하는 동안 completion이 같은 배열에 재진입해 exclusivity conflict로 종료했다. 기존 coordinator test는 새 invalid-bounds 계약에서도 빈 `Entity()`를 성공 fixture로 전달해 running install이 실패한 뒤 존재하지 않는 idle load를 `removeFirst()`하여 종료했다.
- 영향: 첫 focused 실행은 2개 test crash와 exit 65로 GREEN이 아니며, production scale/floor assertion 실패 여부를 최종 판정할 수 없다.
- 원인/가설: 두 종료 모두 synchronous test loader의 부정확한 fixture/lifetime으로 stack과 실행 순서에서 확인됐다. production scale 또는 planner 계산 실패 근거는 없다.
- 조치: pending load를 배열의 `inout` 접근 밖에서 완료하고, 성공 설치 fixture를 유효한 bounds의 `ModelEntity`로 바꾼다. 이어 남은 surprised fixture에도 같은 유효 bounds 규칙을 적용했다.
- 검증: iPhone 17 Pro iOS 26.5 Simulator에서 같은 네 focused suite가 42/42·0 failures와 `** TEST SUCCEEDED **`로 완료됐다. 결과 bundle은 `/tmp/piggyescape-task4-green-3/Logs/Test/Test-PiggyEscape-2026.08.30_01-23-53-+0900.xcresult`다. 이 실행 뒤 self-review로 기존 reveal 테스트를 복원하고 start/retry coordinator 경계를 보강한 최종 45개는 L-20260830-121의 Simulator 대기 경계에 따라 실행 미검증이다.
- 배운 점: synchronous completion이 새 request를 즉시 enqueue하는 test double은 배열의 exclusive access를 유지한 채 호출하지 않고, bounds validation을 추가하면 모든 성공 fixture도 실제 non-empty visual model을 사용해야 한다.

### L-20260830-119 — Task 4 focused RED가 Simulator service 제한으로 compile 전에 중단됨

- 상태: 해결
- 발생 태스크: Task 4 — 18cm 크기와 안전한 floor region 배치
- 재현: iPhone 17 Pro iOS 26.5 destination, `/tmp/piggyescape-task4-red` DerivedData, scale·visual·planner 세 focused test target으로 기본 권한 `xcodebuild test`를 실행한다.
- 관찰: CoreSimulatorService connection과 log 접근이 `Operation not permitted`로 끊겨 설치된 runtime을 찾지 못했고, matching destination 부재 exit 70으로 compile 전에 종료했다.
- 영향: 새 타입 부재 또는 assertion으로 실패하는 의도된 RED를 이 실행으로는 확인할 수 없다.
- 원인/가설: L-20260829-110·L-20260830-114와 같은 Simulator service 접근 제한이며 source failure 근거가 아니다.
- 조치: 동일 project·scheme·destination·DerivedData·focused test 명령을 Simulator service 접근 권한이 있는 실행으로 한 번 재시도했다.
- 검증: 재실행은 새 계약 타입 `RealityFloorRegion` 부재 compiler error, exit 65, `TEST FAILED`로 끝나 의도한 RED를 확인했다. 결과 bundle은 `/tmp/piggyescape-task4-red/Logs/Test/Test-PiggyEscape-2026.08.30_01-17-15-+0900.xcresult`다.
- 배운 점: destination discovery에서 끝난 실행은 TDD RED로 세지 않고, 동일 조건에서 compiler가 새 계약을 거부하는 결과를 따로 확보한다.

### L-20260830-118 — Task 4 RED 전 Tuist 생성이 session 경로 권한으로 중단됨

- 상태: 해결
- 발생 태스크: Task 4 — 18cm 크기와 안전한 floor region 배치
- 재현: 새 `PigScalePolicyTests.swift`를 추가한 뒤 `PiggyEscape` 디렉터리에서 기본 권한으로 `tuist generate --no-open`을 실행한다.
- 관찰: 사용자 상태 디렉터리의 `tuist/sessions/...`에 쓸 수 없다는 `Permission denied`와 함께 exit 133으로 종료했다.
- 영향: 새 test source를 generated Xcode project에 포함해 focused RED를 실행하기 전 단계가 환경 권한에서 중단됐다. Swift compile 또는 assertion 결과는 아직 아니다.
- 원인/가설: 프로젝트 경로 밖 사용자 상태 디렉터리에 session을 기록하려는 동작이 현재 기본 권한에 막힌 것으로 보인다.
- 조치: 같은 Tuist 생성 명령을 사용자 상태 디렉터리 접근 권한이 있는 실행으로 한 번 재시도했다.
- 검증: 권한 있는 `tuist generate --no-open`은 새 workspace와 project를 생성하고 `Project generated`로 완료됐다. 이어지는 focused RED는 별도 항목에 기록한다.
- 배운 점: generated project에 신규 파일 반영이 필요한 RED에서는 Tuist 환경 실패와 compiler RED를 분리해 각각 증거를 남긴다.

### L-20260830-117 — Task 4 시작 fetch가 공용 Git metadata 쓰기 제한으로 중단됨

- 상태: 해결
- 발생 태스크: Task 4 — 18cm 크기와 안전한 floor region 배치
- 재현: `ch1-reality-escape` worktree에서 기본 권한으로 `git fetch --prune origin`을 실행한다.
- 관찰: `.git/worktrees/ch1-reality-escape/FETCH_HEAD`를 열 수 없다는 `Operation not permitted` 오류로 명령이 종료했다.
- 영향: Task 4 구현 전에 원격 변경을 최신 상태로 확인하는 절차가 기본 권한에서는 완료되지 않았다. 현재 작업 트리는 깨끗하고 브랜치는 `ch1-reality-escape`다.
- 원인/가설: L-20260829-113과 같은 연결 worktree 공용 Git metadata 쓰기 제한으로 보이며, source 또는 원격 저장소 오류 근거는 없다.
- 조치: 같은 명령을 공용 Git metadata 쓰기 권한이 있는 실행으로 한 번 재시도했다.
- 검증: 권한 있는 `git fetch --prune origin` 재시도는 출력 없이 exit 0으로 완료됐다. 이후 구현은 갱신된 원격 참조와 현재 worktree 상태를 기준으로 진행한다.
- 배운 점: 반복되는 worktree metadata 제한도 태스크별 시작 근거와 영향 범위를 기록한 뒤 동일 명령만 권한 있게 재시도한다.

### L-20260830-116 — deadline handle이 보관 owner를 되잡는 lifetime cycle

- 상태: 해결
- 발생 태스크: Task 3 검토 보수 — deadline owner 수명
- 재현: owner가 production `RealityDeadlineScheduler`가 반환한 handle을 보관하고, 이전 no-argument operation이 owner 상태를 갱신하도록 한 뒤 외부 owner 참조를 해제한다.
- 관찰: 새 focused XCTest 1개는 weak owner가 nil이 되기를 기대했지만 owner instance가 남아 `XCTAssertNil` 1 failure로 끝났다. wall-clock 대기는 사용하지 않았다.
- 영향: deadline이 아직 만료되지 않아도 handle → operation → owner cycle이 owner 해제를 막고, cancellation 뒤에도 closure가 남을 수 있었다.
- 원인/가설: scheduler가 owner는 약하게 저장했지만 operation은 강하게 유지했고, operation이 owner를 캡처할 수 있었다. cancellation과 one-shot firing도 stored operation을 비우지 않았다.
- 조치: operation이 아직 live인 owner를 인자로 받도록 scheduler 경계를 바꾸고 모든 호출부가 그 인자를 사용하게 했다. cancellation, firing, owner 부재 경로에서 operation과 task 참조를 해제한다.
- 검증: RED 결과 bundle은 `/tmp/piggyescape-task3-lifetime-red/Logs/Test/Test-PiggyEscape-2026.08.30_01-00-25-+0900.xcresult`다. 첫 GREEN 시도는 Simulator `Application failed preflight checks: Busy`로 assertion 전에 중단됐고, 같은 조건 재시도에서 focused 27/27·0 failures를 확인했다. 전체 XCTest도 135/135·0 failures와 `TEST SUCCEEDED`로 완료됐으며 bundle은 각각 `/tmp/piggyescape-task3-lifetime-green/Logs/Test/Test-PiggyEscape-2026.08.30_01-02-38-+0900.xcresult`, `/tmp/piggyescape-task3-lifetime-full/Logs/Test/Test-PiggyEscape-2026.08.30_01-03-04-+0900.xcresult`다.
- 배운 점: weak owner만으로 callback lifecycle이 안전해지지 않는다. owner가 cancellation handle을 보관할 수 있는 API는 closure의 owner capture를 구조적으로 피하고 terminal path에서 stored operation을 비워야 한다.

### L-20260830-115 — Task 3 RED 확인과 actor-isolated deadline cleanup 경계

- 상태: 해결
- 발생 태스크: Task 3 — Reality 준비 상태와 Chapter 3 이전 탭 잠금
- 재현: 새 readiness·deadline·interaction mode XCTest를 추가하고 iPhone 17 Pro iOS 26.5 destination에서 focused test를 실행한다.
- 관찰: 처음에는 scheduler 경계 타입이 없어 compiler가 `RealityDeadlineScheduling`, `RealityDeadlineCancellable`, `RealityDeadline`을 찾지 못해 RED가 됐다. 구현 첫 실행에서는 main-actor deadline object의 `deinit`이 isolated `cancel()`을 동기 호출해 compiler 오류가 났다. 이어 mesh-or-floor 정책으로 바꾼 mutation은 readiness coordinator test에서 5 assertion failures를 냈다.
- 영향: 새 준비 완료·deadline 수명·tap lock의 의도된 RED와 Swift actor 수명 경계를 구분하지 않으면 callback 안정성 또는 TDD 증거를 잘못 판단할 수 있었다.
- 원인/가설: deadline 취소 protocol이 main actor에 격리되지 않았고, deinit은 actor-isolated method를 동기 호출할 수 없었다. 기존 readiness 정책은 한 신호만으로 callback을 보내므로 complete-room 계약을 충족하지 않는다.
- 조치: cancellation protocol과 구현을 main actor 경계에 정렬하고, 약한 self를 가진 task가 deallocated handle 뒤 callback을 전달하지 않도록 deinit 호출을 제거했다. `RealityEnvironmentReadiness`가 mesh와 floor를 독립적으로 latch하고 최초 complete transition만 보고하도록 복원했다.
- 검증: Tuist 생성 성공 뒤 focused XCTest 26/26·0 failures, 전체 XCTest 134/134·0 failures와 `TEST SUCCEEDED`를 확인했다. OR mutation RED 결과는 `/tmp/piggyescape-task3-or-mutant-red/Logs/Test/Test-PiggyEscape-2026.08.30_00-50-44-+0900.xcresult`, 최종 focused 결과는 `/tmp/piggyescape-task3-final-focused/Logs/Test/Test-PiggyEscape-2026.08.30_00-51-29-+0900.xcresult`, 전체 결과는 `/tmp/piggyescape-task3-full/Logs/Test/Test-PiggyEscape-2026.08.30_00-49-19-+0900.xcresult`에 남았다.
- 배운 점: deadline handle과 callback owner의 actor·해제 경계를 API 수준에서 함께 모델링하고, readiness 완료는 개별 signal이 아니라 aggregate transition으로 test해야 한다.

### L-20260830-114 — 병합 후 전체 XCTest가 기본 권한의 CoreSimulatorService 제한으로 시작하지 못함

- 상태: 해결
- 발생 태스크: Task 1 — 공개 DocC 기준선 통합
- 재현: worktree에서 iPhone 17 Pro iOS 26.5 destination과 새 `/tmp/piggyescape-task1-tests` DerivedData를 지정해 전체 `xcodebuild test`를 실행한다.
- 관찰: `CoreSimulatorService connection became invalid`, CoreSimulator log의 `Operation not permitted`, runtime discovery 실패가 발생해 XCTest 실행 결과와 `TEST SUCCEEDED`가 나오기 전에 중단됐다.
- 영향: 병합 뒤 112개 XCTest의 실제 실행 수와 failure 수를 기본 권한 실행만으로 확인할 수 없다.
- 원인/가설: L-20260829-110과 같은 Simulator service·사용자 로그 경로 접근 제한으로 보이며, source compile 또는 test assertion 실패 근거는 아직 없다.
- 조치: 이 환경 중단을 기록한 뒤, 같은 project·scheme·destination·DerivedData 명령을 Simulator service 접근이 가능한 실행으로 한 번 재시도한다.
- 검증: 같은 project·scheme·destination·DerivedData 조건의 재실행이 `PiggyEscapeTests.xctest`와 `All tests` 112/112·0 failures, `** TEST SUCCEEDED **`로 완료됐다. 결과 bundle은 `/tmp/piggyescape-task1-tests/Logs/Test/Test-PiggyEscape-2026.08.30_00-03-08-+0900.xcresult`이며, `xcresulttool` summary도 `totalTestCount: 112`, `passedTests: 112`, `failedTests: 0`, `result: Passed`를 반환했다.
- 배운 점: Simulator service 초기화 이전에 멈춘 실행을 병합 후 앱 회귀 실패로 해석하지 말고, 같은 조건의 권한 있는 한 번의 재실행으로 분리한다.

  - 재발 연결 (2026-08-30, Task 2): 기본 권한 focused test는 같은 CoreSimulatorService 접근 제한으로 시작 전에 중단됐고, 권한 있는 재실행에서 새 type·event 부재 RED compiler failure를 확인했다. 이후 Simulator의 일시적 `Application failed preflight checks: Busy`는 한 번 재시도해 실제 assertion 결과와 분리했다.

### L-20260829-113 — 연결 worktree에서 기본 권한 fetch가 공용 Git metadata 쓰기 제한으로 중단됨

- 상태: 해결
- 발생 태스크: Task 1 — 공개 DocC 기준선 통합
- 재현: `ch1-reality-escape` worktree에서 기본 권한으로 `git fetch --prune origin`을 실행한다.
- 관찰: `.git/worktrees/ch1-reality-escape/FETCH_HEAD`를 열 수 없다는 `Operation not permitted` 오류로 명령이 종료했다.
- 영향: `origin/main`의 공개 DocC·Pages 기준선을 최신 원격 상태에서 병합하기 전 확인이 기본 권한에서는 진행되지 않았다.
- 원인/가설: 연결 worktree가 공용 Git metadata의 `FETCH_HEAD`를 갱신하는 경로가 현재 기본 권한에 허용되지 않은 환경 제약이다. source 또는 원격 상태 오류로 단정할 근거는 없다.
- 조치: 동일 명령을 공용 Git metadata 쓰기 권한이 있는 실행으로 한 번 재시도했다.
- 검증: 재시도한 `git fetch --prune origin`은 오류 없이 완료됐다. 이후 병합과 검증은 이 최신 `origin/main` 기준으로 진행한다.
- 배운 점: 연결 worktree의 fetch가 metadata 쓰기에서 막히면 앱·문서 상태와 구분해 기록하고, 같은 명령의 권한 있는 재시도로 원격 기준만 확인한다.

### L-20260829-112 — 현재 worktree에 컨셉 노트가 없음

- 상태: 해결
- 발생 태스크: Task 1 — 공개 DocC 기준선 통합
- 재현: 현재 `ch1-reality-escape` worktree에서 시작 순서에 지정된 `씬킷에서_리얼리티킷으로_컨셉노트.md`를 연다.
- 관찰: 해당 파일은 worktree에 없으며, 상위 로컬 checkout에는 별도 참고 사본이 존재한다.
- 영향: 현재 작업 트리만으로는 초기 이야기·기술 의도를 직접 읽을 수 없다. 공개 DocC 기준선 병합의 승인 범위 판단에는 최신 설계 문서가 필요하다.
- 원인/가설: 이 파일은 현재 브랜치에 추적되지 않은 로컬 참고물이며, 병합 대상 `origin/main`에도 포함되지 않은 것으로 보인다.
- 조치: 로컬 참고 사본은 읽기 전용으로만 대조하고, 승인된 `docs/superpowers/specs/2026-08-29-four-chapter-experience-and-docc-design.md`와 실행 계획을 현재 범위의 대체 근거로 사용한다.
- 검증: 현재 `docs/PROJECT_CONTEXT.md`의 부재 시 대체 근거 절차와 최신 4장 설계·Task 1 계획을 확인했다.
- 배운 점: 현재 브랜치에 없는 참고 문서가 있어도 로컬 다른 checkout을 수정하지 말고, 승인된 추적 설계와 계획으로 작업 경계를 결정한다.

### L-20260829-111 — paired iPhone 16 Pro가 DDI·tunnel unavailable로 Xcode destination에 없음

- 상태: 실기기 대기
- 발생 태스크: 4개 챕터 실행 계획 — 실기기 기준선 감사
- 재현: device 목록에서 iPhone 16 Pro 세부 상태를 확인하고 `xcodebuild -showdestinations`와 대조한다.
- 관찰: iPhone 16 Pro `CE2EB817-83F9-54CE-9D11-AEB432B82FE4`는 paired·iOS 26.6이지만 `ddiServicesAvailable:false`, `tunnelState:unavailable`이고 Xcode destination 목록에는 나타나지 않는다.
- 영향: 0.18m 실제 크기, LiDAR 5점 메시 가림, 물리적 재발견, replay와 DocC 전·후 증거 캡처를 현재 실행할 수 없다.
- 원인/가설: 기기 연결·잠금 해제·신뢰 또는 Developer Disk Image service/tunnel이 준비되지 않은 외부 상태다. 앱 source 실패 근거는 아니다.
- 조치: 자동 구현·Simulator·DocC 작업은 계속하고, 기기를 연결·잠금 해제·신뢰한 뒤 DDI/tunnel과 Xcode destination을 다시 확인한다.
- 검증: 실기기 항목은 연결 복구 뒤에만 수행하며 Simulator 결과로 대체하지 않는다.
- 배운 점: paired 상태만으로 install·launch 가능하다고 보지 말고 DDI, tunnel, Xcode destination 세 조건을 함께 확인한다.

### L-20260829-110 — sandbox에서 CoreSimulatorService 조회가 권한 제한으로 중단됨

- 상태: 해결
- 발생 태스크: 4개 챕터 실행 계획 — 전체 XCTest 기준선
- 재현: 기본 권한으로 `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -showdestinations`를 실행한다.
- 관찰: `CoreSimulatorService connection became invalid`, CoreSimulator log `Operation not permitted`가 발생하고 placeholder destination만 열거됐다.
- 영향: 설치된 iPhone 17 Pro destination과 전체 XCTest 기준선을 기본 권한 실행으로 선택할 수 없었다.
- 원인/가설: source나 project 오류가 아니라 Simulator service·사용자 로그 경로 접근 제한이며, 권한이 있는 동일 명령 결과로 확인했다.
- 조치: 동일 `showdestinations`를 Simulator service 접근이 가능한 실행으로 한 번 재시도했다.
- 검증: iPhone 17 Pro iOS 26.5 UDID `669EA62B-11F3-47A7-89AD-6E99F22A1B91`를 확인했고, 해당 destination의 전체 XCTest가 112/112·0 failures와 `TEST SUCCEEDED`로 완료됐다.
- 배운 점: placeholder만 보이면 runtime 부재로 단정하지 않고 같은 명령을 service 접근 권한과 분리해 확인한다.

### L-20260829-109 — Swift 6 strict concurrency에서 C3 예약 취소 경계가 빌드되지 않음

- 상태: 보류
- 발생 태스크: Chapter 1–4 완성 설계 — 검증 기준선 감사
- 재현: `PiggyEscape`에서 generic iOS Simulator destination, `SWIFT_VERSION=6 SWIFT_STRICT_CONCURRENCY=complete CODE_SIGNING_ALLOWED=NO`로 scheme을 build한다.
- 관찰: `C3ClosedWorldSceneView.swift:125`에서 non-Sendable `C3AutoDiscoveryCancellable` 접근이 actor 격리 경계를 넘는 오류로 build가 중단됐다. 같은 source는 현재 설정된 Swift 5 모드의 generic Simulator build를 통과했다.
- 영향: 현재 앱을 Swift 6 strict concurrency 대응 완료라고 설명할 수 없다. 일반 앱 구현과 기존 Swift 모드 build는 별도다.
- 원인/가설: 취소 handle protocol과 coordinator lifecycle 경계가 Swift 6의 전송 가능성 검사를 만족하지 않는 것이 compiler 진단으로 확인됐다.
- 조치: 4개 챕터 실행 계획에 해당 수명 경계 보수를 별도 준비 게이트로 넣되, 사용자 경험 변경과 함께 무리하게 언어 모드를 전환하지 않는다.
- 검증: 현재 Swift 5 generic Simulator build 성공은 유지한다. strict concurrency build는 수정 뒤 같은 명령으로 다시 실행해야 한다.
- 배운 점: 프로젝트의 실제 Swift language mode와 선택적 strict diagnostic 결과를 구분하고, 통과하지 않은 모드를 문서의 지원 조건으로 쓰지 않는다.

### L-20260829-108 — 최신 HEAD의 전체 XCTest 통과 근거가 없었음

- 상태: 해결
- 발생 태스크: Chapter 1–4 완성 설계 — 검증 기준선 감사
- 재현: test source에서 XCTest method를 정적으로 집계하고 `docs/WORK_LOG.md`의 마지막 전체·focused 실행 기록과 비교한다.
- 관찰: 현재 test source에는 정적 집계상 112개 test가 있다. 작업 로그의 마지막 전체 실행은 101/101이고, 이후 최신 기록은 planner·AR coordinator focused 36/36뿐이다.
- 영향: 현재 HEAD 전체 회귀가 통과했다고 주장할 수 없으며, 새 범위의 RED 기준선도 확정되지 않았다.
- 원인/가설: 최근 실제 가림 보수에서 focused test만 실행하고 전체 suite를 다시 기록하지 않은 것이 확인된 차이다.
- 조치: iPhone 17 Pro iOS 26.5 Simulator의 UDID를 명시하고 `/tmp/piggyescape-four-chapter-baseline` DerivedData에서 전체 `xcodebuild test`를 실행했다. test를 건너뛸 수 있는 `tuist test` exit code는 근거로 사용하지 않았다.
- 검증: `PiggyEscapeTests.xctest`가 112/112·0 failures, `All tests` 112/112·0 failures, `** TEST SUCCEEDED **`로 완료됐다. 결과 bundle은 `/tmp/piggyescape-four-chapter-baseline/Logs/Test/Test-PiggyEscape-2026.08.29_23-31-56-+0900.xcresult`다.
- 배운 점: test 파일 수나 exit code가 아니라 실제 실행 count·failure count·최종 result를 같은 기준선에서 확인한다.

### L-20260829-107 — 앱용 한 챕터 DocC와 공개 네 챕터 DocC가 서로 다른 원본이 됨

- 상태: 보류
- 발생 태스크: Chapter 1–4 완성 설계 — DocC 구조 감사
- 재현: 기능 worktree의 `PiggyEscape/PiggyEscape/Tutorials/SceneKitToRealityKit.docc`, `origin/main`의 루트 `Tutorials/SceneKitToRealityKit.docc`, 공개 Pages URL을 각각 비교한다.
- 관찰: 기능 worktree는 1개 chapter·5개 snippet·이미지 0개이고, `origin/main`과 공개 사이트는 4개 chapter와 별도 article·배포 pipeline을 가진다. 공개 사이트의 네 장도 동일 icon 반복, 실제 Chapter 3 전·후 이미지 부재, 미해결 링크와 접근성 문제가 남는다.
- 영향: 앱 구현과 학습 문서가 다른 상태·수치·코드를 설명하고, 현재 기능 worktree만으로 공개 사이트를 재현하거나 안전하게 유지할 수 없다.
- 원인/가설: 앱 target 안의 DocC와 GitHub Pages용 루트 DocC가 별도 작업 흐름에서 편집되어 단일 원본 규칙이 없었던 것이 파일 구조로 확인됐다.
- 조치: 2026-08-29 설계에서 루트 catalog를 유일한 원본으로 정하고, 구현 단계에서 `origin/main`의 공개 문서·pipeline을 기능 worktree에 통합한 뒤 앱 내부 복사본을 제거한다.
- 검증: 통합 전이므로 두 catalog는 아직 분리된 상태다. 최종적으로 한 catalog inventory, 경고 없는 convert, 네 route, snippet type-check와 배포 URL을 검증해야 한다.
- 배운 점: DocC를 앱 resource와 Pages source로 복제하지 말고, 하나의 catalog와 하나의 publication pipeline을 기준으로 문서·코드를 함께 갱신한다.

### L-20260819-106 — 실기기 설치 전 Xcode destination 목록에서 iPhone 16 Pro가 사라짐

- 상태: 보류
- 발생 태스크: C3 시작 화면 full-screen 레이아웃 — 실기기 설치
- 재현: iPhone 16 Pro UDID를 지정해 `xcodebuild ... -destination 'id=CE2EB817-83F9-54CE-9D11-AEB432B82FE4' build`를 실행한다.
- 관찰: `Unable to find a destination matching ...`으로 build가 source compile 전에 중단됐고, Xcode는 My Mac·Simulator·Any iOS Device만 열거했다.
- 영향: safe area 수정의 실제 iPhone 화면 확인·설치가 아직 수행되지 않았다.
- 원인/가설: iPhone 연결·신뢰·잠금 상태 또는 Xcode device discovery의 일시적 상태이며, Swift source·signing 실패는 아직 관찰되지 않았다.
- 조치: 기기 연결이 `connected`가 된 뒤 동일한 signed build·install 명령을 재실행했다. C3 view에 `ignoresSafeArea()`와 무한 frame을 직접 추가한 실험도 설치했으나 상·하단 여백은 변하지 않았다. 사용자가 이 항목은 더 진행하지 않기로 했으므로 효과 없던 source 변경은 되돌린다.
- 검증: iPhone 16 Pro signed build·install·launch은 성공했고, 사용자가 실제 화면의 상·하단 여백이 그대로임을 관찰했다.
- 배운 점: 실기기 destination 오류는 앱 build 오류로 해석하지 말고, source 변경 전 device discovery 결과를 분리한다. SwiftUI modifier만으로 변화가 없으면 scene content의 카메라 framing과 container layout을 구분해 별도 설계 범위로 조사한다.

### L-20260819-105 — iPhone 16 Pro에서 AR 카메라가 검게 멈추는 경로를 분리함

- 상태: 해결 — AR 카메라 배경 초기화
- 발생 태스크: 실제 물체 뒤 숨기 검증 — 실기기 카메라 진단과 정리
- 재현: C3에서 권한 전환 후 `RealityHideARView`를 열고, 돼지의 정규화·포즈 로더를 포함한 앵커를 타깃 선택 전부터 AR scene에 추가한다.
- 관찰: iPhone 16 Pro에서 권한 허용 뒤 자막만 보이고 카메라 배경이 검게 멈췄다. 최소 ARView, 수동 world tracking, mesh reconstruction, scene understanding, plane detection, session delegate, 빈 앵커, 원본 돼지 asset 순서의 진단에서는 카메라가 보였고, 정규화된 포즈 controller를 타깃 전 scene에 붙인 조합에서만 문제가 재현됐다.
- 영향: 사용자는 스캔·실제 물체 선택·LiDAR 가림 확인으로 진행할 수 없었다.
- 원인/가설: ARView가 아직 window·유효 bounds를 갖기 전 session을 시작하거나, 타깃 전부터 정규화된 돼지 scene graph를 렌더링하는 수명 순서가 RealityKit camera background 초기화와 충돌한다. 개별 asset 파일이나 LiDAR 지원 여부만의 문제라고 단정할 근거는 없다.
- 조치: container가 window와 nonzero bounds를 갖춘 뒤에만 AR session을 한 번 시작하고, 돼지 anchor는 사용자가 유효한 숨을 타깃을 선택한 뒤 한 번만 scene에 추가하도록 분리했다. 이후 재현에서 `didMoveToWindow`가 container 크기만으로 시작할 수 있는 경계를 추가로 확인해, 내부 `ARView`의 frame·bounds가 배치된 `layoutSubviews` 뒤에만 시작하게 고정했다. 진단 전용 launch argument와 view는 최종 앱 경로에서 제거한다.
- 검증: 새 gate의 API 부재 RED compiler failure 뒤 `RealityHideARViewCoordinatorTests` 17/17·0 failures와 iPhone 16 Pro signed build·install·launch를 확인했다. 사용자가 최신 설치에서 카메라 배경이 정상 표시되는 것을 관찰했다. 실제 물체 뒤의 걷기·메쉬 가림·재시도·재발견은 아직 별도 실기기 검증이 필요하다.
- 배운 점: 에셋 로더는 문제를 재현한 scene graph의 일부였지만 단독 원인으로 결론 내릴 수 없다. ARView container, 내부 render view, session 시작 순서를 분리해 검사하고, 내부 ARView가 실제 크기인 것을 시작 조건으로 삼는다.

### L-20260819-104 — 가림 검증 정책 RED XCTest가 Simulator 서비스 접근 전에 중단됨

- 상태: 해결
- 발생 태스크: 실제 물체 뒤 숨기 검증 — Task 1 RED
- 재현: `PiggyEscape` 디렉터리에서 iPhone 17 Pro Simulator destination과 `RealityHidePlannerTests`만 지정한 `xcodebuild test`를 실행한다.
- 관찰: `CoreSimulatorService connection became invalid`와 CoreSimulator 로그 `Operation not permitted`가 발생해 XCTest가 새 타입의 컴파일 단계에 도달하지 못했다.
- 영향: 새 가림 검증 정책 타입 부재를 보여야 하는 RED 결과를 현재 권한 범위에서 확인할 수 없다.
- 원인/가설: 기존 L-20260818-099와 같은 Simulator service·로그 경로 접근 제한이며, Swift source 또는 새 테스트 assertion 실패가 아니다.
- 조치: 이 환경 중단을 먼저 기록하고, 동일 명령을 Simulator service와 Xcode 로그 접근이 가능한 실행으로 한 번 재시도한다.
- 검증: 접근 가능한 동일 명령을 재실행해 `RealityHideAttempt`와 `RealityHideVerificationPolicy` 타입 부재, 그리고 그 결과의 `.hidden`·`.retry`·`.selectAnotherTarget` 타입 추론 실패로 test-target compile이 중단되는 RED를 확인했다.
- 배운 점: XCTest가 Simulator 초기화 전에 중단되면 RED 또는 GREEN 결과로 해석하지 말고, 접근 가능한 동일 명령을 한 번만 분리 실행한다.

### L-20260818-103 — 저장소 내부 경로에서 activity logging skill을 찾지 못함

- 상태: 해결
- 발생 태스크: C3 자동 진행 최종 보수 — 완료 기록
- 재현: 저장소의 `.agents/skills/logging-activity/SKILL.md`를 읽으려 한다.
- 관찰: `No such file or directory`로 skill instruction을 읽지 못했다.
- 영향: 로컬 activity 기록 절차를 이 경로로는 확인할 수 없다. Git 추적 인수인계·학습 기록과 최종 커밋은 이미 완료됐다.
- 원인/가설: 사용 가능한 skill은 저장소 내부가 아니라 사용자 공용 skill directory에 설치되어 있다.
- 조치: 공용 skill 절대 경로를 읽어 적절한 완료 activity를 남긴다.
- 검증: `/Users/yang-eunseo/.agents/skills/logging-activity/SKILL.md`에서 공용 skill instruction을 읽었고, 해당 helper로 로컬 activity 기록을 남겼다.
- 배운 점: skills catalog가 명시한 절대 source locator를 우선 사용하고, repository 내부 복사본을 가정하지 않는다.

### L-20260818-102 — 최종 보수 파일의 Git index 잠금 생성이 권한으로 중단됨

- 상태: 해결
- 발생 태스크: C3 자동 진행 최종 보수 — 커밋 준비
- 재현: 연결 worktree에서 최종 source·test·DocC·인수인계 파일만 명시한 `git add`를 실행한다.
- 관찰: `Unable to create '.../.git/worktrees/ch1-reality-escape/index.lock': Operation not permitted`로 스테이징 전에 종료했다. `.claude/`를 포함한 미추적 파일은 stage되지 않았다.
- 영향: 검증된 보수를 Git 추적 커밋으로 공유할 수 없다.
- 원인/가설: L-20260811-088과 동일하게 연결 worktree의 공용 Git metadata에 현재 권한으로 index lock을 만들 수 없다.
- 조치: 이 실패를 먼저 기록한 뒤, 같은 명시 파일 목록만 공용 Git metadata 쓰기 권한이 있는 실행으로 한 번 재시도한다.
- 검증: 같은 명시 파일 목록으로 재실행해 cached diff check를 통과했고, `.claude/`는 여전히 미추적·미스테이징 상태임을 확인했다.
- 배운 점: 연결 worktree의 index 잠금 실패는 코드·문서 변경과 구분해 기록하고, 재시도 때에도 명시 파일 목록으로 사용자의 미추적 파일을 보호한다.

### L-20260818-098 — worktree 루트에서 DocC 검증 프로젝트 경로를 찾지 못함

- 상태: 해결
- 발생 태스크: C3 자동 진행 최종 보수 — DocC 검증
- 재현: worktree 루트에서 `xcodebuild -project PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/piggyescape-auto-progress-final-docc docbuild`를 실행한다.
- 관찰: Simulator service 접근 경고 뒤 `xcodebuild: error: 'PiggyEscape.xcodeproj' does not exist.`로 종료했다. DocC 컴파일은 시작하지 않았다.
- 영향: 갱신한 tutorial·resource snippet의 DocC 검증 근거가 아직 없다.
- 원인/가설: Xcode project는 worktree 루트가 아니라 `PiggyEscape/PiggyEscape.xcodeproj`에 있다. L-20260811-087과 같은 상대 경로 기준 오류가 재발했다.
- 조치: 프로젝트 디렉터리를 명시 workdir로 사용해 동일 scheme·destination·derived data 조건으로 한 번 재실행한다.
- 검증: `PiggyEscape` 디렉터리에서 project를 찾는 것을 확인했고, 최종적으로 macOS arm64 destination의 `CODE_SIGNING_ALLOWED=NO docbuild`가 `** BUILD DOCUMENTATION SUCCEEDED **`로 끝났다.
- 배운 점: Xcode 검증 명령은 worktree 기준이 아니라 `.xcodeproj`가 있는 디렉터리 기준으로 실행 경로까지 함께 기록한다.

### L-20260818-099 — Simulator service가 DocC 검증 대상 기기를 열거하지 못함

- 상태: 해결
- 발생 태스크: C3 자동 진행 최종 보수 — DocC 검증
- 재현: `PiggyEscape` 디렉터리에서 iPhone 17 Pro Simulator destination으로 `docbuild`를 실행한다.
- 관찰: 프로젝트 경로는 찾았지만 `CoreSimulatorService connection became invalid` 뒤 `Unable to find a device matching ... iPhone 17 Pro`로 종료했다. Simulator runtime을 열거하지 못해 DocC 컴파일은 시작하지 않았다.
- 영향: iPhone Simulator destination의 DocC 검증을 이 실행으로 완료할 수 없다.
- 원인/가설: source 또는 DocC 오류가 아니라 현재 process가 CoreSimulatorService와 연결되지 않아 실제 iPhone Simulator 목록을 읽지 못하는 환경 제약이다.
- 조치: DocC가 target source를 컴파일하는지 별도로 확인할 수 있도록, Xcode가 제공한 Designed for iPad/iPhone on My Mac destination으로 동일 `docbuild`를 한 번 실행한다. iPhone Simulator build 성공 기록은 별도로 유지한다.
- 검증: iPhone 17 Pro Simulator destination의 기존 XCTest 101/101·0 failures와 Simulator build 성공은 유지한다. DocC는 runtime 열거와 분리해 macOS arm64 destination, `CODE_SIGNING_ALLOWED=NO`에서 `** BUILD DOCUMENTATION SUCCEEDED **`를 확인했다.
- 배운 점: 문서 컴파일 검증과 iOS Simulator runtime 검증은 독립 근거다. runtime을 열거할 수 없을 때는 지원되는 동일 scheme destination으로 문서 컴파일만 분리해 확인한다.

### L-20260818-100 — macOS destination의 variant 값이 xcodebuild 인자로 분리됨

- 상태: 해결
- 발생 태스크: C3 자동 진행 최종 보수 — DocC 검증
- 재현: `-destination 'platform=macOS,arch=arm64,variant=Designed for [iPad,iPhone]'`으로 `docbuild`를 실행한다.
- 관찰: `xcodebuild: error: unreadable input 'iPhone]' at end of value for option 'Destination'`로 argument parser가 종료했다. build는 시작하지 않았다.
- 영향: macOS destination을 이용한 DocC 검증도 아직 수행되지 않았다.
- 원인/가설: destination specifier의 comma가 variant value의 일부로 해석되지 않고 specifier 항목 경계로 처리됐다. 이 scheme에서는 platform·architecture만으로 이미 My Mac destination을 고를 수 있다.
- 조치: `platform=macOS,arch=arm64`만 지정해 같은 `docbuild`를 한 번 실행한다.
- 검증: `platform=macOS,arch=arm64` destination은 Xcode project를 정상 선택했고, 이어 `CODE_SIGNING_ALLOWED=NO`를 지정한 `docbuild`가 `** BUILD DOCUMENTATION SUCCEEDED **`로 끝났다.
- 배운 점: destination value 자체에 comma를 포함할 때는 전체 string quoting만으로 충분한지 먼저 Xcode parser를 확인하고, 유일한 destination이면 불필요한 variant를 제거한다.

### L-20260818-101 — DocC build가 로컬 signing team 부재로 source 컴파일 전에 중단됨

- 상태: 해결
- 발생 태스크: C3 자동 진행 최종 보수 — DocC 검증
- 재현: `-destination 'platform=macOS,arch=arm64'`으로 `docbuild`를 실행한다.
- 관찰: project와 DocC toolchain은 인식됐지만 `Signing for "PiggyEscape" requires a development team` 오류로 `** BUILD DOCUMENTATION FAILED **`가 출력됐다.
- 영향: 갱신한 DocC catalog의 compile 결과를 signing 설정과 분리해 확인하지 못했다.
- 원인/가설: scheme의 iOS app target이 local development team 없이 signing을 요구한다. 문서 source 오류가 아니라 target signing configuration이 build를 막은 것으로 진단됐다.
- 조치: 문서·Swift compile 검증만 수행하도록 동일 command에 `CODE_SIGNING_ALLOWED=NO`를 지정해 한 번 재실행한다. 이 값은 배포용 signing 검증을 대체하지 않는다.
- 검증: `CODE_SIGNING_ALLOWED=NO`를 지정한 macOS arm64 `docbuild`가 `** BUILD DOCUMENTATION SUCCEEDED **`로 끝났다. 이 검증은 signing 설정이 아닌 DocC·source 컴파일만 확인한다.
- 배운 점: DocC build에서 signing 오류가 먼저 나면 catalog 검증 결과로 해석하지 말고, code signing을 끈 문서 컴파일 실행을 별도 근거로 남긴다.

### L-20260818-097 — 단위 테스트의 연결되지 않은 pan recognizer가 translation을 전달하지 않음

- 상태: 해결
- 발생 태스크: C3 자동 진행 최종 보수 — 팬이 진행을 일으키지 않는 회귀 test
- 재현: `SCNView`에 연결하지 않은 새 `UIPanGestureRecognizer`에 `setTranslation`을 호출한 뒤 실제 `Coordinator.handlePan(_:)`을 호출하고 yaw 변화를 assertion한다.
- 관찰: focused test에서 `cameraYaw`가 초기값과 같아 `XCTAssertNotEqual` 한 건이 실패했다. 나머지 예약 지연·한 번 큐잉·dismantle 취소 test와 world test는 통과했다.
- 영향: 이 assertion은 pan recognizer test fixture가 실제 gesture state·translation을 전달했는지 검사하려 했지만, 자동 발견이 팬으로 발생하지 않는 계약 자체를 직접 검증하지 못한다.
- 원인/가설: recognizer를 view에 연결하거나 active gesture state로 전이하지 않아 `translation(in:)`이 0을 반환한 것으로 보인다. Coordinator의 자동 발견 경로는 pan handler에 없으므로, yaw 변화 assertion은 이 회귀의 필수 관찰값이 아니다.
- 조치: 실제 `handlePan(_:)` 호출은 유지하되 yaw 변화 assertion을 제거하고, controlled scheduler 예약 수와 discovery callback이 변하지 않는 행동을 검사한다.
- 검증: 실제 `handlePan(_:)` 뒤 controlled scheduler의 예약 수가 증가하지 않고 discovery callback도 0인 assertion을 포함해 focused C3 XCTest 12/12·0 failures, 전체 XCTest 101/101·0 failures, iPhone 17 Pro Simulator build 성공을 확인했다.
- 배운 점: 제스처 recognizer의 private state를 단위 테스트에서 인위적으로 만들기보다, 해당 handler 호출 뒤 사용자 계약에 직접 영향을 주는 callback·상태가 변하지 않는지 검증한다.

### L-20260818-096 — MainActor protocol conformance가 scheduler 기본 생성자의 격리를 유지함

- 상태: 해결
- 발생 태스크: C3 자동 진행 최종 보수 — scheduler 기본 생성
- 재현: L-20260818-095의 cancel 경계를 actor 독립으로 바꾼 뒤 동일 focused XCTest를 컴파일한다.
- 관찰: `C3TaskAutoDiscoveryScheduler`가 MainActor scheduler protocol을 준수하므로 class initializer도 actor 격리를 추론한다. 기본 인자 `= C3TaskAutoDiscoveryScheduler()`는 계속 nonisolated context에서 해당 initializer를 호출해 같은 격리 컴파일 오류가 남는다.
- 영향: cancellation 경계 보정만으로는 기본 production scheduler를 생성하지 못해 focused test가 실행되지 않는다.
- 원인/가설: protocol conformance가 type initializer의 actor 격리를 추론한다는 compiler note가 확인됐고, 문제 위치는 default argument evaluation 자체임이 분리됐다.
- 조치: default argument에서 scheduler를 만들지 않고 optional injection을 받는다. `Coordinator`의 MainActor initializer body에서 nil일 때 기본 scheduler를 생성한다.
- 검증: optional injection으로 바꾼 뒤 focused C3 XCTest 12/12·0 failures, 전체 XCTest 101/101·0 failures, iPhone 17 Pro Simulator build 성공을 확인했다.
- 배운 점: actor protocol의 기본 implementation을 optional dependency injection의 default expression으로 만들지 말고, actor-isolated initializer body에서 해소한다.

### L-20260818-095 — MainActor scheduler 기본 인자와 deinit 취소가 동기 격리 경계를 넘음

- 상태: 해결
- 발생 태스크: C3 자동 진행 최종 보수 — 예약 scheduler 주입
- 재현: scheduler protocol·기본 scheduler 구현을 추가한 뒤 focused C3 XCTest를 컴파일한다.
- 관찰: `Coordinator`의 기본 인자 `C3TaskAutoDiscoveryScheduler()`와 `deinit`의 `autoDiscoveryTask?.cancel()`에서 각각 `call to main actor-isolated ... in a synchronous nonisolated context` 컴파일 오류가 발생했다.
- 영향: controlled scheduler를 통한 실제 Coordinator lifecycle 테스트를 실행할 수 없고, 새 예약 경계가 앱 타깃에 빌드되지 않는다.
- 원인/가설: Swift에서 기본 인자 평가와 `deinit`은 `Coordinator` 클래스 선언의 MainActor 격리와 별개인 동기 nonisolated context라서 MainActor protocol initializer·method를 직접 호출할 수 없는 것이 compiler 진단으로 확인됐다.
- 조치: scheduler 자체의 cancel·생성을 MainActor에 묶지 않고, operation 실행만 MainActor task로 전환하는 최소 경계로 조정한다. Coordinator의 world 접근은 기존 MainActor closure 안에서만 유지한다.
- 검증: cancellation handle을 actor 독립으로 만들고 operation만 MainActor에서 실행하도록 조정한 뒤 focused C3 XCTest 12/12·0 failures, 전체 XCTest 101/101·0 failures, iPhone 17 Pro Simulator build 성공을 확인했다.
- 배운 점: actor 격리된 타입의 기본 인자와 deinit 수명 정리는 actor class 내부라도 별도 동기 context로 type-check되므로, cancellation handle은 actor 독립 경계로 설계해야 한다.

### L-20260818-094 — DocC 최상위 tutorial을 Tutorials 하위로 잘못 지정함

- 상태: 해결
- 발생 태스크: C3 자동 진행 최종 보수 — 교육 문서 대조
- 재현: `sed -n '1,300p' PiggyEscape/PiggyEscape/Tutorials/SceneKitToRealityKit.docc/Tutorials/SceneKitToRealityKit.tutorial`를 실행한다.
- 관찰: `No such file or directory`로 문서 읽기가 중단됐다.
- 영향: 해당 실행에서는 DocC 최상위 tutorial의 이전 카메라 발견 설명을 검토하지 못했다.
- 원인/가설: 파일은 `Tutorials/` 하위가 아니라 `.docc` 루트에 있어 경로를 한 단계 깊게 지정한 것이 확인된 원인이다.
- 조치: 실패를 기록한 뒤 `rg --files PiggyEscape/PiggyEscape/Tutorials/SceneKitToRealityKit.docc`로 실제 위치를 확인하고, 루트 파일을 명시해 대조한다.
- 검증: 파일 목록에서 `SceneKitToRealityKit.docc/SceneKitToRealityKit.tutorial`의 실제 위치를 확인했다.
- 배운 점: DocC catalog의 최상위 tutorial과 section tutorial은 같은 디렉터리 깊이에 있다고 가정하지 말고, resource 목록으로 위치를 먼저 확인한다.

### L-20260818-091 — 자동 진행 뒤 교육 문서가 제거된 카메라 발견 계약을 유지함

- 상태: 해결
- 발생 태스크: C3 자동 진행 최종 보수 — 문서 계약 정합성
- 재현: `docs/WORK_LOG.md`의 나무 도착 0.40초 자동 진행 설명을 `docs/PROJECT_CONTEXT.md`, `SceneKitToRealityKit.tutorial`, `01-ClosedWorld.tutorial`, `01-ClosedWorld-03-01.swift`와 대조한다.
- 관찰: 인수인계는 카메라 조작과 무관한 자동 발견을 기록하지만, 시작 문서와 DocC는 yaw·프러스텀·0.70 rad 회전 뒤 발견이라는 이전 계약을 설명한다.
- 영향: 다음 작업자와 학습자가 구현·실기기 수용 기준을 잘못 해석할 수 있으며, 현재 앱 동작과 튜토리얼이 달라진다.
- 원인/가설: 자동 진행 변경이 source·unit test·인수인계에만 적용되고, DocC resource snippet과 프로젝트 컨텍스트의 이전 설명은 같은 변경 단위에 포함되지 않은 것이 확인된 원인이다.
- 조치: 최신 2026-08-18 자동 진행 설계·실행 계획을 프로젝트 컨텍스트의 우선 기준으로 지정하고, DocC 본문·section·snippet을 나무 도착 뒤 0.40초 자동 발견 흐름으로 교체한다.
- 검증: PROJECT_CONTEXT와 DocC catalog를 대상으로 `yaw|frustum|0.70 rad|카메라를 돌리면|카메라에 의한 발견` 검색 결과가 없음을 확인했다. macOS arm64 destination에서 `CODE_SIGNING_ALLOWED=NO docbuild`가 `** BUILD DOCUMENTATION SUCCEEDED **`로 끝났다.
- 배운 점: 사용자 경험의 진행 조건을 바꾸면 코드·테스트·인수인계뿐 아니라 시작 문서와 교육용 code listing을 같은 커밋에서 함께 대조한다.

### L-20260818-092 — Coordinator의 자동 진행 예약·취소가 실제 lifecycle 경로에서 검증되지 않음

- 상태: 해결
- 발생 태스크: C3 자동 진행 최종 보수 — 예약 수명 회귀 테스트
- 재현: 실제 `C3ClosedWorldSceneView.Coordinator`에서 callback 설치 뒤 world의 나무 도착을 발생시키고, 지연 전·발화 뒤·`dismantleUIView` 뒤의 발견 callback을 결정론적으로 검사한다.
- 관찰: 현재 test는 `C3ClosedWorld`의 한 번 callback과 자동 발견 상태만 검사한다. Coordinator는 `Task.sleep`을 직접 만들므로 지연·한 번 큐잉·해제 취소를 wall-clock sleep 없이 관찰할 수 없다.
- 영향: 장면 해제 뒤 늦은 자동 발견이 전환을 재시작하거나, 예약이 즉시 또는 중복 발화하는 회귀를 자동 테스트가 막지 못한다.
- 원인/가설: 시간 의존성을 주입 가능한 경계로 분리하지 않았고, test가 실제 Coordinator의 `installCallbacks()`와 `dismantleUIView` lifecycle을 거치지 않은 것이 확인된 원인이다.
- 조치: production 기본 delay와 controlled test scheduler를 같은 최소 protocol 경계에 연결하고, 실제 coordinator callback·dismantle을 호출하는 회귀 test를 추가한다.
- 검증: scheduler seam 부재의 RED 컴파일 오류를 확인했다. 이후 실제 Coordinator callback·controlled scheduler 발화·dismantle 취소·팬 비진행을 포함한 focused C3 XCTest 12/12·0 failures, 전체 XCTest 101/101·0 failures, iPhone 17 Pro Simulator build 성공을 확인했다.
- 배운 점: 수명에 묶인 비동기 예약은 상태 기계만 테스트하지 말고, 실제 lifecycle 소유자의 예약·취소 경로를 시간 제어 seam으로 검증한다.

### L-20260818-093 — 시작 순서의 컨셉 노트가 현재 작업 트리에 없음

- 상태: 보류
- 발생 태스크: C3 자동 진행 최종 보수
- 재현: worktree 루트에서 `sed -n '1,240p' 씬킷에서_리얼리티킷으로_컨셉노트.md`를 실행한다.
- 관찰: `No such file or directory`로 문서를 읽지 못했다.
- 영향: 지정된 시작 순서의 컨셉 노트를 현재 브랜치에서 검토할 수 없다.
- 원인/가설: 현재 브랜치에 해당 문서가 포함되지 않은 것으로 보이며, `docs/PROJECT_CONTEXT.md`가 지정한 부재 처리와 같다.
- 조치: 이 태스크는 승인된 2026-08-18 설계·실행 계획, 현재 인수인계와 최종 검토 findings를 대체 근거로 사용한다.
- 검증: `rg --files`로 경로 부재와 관련 설계·계획 경로 존재를 확인할 예정이다.
- 배운 점: 시작 문서가 브랜치에 없으면 현재 코드와 상충하지 않는 승인된 명세를 대체 근거로 명시하고, 경로를 임의로 만들거나 범위를 확장하지 않는다.

### L-20260818-089 — 자동 진행 RED XCTest가 Simulator 서비스 접근 제한으로 중단됨

- 상태: 해결
- 발생 태스크: C3 자동 진행 Task 1 — 나무 도착 뒤 자동 발견
- 재현: `cd PiggyEscape && xcodebuild -project PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/ClosedWorldEscapeTests test`
- 관찰: 새 callback·자동 발견 API 부재를 확인해야 하는 컴파일 단계 전에 `CoreSimulatorService connection became invalid`, `Unable to discover any Simulator runtimes`, Xcode 로그 경로 `Operation not permitted`로 종료됨.
- 영향: 추가한 C3 자동 진행 테스트의 예상 RED 컴파일 오류를 아직 확인하지 못했고, source 회귀 여부도 이 실행으로 판단할 수 없음.
- 원인/가설: Simulator 서비스·runtime·로그 경로가 작업 트리 밖에 있어 현재 실행 환경에서 접근이 거부된 것으로 보이며, L-20260811-084와 같은 검증 환경 제약이 재발함.
- 조치: 실패를 먼저 기록하고, 동일한 명시 명령을 Simulator 서비스에 접근 가능한 환경에서 한 번 재실행해 예상 RED를 확인한다.
- 검증: 재실행에서 `onTreeHideFinished`와 `automaticallyDiscoverAfterTreeHide()`가 없다는 4개 컴파일 오류로 예상 RED를 확인했다. 구현 뒤 같은 focused XCTest 7/7, 전체 XCTest 97/97·0 failures 및 iPhone 17 Pro Simulator build가 성공했다.
- 배운 점: 새 행동 테스트의 RED도 컴파일 실패와 Simulator 초기화 실패를 구분해야 하며, 환경 중단 결과를 제품 코드의 실패 근거로 기록하지 않는다.

### L-20260811-088 — 최종 인수인계 커밋이 worktree Git index 잠금 권한으로 중단됨

- 상태: 해결
- 발생 태스크: 전체 브랜치 최종 검증 — 인수인계 결과를 Git으로 공유
- 재현: worktree에서 `git add docs/WORK_LOG.md && git commit -m 'Record final escape verification'`를 실행한다.
- 관찰: `fatal: Unable to create '.../.git/worktrees/ch1-reality-escape/index.lock': Operation not permitted`로 스테이징 전에 종료했다.
- 영향: 최신 전체 검증 결과를 추적 커밋으로 공유하지 못했으며, 코드·문서 내용은 변경되지 않았다.
- 원인/가설: 연결 worktree의 공용 Git 메타데이터에 현재 실행 권한으로 `index.lock`를 만들 수 없다.
- 조치: 실패 자체를 먼저 기록한 뒤, 공용 Git 메타데이터 쓰기가 허용된 동일 명령으로 재실행했다.
- 검증: `a9e42de Record final escape verification`이 생성됐고, `docs/WORK_LOG.md`와 이 항목만 포함했다.
- 배운 점: 연결 worktree에서 최종 문서 커밋도 소스 변경과 동일하게 Git 메타데이터 쓰기 권한을 사전 확인해야 한다.

### L-20260811-087 — worktree 루트에서 XCTest 프로젝트 경로를 찾지 못함

- 상태: 해결
- 발생 태스크: Task 6 최종 monitor 보수 2차 — 커밋 전 전체 검증
- 재현: worktree 루트에서 `xcodebuild -project PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/piggyescape-task6-monitor-repair2-tests test`를 실행한다.
- 관찰: XCTest가 시작되기 전에 `xcodebuild: error: 'PiggyEscape.xcodeproj' does not exist.`로 종료했다.
- 영향: 이 실행은 컴파일·테스트를 수행하지 못했으므로 커밋 전 검증 근거로 사용할 수 없다.
- 원인/가설: 프로젝트 파일은 worktree 루트가 아니라 `PiggyEscape/PiggyEscape.xcodeproj`에 있으며, 명령의 상대 경로 기준이 한 단계 달랐음이 `rg --files -g 'project.pbxproj' -g '*.xcodeproj' -g 'Project.swift'` 결과로 확인됐다.
- 조치: 프로젝트 디렉터리 `PiggyEscape`을 명시 workdir로 사용해 같은 scheme·destination·derived data 조건으로 검증을 다시 실행한다.
- 검증: `PiggyEscape` 디렉터리에서 같은 전체 XCTest가 99/99·0 failures 및 `** TEST SUCCEEDED **`로 끝났고, 같은 destination의 Simulator build도 `** BUILD SUCCEEDED **`로 끝났다.
- 배운 점: worktree 최상위와 Xcode 프로젝트 최상위를 구분하고, 검증 명령의 상대 경로는 실행 디렉터리와 함께 기록한다.

### L-20260811-086 — invalid reveal 관찰이 직전 visible 안정 frame을 유지함

- 상태: 해결
- 발생 태스크: Task 6 최종 monitor 보수 2차 — invalid projection 안정성
- 재현: 최초 block 뒤 임계값을 넘긴 pose에서 valid nonblocking 관찰을 한 번 전달하고, screen-out·camera-behind·중단된 projection을 뜻하는 invalid 관찰 한 번 뒤 같은 pose의 valid nonblocking 관찰을 한 번 전달한다.
- 관찰: `RealityHideARView.Coordinator.processRevealFrame`의 `guard isObservationValid`가 monitor 호출보다 먼저 return하므로, `RealityRevealMonitor`의 `stableVisibleObservationCount`가 invalid 관찰을 지나도 남는다. 실제 `evaluateReveal`도 projection gate 실패에서 monitor에 아무 신호를 주지 않고 return한다.
- 영향: 유효 관찰 두 frame이 연속이어야 한다는 계약이 끊긴 projection을 사이에 두고도 충족돼 돼지가 너무 이르게 발견될 수 있다.
- 원인/가설: invalid을 “monitor 입력 없음”으로 취급해, 기존 blocking pose는 보존해야 하지만 transient visible 안정성만 초기화해야 하는 상태 경계를 모델링하지 않은 것이 원인으로 보인다.
- 조치: `RealityRevealMonitor.recordInvalidObservation()`이 stable visible count만 0으로 만들고 최초 blocking pose는 보존하게 했다. `processRevealFrame(isObservationValid: false)`와 camera transform·projection gate의 early-return 경로가 이를 명시 호출한다.
- 검증: RED에서 새 focused 28개 중 이 사례의 두 assertion이 실패했고, 최초 pose latch만 고친 중간 실행에서도 같은 두 failure가 남아 원인을 분리했다. 최종 focused 28/28, 전체 XCTest 99/99·0 failures 및 Simulator build 성공을 확인했다.
- 배운 점: 관찰을 건너뛰는 것은 상태가 없다는 뜻이 아니다. 연속성 조건이 있으면 invalid frame도 안정성 상태를 명시적으로 갱신해야 한다.

### L-20260811-085 — 계속 가려진 frame이 최초 blocking camera pose를 덮어씀

- 상태: 해결
- 발생 태스크: Task 6 최종 monitor 보수 2차 — blocking pose cycle 기준
- 재현: pose A에서 실제 mesh block을 관찰한 뒤, pose B로 0.15m 이상 이동했지만 여전히 block인 frame을 전달하고, B에서 nonblocking 관찰을 두 frame 전달한다.
- 관찰: 현재 `RealityRevealMonitor.update`는 모든 blocked frame에서 `blockingPose = cameraPose`를 다시 대입한다. 따라서 B가 새 기준이 되어, 사용자가 A→B로 이미 움직였어도 B에서 다시 이동하기 전에는 재발견할 수 없다.
- 영향: 실제 물체를 따라 움직이며 시야를 찾는 사용자가 가림이 계속되는 동안의 유효한 이동을 잃고 추가 이동을 강요받을 수 있다.
- 원인/가설: `hasObservedBlockingMesh`가 hide cycle의 최초 block 여부를 표현하지만 `blockingPose` 대입은 이를 guard하지 않아, cycle 시작 기준과 후속 block의 visible 안정성 reset을 한 분기로 처리한 것이 원인으로 보인다.
- 조치: 최초 실제 block에서만 `blockingPose`를 latch하고 후속 block은 stable visible count만 reset하도록 바꿨다. 새 hide cycle은 기존 `RealityRevealMonitor()` 재생성 경계에서 latch를 비운다.
- 검증: RED에서 새 focused 28개 중 A block → B block → B visible 두 frame 사례의 assertion 1건이 실패했다. latch만 적용한 중간 실행에서 이 사례는 통과했고 invalid 관찰의 두 failure만 남아 변경 효과를 분리했다. 최종 focused 28/28, 전체 XCTest 99/99·0 failures 및 Simulator build 성공을 확인했다.
- 배운 점: cycle의 기준 pose와 frame마다 초기화해야 하는 안정성 counter는 별도 상태다. 하나의 block 분기에서 함께 갱신하면 사용자의 이미 수행한 이동을 잃을 수 있다.

### L-20260811-084 — focused XCTest가 Simulator 서비스 접근 제한으로 시작 전에 중단됨

- 상태: 해결
- 발생 태스크: Task 6 최종 통합 리뷰 보수 — floor·reveal·readiness 검증
- 재현: `cd PiggyEscape && xcodebuild -project PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/RealityHidePlannerTests -only-testing:PiggyEscapeTests/RealityHideARViewCoordinatorTests test`
- 관찰: `CoreSimulatorService connection became invalid`, `Error opening log file ... Operation not permitted`, `Unable to discover any Simulator runtimes`가 출력돼 XCTest 컴파일·assertion 전에 중단됨
- 영향: source 수정의 focused 검증 결과를 sandbox 실행만으로 확정할 수 없음
- 원인/가설: Simulator 서비스·runtime·로그 경로가 worktree 밖에 있어 현재 sandbox 접근이 거부된 것으로 보이며, L-20260811-078·069와 같은 환경 제약이 재발함
- 조치: 같은 명시 명령만 Simulator 서비스에 접근 가능한 권한으로 한 번 재실행했다.
- 검증: 권한 재실행에서 `RealityHidePlannerTests` 15개와 `RealityHideARViewCoordinatorTests` 11개, 합계 26개가 0 failures 및 `** TEST SUCCEEDED **`로 끝났다. 이어 전체 XCTest 97/97·0 failures와 Simulator build `** BUILD SUCCEEDED **`를 확인했다.
- 배운 점: Simulator 초기화 실패는 source 회귀와 구분하고, 접근 가능한 동일 명령의 현재 실행 결과로만 검증 근거를 갱신한다.

### L-20260811-083 — AR plane 변환 체인이 Swift 컴파일러 type-check 한계를 초과함

- 상태: 해결
- 발생 태스크: Task 6 최종 통합 리뷰 보수 — floor footprint 구현
- 재현: `cd PiggyEscape && xcodebuild -project PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/RealityHidePlannerTests -only-testing:PiggyEscapeTests/RealityHideARViewCoordinatorTests test`
- 관찰: `RealityHideARView.nearestFloor`의 `anchors → compactMap → filter → compactMap → min` 단일 식에서 `the compiler is unable to type-check this expression in reasonable time`가 발생해 XCTest 컴파일 전에 중단됨
- 영향: footprint 동작을 검증할 focused XCTest 자체를 실행할 수 없음
- 원인/가설: ARKit anchor downcast와 두 closure의 추론·`RealityFloorPlane` 생성·최솟값 비교를 하나의 generic chain에 결합해 Swift type checker가 과도한 추론을 해야 했음
- 조치: plane anchor 수집, footprint 포함 floor 생성, 높이 기준 선택을 명시적 지역 값으로 분리했다. iOS 16 이후 API에서는 `planeExtent`의 width·height·Y축 회전을 사용하고, 회전된 extent도 pure footprint 검사로 처리한다.
- 검증: 같은 focused XCTest는 `RealityHidePlannerTests` 15개와 `RealityHideARViewCoordinatorTests` 11개, 합계 26개를 0 failures로 통과했으며 Swift type-check 오류와 `extent` 사용 중단 경고는 다시 출력되지 않았다. 전체 XCTest 97/97·0 failures 및 Simulator build 성공을 추가 확인했다.
- 배운 점: ARKit anchor 변환처럼 타입이 많은 pipeline은 짧은 체인보다 단계별 지역 값이 컴파일 진단과 유지보수에 안전하다.

### L-20260811-082 — AR 스캔 준비 콜백이 실제 공간 관찰보다 먼저 발생함

- 상태: 해결
- 발생 태스크: Task 6 최종 통합 리뷰 보수 — 스캔 준비 시점
- 재현: `RealityHideARView.Coordinator.attach(to:)`에서 AR 세션 실행·anchor 연결·`onScanningReady` 호출 순서를 추적하고, frame anchor 관찰 전후 callback 수를 확인하는 seam을 준비함
- 관찰: 현재 구현은 세션 시작 직후 `onScanningReady()`를 호출하며, 첫 `ARMeshAnchor` 또는 분류된 수평 floor anchor가 생겼는지 확인하지 않음
- 영향: 상위 화면은 실제로 “숨을 물체의 옆면을 탭해줘.”라고 안내할 준비가 되지 않았는데도 target 선택 상태로 넘어갈 수 있어 `scanFirst` 안내와 실제 공간 상태가 어긋남
- 원인/가설: 세션을 시작할 수 있다는 capability와 공간에서 의미 있는 floor/mesh 관찰을 마쳤다는 readiness를 같은 사건으로 취급한 것이 확인된 원인임
- 조치: 세션 시작 직후 callback을 제거하고, 첫 `ARMeshAnchor` 또는 분류된 수평 floor anchor를 관찰했을 때 한 번만 readiness를 내보내는 상태를 추가했다. 관찰 뒤에는 subscription을 취소하고 `stop()`도 이를 취소한다.
- 검증: production 변경 전 focused coordinator XCTest는 새 seam 부재로 컴파일에 실패하는 RED를 보였다. 변경 뒤 mesh/floor 전에는 callback이 없고 첫 관찰 뒤 한 번만 발생하는 assertion을 포함한 focused 26/26, 전체 XCTest 97/97·0 failures 및 Simulator build 성공을 확인했다.
- 배운 점: AR 세션 실행 성공은 센서 데이터가 사용자 선택을 지원할 만큼 준비되었다는 신호가 아니다.

### L-20260811-081 — 한 번의 mesh hit 누락이 카메라 정지 상태에서도 재발견을 발생시킴

- 상태: 해결
- 발생 태스크: Task 6 최종 통합 리뷰 보수 — 물리적 재발견 gate
- 재현: `RealityRevealMonitor`에 blocked mesh 관찰 뒤 동일한 camera pose와 `meshDistance: nil`을 전달하는 수치 입력을 추적함
- 관찰: 현재 monitor는 blocked 여부만 저장한 뒤 다음 nonblocking 입력 하나에서 `true`를 반환하며, camera pose·방향·연속 관찰 수를 받지 않음
- 영향: 공간 메쉬 갱신이나 hit jitter만으로 돼지가 “들켰다” 상태가 될 수 있어 사용자가 실제로 카메라를 움직여 찾아낸다는 경험 계약을 깨뜨림
- 원인/가설: 재발견 data-flow가 `ARView`의 mesh 거리만 전달하고, 같은 frame에서 이미 읽을 수 있는 AR camera transform을 monitor 경계에 전달하지 않은 것이 확인된 원인임
- 조치: `RealityRevealMonitor` 입력에 실제 `ARFrame.camera.transform`에서 얻은 position·forward pose를 추가했다. 이전 blocking pose에서 0.15m 이상 이동하거나 15° 이상 회전한 뒤 연속된 두 nonblocking 관찰이 있어야 한 번만 재발견한다. 다시 block되면 안정 관찰 수를 초기화한다.
- 검증: production 변경 전 focused planner XCTest는 camera pose API 부재로 컴파일에 실패하는 RED를 보였다. 정지/null, 0.149m·15° 미만, 정확히 0.15m·15°, interrupted visibility, one-time 사례를 포함한 focused 26/26, 전체 XCTest 97/97·0 failures 및 Simulator build 성공을 확인했다.
- 배운 점: 센서의 가시성 변화는 사용자 시점 변화와 구분해야 하며, 한 frame의 null 결과만으로 경험 상태를 전이하면 안 된다.

### L-20260811-080 — floor 선택이 평면 발자국 대신 anchor 중심 거리를 사용함

- 상태: 해결
- 발생 태스크: Task 6 최종 통합 리뷰 보수 — 선택 물체 아래 바닥 판정
- 재현: `RealityHideARView.nearestFloor`가 각 `ARPlaneAnchor`를 transform된 center 하나의 `RealityFloor`로 바꾸는 흐름과 Task 5의 1.2m XZ 검사를 대조함
- 관찰: 큰 floor plane 안의 선택 점이 center에서 1.2m 넘게 떨어지면 실제 바닥이 있어도 거절될 수 있고, center 근처지만 footprint 밖인 점은 바닥으로 잘못 받아들일 수 있음
- 영향: 돼지가 사용자가 선택한 실제 물체 아래 바닥이 아닌 anchor 중심 기준으로 숨기 좌표를 계산하거나 유효한 넓은 바닥을 불필요하게 거절할 수 있음
- 원인/가설: ARPlaneAnchor의 local `center`·`extent`·`transform`을 사용해 선택 world point의 footprint 포함을 판정하지 않은 것이 확인된 원인임
- 조치: world point를 anchor local 좌표로 변환해 center·width·height·Y축 extent 회전이 만든 footprint 안인지 검사하고, 같은 local XZ를 floor Y로 투영한다. 2cm만 가장자리 jitter 여유로 허용한다. 1.2m 제한은 anchor 중심과 무관한 selected-point/floor XZ 안전 경계로 문서화해 유지했다.
- 검증: production 변경 전 focused XCTest는 `RealityFloorPlane` 타입 부재로 컴파일에 실패하는 RED를 보였다. 회전된 큰 plane 안이지만 중심에서 1.2m 넘는 점의 수용, 가까운 중심 밖 점의 거절, 2cm 경계와 extent 회전을 포함한 focused 26/26, 전체 XCTest 97/97·0 failures 및 Simulator build 성공을 확인했다.
- 배운 점: AR 평면의 중심은 발자국 전체를 대표하지 않으므로, 실제 선택 좌표는 local footprint로 판정해야 한다.

### L-20260811-079 — 카메라 거부 상태를 Settings 복귀 신호로 잘못 해석해 일반 active마다 권한을 조회함

- 상태: 해결
- 발생 태스크: Task 7 보수 2차 — 명시적 Settings 복귀 1회 조회
- 재현: 카메라를 거부해 `.cameraDenied`가 된 뒤 `설정 열기`를 탭하지 않고 앱 lifecycle의 active 알림을 두 번 전달함. 이어 `설정 열기`를 한 번 탭한 뒤 active를 두 번 전달함.
- 관찰: 기존 `applicationDidBecomeActive()`는 `.cameraDenied`만 확인하고 매번 `currentVideoAuthorization()`을 호출한다. 이에 따라 Settings를 열지 않은 active에도 조회가 발생하고, Settings를 닫고 권한을 바꾸지 않은 뒤 반복 active에서는 두 번 조회한다. 이전 테스트도 이 두 번째 관찰을 기대값 `2`로 고정해 잘못된 계약을 강화했다.
- 영향: 사용자가 Settings 복구를 선택하지 않았어도 lifecycle 변화가 권한 상태를 읽으며, Settings 복귀 후에도 재시도 경계가 한 번으로 제한되지 않는다.
- 원인/가설: `.cameraDenied` 상태가 Settings를 실제로 열었다는 사용자 의도를 보존하지 못하는데도 그것만 lifecycle guard로 사용한 것이 확인된 원인이다.
- 조치: `openSettingsForRecovery()`의 명시적 사용자 동작에서만 1회 복귀 대기 상태를 설정한다. 다음 active는 이를 권한 조회 전에 소비하고, 이후 active는 거부·제한 상태를 유지하되 조회하지 않는다. 두 번째 명시적 Settings 탭은 새 1회 조회를 허용한다.
- 검증: `EscapeRootCoordinatorTests` focused XCTest는 기존 구현에서 Settings 미탭·반복 active의 조회 횟수 assertion 3건이 실패해 16개 중 3 failures로 RED를 확인했다. 최소 플래그 적용 뒤 focused 16/16, 전체 XCTest 87/87·0 failures 및 iPhone 17 Pro Simulator build 성공을 확인했다.
- 배운 점: lifecycle event 자체를 사용자 의도로 취급하지 말고, 외부 앱 전환을 시작한 명시적 UI action과 복귀 소비 횟수를 별도로 모델링한다.

### L-20260811-078 — 최종 focused XCTest가 Simulator 서비스 접근 제한으로 중단됨

- 상태: 해결
- 발생 태스크: Task 7 보수 — 권한 복귀와 외부 콜백 수명
- 재현: `PiggyEscape/`에서 `xcodebuild -project PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/piggyescape-task7-repair-green -only-testing:PiggyEscapeTests/EscapeRootCoordinatorTests test` 실행
- 관찰: `CoreSimulatorService connection became invalid`, `Error opening log file ... Operation not permitted`, `Unable to discover any Simulator runtimes`가 출력돼 XCTest assertion 실행 전에 중단됨
- 영향: 현재 source 수정 뒤 focused XCTest 결과를 sandbox 안에서 확인할 수 없으므로, 앞선 성공 결과만으로 이 재검증을 대체할 수 없음
- 원인/가설: Simulator 서비스·로그·runtime 상태 경로가 worktree 밖에 있어 sandbox 접근이 거부된 것으로 보이며 L-20260811-069와 같은 환경 제약이 재발함
- 조치: 실패 기록 뒤 동일한 명시 명령을 Simulator 서비스에 접근 가능한 권한으로 한 번만 재실행함
- 검증: 권한 재실행에서 focused XCTest 14/14, 전체 XCTest 85/85·0 failures 및 iPhone 17 Pro Simulator build 성공을 확인함
- 배운 점: 코드 경로가 아니라 Simulator 초기화에서 멈춘 실행은 새 회귀로 분류하지 말고, 현재 명령을 접근 가능한 환경에서 재검증한 뒤에만 완료 근거로 사용한다.

### L-20260811-077 — worktree 루트에서 Xcode 프로젝트 경로를 찾지 못함

- 상태: 해결
- 발생 태스크: Task 7 보수 — 권한 복귀와 외부 콜백 수명
- 재현: worktree 루트에서 `xcodebuild -project PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/piggyescape-task7-repair-green -only-testing:PiggyEscapeTests/EscapeRootCoordinatorTests test` 실행
- 관찰: Simulator 서비스 접근 경고 뒤 `xcodebuild: error: 'PiggyEscape.xcodeproj' does not exist.`로 테스트 실행 전에 종료됨
- 영향: 앱 소스·테스트 컴파일과 assertion은 시작하지 않았으므로, 이 종료를 제품 회귀나 Simulator 결과로 해석할 수 없음
- 원인/가설: 생성된 Xcode 프로젝트는 worktree 루트가 아닌 `PiggyEscape/` 하위 디렉터리에 있으며, 검증 명령의 작업 디렉터리를 그 위치로 지정하지 않은 것이 확인된 원인임
- 조치: 임의 경로 탐색이나 프로젝트 복제 없이, 같은 명령을 `PiggyEscape/` 디렉터리에서 다시 실행함
- 검증: 수정한 작업 디렉터리에서 focused XCTest 14/14, 전체 XCTest 85/85·0 failures 및 iPhone 17 Pro Simulator build 성공을 확인함
- 배운 점: worktree 이름과 Xcode 프로젝트 디렉터리를 같다고 가정하지 말고, 검증 전 `Project.swift`·생성 `.xcodeproj`의 실제 위치를 기준으로 작업 디렉터리를 고정한다.

### L-20260811-076 — AR 스캔 준비 안내는 세션 실행 직후이며 실제 재구성 준비 완료를 뜻하지 않음

- 상태: 보류
- 발생 태스크: Task 7 보수 — 권한 복귀와 외부 콜백 수명
- 재현: `RealityHideARView.Coordinator.attach(to:)`에서 `arView.session.run(...)`와 `onScanningReady()`의 순서를 대조함
- 관찰: 현재 callback은 세션 실행 직후 발생하며 첫 AR frame·메쉬 재구성·분류된 바닥을 기다리지 않는다. 이번 보수는 SwiftUI update 중 발행을 막기 위해 루트에서 다음 turn으로 옮길 뿐, callback의 RealityKit 의미는 바꾸지 않는다.
- 영향: 사용자는 AR 화면이 열리자마자 옆면 선택 안내를 볼 수 있으나 실제 세로 메쉬·바닥이 아직 부족하면 기존 재스캔 안내를 받을 수 있다.
- 원인/가설: Task 6의 `onScanningReady`가 센서 데이터 가용성 대신 AR 세션 시작을 나타내도록 정의돼 있으며, 실제 재구성 준비 기준은 아직 별도 상태로 모델링되지 않았음
- 조치: Task 7 범위를 넘는 RealityKit 세션·평면·재발견 로직은 변경하지 않는다. 실제 mesh/frame 준비 기준과 안내 시점의 개선은 다음 RealityKit 보수 태스크에서 독립적으로 설계·테스트한다.
- 검증: 이번 Task 7 repair는 callback 전달을 다음 MainActor turn으로 지연하고 stale callback을 폐기하는 focused XCTest로만 보호한다. 실제 mesh 준비 기준은 실기기 관찰과 별도 테스트가 필요함.
- 배운 점: AR 세션 시작과 사용자가 행동할 수 있는 공간 재구성 준비 완료를 같은 readiness 용어로 묶지 말고, 후속 설계에서 각각의 관찰 가능한 기준을 둔다.

### L-20260811-075 — actor 격리된 callback deferrer를 relay 기본 인자에서 생성할 수 없음

- 상태: 해결
- 발생 태스크: Task 7 보수 — 권한 복귀와 외부 콜백 수명
- 재현: callback relay·현재 권한 조회의 최소 구현 뒤 `EscapeRootCoordinatorTests` focused XCTest 컴파일
- 관찰: `RealityCallbackRelay.init(deferrer: any MainActorCallbackDeferring = TaskMainActorCallbackDeferrer())`에서 `Call to main actor-isolated initializer 'init()' in a synchronous nonisolated context`가 발생해 앱 모듈 생성이 중단됨
- 영향: 권한 복귀·callback relay assertion까지 실행하지 못하며, 이 컴파일 실패를 기능 GREEN으로 해석할 수 없음
- 원인/가설: `MainActorCallbackDeferring` 적합성으로 시스템 deferrer의 생성도 MainActor에 격리됐지만, relay initializer의 기본 인자 평가 지점은 동기 비격리로 처리된 것이 L-20260811-062와 같은 원인임
- 조치: 기본 인자 생성식을 없애고 MainActor 무인자 initializer에서 시스템 deferrer를 만들며, 테스트용 주입 initializer는 의존성만 받게 분리함
- 검증: 기본 인자를 제거한 뒤 `EscapeRootCoordinatorTests` focused XCTest 14/14, 전체 XCTest 85/85·0 failures 및 iPhone 17 Pro Simulator build 성공을 확인했고 같은 actor 격리 컴파일 오류는 다시 출력되지 않음
- 배운 점: MainActor 의존성을 가진 relay·coordinator도 기본 인자 생성으로 편의화하지 말고, 격리된 무인자 경계와 명시적 주입 경계를 나눈다.

### L-20260811-074 — RealityKit 준비 콜백이 SwiftUI 뷰 생성 중 루트 상태를 동기로 바꿈

- 상태: 해결
- 발생 태스크: Task 7 보수 — 권한 복귀와 외부 콜백 수명
- 재현: `RealityHideARView.makeUIView` → `Coordinator.attach(to:)` → `onScanningReady()` 호출과 `EscapeRootView`가 전달한 `coordinator.realityScanningDidBecomeReady`를 따라감
- 관찰: `attach(to:)`는 `makeUIView`의 동기 호출 경로에서 지원 확인 뒤 `onScanningReady()`를 바로 실행한다. 루트는 이를 `@Published machine` 변경으로 연결하므로 SwiftUI가 UIKit 뷰를 생성·갱신하는 같은 turn에 상태를 발행할 수 있다. 미지원 경로의 `onUnavailable()`도 같은 외부 callback 경계를 가진다.
- 영향: SwiftUI 갱신 중 상태 발행 경고·재렌더링 순서 불안정·dismantle 뒤 이미 예약된 callback이 새 화면 상태를 덮는 위험이 있다.
- 원인/가설: Task 7 루트가 `UIViewRepresentable` 외부 callback을 UIKit 생성 경계 밖의 다음 MainActor turn으로 넘기지 않고 coordinator 메서드를 직접 전달한 것이 확인된 원인이다.
- 조치: `RealityHideARView` 내부의 세션·평면·재발견 로직은 변경하지 않는다. 루트 소유의 취소 가능한 callback relay를 추가해 모든 AR 외부 callback을 다음 MainActor turn으로 지연하고, AR 화면 해제·뷰 사라짐 뒤 세대가 다른 callback을 버리도록 한다.
- 검증: type 부재로 실패한 RED 뒤 relay의 동기 미발행·다음 turn 전달·해제 뒤 stale callback 폐기를 포함한 `EscapeRootCoordinatorTests` focused XCTest 14/14, 전체 XCTest 85/85·0 failures 및 iPhone 17 Pro Simulator build 성공을 확인함. 실제 mesh 준비 기준은 L-20260811-076으로 분리해 보류함.
- 배운 점: `UIViewRepresentable.makeUIView`에서 온 callback은 MainActor 위에 있더라도 SwiftUI update 중일 수 있으므로, 상태를 직접 발행하지 말고 수명 가드가 있는 다음 turn으로 넘긴다.

### L-20260811-073 — Settings 복귀 후 카메라 허용 상태를 다시 읽지 못함

- 상태: 해결
- 발생 태스크: Task 7 보수 — 권한 복귀와 외부 콜백 수명
- 재현: C3 발견 뒤 권한을 거부하고 `설정 열기`를 눌러 앱 Settings에서 카메라를 허용한 다음 앱을 foreground/active로 복귀함
- 관찰: `openSettingsForRecovery()`는 Settings URL만 열고, `EscapeRootView`에는 `scenePhase`/foreground 관찰이 없다. `EscapeExperienceMachine`도 `.cameraDenied`에서 `.cameraAuthorized`로 가는 전이가 없어, 현재 권한이 허용으로 바뀌어도 `.cameraDenied` 안내에 머문다.
- 영향: 사용자가 명시적으로 카메라를 허용해도 AR 화면으로 이어지지 않으며, 다시 권한 요청을 시도하는 임시 우회는 시스템 문구·Settings 재열기 규칙을 어길 수 있다.
- 원인/가설: 초기 권한 요청의 callback만 상태 기계에 연결하고, Settings 복귀라는 별도 lifecycle 경계의 현재 권한 조회와 합법적인 재진입 전이를 설계하지 않은 것이 확인된 원인이다.
- 조치: prompt-capable 요청과 현재 상태 조회를 `CameraAuthorizing`에서 분리한다. `설정 열기`의 명시적 탭이 1회 복귀 대기를 남긴 경우에만 앱 active에서 현재 상태를 읽고, 허용이면 한 번 `.scanningReality`로 전환한다. 거부·제한이면 현재 차단 안내를 유지하며, 대기는 조회 전에 소비한다. 이 경로에서는 권한 요청·Settings 열기를 자동 실행하지 않는다.
- 검증: 1차 보수 뒤 일반 active마다 조회하던 회귀를 L-20260811-079로 확인했다. Settings 미탭 active, Settings에서 허용 후 active, 변경 없이 Settings 닫기, 제한 상태, 반복 active, 두 번째 Settings 탭, 이미 AR에 진입한 상태를 포함한 `EscapeRootCoordinatorTests` focused XCTest 16/16, 전체 XCTest 87/87·0 failures 및 iPhone 17 Pro Simulator build 성공을 확인함.
- 배운 점: Settings 복구는 URL을 여는 동작으로 끝나지 않으며, 복귀 lifecycle에서 비침습적인 현재 권한 조회와 중복 없는 상태 재진입을 함께 계약해야 한다.

### L-20260811-072 — 공동 시작 문서가 현재 worktree에 없음

- 상태: 보류
- 발생 태스크: Task 7 보수 — 권한 복귀와 외부 콜백 수명
- 재현: 저장소 시작 순서에 따라 `씬킷에서_리얼리티킷으로_컨셉노트.md`를 읽으려 했음
- 관찰: 현재 worktree 루트에 해당 파일이 없어 `sed: ... No such file or directory`로 종료됨
- 영향: 별도 컨셉 노트를 보조 근거로 읽을 수 없으므로, 현재 승인 설계와 실행 계획만을 구현 근거로 사용해야 함
- 원인/가설: `docs/PROJECT_CONTEXT.md`가 이미 허용한 현재 브랜치의 문서 부재 상태이며, 작업 시작 시점에는 파일이 제공되지 않았음
- 조치: 파일을 새로 만들거나 다른 위치의 대화 기록으로 대체하지 않고, `docs/superpowers/specs/2026-08-10-ch1-reality-escape-design.md`와 실행 계획을 현재 범위의 기준으로 사용함
- 검증: 이번 보수의 변경 범위는 Task 7 루트·상태 전이·테스트·인수인계·학습 기록에 한정함
- 배운 점: 공동 시작 문서가 없으면 추정으로 복원하지 말고 승인된 설계 명세를 대체 근거로 명시한다.

### L-20260811-071 — Task 8 문서 staging이 연결 작업 트리 index 잠금 권한으로 중단됨

- 상태: 해결
- 발생 태스크: Task 8 — 전체 회귀·실기기 검증과 DocC·인수인계
- 재현: `git add PiggyEscape/PiggyEscape/Tutorials docs/PROJECT_CONTEXT.md docs/WORK_LOG.md docs/LEARNING_LOG.md docs/TROUBLESHOOTING.md docs/superpowers/plans/2026-08-10-ch1-reality-escape-implementation.md`
- 관찰: `fatal: Unable to create '.../.git/worktrees/ch1-reality-escape/index.lock': Operation not permitted`로 명시 경로 staging 전에 종료됨
- 영향: 검증된 Task 8 튜토리얼·공유 문서를 아직 커밋할 수 없음
- 원인/가설: L-20260810-048과 같은 연결 작업 트리 공용 Git index 잠금 경로가 현재 권한 범위 밖인 것으로 보임
- 조치: 실패 기록 뒤 동일한 명시 경로만 공용 Git 메타데이터에 접근 가능한 권한으로 한 번 재실행했다. `.claude/`와 생성물은 계속 제외했다.
- 검증: 권한 재실행 뒤 cached diff 검사에 오류가 없었고, staged 목록은 Task 8 tutorial·tracked 문서만, 작업 트리에는 사용자 소유 `.claude/`만 남았다.
- 배운 점: 최종 문서 태스크도 worktree 파일 수정과 Git index lock 쓰기는 다른 권한 경계이므로, staging 실패 뒤 일부 파일이 추가됐다고 가정하지 않는다.

### L-20260811-070 — Task 8 DocC build가 두 개의 섹션에 Steps 지시문 누락 경고를 출력함

- 상태: 보류
- 발생 태스크: Task 8 — 전체 회귀·실기기 검증과 DocC·인수인계
- 재현: `cd PiggyEscape && xcodebuild docbuild -project PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/piggyescape-reality-docc`
- 관찰: DocC archive는 생성됐지만 카메라 권한 전환·실기기 확인 섹션에서 각각 `Missing 'Steps' child directive` 경고가 출력됨. Chapter의 Image child 경고도 기존 이미지 에셋을 추가하지 않는 범위에서 계속 출력됨.
- 영향: 문서는 생성됐지만 두 섹션이 튜토리얼 단계 구조를 충족하지 못하며, 경고 없는 DocC 결과로 해석할 수 없음
- 원인/가설: 두 섹션이 `@ContentAndMedia`만 포함하고 `@Steps`를 선언하지 않았음. Chapter Image 경고는 새 이미지 에셋을 금지한 현재 C3 디자인 제약과 기존 카탈로그 구조의 충돌임.
- 조치: Steps 누락은 같은 튜토리얼 안에 짧은 관찰·복구 단계를 추가해 고쳤다. Image 경고는 존재하지 않는 이미지 파일을 참조하거나 새 이미지 에셋을 추가하지 않고, 제한 사항으로 남긴다.
- 검증: 수정 뒤 같은 `xcodebuild docbuild`를 재실행해 두 Steps 경고가 사라졌고 `** BUILD DOCUMENTATION SUCCEEDED **` 및 `/tmp/piggyescape-reality-docc/Build/Products/Debug-iphonesimulator/PiggyEscape.doccarchive` 존재를 확인했다. `@Chapter`의 Image child 경고 1건은 남아 있다.
- 배운 점: DocC가 archive를 생성해도 구조 경고를 성공으로 묶지 말고, 코드·에셋 범위 제약으로 남는 경고와 문서 구조 결함을 구분한다.

### L-20260811-069 — Task 8 전체 XCTest가 Simulator 서비스 접근 제한으로 중단됨

- 상태: 해결
- 발생 태스크: Task 8 — 전체 회귀·실기기 검증과 DocC·인수인계
- 재현: `cd PiggyEscape && xcodebuild -project PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/piggyescape-reality-tests test`
- 관찰: `CoreSimulatorService connection became invalid`, `Error opening log file ... Operation not permitted`, `Unable to discover any Simulator runtimes`가 출력돼 XCTest 실행 전 Simulator 초기화가 중단됨
- 영향: 전체 XCTest 수·실패 수를 현재 권한에서 확인할 수 없으며, 이 종료를 코드·DocC 실패로 해석할 수 없음
- 원인/가설: L-20260811-059와 같은 Simulator 서비스·로그·기기 상태 경로가 작업 트리 밖에 있어 접근이 거부된 것으로 보임
- 조치: 실패 기록 뒤 Simulator 서비스에 접근 가능한 권한으로 같은 명시 명령을 한 번 재실행했다.
- 검증: 권한 재실행에서 `PiggyEscapeTests.xctest` 79개가 0 failures로 끝났고 `** TEST SUCCEEDED **`를 확인했다. 기존 AppIntents·SceneKit·RealityKit Simulator 경고는 L-20260811-064·L-20260810-046과 같은 범위 밖 진단으로 별도 보류한다.
- 배운 점: 최종 회귀도 종료 코드나 사전 기록이 아니라, 현재 실행의 XCTest 수와 `TEST SUCCEEDED`를 근거로만 판정한다.

### L-20260811-068 — Task 8 DocC 검증 준비의 Tuist 생성이 세션 상태 디렉터리 권한으로 중단됨

- 상태: 해결
- 발생 태스크: Task 8 — 전체 회귀·실기기 검증과 DocC·인수인계
- 재현: `cd PiggyEscape && tuist generate --no-open`
- 관찰: `Fatal error: Error raised at top level: Permission denied: /Users/yang-eunseo/.local/state/tuist/sessions/...`로 생성 프로젝트 갱신 전에 종료됨
- 영향: 바뀐 DocC 원본과 전체 XCTest가 현재 생성 프로젝트에 반영됐는지 확인할 수 없음
- 원인/가설: L-20260811-058과 같은 Tuist 사용자 세션 상태 경로가 작업 트리 밖에 있어 현재 권한에서 쓰기 거부된 것으로 보임
- 조치: 이 실패를 기록한 뒤 사용자 세션 상태에 접근 가능한 권한으로 같은 명령을 한 번 재실행했다.
- 검증: 권한 재실행이 `✔ Success`로 끝나 `PiggyEscape.xcodeproj`·workspace를 새로 생성했다. XCTest·DocC 결과는 별도 명령으로 계속 검증한다.
- 배운 점: 최종 DocC 검증도 일반 Xcode 프로젝트가 최신이라고 가정하지 말고, Tuist 생성 실패와 문서 자체 오류를 분리해야 한다.

### L-20260811-067 — Task 8 시작 전 원격 fetch가 연결 작업 트리 메타데이터 권한으로 중단됨

- 상태: 보류
- 발생 태스크: Task 8 — 전체 회귀·실기기 검증과 DocC·인수인계
- 재현: `git fetch --prune origin`
- 관찰: `error: cannot open '.../.git/worktrees/ch1-reality-escape/FETCH_HEAD': Operation not permitted`로 원격 참조 갱신 전에 종료됨
- 영향: Task 8 문서·검증 시작 시점의 원격 변경 여부를 현재 권한 범위에서 확정할 수 없음
- 원인/가설: L-20260811-049와 같은 연결 작업 트리 공용 Git 메타데이터 `FETCH_HEAD` 쓰기 경로의 권한 제약이 재발한 것으로 보임
- 조치: 실패 근거를 먼저 남기고, 권한이 허용되는 환경에서 같은 명령을 한 번만 재실행해 결과를 확인한다. 그 전에는 원격 상태를 추정하지 않는다.
- 검증: 재실행 전 상태는 사용자 소유의 추적되지 않은 `.claude/`만 표시하며, Task 8 문서 변경은 아직 시작하지 않음
- 배운 점: 최종 문서 태스크도 시작 순서의 fetch 실패를 이전 성공으로 대체하지 말고, 현재 재현·영향·보류 상태를 독립 항목으로 남긴다.

### L-20260811-066 — 최종 `tuist test`가 성공 코드와 함께 테스트를 건너뜀

- 상태: 해결
- 발생 태스크: Task 7 — 자동 SceneKit→RealityKit 전환과 C3 스타일 안내
- 재현: `PiggyEscape` 디렉터리에서 최종 검증으로 `tuist test PiggyEscape` 실행
- 관찰: exit 0이었지만 `The scheme PiggyEscape's test action has no tests to run, finishing early.`가 출력되어 XCTest 79개가 실제 실행되지 않음
- 영향: exit code만으로는 최종 전체 회귀 성공을 주장할 수 없으며, 생성된 scheme 또는 Tuist 명령의 테스트 대상 해석을 확인해야 함
- 원인/가설: `tuist test PiggyEscape`의 testing용 생성 결과에서 `PiggyEscapeTests` 타깃과 scheme testable이 빠진 것을 직접 확인했다. 같은 manifest를 `tuist generate --no-open`로 일반 생성하면 테스트 타깃과 scheme testable이 복원되어 manifest·테스트 소스 부재는 원인이 아니었으며, 현재 Tuist testing 생성 경로의 해석 차이가 원인으로 남음
- 조치: 빈 test action의 exit 0을 성공으로 집계하지 않았다. 일반 프로젝트 생성 뒤 명시적인 `xcodebuild -project PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`를 전체 회귀의 기준 명령으로 사용함
- 검증: 명시적 Xcode scheme 실행에서 79/79, 0 failures와 `** TEST SUCCEEDED **`를 확인함
- 배운 점: `tuist test`의 exit 0보다 XCTest case 개수와 `TEST SUCCEEDED` 출력을 완료 근거로 우선한다.

### L-20260811-065 — Task 7 실제 카메라 권한·자동 AR 전환·화면 확대는 실기기 대기

- 상태: 실기기 대기
- 발생 태스크: Task 7 — 자동 SceneKit→RealityKit 전환과 C3 스타일 안내
- 재현: LiDAR 지원 iPhone에서 C3 돼지를 나무 뒤로 보내고 카메라 회전으로 발견한 뒤 0.70초 페이드, 시스템 카메라 권한, AR 스캔 화면 전환을 관찰함. 거부·제한 경로에서는 Settings 버튼을 직접 탭하고, 현실 재발견에서는 돼지 1.5배와 화면 1.12배 동시 반응을 관찰함
- 관찰: 현재 환경에서는 주입 fake로 권한 허용·거부·제한과 callback 순서를 자동 검증하고 iOS Simulator build를 확인했지만, 실제 시스템 권한 문구·실기기 카메라 영상·LiDAR 메쉬·물리 오클루전·체감 확대는 실행하지 못함
- 영향: 실제 기기에서 시스템 알림의 시점, 앱 복귀 후 상태, 0.70초 페이드와 카메라 전환의 시각 연속성, 화면 확대의 체감 품질은 아직 확정할 수 없음
- 원인/가설: Simulator와 단위 테스트가 실제 카메라 센서·LiDAR 공간 재구성과 시스템 권한 상호작용을 제공하지 않는 하드웨어 검증 경계임
- 조치: 권한 요청은 페이드 완료 callback 뒤 한 번만 발생하도록 하고 실제 AR camera transform을 변경하지 않는 화면 container scale로 구현했으며, 실기기 절차는 Task 8 수동 검증으로 넘김
- 검증: 자동 근거는 Task 7 focused 8/8, 전체 79/79, Simulator build 성공이며 실제 기기 결과는 기록하지 않음
- 배운 점: 권한 fake와 Simulator build가 통과해도 시스템 권한 UI·카메라 영상·물리 오클루전·전환 감각은 실기기 관찰 전에는 완료로 단정하지 않는다.

### L-20260811-064 — Task 7 focused XCTest는 통과했지만 기존 Simulator 런타임 경고가 반복됨

- 상태: 보류
- 발생 태스크: Task 7 — 자동 SceneKit→RealityKit 전환과 C3 스타일 안내
- 재현: Task 7 coordinator focused XCTest 8개 실행
- 관찰: 8/8과 `** TEST SUCCEEDED **`를 확인했지만 AppIntents metadata skip, `TBB Global TLS count is not == 1`, `SCNView` focus caching 경고가 함께 출력됨
- 영향: Task 7 assertion과 앱 컴파일은 성공했지만 테스트 로그가 경고 없이 깨끗한 상태는 아님
- 원인/가설: L-20260810-046 등에서 이미 관찰한 앱 타깃·SceneKit Simulator 런타임 진단이 같은 조건에서 반복된 것이며 새 루트 상태 전이 assertion 실패는 아님
- 조치: Task 7 범위 밖 Simulator/AppIntents 설정은 변경하지 않고 focused·전체 검증 결과와 분리해 보류함
- 검증: focused `EscapeRootCoordinatorTests` 8/8, 명시적 Xcode scheme 전체 XCTest 79/79, iPhone 17 Pro Simulator 대상 build가 모두 통과했으며 기존 경고만 별도로 남음
- 배운 점: 전환 coordinator의 회귀 결과와 반복되는 SceneKit Simulator 진단을 하나의 성공 신호로 합치지 않는다.

### L-20260811-063 — RealityKit 화면 확대가 Reduce Motion 설정을 구분하지 않음

- 상태: 해결
- 발생 태스크: Task 7 — 자동 SceneKit→RealityKit 전환과 C3 스타일 안내
- 재현: Reduce Motion 켜짐/꺼짐 입력에 따라 AR 화면 확대 목표값이 달라지는 focused 테스트를 추가하고 실행함
- 관찰: 기존 모션 계약은 1.12 상수만 제공해 접근성 설정을 입력받을 함수가 없었고, 테스트는 `cannot call value of non-function type 'CGFloat'`의 의도적인 RED로 종료됨
- 영향: 동작 줄이기를 선호하는 사용자에게도 실제 카메라 화면이 강제로 확대되어 불편이나 멀미를 유발할 수 있음
- 원인/가설: 승인된 연출의 최대 확대값만 모델링하고 SwiftUI의 `accessibilityReduceMotion` 환경값을 모션 결정에 포함하지 않은 것이 원인임
- 조치: 모션 계약이 접근성 설정을 입력받아 일반 모드에는 1.12, Reduce Motion에는 1.0을 반환하게 하고 View의 확대 실행도 같은 값을 사용하도록 함
- 검증: `test_reducedMotionDoesNotDigitallyScaleTheRealityCameraSurface`를 포함한 Task 7 focused XCTest 8/8이 통과함
- 배운 점: 카메라처럼 화면 전체를 움직이는 연출은 기능 요구 수치와 함께 시스템 Reduce Motion 대안을 처음부터 계약으로 둔다.

### L-20260811-062 — 프로토콜 적합성으로 격리된 시스템 기본값을 View 기본 인자에서 생성할 수 없음

- 상태: 해결
- 발생 태스크: Task 7 — 자동 SceneKit→RealityKit 전환과 C3 스타일 안내
- 재현: Tuist 재생성 뒤 Task 7 focused XCTest로 `EscapeRootView.swift`를 컴파일함
- 관찰: `CameraAuthorizing`와 `AppSettingsOpening`의 `@MainActor` 적합성으로 시스템 구현의 초기화도 격리됐고, View initializer의 default argument 평가 지점은 동기 비격리로 판단되어 두 `init()` 호출이 컴파일 오류가 됨
- 영향: 앱 모듈 생성이 중단되어 focused assertion을 실행하지 못함
- 원인/가설: initializer 선언에 `@MainActor`를 붙여도 기본 인자 표현식의 평가 격리를 보장하지 않는 Swift 기본 인자 규칙이 확인된 원인임
- 조치: 첫 수정에서 View initializer만 분리했으나 coordinator initializer에도 같은 기본 인자가 남은 사실을 재컴파일로 확인했다. 두 타입 모두 시스템 구현을 만드는 무인자 격리 initializer와 주입 객체만 받는 initializer를 분리해 기본 인자 표현식을 제거함
- 검증: 두 initializer의 기본 인자를 제거한 뒤 focused XCTest 7/7이 통과했고 해당 actor 격리 오류가 다시 출력되지 않음
- 배운 점: actor-isolated 의존성은 기본 인자에서 즉석 생성하지 말고 격리된 convenience 경계에서 명시적으로 생성한다.

### L-20260811-061 — Task 7 첫 GREEN 컴파일에 새 루트 소스가 생성 프로젝트에 포함되지 않음

- 상태: 해결
- 발생 태스크: Task 7 — 자동 SceneKit→RealityKit 전환과 C3 스타일 안내
- 재현: RED 프로젝트 생성 뒤 `EscapeRootView.swift`를 새로 추가하고 같은 focused XCTest를 실행함
- 관찰: 앱의 Swift 파일 목록에 새 파일이 없고 `ContentView.swift: cannot find 'EscapeRootView' in scope`로 컴파일이 중단됨
- 영향: 루트 구현 자체의 컴파일과 테스트 assertion까지 아직 도달하지 못함
- 원인/가설: Tuist 프로젝트는 glob을 생성 시점에 해석하는데 RED 때는 테스트 파일만 존재했고, production 파일은 그 뒤 추가되어 기존 `.xcodeproj` 소스 목록에 반영되지 않은 것이 확인된 원인임
- 조치: production 소스 추가 뒤 `tuist generate --no-open`를 다시 실행해 프로젝트 파일 목록을 갱신함
- 검증: 재생성 뒤 같은 focused XCTest의 앱 Swift 파일 목록에 `EscapeRootView.swift`가 포함됐고 해당 파일 컴파일까지 진행됨
- 배운 점: Tuist glob 프로젝트에서 RED 후 새 production 파일을 만들면 GREEN 검증 전에 반드시 프로젝트를 다시 생성한다.

### L-20260811-060 — Task 7 RED가 루트 전환 계약의 구현 부재를 확인함

- 상태: 해결
- 발생 태스크: Task 7 — 자동 SceneKit→RealityKit 전환과 C3 스타일 안내
- 재현: 환경 권한을 확보한 뒤 Task 7 coordinator focused XCTest를 실행함
- 관찰: `EscapeRootCoordinator`, `CameraAuthorizing`, `CameraAuthorizationResult`, `AppSettingsOpening`, 루트 문구·모션 계약을 찾지 못해 테스트 타깃 컴파일이 `** TEST FAILED **`로 종료됨
- 영향: C3 발견 뒤 페이드·카메라 권한·RealityKit 상태 연결과 복구 UI의 공개 계약이 아직 구현되지 않았음을 확인함
- 원인/가설: Task 6까지는 C3·AR 화면 내부 콜백만 존재하며 두 화면을 소유하는 Task 7 루트 타입은 계획대로 아직 추가되지 않았음
- 조치: 실패한 테스트가 요구하는 순수 상태 coordinator, 시스템 권한·Settings 주입 경계, SwiftUI 루트 화면을 최소 구현함
- 검증: 구현 뒤 같은 focused XCTest 8/8, 명시적 Xcode scheme 전체 XCTest 79/79, iPhone 17 Pro Simulator 대상 build가 모두 통과함
- 배운 점: 센서 UI 자체를 단위 테스트하지 않더라도 권한 요청 시점과 물리 이벤트 순서는 주입 가능한 상위 coordinator에서 먼저 고정할 수 있다.

### L-20260811-059 — Task 7 focused RED가 Simulator 서비스 접근 제한으로 중단됨

- 상태: 해결
- 발생 태스크: Task 7 — 자동 SceneKit→RealityKit 전환과 C3 스타일 안내
- 재현: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/EscapeRootCoordinatorTests test`
- 관찰: `CoreSimulatorService connection became invalid`, Simulator 로그 접근 거부, `Unable to find a device matching`이 발생해 새 루트 타입 부재 컴파일 단계 전에 exit 70으로 종료됨
- 영향: 권한 전환 테스트가 의도한 기능 부재 RED인지 아직 확인하지 못함
- 원인/가설: Simulator 서비스·Xcode DerivedData가 현재 작업 트리 쓰기 권한 밖인 기존 환경 경계와 같은 증상임
- 조치: 이 기록을 남긴 뒤 Simulator와 Xcode 상태 경로에 접근 가능한 권한으로 같은 focused 테스트를 한 번 재실행함
- 검증: 권한 재실행이 Simulator를 찾고 테스트 타깃 컴파일까지 진행해 `EscapeRootCoordinator` 등 새 타입 부재의 의도적인 RED에 도달함
- 배운 점: 기능 RED 전에 Simulator 환경이 실패하면 성공·실패 의미를 섞지 않고 같은 명령을 환경 권한만 바꿔 재현한다.

### L-20260811-058 — Task 7 RED 준비의 Tuist 생성이 세션 상태 디렉터리 권한으로 중단됨

- 상태: 해결
- 발생 태스크: Task 7 — 자동 SceneKit→RealityKit 전환과 C3 스타일 안내
- 재현: `PiggyEscape` 디렉터리에서 `tuist generate --no-open` 실행
- 관찰: `Permission denied: /Users/yang-eunseo/.local/state/tuist/sessions/...`로 새 루트 coordinator 테스트를 생성 프로젝트에 반영하기 전에 종료됨
- 영향: 카메라 권한·페이드·RealityKit 전환 타입 부재를 의도한 RED로 아직 확인하지 못함
- 원인/가설: 이전 L-20260810-039와 같은 Tuist 사용자 세션 상태 경로가 현재 작업 트리 쓰기 권한 밖에 있는 환경 제약으로 보임
- 조치: 이 기록을 먼저 남긴 뒤 해당 상태 경로에 접근 가능한 권한으로 같은 생성 명령을 한 번 재실행함
- 검증: 권한 재실행 `tuist generate --no-open`가 `✔ Success`로 완료되어 새 테스트 파일이 생성 프로젝트에 반영됨
- 배운 점: 새 테스트 파일을 추가한 태스크에서는 테스트 전에 Tuist 생성 단계의 환경 실패와 기능 부재 RED를 분리해 기록한다.

### L-20260811-057 — 테스트 기본 RealityKit 로더의 actor 격리 계약이 누락됨

- 상태: 해결
- 발생 태스크: Task 6 독립 리뷰 수정 2차 — 포즈 실패 테스트 경계
- 재현: 포즈 실패 처리 구현 후 coordinator focused XCTest를 컴파일함
- 관찰: 테스트 기본 loader closure 안의 `Entity()` 생성에 `call to main actor-isolated initializer ... in a synchronous nonisolated context` 경고가 출력됨
- 영향: 현재 Swift 5 모드에서는 테스트가 통과하지만 더 엄격한 동시성 검사에서는 오류가 될 수 있고, RealityKit 엔티티 loader가 어느 actor에서 실행되는지 타입 계약이 불명확했음
- 원인/가설: visual controller 클래스는 `@MainActor`였지만 저장한 `EntityLoader` 함수 타입에는 actor 격리가 표현되지 않은 것이 원인임
- 조치: `EntityLoader` 타입 자체를 `@MainActor` closure로 선언해 production과 deterministic fake가 같은 실행 경계를 사용하도록 함
- 검증: 변경 후 visual controller focused XCTest 3/3이 통과했고 해당 actor 경고가 다시 출력되지 않음
- 배운 점: actor-isolated 소유자 안의 closure 프로퍼티도 함수 타입에 격리를 명시해야 생성·콜백의 동시성 계약이 보존된다.

### L-20260811-056 — 고정 전방 0.8m 시작점이 선택한 가까운 표면 뒤에 놓일 수 있음

- 상태: 해결
- 발생 태스크: Task 6 독립 리뷰 수정 2차 — 선택 표면 기반 시작 배치
- 재현: 카메라 `(0, 1.5, 0)`, 선택 면 점 `(0, 1, -0.5)`, 법선 `(0, 0, 1)`, 계획 목적지 약 `(0, 0, -0.78)`을 기존 `RealityInitialPigPlacement`에 대입함
- 관찰: 기존 규칙은 선택 면과 무관하게 카메라 전방 0.8m인 z=-0.8을 반환해 선택 면 z=-0.5보다 뒤에서 시작하며, 돼지가 이미 물체 뒤에 나타난 뒤 거의 움직이지 않는 경로가 됨
- 영향: Task 5가 허용하는 0.45m 근거리 표면에서 “카메라에 보이는 쪽에서 물체 뒤로 걸어감” 연출이 깨짐
- 원인/가설: 시작 위치 data-flow에 실제 hit 점·법선·계획 목적지가 전달되지 않고 카메라 transform과 바닥 Y만 사용한 것이 확인된 원인임
- 조치: 근거리·원거리 표면 모두에서 바닥 Y, 카메라 쪽 반공간, 목적지 반대편 조건을 고정하는 순수 배치 RED 테스트를 추가하고, 실제 hit 점·법선·계획 목적지를 배치 함수에 전달해 표면의 카메라 쪽 0.28m에서 시작하도록 수정함
- 검증: 기존 `cameraForward` API 때문에 발생한 focused 컴파일 RED를 확인한 뒤 coordinator focused XCTest 10/10을 통과함. 재현 사례는 z=-0.22에서 시작해 z=-0.78로 이동하며, 원거리 사례도 선택 면 카메라 쪽 0.28m를 유지함
- 배운 점: 실제 물체를 기준으로 하는 이동의 시작·끝은 같은 hit 좌표계에서 계산해야 하며 고정 카메라 거리로 대체할 수 없다.

### L-20260811-055 — 포즈 에셋 로드 실패가 walking·revealing 상태를 영구 정지시킴

- 상태: 해결
- 발생 태스크: Task 6 독립 리뷰 수정 2차 — RealityKit 포즈 실패 종결
- 재현: 수동으로 `Result.failure`를 방출하는 entity loader를 running, 도착 후 idle, surprised 요청에 각각 주입하고 coordinator 상태·콜백·표시 여부를 관찰함
- 관찰: `setPose`가 failure를 버리므로 running/idle 실패에는 walk completion이 없고, surprised 실패에는 reveal completion이 없어 subscription을 취소한 `.revealing` 상태로 남음
- 영향: 사용자에게 원인을 알리지 않은 채 탭 재시도와 재발견이 영구 중단될 수 있고, 상위 Task 7 화면도 오류 상태를 받을 공개 신호가 없음
- 원인/가설: 비동기 로더의 성공만 completion으로 모델링하고 실패 data-flow를 visual controller→coordinator→UI callback으로 전달하지 않은 것이 확인된 원인임
- 조치: 세 포즈 failure의 안전 상태·발견 미발행·고정 한국어 메시지·오류 callback 계약을 각각 focused RED 테스트로 추가함. pose completion을 `Result`로 바꾸고 running/idle 실패는 비활성 `.waitingForTarget`, surprised 실패는 재감시 가능한 `.hidden`으로 복구하며 `onError`와 `"돼지를 불러오지 못했어. 잠시 후 다시 시도해줘."`를 전달함
- 검증: `onError`, 공개 status, 실패 문자열 부재를 보여 준 focused 컴파일 RED를 확인한 뒤 coordinator focused XCTest 10/10과 visual focused XCTest 3/3을 통과함. surprised failure에서는 `onRevealed`가 0이며 다음 blocked→visible 재시도가 다시 시작됨
- 배운 점: 비동기 에셋 작업의 completion은 성공 전용 closure가 아니라 성공과 실패를 모두 종결하는 결과여야 한다.

### L-20260811-054 — AR 진입 직후 돼지가 월드 원점에 활성화되는 배치 계약이 없음

- 상태: 해결
- 발생 태스크: Task 6 독립 리뷰 수정 1차 — 유효 바닥 기반 초기 배치
- 재현: 돼지 시각 컨트롤러 생성 직후 `outerEntity.isEnabled`와 `RealityHideARView.attach`의 월드 원점 anchor 연결 순서를 검사하고, 카메라 전방·바닥 높이 입력의 순수 배치 테스트를 추가함
- 관찰: 기존 엔티티는 활성 상태였고 바닥을 찾기 전 `(0, 0, 0)` anchor에 붙어 카메라 원점 부근에 보일 수 있었으며, 유효한 시작 위치를 계산하는 규칙이 없었음
- 영향: AR 진입 직후 돼지가 눈앞이나 잘못된 높이에 나타나 현실 공간 전환의 연속성이 깨질 수 있었음
- 원인/가설: 최종 숨기 목적지는 계획했지만 AR에서 돼지를 처음 표시할 시점과 시작 위치를 별도 상태로 설계하지 않은 것이 원인임
- 조치: 돼지 엔티티를 기본 비활성화하고, 바닥이 카메라보다 충분히 낮고 수평 카메라 전방 벡터가 유효할 때만 바닥 Y의 전방 0.8m 위치를 만들며, 타깃 수락 뒤 그 위치에서 활성화하도록 함
- 검증: `RealityHideARViewCoordinatorTests.test_initialPlacementUsesFloorAndCameraForwardOnlyWhenDefensible`와 타깃 이동 테스트를 포함한 coordinator focused XCTest 7/7 통과
- 배운 점: AR 콘텐츠는 anchor 생성과 표시를 같은 사건으로 취급하지 말고, 센서로 방어 가능한 배치가 확보될 때까지 비활성 상태를 유지해야 한다.

### L-20260811-053 — 실제 타깃 선택과 돼지 도착을 하나의 이벤트로 축약함

- 상태: 해결
- 발생 태스크: Task 6 독립 리뷰 수정 1차 — 실제 숨기 이동 완료 경계
- 재현: Task 2 상태 전이와 `RealityHideARView.handleTap`의 수락·이동 completion 호출을 대조하고, 지연 모델 로더로 이동 중 발견 입력과 callback 순서를 검사함
- 관찰: 기존 공개 계약에는 `onTargetAccepted`만 있고 `onPigReachedTarget`이 없어 `.walkingBehindRealObject`에서 `.hiddenInReality`로 전이할 실제 완료 신호가 없었음
- 영향: 상위 화면이 선택 직후 숨김 완료로 오인하거나 돼지 도착 전에 발견 상태로 넘어갈 수 있었음
- 원인/가설: 사용자 입력 수락과 비동기 이동·idle 포즈 설치 완료를 하나의 콜백으로 축약한 것이 원인임
- 조치: `onPigReachedTarget`을 분리하고, running 로드·이동·idle 설치 완료 뒤에만 호출하며 reveal monitor도 `.hidden` 상태에서만 입력을 소비하도록 함
- 검증: `RealityHideARViewCoordinatorTests.test_targetAcceptedAndReachedCallbacksAreSeparatedByMovementCompletion`이 `accepted → reached → revealed` 순서와 도착 전 발견 불가를 확인했고 coordinator focused XCTest 7/7 통과
- 배운 점: 입력 수락, 애니메이션 도착, 발견은 각각 별도 도메인 이벤트여야 상태 기계와 실제 화면이 같은 순서를 유지한다.

### L-20260811-052 — 놀람 콜백이 비동기 모델 설치보다 먼저 실행됨

- 상태: 해결
- 발생 태스크: Task 6 독립 리뷰 수정 1차 — 놀람 포즈 완료 경계
- 재현: 완료를 수동으로 방출하는 entity loader를 주입해 `showSurprised` 호출 직후와 로드 성공 뒤의 자식 엔티티·callback 상태를 비교함
- 관찰: 기존 `showSurprised()`는 비동기 로드를 시작한 직후 coordinator가 확대와 `onRevealed`를 실행해 idle/running 모델이 확대될 수 있었음
- 영향: “들켰다” 자막·상태가 놀란 돼지 모델보다 먼저 나타나 시각 연출 순서가 깨질 수 있었음
- 원인/가설: pose 요청 상태와 모델 설치 완료 상태를 구분하지 않고 호출 반환을 완료로 간주한 것이 원인임
- 조치: entity loader를 완료 경계로 추상화하고, 놀란 모델을 안정 바깥 엔티티에 실제 설치한 뒤에만 completion을 호출하며 coordinator의 확대·발견 콜백을 그 completion 안으로 옮김
- 검증: `RealityPigVisualControllerTests.test_surpriseCompletionWaitsUntilTheSurprisedModelIsInstalled`를 포함한 visual focused XCTest 3/3 통과
- 배운 점: 비동기 에셋 전환의 도메인 이벤트는 요청 시점이 아니라 화면 트리에 새 모델이 설치된 시점에 발생해야 한다.

### L-20260811-050 — Task 6 독립 검토가 AR 재발견·포즈·상태·초기 배치 경계 결함 4건을 확인함

- 상태: 해결
- 발생 태스크: Task 6 — RealityKit 돼지 포즈와 실제 메쉬 뒤 숨기 리뷰 수정
- 재현: `RealityHideARView.evaluateReveal`, `processRevealFrame`, 실제 타깃 수락 분기, `attach`, `RealityPigVisualController.showSurprised`의 호출 순서와 상태 입력을 추적함
- 관찰: (1) 투영점의 bounds·카메라 전방 검증 없이 mesh hit `nil`을 visible로 소비함, (2) 놀란 에셋 비동기 로드 완료 전 scale·`onRevealed`를 호출함, (3) 선택 수락 콜백만 있고 돼지 도착 콜백이 없음, (4) 유효한 바닥을 찾기 전에 1.5m 돼지를 활성 상태로 AR 원점에 붙임
- 영향: 화면 밖/카메라 뒤 돼지가 발견될 수 있고, idle/running 모델에 놀람 확대가 적용될 수 있으며, Task 2의 `realTargetAccepted → pigReachedRealObject → realityPigDiscovered` 순서를 루트가 표현할 수 없고, AR 진입 직후 돼지가 카메라 원점·눈높이에 나타날 수 있음
- 원인/가설: 센서 입력을 테스트 가능한 관찰/배치 규칙으로 추출하지 않았고, 비동기 모델 설치와 외부 이벤트 콜백을 하나의 완료 경계로 묶지 않았으며, 선택과 도착을 같은 콜백으로 축약한 것이 확인된 원인임
- 조치: 네 경계를 각각 실패 테스트로 고정한 뒤 화면 유효성 gate, 포즈 설치 completion, 별도 도착 callback, 유효 계획 이후 floor-Y 전방 시작 위치와 pending-hidden 규칙을 구현함
- 검증: 원인별 focused GREEN은 L-20260811-051~054에 기록했으며, 수정 뒤 전체 XCTest 68/68과 iOS Simulator build가 성공함
- 배운 점: AR 화면의 `nil hit`은 보임을 뜻하지 않고 유효 관찰 문맥 안에서만 의미가 있으며, 비동기 시각 상태와 경험 상태 이벤트는 실제 완료 순간을 공유해야 한다.

### L-20260811-049 — Task 6 리뷰 수정 시작 전 원격 fetch가 worktree 메타데이터 권한으로 중단됨

- 상태: 해결
- 발생 태스크: Task 6 — RealityKit 돼지 포즈와 실제 메쉬 뒤 숨기 리뷰 수정
- 재현: `git fetch --prune origin`
- 관찰: `error: cannot open '.../.git/worktrees/ch1-reality-escape/FETCH_HEAD': Operation not permitted`로 원격 참조 갱신 전에 종료됨
- 영향: 리뷰 수정 전 원격 변경 유무를 현재 권한으로 확정하지 못함
- 원인/가설: 이전 L-20260810-020·032와 같은 연결 작업 트리 공용 Git 메타데이터 쓰기 권한 경계가 재발함
- 조치: 공용 Git 메타데이터에 접근 가능한 권한으로 같은 fetch를 한 번 재실행함
- 검증: 권한 재실행 `git fetch --prune origin`이 오류 없이 완료됐고, 직후 상태는 이 학습 기록 변경과 사용자 소유 `.claude/`뿐이며 기준 HEAD는 `e3f58d9`임
- 배운 점: 리뷰 수정 라운드도 새 구현처럼 원격 상태 확인 실패를 먼저 기록하고, 성공을 추정하지 않는다.

### L-20260810-048 — Task 6 staging이 연결 작업 트리 index lock 권한으로 중단됨

- 상태: 해결
- 발생 태스크: Task 6 — RealityKit 돼지 포즈와 실제 메쉬 뒤 숨기
- 재현: Task 6 소스·테스트·`WORK_LOG`·`LEARNING_LOG`의 명시 경로만 지정한 `git add`
- 관찰: `fatal: Unable to create '.../.git/worktrees/ch1-reality-escape/index.lock': Operation not permitted`로 어떤 파일도 staging되지 않음
- 영향: 검증된 Task 6 변경을 아직 커밋할 수 없음
- 원인/가설: 연결 작업 트리의 Git index 메타데이터가 현재 파일 권한 범위 밖의 공용 `.git/worktrees/...`에 있어 lock 파일 생성이 거부됨
- 조치: 동일한 명시 파일 목록을 공용 Git 메타데이터에 접근 가능한 권한으로 한 번 재실행했으며 `.claude/`와 생성물은 포함하지 않음
- 검증: 권한 재실행 `git add`가 오류 없이 완료됐고, 후속 cached diff와 상태 검사로 정확한 staging 범위를 확인함
- 배운 점: 연결 작업 트리의 작업 파일 쓰기와 Git index lock 쓰기는 별도 권한 경계이므로, staging 실패 뒤 일부 반영을 가정하지 않는다.

### L-20260810-046 — Task 6 focused XCTest는 통과했지만 기존 Simulator 런타임 경고가 출력됨

- 상태: 보류
- 발생 태스크: Task 6 — RealityKit 돼지 포즈와 실제 메쉬 뒤 숨기
- 재현: Task 6 Reality visual/coordinator focused XCTest 5개 실행
- 관찰: 5/5와 `** TEST SUCCEEDED **`를 확인했지만 `Metadata extraction skipped. No AppIntents.framework dependency found`, `TBB Global TLS count is not == 1`, `UIFocus` 캐시 제한 경고가 함께 출력됨
- 영향: Task 6 assertion은 실패하지 않았지만 테스트 출력이 경고 없이 깨끗하다는 조건은 충족하지 못함
- 원인/가설: 앞선 태스크에서도 반복된 앱 타깃·iOS Simulator 런타임 진단이며, 이번 RealityKit 소스의 컴파일 오류나 assertion 실패는 아님
- 조치: Task 6 범위 밖의 AppIntents/Simulator 런타임 설정은 변경하지 않고 focused·전체 테스트 결과와 분리해 보류함
- 검증: focused `RealityPigVisualControllerTests` 2개와 `RealityHideARViewCoordinatorTests` 3개가 모두 통과함
- 배운 점: RealityKit 로직 회귀와 반복되는 Simulator 런타임 경고를 같은 성공 신호로 합치지 않는다.

### L-20260810-047 — Task 6 실제 LiDAR 메쉬 탭·물리 오클루전·재발견은 실기기 대기

- 상태: 실기기 대기
- 발생 태스크: Task 6 — RealityKit 돼지 포즈와 실제 메쉬 뒤 숨기
- 재현: LiDAR 지원 iPhone/iPad에서 카메라 권한 허용 후 공간을 스캔하고 실제 물체 세로 면을 탭한 뒤 물체 반대편으로 이동해 돼지의 가림과 재발견을 관찰하는 절차
- 관찰: 이 환경에서는 Fake capability와 수치형 mesh/pig 거리 입력으로 지원 분기·1회 재발견 계약만 자동 검증했으며, 실제 ARFrame의 mesh hit·floor classification·깊이 오클루전은 실행하지 못함
- 영향: `sceneReconstruction`, scene-understanding 옵션, 실제 세로 면 법선, 분류된 바닥, 물리적 카메라 이동에 따른 가림 해제의 현장 동작은 아직 확정할 수 없음
- 원인/가설: Simulator가 LiDAR 센서와 실제 공간 재구성 메쉬를 제공하지 않는 하드웨어 검증 경계임
- 조치: actual AR session 경로는 `SystemRealityMeshSupport` guard 뒤에서만 시작하도록 두고, 실기기 절차는 Task 8의 수동 검증으로 넘김
- 검증: 현재 자동 근거는 미지원 세션 차단, 거절 메시지, blocked→visible 1회 재발견, 놀란 포즈·1.5→1.0 확대이며 실제 기기 결과는 기록하지 않음
- 배운 점: ARView가 빌드되고 수치 테스트가 통과해도 실제 메쉬가 돼지를 가린다는 결론은 LiDAR 실기기 관찰 전에는 내리지 않는다.

### L-20260810-045 — RealityKit animation·scene subscription의 실제 SDK 타입 계약이 초안과 달랐음

- 상태: 해결
- 발생 태스크: Task 6 — RealityKit 돼지 포즈와 실제 메쉬 뒤 숨기
- 재현: Foundation import 보완 뒤 같은 focused RealityKit XCTest 재실행
- 관찰: `AnimationResource`에는 `repeatingForever()`가 없고, `Scene.subscribe` 반환값 `any Cancellable`을 `AnyCancellable` 프로퍼티에 직접 대입할 수 없어 앱 컴파일이 중단됨
- 영향: 걷기 애니메이션 반복과 frame update subscription 소유 구현이 실제 iOS 17 SDK 계약에 맞지 않음
- 원인/가설: SDK 선언 대조 결과 `repeatingForever()`는 `AnimationDefinition`의 메서드이고, iOS 17 호환 `AnimationResource` 반복 API는 ``repeat(duration:)``임. 또한 `Scene.subscribe`는 구체 `AnyCancellable`이 아니라 `any Combine.Cancellable`을 반환함
- 조치: 애니메이션에는 ``resource.repeat()``을 사용하고 subscription 저장 타입은 `any Cancellable` existential로 좁게 변경함
- 검증: 동일 focused XCTest가 앱·테스트 타깃을 컴파일한 뒤 5/5와 `** TEST SUCCEEDED **`로 완료됨
- 배운 점: 같은 이름의 RealityKit animation 타입이라도 resource와 definition의 반복 API가 다르며, SDK 26에서 iOS 17 배포 계약의 반환 타입을 실제 선언으로 확인해야 한다.

### L-20260810-043 — Task 6 첫 GREEN 컴파일이 Dispatch 타입 import 누락으로 중단됨

- 상태: 해결
- 발생 태스크: Task 6 — RealityKit 돼지 포즈와 실제 메쉬 뒤 숨기
- 재현: Task 6 production 타입 추가 뒤 focused RealityKit XCTest 실행
- 관찰: `RealityPigVisualController.swift:19:37: error: cannot find type 'DispatchWorkItem' in scope`로 앱 모듈 생성이 중단됨
- 영향: 새 RealityKit 소스의 나머지 컴파일과 focused assertion을 아직 실행하지 못함
- 원인/가설: 새 파일이 `Combine`, `RealityKit`, `simd`만 import한 상태에서 `DispatchWorkItem`, `DispatchQueue`, `TimeInterval`을 직접 사용하며, 해당 타입을 선언하는 모듈을 파일이 import하지 않은 것이 원인으로 보임
- 조치: 기존 변경 중 해당 파일의 import 목록과 Dispatch 타입 사용 위치를 대조했고, 한 개의 명시적 `Foundation` import만 추가함
- 검증: 동일 focused XCTest 재실행에서 `DispatchWorkItem` 오류가 사라지고 다음 실제 SDK API 계약 오류까지 컴파일이 진행됨
- 배운 점: Swift 파일은 프레임워크의 우연한 재노출에 기대지 말고 직접 사용하는 Foundation/Dispatch 타입의 모듈을 명시한다.

### L-20260810-044 — SDK Dispatch 선언 검색에서 존재를 가정한 glob 실패가 재발함

- 상태: 해결
- 발생 태스크: Task 6 — RealityKit 돼지 포즈와 실제 메쉬 뒤 숨기
- 재현: 두 후보 SDK 경로의 `Dispatch.swiftmodule/*.swiftinterface`를 zsh glob으로 넘긴 선언 검색
- 관찰: 두 번째 후보 경로가 존재하지 않아 `zsh: no matches found`가 발생했고 뒤따른 diff 출력이 실행되지 않음
- 영향: Dispatch 선언 파일 자체의 경로 확인은 중단됐지만, 컴파일 오류 위치와 현재 파일의 import/사용 대조에는 영향이 없음
- 원인/가설: L-20260810-040과 같이 파일 존재를 먼저 확인하지 않고 복수 glob을 직접 명령 인자로 사용했음
- 조치: SDK 내부 선언 경로 탐색을 중단하고 컴파일러 진단과 소스의 직접 import 경계를 근거로 삼음
- 검증: `rg`에서 Task 6 소스 내 `DispatchWorkItem` 사용과 명시 import 부재를 확인함
- 배운 점: 동일한 glob 실패를 반복하지 않도록 선택적 SDK 경로는 `find` 결과를 먼저 확보한 경우에만 검색한다.

### L-20260810-042 — Task 6 RED가 RealityKit visual/coordinator API 부재를 확인함

- 상태: 해결
- 발생 태스크: Task 6 — RealityKit 돼지 포즈와 실제 메쉬 뒤 숨기
- 재현: 권한이 확보된 환경에서 `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/RealityPigVisualControllerTests -only-testing:PiggyEscapeTests/RealityHideARViewCoordinatorTests test`
- 관찰: `RealityPigVisualController`와 `RealityHideARView`를 찾지 못해 테스트 타깃 컴파일이 실패하고 `** TEST FAILED **`로 종료됨
- 영향: 안정적인 RealityKit 돼지 엔티티, 놀람 확대, 메쉬 세션 지원 분기, 숨김 후 재발견 연결이 아직 구현되지 않았음을 확인함
- 원인/가설: Task 5는 순수 위치 계획·지원 판정만 제공했고 Task 6의 RealityKit 어댑터 타입은 아직 없음
- 조치: 실제 에셋 비동기 로딩을 소유하는 visual controller와 수동 AR 세션·실제 메쉬 탭·재발견 update를 소유하는 ARView coordinator를 최소 구현할 예정임
- 검증: 구현 후 같은 focused XCTest의 통과와 전체 XCTest·Simulator build를 새로 실행할 예정임
- 배운 점: 센서 입력을 직접 자동화할 수 없어도 안정 엔티티·분기·메시지·재발견 소비 경계는 먼저 실패하는 단위 테스트로 고정할 수 있다.

### L-20260810-041 — Task 6 RED XCTest가 Simulator 서비스 접근 제한으로 중단됨

- 상태: 해결
- 발생 태스크: Task 6 — RealityKit 돼지 포즈와 실제 메쉬 뒤 숨기
- 재현: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/RealityPigVisualControllerTests -only-testing:PiggyEscapeTests/RealityHideARViewCoordinatorTests test`
- 관찰: `CoreSimulatorService connection became invalid`, `Error opening log file ... Operation not permitted`, `Unable to discover any Simulator runtimes`가 발생해 새 타입 부재 컴파일 단계 전에 XCTest가 종료됨
- 영향: RealityKit visual/coordinator의 의도적인 RED를 아직 관찰하지 못함
- 원인/가설: Simulator 기기·로그·DerivedData 경로가 현재 파일 권한 범위 밖이어서 이전 태스크와 같은 환경 제약이 재발함
- 조치: Simulator 서비스와 Xcode 상태 경로에 접근 가능한 권한으로 같은 focused XCTest를 한 번 재실행함
- 검증: 권한 재실행이 새 타입 부재까지 도달해 의도적인 RED를 확인했으며 상세는 L-20260810-042에 기록함
- 배운 점: 새 RealityKit 테스트의 RED도 환경 권한 실패와 요구 API 부재 실패를 분리해 기록해야 한다.

### L-20260810-039 — Task 6 RED 준비의 Tuist 생성이 세션 상태 디렉터리 권한으로 중단됨

- 상태: 해결
- 발생 태스크: Task 6 — RealityKit 돼지 포즈와 실제 메쉬 뒤 숨기
- 재현: `cd PiggyEscape && tuist generate --no-open`
- 관찰: `Fatal error: Error raised at top level: Permission denied: /Users/yang-eunseo/.local/state/tuist/sessions/333F03BD-9BEA-4EA1-9A39-5C2A7A53EF26`로 새 XCTest 파일을 생성 프로젝트에 반영하기 전에 종료됨
- 영향: 새 RealityKit visual/coordinator 테스트의 의도적인 타입 부재 RED를 아직 실행할 수 없음
- 원인/가설: 이전 태스크와 같이 Tuist가 연결 작업 트리 밖 사용자 세션 상태 경로에 쓰기를 시도하지만 현재 권한 범위에 포함되지 않음
- 조치: 해당 상태 경로에 접근 가능한 권한으로 같은 생성 명령을 한 번 재실행함
- 검증: 권한 재실행 `tuist generate --no-open`가 `✔ Success`로 완료됐고, 이후 focused XCTest가 새 테스트 파일을 컴파일하며 API 부재 RED까지 도달함
- 배운 점: 새 Task 6 테스트 파일도 생성 프로젝트에 반영하려면 Tuist 사용자 세션 상태 쓰기 권한이 필요하다.

### L-20260810-040 — SDK 선언 검색의 ARKit glob이 일치 파일 부재로 중단됨

- 상태: 해결
- 발생 태스크: Task 6 — RealityKit 돼지 포즈와 실제 메쉬 뒤 숨기
- 재현: Simulator SDK의 `ARKit.framework/Modules/ARKit.swiftmodule/*.swiftinterface`를 zsh glob으로 넘긴 `rg` 검색
- 관찰: `zsh: no matches found: .../ARKit.swiftmodule/*.swiftinterface`가 출력되어 해당 검색 구간이 실행되지 않음
- 영향: `ARPlaneAnchor` 선언 위치를 첫 검색에서 확인하지 못했지만 RealityKit의 `project`, scene-understanding `hitTest`, `CollisionCastHit.normal` 계약 확인에는 영향이 없음
- 원인/가설: 현재 Simulator SDK의 ARKit 모듈은 검색한 경로에 일반 `.swiftinterface` 파일을 노출하지 않음
- 조치: 확인이 필요한 ARKit 타입은 컴파일러 검증과 공개 헤더/모듈 선언을 기준으로 확인하고, 존재를 가정한 glob은 사용하지 않음
- 검증: RealityKit 및 RealityFoundation의 실제 `.swiftinterface`에서 `ARView.project`, scene-understanding `hitTest`, `CollisionCastHit.position/normal` 선언을 확인함
- 배운 점: SDK 내부 선언 탐색은 먼저 `find`로 실제 파일 형식을 확인한 뒤 검색하며, 특정 모듈이 Swift interface를 반드시 제공한다고 가정하지 않는다.

### L-20260810-032 — Task 5 시작 전 원격 fetch가 연결 작업 트리 메타데이터 권한으로 중단됨

- 상태: 해결
- 발생 태스크: Task 5 — 실제 물체 숨기 계획과 LiDAR 지원 판정
- 재현: `git fetch --prune origin`
- 관찰: `error: cannot open '/Users/yang-eunseo/Downloads/SpatialComputing_TechMap/.git/worktrees/ch1-reality-escape/FETCH_HEAD': Operation not permitted`로 원격 참조 갱신 전에 종료됨
- 영향: 구현 전 원격 변경 동기화 상태를 현재 권한 범위에서 확정할 수 없음
- 원인/가설: 이전 연결 작업 트리의 L-20260810-020와 같은 공용 Git 메타데이터 `FETCH_HEAD` 쓰기 경로 권한 제약으로 보임
- 조치: 공용 Git 메타데이터에 접근 가능한 권한으로 같은 명령을 재실행함
- 검증: 권한 재실행 `git fetch --prune origin`이 성공했고, 직후 `git status --short`는 이 항목을 포함한 `docs/LEARNING_LOG.md` 변경과 기존 사용자 소유 `.claude/`만 표시함
- 배운 점: 시작 순서의 fetch가 권한으로 중단되면 구현이나 테스트 재시도 전에 실패 근거를 먼저 남긴다.

### L-20260810-033 — Task 5 RED 준비의 Tuist 생성이 세션 상태 디렉터리 권한으로 중단됨

- 상태: 해결
- 발생 태스크: Task 5 — 실제 물체 숨기 계획과 LiDAR 지원 판정
- 재현: `cd PiggyEscape && tuist generate --no-open`
- 관찰: `Fatal error: Error raised at top level: Permission denied: /Users/yang-eunseo/.local/state/tuist/sessions/5EB5AE43-8EB9-4043-ADD9-EFD4F37F3DED`로 새 XCTest 파일을 생성 프로젝트에 반영하기 전에 종료됨
- 영향: 새 Reality 계획·지원 판정 테스트의 의도적인 타입 부재 RED를 아직 실행할 수 없음
- 원인/가설: Tuist가 연결 작업 트리 밖 사용자 세션 상태 경로에 쓰기를 시도하지만 현재 권한 범위에 포함되지 않음
- 조치: 해당 세션 상태 경로에 접근 가능한 권한으로 같은 생성 명령을 재실행함
- 검증: 권한 재실행 `tuist generate --no-open`가 `✔ Success`로 완료되어 새 Reality XCTest가 생성 프로젝트에 반영됨
- 배운 점: 새 XCTest를 추가한 뒤 RED를 확인하려면 생성 프로젝트뿐 아니라 Tuist 세션 상태 쓰기 권한도 먼저 충족해야 한다.

### L-20260810-034 — Task 5 RED XCTest가 Simulator 서비스 접근 제한으로 중단됨

- 상태: 해결
- 발생 태스크: Task 5 — 실제 물체 숨기 계획과 LiDAR 지원 판정
- 재현: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/RealityHidePlannerTests -only-testing:PiggyEscapeTests/RealityCapabilityTests test`
- 관찰: `CoreSimulatorService connection became invalid`, `Error opening log file ... Operation not permitted`, `Unable to discover any Simulator runtimes`가 발생해 새 타입 부재 컴파일 단계 전에 XCTest가 종료됨
- 영향: Reality 계획·지원 판정의 의도적인 RED를 아직 확인할 수 없음
- 원인/가설: Simulator 기기·로그·DerivedData 상태 경로가 현재 파일 권한 범위 밖에 있음
- 조치: Simulator 서비스와 Xcode 상태 경로에 접근 가능한 권한으로 같은 focused XCTest를 재실행함
- 검증: 권한 재실행에서 `RealityMeshSupporting`과 `RealityAvailabilityMessage`를 찾지 못해 `PiggyEscapeTests` 컴파일이 실패했고, 지정 Reality 계약이 아직 구현되지 않았음을 확인함
- 배운 점: Simulator 기반 RED에서는 환경 권한 실패와 새 API 부재를 분리해 기록해야 테스트 의도를 보존할 수 있다.

### L-20260810-035 — Task 5 GREEN 준비의 Tuist 명령이 잘못된 작업 디렉터리에서 실행됨

- 상태: 해결
- 발생 태스크: Task 5 — 실제 물체 숨기 계획과 LiDAR 지원 판정
- 재현: 작업 트리 루트에서 `tuist generate --no-open` 뒤 지정 Reality focused XCTest 실행
- 관찰: Tuist가 `Manifest not found at path .../.worktrees/ch1-reality-escape`로 종료했고, 이어진 XCTest는 기존 생성 프로젝트를 사용해 새 `RealityMeshSupporting`과 `RealityAvailabilityMessage`를 찾지 못함
- 영향: 방금 추가한 Reality 소스가 생성 프로젝트에 반영되지 않아 GREEN 동작을 검증할 수 없음
- 원인/가설: `Project.swift`는 `PiggyEscape/`에 있는데 생성 명령의 작업 디렉터리가 그 상위 작업 트리 루트였음. 따라서 생성 실패 후 이전 `.xcodeproj`의 소스 목록이 유지된 것으로 보임
- 조치: `PiggyEscape/Project.swift`가 존재하고 이전 `.xcodeproj`에는 Reality 테스트만 포함하며 Reality 소스는 빠진 것을 확인함. manifest가 있는 `PiggyEscape/`에서만 생성 명령을 재실행함
- 검증: `cd PiggyEscape && tuist generate --no-open`가 성공했고, 같은 focused XCTest가 `RealityHidePlanner.swift`와 `RealityCapability.swift`를 컴파일한 뒤 8/8 assertion을 통과함
- 배운 점: Tuist 생성은 프로젝트 파일 위치가 아니라 manifest를 기준으로 작업 디렉터리를 선택하며, 생성 실패 뒤에는 기존 Xcode 프로젝트를 검증 근거로 사용하지 않는다.

### L-20260810-036 — Task 5 focused XCTest에 기존 Simulator 런타임 경고가 출력됨

- 상태: 보류
- 발생 태스크: Task 5 — 실제 물체 숨기 계획과 LiDAR 지원 판정
- 재현: `cd PiggyEscape && xcodebuild -project PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/RealityHidePlannerTests -only-testing:PiggyEscapeTests/RealityCapabilityTests test`
- 관찰: 8개 XCTest와 `** TEST SUCCEEDED **`는 확인했지만 `Metadata extraction skipped. No AppIntents.framework dependency found`, `TBB Global TLS count is not == 1`, `UIFocus` 캐시 제한 경고가 함께 출력됨
- 영향: Reality 계획·메시지·주입 지원 판정 회귀 assertion은 통과했지만 XCTest 출력이 경고 없이 깨끗하다는 조건은 충족하지 못함
- 원인/가설: 기존 AppIntents 의존성이 없는 앱 타깃과 iOS Simulator 런타임 진단으로, Task 5 순수 Swift·ARKit 지원 경계의 컴파일 또는 assertion 실패는 아님
- 조치: Task 5 범위 밖의 앱 타깃·Simulator 런타임을 변경하지 않고, 경고를 보류한 채 전체 XCTest와 Simulator build로 회귀 범위를 확인함
- 검증: focused Reality XCTest 8/8과 전체 XCTest 58/58이 통과했고, 같은 destination의 `xcodebuild ... build`가 `** BUILD SUCCEEDED **`로 완료됨
- 배운 점: LiDAR 지원 자체는 Fake `RealityMeshSupporting`로 결정론적으로 검증하고, Simulator 런타임 경고 또는 실제 LiDAR 판정을 자동 테스트 성공으로 대체하지 않는다.

### L-20260810-037 — Task 5의 실제 LiDAR 메쉬 지원과 물리 오클루전은 Simulator에서 검증할 수 없음

- 상태: 실기기 대기
- 발생 태스크: Task 5 — 실제 물체 숨기 계획과 LiDAR 지원 판정
- 재현: LiDAR가 있는 iOS 기기에서 `SystemRealityMeshSupport.supportsMeshWithClassification`을 확인하고, 실제 세로 물체·바닥을 스캔한 뒤 메쉬가 돼지보다 앞에 있을 때와 벗어났을 때를 관찰하는 절차
- 관찰: 이 태스크에서는 순수 입력·거리·평면 수학, 0.03m 재발견 허용오차, Fake 지원 주입만 자동 검증했다. Simulator ARKit으로 LiDAR 지원을 흉내 내거나 실제 메쉬 오클루전을 실행하지 않았음
- 영향: 지원 여부의 시스템 API 결과와 실제 재구성 메쉬의 거리 데이터는 자동 테스트만으로 확정할 수 없음
- 원인/가설: LiDAR 센서와 실제 환경 메쉬는 Simulator가 제공하지 않는 하드웨어·공간 입력임
- 조치: 시스템 판정은 `SystemRealityMeshSupport` 한 곳으로 제한하고, 테스트는 ARKit을 호출하지 않는 Fake 주입으로 true/false 경계를 검증함
- 검증: `RealityCapabilityTests/test_injectedCapabilityDoesNotDependOnTheSimulator`가 true/false Fake를 모두 통과했고, 실제 기기 검증은 Task 6의 ARView 연결 뒤 수행할 예정임
- 배운 점: LiDAR 가능 여부와 실제 오클루전은 시스템 API·실기기 근거로만 확인하며, Simulator의 값이나 순수 테스트를 하드웨어 검증으로 표현하지 않는다.

### L-20260810-038 — Task 5 인수인계·학습 기록 통합 패치가 문맥 불일치로 적용되지 않음

- 상태: 해결
- 발생 태스크: Task 5 — 실제 물체 숨기 계획과 LiDAR 지원 판정
- 재현: `docs/LEARNING_LOG.md`와 `docs/WORK_LOG.md`를 함께 갱신하는 `apply_patch`
- 관찰: `apply_patch verification failed`가 `WORK_LOG.md`의 현재 인수인계 문맥을 찾지 못해 전체 패치가 적용되지 않음
- 영향: 학습 기록의 전체 XCTest·실기기 한계 갱신과 Task 5 인수인계가 아직 저장되지 않음
- 원인/가설: 패치 문맥이 실제 제목 `## 현재 인수인계`와 달리 앞 공백이 있는 문자열을 사용해 정확히 일치하지 않았음
- 조치: 실패 뒤 두 문서의 실제 첫 부분을 읽어 문맥 불일치를 확인했고, 학습 기록과 인수인계를 별도 정확 문맥 패치로 분리함
- 검증: 분리 패치가 전체 XCTest 58/58·Simulator build 성공, 실제 LiDAR 실기기 대기, Task 6 다음 시작점을 각각 두 문서에 반영함
- 배운 점: 서로 다른 문서를 한 패치로 바꿀 때는 각 문서의 제목·공백까지 실제 문맥을 먼저 대조하고, 실패 시 부분 적용을 가정하지 않는다.

### L-20260810-031 — Task 4 리뷰 RED에서 놀람 콜백 순서와 Coordinator 수명 누수가 확인됨

- 상태: 해결
- 발생 태스크: Task 4 — SceneKit 나레이션·탭·가짜 숨기·카메라 발견 (리뷰 보완)
- 재현: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/ClosedWorldEscapeTests -only-testing:PiggyEscapeTests/C3ClosedWorldSceneViewOwnershipTests -only-testing:PiggyEscapeTests/NarrationOverlaySceneTests test`
- 관찰: 12개 focused XCTest 중 10개는 통과했으나, `test_surpriseScaleActionStartsBeforeCaptionCallback`은 콜백 안에서 `escapePig.surpriseScale` action을 찾지 못했고, `test_coordinatorIsReleasedWhenWorldOutlivesInstalledCallbacks`는 외부가 `world`를 보유한 뒤에도 `Coordinator`가 해제되지 않았음
- 영향: 외부 `onDiscovered`가 동기적으로 뷰를 해제하면 필수 놀람 action 시작 전에 씬이 사라질 수 있고, 발견 뒤 화면 전환에서 world→closure→coordinator 순환 참조가 남을 수 있음
- 원인/가설: `performSurpriseReaction()`이 keyed scale action보다 `onSurpriseCaption`을 먼저 호출했고, `world.onSurpriseCaption` closure가 coordinator `self`를 강하게 캡처했음
- 조치: scale sequence를 외부 caption callback보다 먼저 시작하고, callback closure가 coordinator와 overlay를 약하게 캡처하도록 변경함
- 검증: 같은 focused XCTest가 12/12을 통과했고, 전체 `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`가 50/50, 같은 destination의 `xcodebuild ... build`가 `** BUILD SUCCEEDED **`로 완료됨
- 배운 점: 외부 전환 콜백보다 먼저 화면 내 필수 action을 등록하고, owned world에 저장하는 callback은 owner를 약하게 캡처해 수명 경계를 테스트한다.

### L-20260810-019 — Task 4 시작 순서의 프로젝트 맥락 문서가 작업 트리에 없음

- 상태: 보류
- 발생 태스크: Task 4 — SceneKit 나레이션·탭·가짜 숨기·카메라 발견
- 재현: `sed -n '1,260p' docs/PROJECT_CONTEXT.md`
- 관찰: `sed: docs/PROJECT_CONTEXT.md: No such file or directory`로 지정 문서를 읽지 못했고, 이어지는 시작 순서 명령은 실행되지 않았음
- 영향: 시작 순서의 프로젝트 맥락 문서를 현재 브랜치에서 직접 검토할 수 없음
- 원인/가설: L-20260810-010 및 L-20260810-004와 같이 이 연결 작업 트리에 해당 문서가 포함되지 않은 상태임
- 조치: 존재하는 `docs/WORK_LOG.md`, Reality escape 설계·구현 계획, Task 4 브리프를 대체 근거로 사용하며 범위를 넓히지 않음
- 검증: `rg --files -g 'PROJECT_CONTEXT.md' -g 'WORK_LOG.md' -g '*task-4*'`에서 `PROJECT_CONTEXT.md` 부재와 대체 문서 존재를 확인함
- 배운 점: 시작 필수 문서의 경로 부재는 명령이 중단된 태스크마다 재현·대체 근거를 남기고, 없는 문서를 추정하지 않는다.

### L-20260810-020 — Task 4 시작 전 원격 fetch가 연결 작업 트리 메타데이터 권한으로 중단됨

- 상태: 해결
- 발생 태스크: Task 4 — SceneKit 나레이션·탭·가짜 숨기·카메라 발견
- 재현: `git fetch --prune origin`
- 관찰: `error: cannot open '/Users/yang-eunseo/Downloads/SpatialComputing_TechMap/.git/worktrees/ch1-reality-escape/FETCH_HEAD': Operation not permitted`로 원격 참조 갱신 전에 종료됨
- 영향: 구현 전 원격 변경 동기화 상태를 현재 권한 범위에서 확정할 수 없음
- 원인/가설: L-20260810-009와 같은 연결 작업 트리 공용 Git 메타데이터 `FETCH_HEAD` 쓰기 경로 권한 제약으로 보임
- 조치: 공용 Git 메타데이터에 접근 가능한 권한으로 같은 명령을 한 번 재실행해 원격 상태를 확인함
- 검증: 권한 재실행 `git fetch --prune origin && git status --short`가 성공했고, Task 4 시작 시점의 추적 변경은 기록 문서와 사용자 소유 `.claude/`뿐임을 확인함
- 배운 점: 시작 순서의 fetch가 권한으로 중단되면 재시도 전에 실패를 기록하고, 성공 여부를 추정하지 않는다.

### L-20260810-021 — Task 4 RED 준비 중 Tuist 세션 상태 디렉터리 쓰기가 거부됨

- 상태: 해결
- 발생 태스크: Task 4 — SceneKit 나레이션·탭·가짜 숨기·카메라 발견
- 재현: `tuist generate --no-open`
- 관찰: `Fatal error: Error raised at top level: Permission denied: /Users/yang-eunseo/.local/state/tuist/sessions/14A284BC-B6AD-49F5-A6B3-B8BD8A84183D`로 생성이 XCTest 실행 전에 종료됨
- 영향: 새 Task 4 XCTest가 생성 프로젝트에 반영되지 않아 API 부재 RED를 아직 확인하지 못함
- 원인/가설: Tuist가 연결 작업 트리 밖의 사용자 세션 상태 경로에 쓰기를 시도하지만 현재 파일 권한 범위에 포함되지 않음
- 조치: 해당 상태 경로에 접근 가능한 권한으로 같은 생성 명령을 재실행한 뒤, 새 Task 4 focused XCTest를 실행함
- 검증: 권한 재실행 `tuist generate --no-open`가 `✔ Success`로 완료되어 새 Task 4 XCTest와 소스가 생성 프로젝트에 반영됨
- 배운 점: Tuist의 새 테스트 반영은 생성물 경로뿐 아니라 사용자 세션 상태 쓰기 권한을 먼저 충족해야 한다.

### L-20260810-022 — Task 4 RED XCTest가 Simulator 서비스 접근 제한으로 중단됨

- 상태: 해결
- 발생 태스크: Task 4 — SceneKit 나레이션·탭·가짜 숨기·카메라 발견
- 재현: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/ClosedWorldEscapeTests -only-testing:PiggyEscapeTests/NarrationOverlaySceneTests test`
- 관찰: `CoreSimulatorService connection became invalid`와 `Error opening log file ... Operation not permitted`가 발생해 새 API 부재 컴파일 단계 전에 XCTest가 종료됨
- 영향: Task 4의 의도적인 RED가 환경 제약 때문에 아직 관찰되지 않음
- 원인/가설: Simulator 기기·로그·DerivedData 상태 경로가 현재 파일 권한 범위 밖에 있음
- 조치: Simulator 서비스와 Xcode 상태 경로에 접근 가능한 권한으로 같은 focused XCTest를 재실행해, 새 API 부재 RED를 확인함
- 검증: 권한 재실행에서 `C3ClosedWorld`의 `tapPig`, 내레이션·발견·놀람 API와 검사 상태 부재로 테스트 타깃 컴파일이 실패했으며, 상세는 L-20260810-023에 기록함
- 배운 점: Simulator 기반 RED는 API 부재와 환경 권한 실패를 분리해야 테스트 의도를 보존할 수 있다.

### L-20260810-023 — Task 4 RED XCTest가 새 가짜 숨기·발견 API 부재로 컴파일 실패함

- 상태: 해결
- 발생 태스크: Task 4 — SceneKit 나레이션·탭·가짜 숨기·카메라 발견
- 재현: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/ClosedWorldEscapeTests -only-testing:PiggyEscapeTests/NarrationOverlaySceneTests test`
- 관찰: `C3ClosedWorld`에서 `tapPig`, `completeOpeningNarration`, `finishTreeHideForTesting`, `isDiscoveredAfterCameraRotation`, `performSurpriseReaction` 및 검사 상태 `currentPose`, `lastCaption`, `surprisePeakScale`를 찾지 못해 테스트 타깃 컴파일이 중단됨
- 영향: 나레이션 게이트·나무 도착 뒤 카메라 발견·놀람 연출의 요구 계약이 아직 앱에 없음
- 원인/가설: Task 3 어댑터는 섬·돼지·카메라까지만 소유하며 Task 4의 상호작용 API와 SpriteKit 오버레이를 아직 구현하지 않았음
- 조치: 실제 씬의 `HideTree`를 필수로 요구하는 C3 월드 상태/액션과 C3 스타일 `NarrationOverlayScene`, 제스처 어댑터를 구현할 예정임
- 검증: 구현 뒤 같은 focused XCTest에서 새 API의 컴파일 및 행위 assertion을 확인하고, 전체 XCTest와 앱 빌드를 실행할 예정임
- 배운 점: SceneKit 타이밍은 XCTest에 직접 의존시키지 않고, 상태·도착 테스트 훅·발견 판정을 결정론적 API로 노출해야 한다.

### L-20260810-024 — Task 4 구현 패치가 기존 ContentView의 정확한 형식 불일치로 적용되지 않음

- 상태: 해결
- 발생 태스크: Task 4 — SceneKit 나레이션·탭·가짜 숨기·카메라 발견
- 재현: Task 4 소스·`ContentView.swift`를 함께 갱신하는 `apply_patch`
- 관찰: `ContentView`의 기존 `ClosedWorldSceneView()` 호출에 이미 `.ignoresSafeArea()` 체인이 있어, 예상한 한 줄 본문과 일치하지 않아 `apply_patch verification failed`로 전체 패치가 적용되지 않음
- 영향: 새 C3 나레이션·상호작용 소스는 쓰이지 않았고, RED 상태가 유지됨
- 원인/가설: 패치의 문맥이 기존 SwiftUI 체인을 완전하게 반영하지 못함
- 조치: 실제 `ContentView.swift`의 네 줄 본문을 확인했고, 정확한 체인을 기준으로 소스 패치를 다시 적용할 예정임
- 검증: 실패 직후 `test -e .../NarrationOverlayScene.swift`가 `1`을 반환하고 `git diff -- C3ClosedWorld.swift`가 비어 있어 생산 코드가 부분 적용되지 않았음을 확인함
- 배운 점: 여러 파일을 한 번에 바꿀 때는 SwiftUI modifier 체인까지 정확한 문맥으로 지정하고, 실패 뒤 부분 적용 여부를 확인한다.

### L-20260810-025 — Task 4 GREEN XCTest가 SceneKit 프러스텀 API 수신자 오류로 컴파일 실패함

- 상태: 해결
- 발생 태스크: Task 4 — SceneKit 나레이션·탭·가짜 숨기·카메라 발견
- 재현: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/ClosedWorldEscapeTests -only-testing:PiggyEscapeTests/NarrationOverlaySceneTests test`
- 관찰: `C3ClosedWorld.swift:78:28: error: value of type 'SCNNode' has no member 'isInsideFrustum'`로 앱 타깃 컴파일이 중단됨
- 영향: 나무 도착 뒤 프러스텀·yaw·한 번만 발견하는 GREEN 동작을 테스트할 수 없음
- 원인/가설: SceneKit의 프러스텀 판정은 돼지 노드가 아니라 카메라 노드에 호출해 검사 대상 노드를 전달하는 API로 선언된 것으로 보임
- 조치: 로컬 SceneKit Swift interface에서 메서드 선언을 확인한 뒤, 카메라 노드 수신자로 정확히 교체할 예정임
- 검증: 수정 후 같은 focused XCTest에서 컴파일·발견 assertion을 다시 확인할 예정임
- 배운 점: 요구 문장의 개념상 주어와 Swift API의 실제 메서드 수신자는 다를 수 있으므로, SceneKit 선언을 먼저 대조한다.

### L-20260810-026 — Task 4 GREEN XCTest가 탭 조상 순회의 optional shadowing 오류로 컴파일 실패함

- 상태: 해결
- 발생 태스크: Task 4 — SceneKit 나레이션·탭·가짜 숨기·카메라 발견
- 재현: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/ClosedWorldEscapeTests -only-testing:PiggyEscapeTests/NarrationOverlaySceneTests test`
- 관찰: `C3ClosedWorldSceneView.swift:110`에서 `current`가 `while let`로 shadow된 상수라 `current = current.parent`를 할 수 없고, optional `parent`도 대입되지 않아 앱 타깃 컴파일이 중단됨
- 영향: 실제 `EscapePig` 자손만 탭을 허용하는 제스처 경로를 포함한 focused XCTest가 실행되지 않음
- 원인/가설: optional 순회 변수와 unwrap 상수에 같은 식별자를 사용했음
- 조치: 순회 optional은 `current`, unwrap 상수는 `candidate`로 분리해 부모를 안전하게 대입할 예정임
- 검증: 수정 후 같은 focused XCTest에서 탭 게이트·나레이션·발견 assertion을 실행할 예정임
- 배운 점: SceneKit의 부모 체인을 순회할 때 optional 저장 변수와 현재 노드 상수의 이름을 분리하면 Swift shadowing 오류를 피할 수 있다.

### L-20260810-027 — Task 4 GREEN XCTest에서 프러스텀 판정이 발견을 막음

- 상태: 해결
- 발생 태스크: Task 4 — SceneKit 나레이션·탭·가짜 숨기·카메라 발견
- 재현: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/ClosedWorldEscapeTests -only-testing:PiggyEscapeTests/NarrationOverlaySceneTests test`
- 관찰: 6개 focused XCTest 중 나레이션·탭·실제 `HideTree`·놀람·오버레이 5개는 통과했으나, `test_cameraDiscoveryNeedsYawChangeAndVisiblePig`에서 π/2 yaw 뒤 `isDiscoveredAfterCameraRotation()`이 `false`이고 포즈가 `idle`로 남아 2개 assertion이 실패함
- 영향: 돼지가 나무에 도착한 뒤 충분한 카메라 회전으로 발견되는 Task 4 핵심 흐름을 자동 검증하지 못함
- 원인/가설: renderer 없는 테스트용 직교 프러스텀 기하 판정에서 카메라 방향/좌표 변환 또는 허용 범위가 실제 SceneKit 렌더러와 다르게 계산된 것으로 보임. 실제 `SCNView.isNode(_:insideFrustumOf:)`는 화면이 연결될 때 별도 사용함
- 조치: 카메라 공간 돼지 좌표와 constraint 평가를 측정했고, renderer가 실제 프러스텀 결과를 주입하도록 단일 경계를 바꿈
- 검증: 후속 focused 6/6, 전체 44/44 XCTest, iOS Simulator build 성공. renderer 없는 문제의 진단·해결 근거는 L-20260810-028에 남김
- 배운 점: renderer 안전 단위 테스트의 프러스텀 대체 판정은 실제 화면 경로와 분리하되, 같은 카메라 변환·투영 경계를 수치로 검증해야 한다.

### L-20260810-028 — renderer 없는 프러스텀 진단이 카메라 LookAt 제약의 미평가를 확인함

- 상태: 해결
- 발생 태스크: Task 4 — SceneKit 나레이션·탭·가짜 숨기·카메라 발견
- 재현: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/ClosedWorldEscapeTests/test_cameraDiscoveryNeedsYawChangeAndVisiblePig test`
- 관찰: π/2 회전 뒤 카메라는 `(12.020815, 12.0, -12.020815)`, 돼지는 `(-4.2649684, 0.63528, -1.5202962)`였지만 `cameraEuler`는 `(0, 0, 0)`이었다. 단일 테스트는 같은 발견 assertion 2개로 계속 실패함
- 영향: SceneKit renderer 없이 `SCNLookAtConstraint` 결과를 전제로 한 카메라 공간 변환은 신뢰할 수 없음
- 원인/가설: `SCNLookAtConstraint`는 renderer/프레임 평가 중 적용되므로 XCTest의 독립 노드 그래프에서 카메라 방향이 갱신되지 않았음. 실제 화면에서는 `SCNView.isNode(_:insideFrustumOf:)`가 renderer의 프러스텀을 판정할 수 있음
- 조치: 월드의 발견 판정은 프러스텀 결과를 주입받아 fail-closed로 처리하고, C3 SceneKit view가 실제 `SCNView.isNode(_:insideFrustumOf:)` 결과를 제공하게 함. 단위 테스트는 명시적으로 보이는 상태를 주입해 yaw·도착·한 번만 조건을 결정론적으로 검증함
- 검증: 진단 `print`를 제거하고, 주입된 visible/actual SCNView 경로를 포함해 focused XCTest를 다시 실행할 예정임
- 배운 점: 렌더러가 소유하는 constraint·frustum 결과는 순수 상태 테스트에서 재계산하지 말고, 실제 어댑터에서 측정해 주입한다.

### L-20260810-029 — Task 4 전체 XCTest는 통과했지만 기존 Simulator 런타임 경고가 출력됨

- 상태: 보류
- 발생 태스크: Task 4 — SceneKit 나레이션·탭·가짜 숨기·카메라 발견
- 재현: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`
- 관찰: 44개 XCTest와 `** TEST SUCCEEDED **`는 확인했지만, `Metadata extraction skipped. No AppIntents.framework dependency found`, `TBB Global TLS count is not == 1`, `UIFocus` 캐시 제한, `UIAccessibilityLoaderWebShared` 중복 구현 경고가 함께 출력됨
- 영향: Task 4의 C3 숨기·발견 회귀 assertion은 실패하지 않았지만 XCTest 출력이 경고 없이 깨끗하다는 조건은 충족하지 못함
- 원인/가설: AppIntents 의존성이 없는 앱 타깃과 iOS Simulator 26.5의 기존 런타임 진단으로, Task 4 소스의 컴파일 또는 XCTest assertion 실패는 없음
- 조치: Task 4 범위 밖의 기존 앱 타깃·Simulator 런타임을 변경하지 않고, 경고를 보류한 채 focused·전체 XCTest의 통과 결과를 유지함
- 검증: focused `ClosedWorldEscapeTests`/`NarrationOverlaySceneTests` 6/6과 전체 XCTest 44/44가 통과했으며, 새 C3 프러스텀 경로는 `SCNView.isNode(_:insideFrustumOf:)`로 연결됨
- 배운 점: SceneKit 상호작용 회귀와 Simulator/AppIntents 런타임 경고를 분리해 기록하고, 태스크 범위 밖 경고를 해결하려고 앱 구조를 바꾸지 않는다.

### L-20260810-030 — Task 4의 실제 손가락 제스처·프러스텀 시각 확인은 자동 빌드로 대체할 수 없음

- 상태: 보류
- 발생 태스크: Task 4 — SceneKit 나레이션·탭·가짜 숨기·카메라 발견
- 재현: iPhone 17 Pro Simulator에서 C3 섬을 표시한 뒤, 나레이션 종료 후 돼지 모델 자손을 탭하고 화면 폭의 약 1/2를 팬해 발견 자막·확대를 관찰하는 수동 절차
- 관찰: 이 작업에서는 focused 6/6, 전체 44/44 XCTest와 iOS Simulator `xcodebuild build` 성공을 확인했지만, 터치 좌표의 실제 hitTest·렌더러 프러스텀·SpriteKit 프레임 완료를 수동 조작으로 촬영하지는 않았음
- 영향: 자동 검증은 상태·액션 키·카피·실제 `SCNView.isNode(_:insideFrustumOf:)` 연결을 증명하지만, 실제 화면에서 돼지가 나무 뒤에 가려졌다가 팬으로 보이는 연출의 시각 품질은 확정하지 못함
- 원인/가설: SceneKit constraint·renderer 프러스텀·SpriteKit 액션은 테스트용 독립 노드 그래프와 달리 표시 중인 `SCNView` 프레임에서 평가됨
- 조치: Task 4 범위의 자동 검증을 완료 근거로 유지하고, 후속 검토 또는 수동 Simulator 세션에서 위 절차를 별도로 확인함. RealityKit·권한 전환은 시작하지 않음
- 검증: `C3ClosedWorldSceneView`는 실제 뷰의 `isNode(_:insideFrustumOf:)` 결과를 발견 조건에 주입하고, renderer 없는 XCTest는 visible 결과를 명시 주입해 yaw·도착·한 번만 조건을 44개 전체 회귀 안에서 검증함
- 배운 점: 렌더러 의존 연출은 결정론적 상태 단위 테스트와 실제 화면 수동 확인을 모두 필요로 하며, 전자를 후자로 오인하지 않는다.

### L-20260810-018 — Task 3 커밋 준비가 연결 작업 트리 index 잠금 권한으로 중단됨

- 상태: 해결
- 발생 태스크: Task 3 — C3 섬, 돼지 모델, 궤도 카메라 어댑터
- 재현: `git add PiggyEscape/PiggyEscape/Sources/C3World PiggyEscape/PiggyEscapeTests/C3IslandBuilderTests.swift PiggyEscape/PiggyEscapeTests/C3PigModelFactoryTests.swift PiggyEscape/PiggyEscapeTests/C3ClosedWorldTests.swift docs/WORK_LOG.md docs/LEARNING_LOG.md`
- 관찰: `fatal: Unable to create '/Users/yang-eunseo/Downloads/SpatialComputing_TechMap/.git/worktrees/ch1-reality-escape/index.lock': Operation not permitted`로 index 갱신 전에 중단됨
- 영향: 검증된 Task 3 변경을 태스크 단위 커밋으로 기록하지 못함
- 원인/가설: 연결 작업 트리의 공용 Git 메타데이터 index 잠금 경로가 현재 권한 범위 밖에 있음
- 조치: 공용 Git 메타데이터에 쓸 수 있는 권한으로 같은 명시적 Task 3 파일 목록만 stage와 commit할 예정임
- 검증: 공용 Git 메타데이터 접근 권한으로 같은 명시적 파일 목록을 stage했고, 커밋 후 `git show --stat --oneline HEAD`와 `git status --short`로 Task 3 파일만 포함됐는지 확인함
- 배운 점: 연결 작업 트리에서는 작업 트리 파일 쓰기 권한과 별도로 공용 Git index 잠금 경로 쓰기 권한이 필요하다.

### L-20260810-017 — 내부 돼지 모델이 아니라 그 하위 아트 노드가 USD 축 보정을 소유함

- 상태: 해결
- 발생 태스크: Task 3 — C3 섬, 돼지 모델, 궤도 카메라 어댑터
- 재현: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/C3PigModelFactoryTests/test_innerModelOwnsUsdAxisCorrectionAndFloorNormalization test`
- 관찰: 새 실제 SceneKit 노드 테스트에서 `PigModel_idle.eulerAngles.x`와 `.z`가 각각 `0.0`으로 관찰되어 기대한 `Float.pi / 2`, `Float.pi`와 일치하지 않았고 2개 assertion이 실패함
- 영향: 외부 `EscapePig`와 이름 있는 내부 `PigModel_*`의 변환 책임 경계가 명세보다 한 단계 더 깊게 분산됨
- 원인/가설: `loadNormalizedModel`이 `PigModel_*`의 하위 `art` 노드에 축 보정을 적용하고, 내부 모델 컨테이너에는 정규화만 적용했음
- 조치: `PigModel_*` 자체가 축 보정·균일 스케일·바닥 정렬을 모두 소유하도록 측정용 임시 루트에서 변환 반영 경계를 계산할 예정임
- 검증: `PigModel_*`을 측정용 임시 루트에서 회전·스케일·바닥 정렬하도록 수정한 뒤 같은 단일 XCTest를 재실행해 1/1 통과와 `** TEST SUCCEEDED **`를 확인함. 이어서 focused·전체 suite를 다시 실행함.
- 배운 점: 외부 애니메이션·확대 대상과 내부 USD 변환 대상의 경계는 이름 있는 노드의 실제 `eulerAngles`와 변환된 바운딩 박스로 회귀 테스트한다.

### L-20260810-016 — Task 3 전체 XCTest는 통과했지만 기존 Simulator 런타임 경고가 출력됨

- 상태: 보류
- 발생 태스크: Task 3 — C3 섬, 돼지 모델, 궤도 카메라 어댑터
- 재현: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`
- 관찰: 최종 38개 XCTest는 모두 통과했지만 `Metadata extraction skipped. No AppIntents.framework dependency found`, `UIFocus` 캐시 제한, `TBB Global TLS count is not == 1`, Simulator 런타임의 `UIAccessibilityLoaderWebShared` 중복 구현 경고가 출력됨
- 영향: Task 3의 C3 노드·카메라 자동 검증에는 실패가 없지만 XCTest 출력이 경고 없이 깨끗하다는 조건은 충족하지 못함
- 원인/가설: AppIntents 의존성이 없는 기존 앱 타깃의 메타데이터 처리와 iOS Simulator 26.5의 UI·접근성 런타임 진단이며, 새 C3 소스의 컴파일·XCTest assertion 실패는 없음
- 조치: Task 3 범위 밖의 앱 타깃과 Simulator 런타임 설정을 변경하지 않고, focused 및 전체 XCTest 통과를 기록함
- 검증: 최종 focused C3 XCTest 8/8, 전체 XCTest 38/38 통과와 `** TEST SUCCEEDED **`를 확인함
- 배운 점: SceneKit 단위 테스트의 통과 결과와 기존 Simulator 런타임 경고를 분리해 기록하고, 범위 밖 경고를 해결하려고 기존 앱 구조를 변경하지 않는다.

### L-20260810-015 — Task 3 XCTest가 앱 모듈 import 누락으로 C3 월드 타입을 찾지 못함

- 상태: 해결
- 발생 태스크: Task 3 — C3 섬, 돼지 모델, 궤도 카메라 어댑터
- 재현: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/C3IslandBuilderTests -only-testing:PiggyEscapeTests/C3PigModelFactoryTests -only-testing:PiggyEscapeTests/C3ClosedWorldTests test`
- 관찰: 앱 타깃의 C3 소스 컴파일 후 `C3ClosedWorldTests.swift`에서 `cannot find 'C3ClosedWorld' in scope` 3건으로 테스트 타깃 컴파일이 중단됨
- 영향: 실제 SceneKit C3 월드 동작 assertion을 실행하지 못함
- 원인/가설: 새 테스트 세 파일에 기존 XCTest 파일의 `@testable import PiggyEscape`가 누락되어 앱 타깃 심볼이 테스트 모듈에 노출되지 않음
- 조치: 세 C3 XCTest 파일에 `@testable import PiggyEscape`를 추가할 예정임
- 검증: 세 C3 XCTest 파일에 `@testable import PiggyEscape`를 추가한 뒤 같은 focused XCTest를 재실행해 7개 테스트가 모두 통과하고 `** TEST SUCCEEDED **`를 확인함.
- 배운 점: 별도 XCTest 타깃의 새 테스트는 기존 테스트 파일의 모듈 import 계약을 먼저 따르고, 타입 부재 RED와 import 누락을 구분한다.

### L-20260810-014 — Task 3 재시도 XCTest가 초기화 순서와 π 타입 추론 오류로 중단됨

- 상태: 해결
- 발생 태스크: Task 3 — C3 섬, 돼지 모델, 궤도 카메라 어댑터
- 재현: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/C3IslandBuilderTests -only-testing:PiggyEscapeTests/C3PigModelFactoryTests -only-testing:PiggyEscapeTests/C3ClosedWorldTests test`
- 관찰: `setupCamera`·`setupLighting` 호출 시 `pigContainer`와 `hideTree`가 초기화되기 전의 `self` 사용 오류 2건, `C3PigModelFactory`의 `.pi` 모호성 2건으로 컴파일이 중단됨
- 영향: focused C3 XCTest가 실행되지 못함
- 원인/가설: Swift의 non-optional `let` 저장 프로퍼티 초기화 규칙과 `Float`/`CGFloat`/`Double` 간 문맥 없는 `.pi` 선택 규칙을 충족하지 못함
- 조치: 섬에서 얻은 숨기 나무·돼지를 먼저 저장 프로퍼티에 할당한 뒤 카메라·조명을 구성하고, 돼지 각도에 `Float.pi`를 명시할 예정임
- 검증: 초기화 순서를 수정하고 `Float.pi`를 명시한 뒤 같은 focused XCTest를 재실행했으며, 이 항목의 4개 진단은 사라졌다. 이어진 테스트 타깃 import 오류는 L-20260810-015에 기록했다.
- 배운 점: SceneKit 월드 생성자는 노드 그래프를 만들기 전에 모든 non-optional 저장 프로퍼티를 초기화하고, 벡터 각도는 `Float` 상수를 명시한다.

### L-20260810-013 — Task 3 GREEN XCTest가 C3 어댑터의 Swift 컴파일 오류로 실패함

- 상태: 해결
- 발생 태스크: Task 3 — C3 섬, 돼지 모델, 궤도 카메라 어댑터
- 재현: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/C3IslandBuilderTests -only-testing:PiggyEscapeTests/C3PigModelFactoryTests -only-testing:PiggyEscapeTests/C3ClosedWorldTests test`
- 관찰: `Decoration` 멤버와이즈 초기화의 인자 레이블 9건 누락, `SCNVector3.zero` 미정의, `SCNScene.pointOfView` 미정의로 앱 타깃 컴파일이 중단됨
- 영향: 새 C3 노드 동작 XCTest를 실행하지 못함
- 원인/가설: 구현에서 Swift 구조체의 기본 이니셜라이저 호출 규칙과 SceneKit API 소유 타입을 잘못 적용함. `pointOfView`는 `SCNView`의 속성임
- 조치: C3 장식 명세에 무레이블 이니셜라이저를 명시하고, 영 벡터는 `SCNVector3(0, 0, 0)`으로, 잘못된 scene 카메라 할당은 제거함
- 검증: 무레이블 `Decoration` 이니셜라이저를 추가하고, 영 벡터·잘못된 `SCNScene.pointOfView` 할당을 수정한 뒤 같은 focused XCTest를 재실행했으며, 이 항목의 11개 진단은 사라졌다. 다음 컴파일 오류는 L-20260810-014에 기록했다.
- 배운 점: 새 SceneKit 어댑터에서는 구조체 초기화 레이블과 `SCNScene`/`SCNView` 책임 경계를 컴파일 전 원본 API와 대조한다.

### L-20260810-012 — Task 3 RED XCTest가 Simulator 서비스 접근 제한으로 중단됨

- 상태: 해결
- 발생 태스크: Task 3 — C3 섬, 돼지 모델, 궤도 카메라 어댑터
- 재현: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/C3IslandBuilderTests -only-testing:PiggyEscapeTests/C3PigModelFactoryTests -only-testing:PiggyEscapeTests/C3ClosedWorldTests test`
- 관찰: `CoreSimulatorService connection became invalid`와 `Error opening log file ... Operation not permitted`가 발생해 XCTest가 새 타입의 컴파일 단계에 도달하기 전에 종료됨
- 영향: C3 타입 부재를 보여야 하는 RED를 현재 권한 범위에서 확인하지 못함
- 원인/가설: Simulator의 기기·로그·서비스 상태 경로가 현재 파일 권한 범위 밖에 있음
- 조치: Simulator 서비스와 Xcode 상태 경로에 접근 가능한 권한으로 같은 focused XCTest 명령을 재실행할 예정임
- 검증: Simulator 서비스와 Xcode 상태 경로 접근 권한으로 focused XCTest를 재실행했고, `C3ClosedWorldTests.swift`에서 `cannot find 'C3ClosedWorld' in scope` 3건으로 테스트 타깃 컴파일이 중단됨을 확인함. 첫 컴파일 오류에서 중단되어 나머지 C3 타입의 진단은 생성되지 않았음.
- 배운 점: iOS Simulator XCTest는 생성 프로젝트만으로 동작하지 않으며, Simulator 서비스·로그 상태 경로 접근이 필요하다.

### L-20260810-011 — Task 3 RED 준비 중 Tuist 세션 상태 디렉터리 쓰기가 거부됨

- 상태: 해결
- 발생 태스크: Task 3 — C3 섬, 돼지 모델, 궤도 카메라 어댑터
- 재현: `cd PiggyEscape && tuist generate --no-open`
- 관찰: `Fatal error: Error raised at top level: Permission denied: /Users/yang-eunseo/.local/state/tuist/sessions/F7174714-4104-4318-A365-0F8648073706`로 생성이 테스트 실행 전에 종료됨
- 영향: 새 XCTest 소스가 생성 프로젝트에 반영되지 않아 C3 타입 부재 RED를 아직 관찰하지 못함
- 원인/가설: Tuist가 작업 트리 밖의 사용자 세션 상태 디렉터리에 쓸 수 없어 생성 과정이 중단됨
- 조치: 해당 상태 경로에 접근 가능한 권한으로 동일 명령을 재실행해, 생성 성공 뒤 RED 컴파일 실패를 확인할 예정임
- 검증: 사용자 세션 상태 경로 접근 권한으로 같은 `tuist generate --no-open`을 재실행했고 `✔ Success`를 확인함. 이어서 지정된 C3 focused XCTest로 타입 부재 RED를 확인함.
- 배운 점: 새 Swift XCTest의 유효한 RED는 Tuist가 테스트 타깃 파일 목록을 다시 생성한 뒤에만 관찰할 수 있다.

### L-20260810-009 — Task 3 시작 전 원격 fetch가 연결 작업 트리 메타데이터 권한으로 중단됨

- 상태: 보류
- 발생 태스크: Task 3 — C3 섬, 돼지 모델, 궤도 카메라 어댑터
- 재현: `git fetch --prune origin`
- 관찰: `error: cannot open '/Users/yang-eunseo/Downloads/SpatialComputing_TechMap/.git/worktrees/ch1-reality-escape/FETCH_HEAD': Operation not permitted`로 원격 참조 갱신 전에 종료됨
- 영향: 구현 전 원격 변경 동기화 상태를 이 작업 트리에서 확정할 수 없음
- 원인/가설: 연결 작업 트리의 Git 메타데이터 `FETCH_HEAD` 쓰기 경로가 현재 파일 권한 범위 밖에 있음
- 조치: 기존 L-20260810-001과 같은 제약으로 기록하고, 작업 트리 내부의 읽기 전용 상태와 지정된 Task 3 명세로 범위를 확인함
- 검증: 후속 `git status --short`와 브랜치 확인을 별도 실행할 예정이며, 원격 fetch는 권한 확보 전까지 미검증으로 유지함
- 배운 점: 동일한 환경 제약이 후속 태스크에서도 재현되면 새 항목으로 명령·영향을 남기고 원격 상태를 추정하지 않는다.

### L-20260810-010 — Task 3 시작 순서의 프로젝트 맥락 문서가 작업 트리에 없음

- 상태: 보류
- 발생 태스크: Task 3 — C3 섬, 돼지 모델, 궤도 카메라 어댑터
- 재현: `sed -n '1,260p' docs/PROJECT_CONTEXT.md`
- 관찰: `sed: docs/PROJECT_CONTEXT.md: No such file or directory`로 지정 문서를 읽지 못함
- 영향: 시작 순서의 프로젝트 맥락 문서를 현재 브랜치에서 검토할 수 없음
- 원인/가설: 기존 L-20260810-004와 동일하게, 이 연결 작업 트리의 문서 구조에 해당 경로가 아직 포함되지 않은 것으로 보임
- 조치: 존재하는 `docs/WORK_LOG.md`, Reality escape 설계·계획, Task 3 브리프를 대체 근거로 사용함
- 검증: `rg --files`로 경로 부재와 대체 문서 존재를 확인할 예정임
- 배운 점: 시작 필수 문서가 반복적으로 부재하면 이전 기록을 참조하되, 현재 태스크의 재현 명령과 대체 근거를 별도 기록한다.

### L-20260810-008 — Task 2 커밋 준비가 연결 작업 트리 index 잠금 권한으로 중단됨

- 상태: 해결
- 발생 태스크: Task 2 — 경험 상태와 숨기 좌표를 순수 로직으로 만든다
- 재현: `git add PiggyEscape/PiggyEscape/Sources/Escape/EscapeExperienceState.swift PiggyEscape/PiggyEscape/Sources/Escape/HidePlanning.swift PiggyEscape/PiggyEscapeTests/EscapeExperienceStateTests.swift PiggyEscape/PiggyEscapeTests/HidePlanningTests.swift docs/WORK_LOG.md docs/LEARNING_LOG.md && git commit -m 'Add escape state and hide planning'`
- 관찰: `fatal: Unable to create '/Users/yang-eunseo/Downloads/SpatialComputing_TechMap/.git/worktrees/ch1-reality-escape/index.lock': Operation not permitted`로 index 갱신 전에 중단됨
- 영향: 검증된 Task 2 변경을 태스크 단위 커밋으로 기록하지 못함
- 원인/가설: 연결 작업 트리의 공용 Git 메타데이터 index 잠금 경로가 현재 권한 범위 밖에 있음
- 조치: 공용 Git 메타데이터에 쓸 수 있는 권한으로 같은 명시적 파일 목록을 stage 및 commit함
- 검증: 커밋 후 `git show --stat --oneline HEAD`와 `git status --short`로 Task 2 파일만 커밋되었고 사용자 소유의 `.claude/`만 남았는지 확인함
- 배운 점: 연결 작업 트리에서는 작업 트리 파일 쓰기 권한과 별도로 공용 Git index 잠금 경로 쓰기 권한이 필요하다.

### L-20260810-007 — 전체 XCTest 성공 중 기존 Simulator 런타임 경고가 출력됨

- 상태: 보류
- 발생 태스크: Task 2 — 경험 상태와 숨기 좌표를 순수 로직으로 만든다
- 재현: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`
- 관찰: 30개 XCTest는 모두 통과했지만 `Metadata extraction skipped. No AppIntents.framework dependency found`, `UIFocus` 캐시 제한, Simulator 런타임의 `UIAccessibilityLoaderWebShared` 중복 구현 경고가 출력됨
- 영향: Task 2의 순수 로직 테스트 결과에는 실패가 없지만 XCTest 출력이 경고 없이 깨끗하다는 조건은 충족하지 못함
- 원인/가설: AppIntents 의존성이 없는 기존 앱 타깃의 메타데이터 처리와 iOS Simulator 26.5의 UI/접근성 런타임 진단이며, Task 2의 두 순수 소스는 UIKit·SceneKit·ARKit·RealityKit을 import하지 않음
- 조치: Task 2 범위 밖의 앱 타깃·Simulator 런타임 설정은 변경하지 않고, focused 및 전체 XCTest의 통과 결과를 기록함
- 검증: focused XCTest 3/3, 전체 XCTest 30/30 통과. `rg -n '^(import (UIKit|SceneKit|ARKit|RealityKit))' PiggyEscape/PiggyEscape/Sources/Escape`로 금지 프레임워크 import가 없음을 확인함
- 배운 점: 순수 로직 변경의 회귀 검증과 기존 Simulator 런타임 경고를 분리해 기록하고, 범위 밖 경고를 해결하려고 앱 구조를 변경하지 않는다.

### L-20260810-006 — Task 2 RED XCTest가 Simulator 서비스 접근 제한으로 중단됨

- 상태: 해결
- 발생 태스크: Task 2 — 경험 상태와 숨기 좌표를 순수 로직으로 만든다
- 재현: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/EscapeExperienceStateTests -only-testing:PiggyEscapeTests/HidePlanningTests test`
- 관찰: `CoreSimulatorService connection became invalid`와 `Error opening log file ... Operation not permitted`가 발생해 컴파일 단계 전에 Simulator 서비스를 초기화하지 못함
- 영향: 새 타입 부재를 보여야 하는 RED XCTest가 실제 컴파일 오류까지 도달하지 못함
- 원인/가설: Simulator의 기기·로그·서비스 상태 경로가 현재 권한 범위 밖에 있음
- 조치: Simulator 서비스와 Xcode 상태 경로에 접근 가능한 권한으로 동일한 명령을 재실행함
- 검증: 재실행에서 `EscapeExperienceMachine` 미발견 컴파일 실패를 확인함. 테스트 타깃이 첫 컴파일 오류에서 중단되어 `TreeHidePlanner` 진단은 생성되지 않았음
- 배운 점: iOS Simulator XCTest는 프로젝트 파일만으로 동작하지 않으며, Simulator 서비스와 Xcode 로그 상태에 접근할 수 있어야 한다.

### L-20260810-005 — Task 2 RED 준비 중 Tuist 세션 상태 디렉터리 쓰기가 거부됨

- 상태: 해결
- 발생 태스크: Task 2 — 경험 상태와 숨기 좌표를 순수 로직으로 만든다
- 재현: `cd PiggyEscape && tuist generate --no-open`
- 관찰: `Fatal error: Error raised at top level: Permission denied: /Users/yang-eunseo/.local/state/tuist/sessions/AC8F4B22-C54F-4CF0-8096-E18EF5C09C3D`로 프로젝트 생성이 테스트 실행 전에 종료됨
- 영향: 새 XCTest 파일을 기존 생성 프로젝트에 반영하지 못해 타입 부재 RED를 아직 관찰할 수 없음
- 원인/가설: Tuist가 작업 트리 밖의 사용자 세션 상태 디렉터리에 쓰기를 시도하지만 현재 권한 범위에 포함되지 않음
- 조치: 해당 상태 경로에 쓸 수 있는 권한으로 같은 생성 명령을 재실행함
- 검증: 권한 확보 후 프로젝트를 다시 생성하고, 지정한 두 테스트를 실행해 `EscapeExperienceMachine` 부재 컴파일 실패를 확인함. 컴파일이 첫 오류에서 중단되어 `TreeHidePlanner` 미발견 진단은 생성되지 않았음
- 배운 점: 새 Swift 소스의 RED는 생성 프로젝트에 소스 글로브가 반영된 뒤에만 의미가 있으므로, 먼저 Tuist 세션 상태 쓰기 권한을 확인한다.

### L-20260810-002 — Tuist 생성이 세션 상태 디렉터리 권한으로 중단됨

- 상태: 해결
- 발생 태스크: Task 1 — C3 에셋과 카메라 권한을 앱 타깃에 등록한다
- 재현: `cd PiggyEscape && tuist generate --no-open && xcodebuild -project PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/AssetLoaderTests/test_c3EscapeAssets_loadFromTheAppBundle test`
- 관찰: Tuist가 `Fatal error: Error raised at top level: Permission denied: /Users/yang-eunseo/.local/state/tuist/sessions/BB509A80-33DE-4668-A2F8-BF6CBB5F6FDA`로 종료되어 XCTest 실행 전 중단됨
- 영향: RED 단계의 번들 로딩 실패를 아직 확인하지 못함
- 원인/가설: Tuist가 작업 트리 밖의 사용자 세션 상태 디렉터리에 쓰기를 시도하지만 현재 권한 범위에 포함되지 않음
- 조치: 해당 Tuist 상태 경로에 쓸 수 있는 권한으로 같은 명령을 재실행함
- 검증: Tuist 생성은 성공했고, `AssetLoaderTests.test_c3EscapeAssets_loadFromTheAppBundle`가 새 C3 에셋 부재로 16개 assertion 실패함
- 배운 점: Tuist 기반 검증은 프로젝트 생성물 경로뿐 아니라 사용자 세션 상태 경로의 쓰기 권한도 필요하다.

### L-20260810-003 — C3 에셋 번들 로딩 회귀 테스트가 새 에셋 누락으로 실패함

- 상태: 해결
- 발생 태스크: Task 1 — C3 에셋과 카메라 권한을 앱 타깃에 등록한다
- 재현: `cd PiggyEscape && tuist generate --no-open && xcodebuild -project PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/AssetLoaderTests/test_c3EscapeAssets_loadFromTheAppBundle test`
- 관찰: `Piggy_running`, `Piggy_surprised`, 두 `Cylinder_Tree`, `Manger_Color`, `Stone_Color`, `Coin_Color`, `Warehouse_Color`가 `expected bundled C3 asset` assertion에서 nil이었고, 총 16개 assertion이 실패함
- 영향: C3 월드 어댑터가 필요한 걷기·놀람·나무·섬 장식 리소스를 앱 번들에서 찾을 수 없음
- 원인/가설: 8개 C3 원본 에셋이 앱 리소스 디렉터리에 아직 복사되지 않았음
- 조치: 지정한 11개 C3 원본을 바이트 변경 없이 앱 리소스에 복사하고, 카메라 권한 Info.plist 항목을 추가함
- 검증: 11개 원본/대상 쌍의 `cmp -s`와 SHA-256 값이 일치했고, `xcodebuild ... -only-testing:PiggyEscapeTests/AssetLoaderTests test`가 5개 테스트를 통과했으며, 생성된 Info.plist에서 고정 목적 문구를 추출함
- 배운 점: 앱 번들 리소스 계약은 확장자 없는 로더 호출을 실제 앱 번들에서 실행하는 회귀 테스트로 보호한다.

### L-20260810-004 — 시작 순서에 지정된 두 문서가 작업 트리에 없음

- 상태: 보류
- 발생 태스크: Task 1 — C3 에셋과 카메라 권한을 앱 타깃에 등록한다
- 재현: `sed -n '1,240p' docs/PROJECT_CONTEXT.md` 및 `sed -n '1,260p' 씬킷에서_리얼리티킷으로_컨셉노트.md`
- 관찰: `docs/PROJECT_CONTEXT.md: No such file or directory`로 명령이 중단되었고, 파일 목록에도 두 경로가 없음
- 영향: 시작 순서의 일부 문서를 현재 작업 트리에서 검토할 수 없음
- 원인/가설: 현재 브랜치의 문서 구조가 공통 작업 지침보다 이전이거나, 해당 문서가 아직 이 브랜치에 추가되지 않음
- 조치: 현존하는 Reality escape 설계 명세·구현 계획·작업 인수인계와 태스크 브리프를 기준으로 Task 1 범위를 구현함
- 검증: `rg --files`로 해당 두 경로의 부재와 관련 설계/계획 문서의 존재를 확인함
- 배운 점: 작업 시작 문서가 없을 때는 경로 부재와 대체한 저장소 내 근거를 기록하고, 범위를 확장하지 않는다.

### L-20260810-001 — 작업 트리에서 원격 fetch의 FETCH_HEAD를 쓸 수 없음

- 상태: 보류
- 발생 태스크: Task 1 — C3 에셋과 카메라 권한을 앱 타깃에 등록한다
- 재현: `git fetch --prune origin`
- 관찰: `error: cannot open '/Users/yang-eunseo/Downloads/SpatialComputing_TechMap/.git/worktrees/ch1-reality-escape/FETCH_HEAD': Operation not permitted`
- 영향: 원격 변경 확인이 완료되지 않아 시작 전 원격 동기화 상태를 확정할 수 없음
- 원인/가설: 작업 트리의 공용 Git 메타데이터 쓰기 경로가 현재 권한 범위 밖에 있음
- 조치: 현재 작업 트리의 `git status --short`와 브랜치 정보를 확인하고, 원격 fetch 재시도는 권한이 확보될 때까지 보류함
- 검증: `git status --short`에서 사용자 소유의 추적되지 않은 `.claude/`만 확인됨; 원격 fetch는 미검증 상태로 남음
- 배운 점: 연결 작업 트리에서는 원격 확인 전에 공용 Git 메타데이터의 쓰기 권한을 먼저 확인한다.
### L-20260811-051 — 화면 밖 관찰도 발견 프레임으로 소비하는 회귀 테스트가 컴파일 RED를 만듦

- 상태: 해결
- 발생 태스크: Task 6 독립 리뷰 수정 1차 — 유효한 화면 관찰만 발견 판정에 반영
- 재현: `xcodebuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PiggyEscapeTests/RealityHideARViewCoordinatorTests test`
- 관찰: 새 테스트가 요구한 `isObservationValid` 인자와 `RealityProjectionGate`가 구현에 없어 컴파일이 실패함
- 영향: 기존 구현은 투영점이 화면 밖이거나 돼지가 카메라 뒤에 있어도 메시 히트가 없으면 가시 프레임으로 소비할 수 있었음
- 원인/가설: `ARView.project`가 반환한 좌표의 뷰포트 포함 여부와 카메라 전방 반공간을 확인하지 않고 거리 모니터에 전달했음
- 조치: 투영점이 화면 안에 있고 돼지가 카메라 전방에 있을 때만 관찰을 유효하게 만드는 순수 `RealityProjectionGate`를 추가하고, 무효 프레임은 `RealityRevealMonitor`에 전달하지 않도록 함
- 검증: 수정 전 컴파일 RED를 확인했고 `RealityHideARViewCoordinatorTests` focused XCTest 5/5를 통과함
- 배운 점: 화면 좌표 변환의 성공 여부만으로 가시성을 추론하지 말고, 뷰포트 경계와 카메라 기준 깊이를 함께 검증해야 한다.
