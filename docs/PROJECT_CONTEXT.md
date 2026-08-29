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

- 자동 검증: 현재 HEAD에는 정적 집계상 112개 XCTest가 있으나 최신 변경 뒤 전체 실행 근거는 아직 없다. 구현 계획의 첫 기준선과 최종 게이트에서 실제 실행 수·`TEST SUCCEEDED`, Debug/Release build, DocC와 snippet 검증을 새로 기록한다.
- 언어 모드: 현재 일반 Simulator build는 설정된 Swift 5 모드에서 성공했다. Swift 6 strict concurrency는 알려진 격리 오류가 있으므로 지원 완료로 주장하지 않는다.
- 실기기 검증: 카메라 권한·Settings 복구, 0.18m 크기, 다섯 점 LiDAR mesh 가림, 0.15m/15° 이동 재발견, replay와 증거 스크린샷은 관찰 전까지 `실기기 대기`다. 자동 테스트나 Simulator 결과로 대체하지 않는다.

## C3 참고 원본

`/Users/yang-eunseo/Downloads/C3_Piggy/C3_Piggy`의 월드 표현을 참고했다. 지정된 C3 에셋은 바이트 변경 없이 앱 리소스에 두며, 재사용 범위는 섬·나무·돼지 포즈·궤도 카메라·조명·장식 배치다. 금융과 Watch 기능은 의도적으로 가져오지 않는다.
