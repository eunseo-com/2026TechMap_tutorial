# 작업 인수인계 기록

> 다음 작업을 시작하기 전에 **현재 인수인계**를 먼저 읽는다. 의미 있는 작업 단위가 끝나면 결과물과 같은 커밋에 이 문서를 갱신한다. 사용한 도구나 모델 이름은 쓰지 않는다.

## 현재 인수인계

- 상태: Chapter 1 구현·DocC 카탈로그 완료, Draft PR의 최종 보완 대기
- 진행 중 범위: Chapter 1 `ClosedWorld` 구현과 DocC 카탈로그(Task 1~8)를 완료했다. 최종 검토에서 확인한 보완 항목을 별도 커밋으로 처리한 뒤 병합 준비를 마친다.
- 마지막 완료 범위: Task 8 — Chapter 1 DocC 튜토리얼 카탈로그, 5개 현재 소스 스니펫, Tuist 타깃 인식 설정.
- 마지막 검증: `tuist generate --no-open` 성공. `xcodebuild docbuild -project PiggyEscape/PiggyEscape.xcodeproj -scheme PiggyEscape -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/piggyescape-docbuild`가 `.doccarchive`를 만들고 `** BUILD DOCUMENTATION SUCCEEDED **`로 완료했다.
- 다음 시작점: 가짜 소파 바닥 정렬, 실제 장면의 NodeInspector 실행 예시, DocC의 가짜 소파 코드·화면 연결 설명, 공통 인수인계 문서 통합을 보완하고 재검토한다.
- 차단 요소: 없음.

### Task 7에서 해결한 항목

1. **RoomBuilder 바닥 방향** — `Ground_Color`을 X축으로 -90° 회전하고, 변환된 경계를 재서 4×4×0.1m에 맞춘 뒤 바닥면을 y=0에 정렬했다. 회전 전 원본 경계로 스케일하는 실수를 회귀 테스트로 막는다.
2. **돼지 좌표계·바닥 정렬** — `Piggy`도 Blender Z-up 모델이므로 내부 모델에서 Y-up 회전·균일 스케일·바닥 정렬을 수행하고, 바깥 노드는 위치와 액션만 맡게 분리했다.
3. **초기 프레이밍** — 카메라와 너무 가까워 화면 밖으로 밀리던 돼지의 임의 하드코딩 z 좌표를 1에서 0으로 조정했다. 카메라 설정과 `allowsCameraControl`은 계획값을 유지한다.

## 작업 이력

| 날짜 | 작업 범위 | 결과 | 검증 | 다음 시작점 |
| --- | --- | --- | --- | --- |
| 2026-08-10 | Chapter 1 최종 검토 | 가짜 소파 바닥 정렬, 실제 노드 구조 탐구 실행, DocC 단계 완결성, 공통 인수인계 문서 통합의 보완 필요를 확인 | 전체 변경·문서·검증 근거 검토 | 보완 커밋과 재검토 |
| 2026-08-10 | Chapter 1 Task 8 | Chapter 1 DocC 튜토리얼 카탈로그와 현재 구현을 반영한 5개 코드 스니펫을 추가하고 앱 타깃에 등록함 | `tuist generate --no-open` 성공, `xcodebuild docbuild`가 `.doccarchive`를 생성하고 성공으로 완료 | Chapter 1 결과물 검토 또는 다음 챕터 설계 |
| 2026-08-10 | Chapter 1 Task 7 최종 재검토 | 구현·변환·카메라·인터랙션 회귀 검토를 마침. 생성물 제외 규칙과 테스트 추적 상태를 보완함 | 26/26 테스트 통과 결과와 변경 내용을 재검토 | Task 8 |
| 2026-08-10 | Chapter 1 Task 7 보정·재검증 | Blender 좌표계 보정으로 바닥·돼지를 방 바닥에 맞추고, 초기 프레임에 돼지를 표시. Task 7 탭 연결 테스트 추가 | `tuist generate --no-open`, `xcodebuild ... build` 성공, `xcodebuild ... test` 26/26 통과, Simulator 장면 확인 | Task 7 최종 재검토·커밋 후 Task 8 |
| 2026-08-10 | Chapter 1 Task 1~6 | Tuist 스캐폴드부터 HideAction까지 완료, 태스크마다 검토·필요 시 수정 라운드 거침 | 각 태스크 `xcodebuild test` 통과, 태스크별 검토 승인 | Task 7 |
| 2026-08-10 | Chapter 1 Task 7 (진행 중) | SwiftUI 화면 연결, 가짜 소파 스케일 버그와 `pointOfView` 누락 버그 발견·수정, 공용 지오메트리 헬퍼 분리 | `xcodebuild test` 23/23 통과. 위 3개 미해결 항목은 미검증 | 미해결 항목 처리 후 Task 7 완료, 이어서 Task 8 |

## 기록 형식

새 항목은 작업 이력 표의 첫 행에 추가한다. 각 항목에는 아래 정보만 기록한다.

- 날짜
- 작업 범위
- 결과
- 검증 근거
- 다음 시작점

기록에 사람·도구·모델 이름, 대화 내용, 비밀 정보는 넣지 않는다.
