# 프로젝트 컨텍스트

> 이 문서는 저장소를 함께 다루는 작업자의 공통 시작점이다. 로컬 대화 기록이 아니라, 이 문서와 `docs/WORK_LOG.md`·설계·실행 계획의 Git 추적 상태를 기준으로 작업한다.

## 현재 승인 범위

- 범위: 사용자가 Chapter 2–4 확장을 승인했다. 최종 범위는 **C3 SceneKit 닫힌 세계 → RealityKit 현실 준비 → 실제 물체 뒤 숨기·이동 재발견 → SceneKit/RealityKit 비교·완료**의 네 챕터다.
- 상세 기준: 사용자가 [4개 챕터 완성 설계](superpowers/specs/2026-08-29-four-chapter-experience-and-docc-design.md)를 승인했다. 구현은 이 설계와 [4개 챕터 실행 계획](superpowers/plans/2026-08-29-four-chapter-experience-and-docc-implementation.md)의 테스트·커밋 순서를 따른다.
- 기준선: 기존 방·가짜 소파 구현은 SceneKit 개념을 설명하는 참고 예제로 보존한다. 실행 앱의 Chapter 1은 현재 C3 섬·기존 나무·돼지 경험을 기준으로 한다.
- 진입 화면: `ContentView`는 `EscapeRootView` 하나를 시작한다. Chapter 2와 3은 같은 `RealityHideARView`·AR session을 유지하고 Chapter 4에서 정리한다.
- 공개 문서: 저장소 루트 `Tutorials/SceneKitToRealityKit.docc`를 유일한 공개 DocC 원본으로 통합하고, `scripts/build-docc-site.sh`와 Pages 파이프라인으로 기준 URL의 네 챕터를 앱 구현과 동기화한다.
- 제외: 금융 상태, SwiftData 저장, 용돈·작은 돼지, WatchConnectivity, Watch UI, 물체 의미 자동 분류, LiDAR 미지원 기기의 가짜 오클루전.

## 경험 계약

1. **Chapter 1**: SceneKit C3 섬에서 나레이션 뒤 돼지를 탭하면 기존 나무 뒤로 걷고, 도착 0.40초 뒤 자동으로 한 번 발견된다. 0.70초 페이드 뒤 Chapter 2로 전환한다.
2. **Chapter 2**: 카메라 권한과 LiDAR 지원을 확인하고, 유효한 `ARView`에서 최소 한 개의 mesh와 최소 한 개의 분류된 floor를 모두 관찰한다. 준비 완료 CTA 전에는 실제 물체 선택 탭을 받지 않는다.
3. **Chapter 3**: 높이 0.18m의 돼지를 카메라에서 0.90m 이상 떨어진 세로 물체 뒤로 이동한다. 현재 카메라 기준 중심·상·하·좌·우 다섯 점 중 중심을 포함한 네 점이 서로 다른 AR frame의 연속 두 관찰에서 실제 mesh에 가려진 뒤에만 찾기 안내를 표시한다.
4. 사용자가 최초 가림 pose에서 0.15m 이상 이동하거나 15° 이상 회전한 이력을 만든 뒤, 중심을 포함한 세 점이 서로 다른 AR frame의 연속 두 관찰에서 보일 때 한 번 발견한다. 이후 같은 AR session에서 다시 숨기거나 Chapter 4로 진행한다.
5. **Chapter 4**: 세계·좌표·앞뒤 관계·책임 구조의 네 축으로 SceneKit과 RealityKit을 비교하고 완료 또는 replay를 제공한다.

정확한 상태 전이·수치·오류·DocC·검증 경계는 승인된 [4개 챕터 완성 설계](superpowers/specs/2026-08-29-four-chapter-experience-and-docc-design.md)를 최우선으로 한다. 이전 설계는 변경 이유와 구현 이력을 확인하는 참고 문서로 유지한다.

## 시작 순서와 협업 규칙

1. 이 문서
2. `docs/WORK_LOG.md`
3. `씬킷에서_리얼리티킷으로_컨셉노트.md` (현재 브랜치에 없으면 부재 사실을 `docs/LEARNING_LOG.md`에 기록하고 승인된 설계 명세를 대체 근거로 사용)
4. 관련 설계 명세와 실행 계획

구현 전에는 `git fetch --prune origin`, `git status --short` 순서로 상태를 확인한다. 권한·환경 문제로 명령이 실패하면 재시도나 보류 전에 `docs/LEARNING_LOG.md`에 재현·관찰·영향을 기록한다. 다른 작업자가 만들었거나 추적하지 않은 파일은 요청 없이 이동·삭제·스테이징하지 않는다.

의사결정, 검증 결과, 남은 위험, 다음 시작점은 `docs/WORK_LOG.md`에 결과물과 같은 커밋으로 기록한다. 실패·예상 밖 동작·실기기 한계는 `docs/LEARNING_LOG.md`에 남긴다. `.claude/`와 대용량 C3 참고 사본은 로컬 참고물이며 추적하지 않는다.

커밋·PR에는 작업자·도구·모델·AI 생성 표기와 `Co-Authored-By`를 넣지 않는다. 생성된 Xcode 프로젝트, DerivedData, `/tmp` 산출물은 추적하지 않는다.

## 검증 상태

- 2026-09-08 새 경로 보수: 물체를 탭해도 경로가 거절되는 두 실제 산술 회귀를 재현하고, 배치 전 안전 출발점·세밀한 측면 후보·실제 첫 점 전달·원인별 안내를 보수했다. host 정책 55/55와 Swift 5·Swift 6 strict generic iPhoneOS build는 통과했다. 최신 정적 XCTest 230개의 physical 실행과 새 앱 설치는 기기 잠금으로 대기한다. 아래 223/223은 직전 버전의 기준선이며 이번 수정의 기기 성공 증거가 아니다. [경로 보수 계획](superpowers/plans/2026-09-08-hide-route-rejection.md)과 WORK_LOG의 최신 항목을 우선한다.

