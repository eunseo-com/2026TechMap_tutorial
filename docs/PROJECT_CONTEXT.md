# 프로젝트 컨텍스트

> 이 문서는 저장소를 함께 다루는 작업자의 공통 시작점이다. 로컬 대화 기록이 아니라, 이 문서와 `docs/WORK_LOG.md`·설계·실행 계획의 Git 추적 상태를 기준으로 작업한다.

## 현재 승인 범위

- 범위: Chapter 1 `ClosedWorld`의 **C3 월드에서 RealityKit 현실 세계로 탈출하기** 경험.
- 기준선: 기존 방·가짜 소파 구현을 담은 Draft PR은 참고 기준선으로 보존한다. 현재 작업 브랜치는 그 기준선 위에서 C3 섬과 실제 물체 뒤 숨기를 추가한다.
- 진입 화면: `ContentView`는 `EscapeRootView`만 시작한다. 예전 `ClosedWorldSceneView`·`FakeSofa`는 참고 코드로 컴파일되지만 현재 경험을 시작하지 않는다.
- 제외: 금융 상태, SwiftData 저장, 용돈·작은 돼지, WatchConnectivity, Watch UI, Chapter 2 이후 구현.

## 경험 계약

1. SceneKit의 C3 섬에서 돼지가 “아, 나 좀 그만 쳐다보지. 나 숨고 싶어…”라고 말한다.
2. 나레이션이 끝난 뒤 돼지를 탭하면 `Piggy_running`으로 기존 `Cylinder_Tree` 뒤를 향해 걷는다.
3. 카메라 yaw 변화와 실제 프러스텀 조건이 함께 충족되면 `Piggy_surprised`·“아, 들켰네… 제대로 숨고 싶은데.”·1.5배 후 1.0배 복귀가 한 번 실행된다.
4. 0.70초 페이드 뒤에만 시스템 카메라 권한을 요청한다. 허용되면 RealityKit AR 화면으로 자동 전환한다.
5. LiDAR 지원 기기에서 사용자가 실제 물체의 수직 옆면을 탭하면 돼지는 카메라 반대편 바닥으로 이동한다. 실제 재구성 메쉬가 돼지를 가리고, 사용자가 물리적으로 이동해 다시 볼 때 같은 놀람 반응과 화면 1.12배 후 1.0배 복귀가 한 번 실행된다.

정확한 상태 전이·수치·에셋 경계는 [설계 명세](superpowers/specs/2026-08-10-ch1-reality-escape-design.md)와 [실행 계획](superpowers/plans/2026-08-10-ch1-reality-escape-implementation.md)을 우선한다.

## 시작 순서와 협업 규칙

1. 이 문서
2. `docs/WORK_LOG.md`
3. `씬킷에서_리얼리티킷으로_컨셉노트.md` (현재 브랜치에 없으면 부재 사실을 `docs/LEARNING_LOG.md`에 기록하고 승인된 설계 명세를 대체 근거로 사용)
4. 관련 설계 명세와 실행 계획

구현 전에는 `git fetch --prune origin`, `git status --short` 순서로 상태를 확인한다. 권한·환경 문제로 명령이 실패하면 재시도나 보류 전에 `docs/LEARNING_LOG.md`에 재현·관찰·영향을 기록한다. 다른 작업자가 만들었거나 추적하지 않은 파일은 요청 없이 이동·삭제·스테이징하지 않는다.

의사결정, 검증 결과, 남은 위험, 다음 시작점은 `docs/WORK_LOG.md`에 결과물과 같은 커밋으로 기록한다. 실패·예상 밖 동작·실기기 한계는 `docs/LEARNING_LOG.md`에 남긴다. `.claude/`와 대용량 C3 참고 사본은 로컬 참고물이며 추적하지 않는다.

커밋·PR에는 작업자·도구·모델·AI 생성 표기와 `Co-Authored-By`를 넣지 않는다. 생성된 Xcode 프로젝트, DerivedData, `/tmp` 산출물은 추적하지 않는다.

## 검증 상태

- 자동 검증: Task 8에서 명시적인 `xcodebuild` 전체 XCTest, Simulator build, DocC build를 새로 실행해 `docs/WORK_LOG.md`에 실제 결과를 기록한다.
- 실기기 검증: 카메라 권한 문구·허용/거부·Settings 복구, C3 탭/카메라 발견, LiDAR 메쉬 오클루전, 실제 이동 재발견, 1.5배 돼지·1.12배 화면 반응은 관찰 전까지 `실기기 대기`다. 자동 테스트나 Simulator 결과로 대체하지 않는다.

## C3 참고 원본

`/Users/yang-eunseo/Downloads/C3_Piggy/C3_Piggy`의 월드 표현을 참고했다. 지정된 C3 에셋은 바이트 변경 없이 앱 리소스에 두며, 재사용 범위는 섬·나무·돼지 포즈·궤도 카메라·조명·장식 배치다. 금융과 Watch 기능은 의도적으로 가져오지 않는다.
