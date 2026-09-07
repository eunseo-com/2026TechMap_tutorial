# AR 사용성 개선 실행 기록

기준: `2026-09-07-ar-usability-polish.md`, branch `codex/ar-usability-polish`, 시작 commit `e7b5e88`.

- [x] 1. 작은 AR HUD와 펼쳐 보는 학습 sheet, 실제 4Hz scan telemetry, 중복 frame·추적 복구 정책 및 테스트
- [x] 2. 선택 전 실시간 실제 표면 preview와 actionable rejection, 탭 재검증·학습 sheet 수명
- [x] 3. 물체 옆 경로·메시 충돌 검사, 제자리 회전/scene-time 이동·종료/취소, 경로 및 통합 회귀 추가
- [x] 4. 앱과 같은 흐름의 DocC 설명·코드·용어·개선 이미지, 학습 관찰/복구 순서
- [x] 5. iPhoneOS 빌드·정책 runtime·DocC/Pages gate·리뷰 후 main 통합·공개 배포
- [ ] 6. LiDAR 실기기에서 카메라 시야·실시간 관찰·숨기/찾기/replay 및 실제 전후 캡처

실기기 연결 전에도 1–5를 진행한다. 정책 runtime 통과를 LiDAR 관찰 증거로 간주하지 않는다.

## 2026-09-07 앱 체크포인트

1–3의 체크는 **코드 구현·순수 정책 runtime·iPhoneOS 컴파일** 기준이다. 실제 UI/AR integration assertions와 시각 수용은 6의 실기기 대기이며, 앱 동작을 완벽하게 검증했다는 뜻이 아니다.

- `bash scripts/test-reality-policies.sh`: 48 XCTest 실행, 0 failures. telemetry/preview/route/timeline와 기존 다섯 점 가림·이동 재발견 정책의 실제 production Swift를 실행했다.
- generic iPhoneOS app·unit test bundle Swift 5 build-for-testing exit 0. 현재 테스트 정적 inventory 222개이며 이 전체를 이번에 실행한 것은 아니다.
- 같은 222개 bundle의 Swift 6 strict preparation도 exit 0이다. Swift 5 프로젝트 설정은 유지한다.
- 별도 코드 검토에서 확인한 학습 창 뒤 콜백·불안정 tracking 관찰·C3 busy 누락·가로 안내 clipping을 보수했다. 체크포인트 이후 같은 회귀의 실기기 실행은 대기한다.
- 다음은 공개 DocC의 `showSceneUnderstanding` 설명·기존 빈 UI 컨셉 그림·코드 예제를 새 시야/스캔/측면 경로와 일치시키는 4번이다. 아직 공개 사이트를 갱신하지 않았다.

## 2026-09-07 문서 체크포인트

4번은 네 챕터 학습 제목·공통 안내와 현재 앱 동작을 연결하고, 독립 예제 12개·새 세로 컨셉 이미지 4개·보존한 가로 그림 4개의 통합으로 완료했다. 문서 검토에서 발견한 학습 용어 불일치를 수정하고 재검토를 통과했다. 이미지 교체에 필요한 content gate의 네 해시 변경은 통합 범위로 승인했으며, 이미지 파일과 site gate의 별도 소유 범위는 유지했다.

- 최종 content gate: 12/12 예제 typecheck, 금지 패턴 0, 실제 출처 경로·학습 문구 검사 통과.
- archive/site gate: 경고 0, 이미지 8개의 해시·디코딩·원본/산출물 일치 통과.
- 브라우저: 44회 렌더, 내부 링크 100개, no-slash 이동 10개 통과. 검사기 자체의 failure contract도 13/13이다.
- 정책 runtime도 다시 48/48 통과했다. 다음은 최종 통합 검토와 main/Pages 배포이며, 6번의 실제 LiDAR 수용은 여전히 별도 대기다.

## 2026-09-07 공개 반영 체크포인트

최종 통합 검토는 중요 결함 없이 통과했다. PR #5를 main `b03d27b`로 통합한 Pages run `34131852587`의 build·deploy가 모두 성공했다. 공개 11개 경로 HTTP 200, 이미지 8/8 해시 일치, 최신 Chapter 2/3 문구·예제 출처, 실제 브라우저의 소개·스캔 그림·연결 코드를 확인했다. 1–5는 완료이며 **6의 실제 LiDAR 시야·숨기/찾기/replay·캡처 및 최신 222개 iPhone XCTest는 기기 연결 대기**다. 기존 작업 트리와 파일은 이 후속 검증을 위해 보존한다.

## 2026-09-07 실기기 자동 회귀 후속

사용자에게 연결을 다시 요청하지 않은 상태에서 paired iPhone이 local network로 사용 가능해졌다. 잠금 해제·Developer Mode·DDI를 read-only로 확인한 뒤 실제 iPhone에서 전체 222개를 실행했다. 실행 중 자막 종료 callback의 background publishing 경고를 발견해 표시된 `SCNView` 회귀를 먼저 추가했고, 의도한 스레드 assertion RED를 확인한 뒤 완료 queue만 `.main`으로 지정했다.

- 수정 뒤 physical iPhone 16 Pro / iOS 26.6.1 전체 223/223, failed/skipped 0, exit 0. 같은 로그에서 해당 SwiftUI 경고는 관찰되지 않았다.
- 수정 뒤 Swift 5 및 Swift 6 strict generic iPhoneOS app/test build 각각 exit 0. 프로젝트 언어 모드·기기 설정은 변경하지 않았다.
- 위의 최신 전체 XCTest 실행 대기는 해소됐다. **6번의 실제 공간에서 스캔·숨기/찾기/replay를 관찰하고 캡처하는 수용은 계속 미완료**이며, 테스트 성공으로 체크하지 않는다. Simulator는 사용하지 않았다.
- 후속 코드 검토 중요·경미 결함 0. 최신 검증 경계를 반영한 DocC 예제 12/12·경고 없는 archive·이미지/링크·브라우저 44회·내부 링크 100개·no-slash 이동 10개 통과 후 기존 공개 경로에 반영한다.