- 2026-09-08 후속 공개 반영: PR #7 main `28c4f3c`의 Pages run `34136015665` build·deploy 성공. 공개 11개 경로, 이미지 8/8 해시, 최신 Chapter 2/3 내용·예제 출처와 진단 문서의 223/223 실행 증거를 확인했다. 코드·자동 테스트·DocC 공개는 완료이며, 아래 실제 LiDAR 시각 수용만 미완료다.

- 2026-09-07 최신 실기기 자동 회귀: 연결 요청을 반복하지 않은 상태에서 paired iPhone이 사용 가능해져 read-only 잠금·DDI 확인 후 전체 테스트를 실행했다. 222개 실행에서 발견한 자막 종료의 background publishing 경고는 실제 `SCNView` 회귀 RED 뒤 완료 queue를 `.main`으로 지정해 보수했다. 수정 뒤 iPhone 16 Pro/iOS 26.6.1 **223/223 통과·실패/skip 0**, 같은 로그에서 해당 경고 미관찰, Swift 5·Swift 6 strict generic iPhoneOS build exit 0이다. 아래 과거 기록의 222개·190개 실행 대기는 해소됐지만 **실제 LiDAR 시야·스캔·숨기/찾기·캡처는 여전히 미완료**다. Simulator나 기기 설정 변경은 없었다.

### 이전 체크포인트 — 최신 실행 상태는 위 항목을 우선

- 2026-09-07 DocC 추가 개선: 네 챕터의 실제 학습 제목·안내, 현재 스캔/측면 이동/복구 설명과 독립 예제 12개, 새 세로 화면 컨셉 4개를 정합화했다. 문서 및 최종 통합 검토, content 12/12·경고 없는 archive·이미지 8개 검증·44회 브라우저 렌더·내부 링크 100개가 통과했다. PR #5의 main `b03d27b`를 Pages run `34131852587`로 배포했고, 공개 11개 경로와 이미지 8/8 해시·최신 Chapter 2/3 문구·예제 출처·브라우저 표시를 확인했다. 실제 화면 이미지는 촬영 증거가 아닌 컨셉으로 명시한다.

- 2026-09-07 추가 사용성 범위: [AR 개선 명세](superpowers/specs/2026-09-07-ar-usability-polish.md)에 따라 작은 HUD/학습 sheet, 실제 4Hz 메시·바닥·추적 snapshot, 측정된 옆면 preview, 몸통 convex cast를 통과한 측면 경로와 scene update 기반 이동을 추가했다. 불안정 tracking은 가림/발견 입력에서 무효화하고 학습·비활성화 수명을 보수했다. 이번 순수 정책 runtime은 48/48, iPhoneOS compile/link 기준 테스트 inventory는 222개다. 전체 222개 iPhone runtime·실제 LiDAR 시각 확인은 실행하지 않았다. 사용자가 현재 기기 연결이 어렵다고 답했으므로 기기 연결을 재요청하거나 Simulator로 대체하지 않는다. DocC/이미지/Pages 동기화는 완료했으며 아래 190개·기기 잠금 기록은 9월 3일 기준선이다.

- 자동 검증: 현재 worktree에는 정적 집계상 190개 XCTest가 있다. `2c4d854` 기준 physical focused 4/4와 full suite 186/186은 exit 0으로 통과했다. 이후 Chapter 1 Reduce Motion 2개와 C3 cancellation handle의 compile-time Sendable·실제 coordinator deinit 취소 회귀 2개를 추가했다. 현재 Swift 5와 Swift 6 strict의 fresh generic iPhoneOS `build-for-testing`은 모두 exit 0이지만, 최신 read-only 잠금 상태가 `passcodeRequired: true`라 새 4개를 포함한 runtime은 이번 범위에서 0건이다. Task 9의 UI test target·launch fixture·XCUITest는 명시적 no-Simulator 범위에 따라 계속 보류한다.
- 언어 모드: 프로젝트 설정은 Swift 5를 유지한다. `C3AutoDiscoveryCancellable`이 checked `Sendable` 계약을 가지며 immutable `Task<Void, Never>` production wrapper와 nonisolated `deinit` 정리를 함께 보존한다. 2026-09-03 fresh generic iPhoneOS Swift 6 strict app·unit-test bundle compile/link가 exit 0이므로 이 preparation diagnostic은 닫혔지만 프로젝트 언어 모드를 Swift 6으로 전환한 것은 아니다.
- 실기기 검증: 최신 read-only 확인은 paired physical iPhone 16 Pro(iPhone17,1), iOS 26.6, Developer Mode·DDI usable을 확인했지만 현재 `passcodeRequired: true`다. 잠금 우회 없이 focused 실행을 생략했으므로 이번 Task 9 runtime은 0건이며, 기준 186/186만 유효하다. 사용자 상호작용이나 capture가 없으므로 visual/LiDAR acceptance는 주장하지 않는다. 카메라 권한·Settings 복구, 0.18m 크기, 다섯 점 LiDAR mesh 가림, 0.15m/15° 이동 재발견, replay와 증거 스크린샷은 여전히 `실기기 대기`다.

## C3 참고 원본

`/Users/yang-eunseo/Downloads/C3_Piggy/C3_Piggy`의 월드 표현을 참고했다. 지정된 C3 에셋은 바이트 변경 없이 앱 리소스에 두며, 재사용 범위는 섬·나무·돼지 포즈·궤도 카메라·조명·장식 배치다. 금융과 Watch 기능은 의도적으로 가져오지 않는다.
