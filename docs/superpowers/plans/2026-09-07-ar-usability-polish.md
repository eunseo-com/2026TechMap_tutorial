# AR 사용성 개선 실행 기록

기준: `2026-09-07-ar-usability-polish.md`, branch `codex/ar-usability-polish`, 시작 commit `e7b5e88`.

- [x] 1. 작은 AR HUD와 펼쳐 보는 학습 sheet, 실제 4Hz scan telemetry, 중복 frame·추적 복구 정책 및 테스트
- [x] 2. 선택 전 실시간 실제 표면 preview와 actionable rejection, 탭 재검증·학습 sheet 수명
- [x] 3. 물체 옆 경로·메시 충돌 검사, 제자리 회전/scene-time 이동·종료/취소, 경로 및 통합 회귀 추가
- [x] 4. 앱과 같은 흐름의 DocC 설명·코드·용어·개선 이미지, 학습 관찰/복구 순서
- [ ] 5. iPhoneOS 빌드·정책 runtime·DocC/Pages gate·리뷰 후 main 통합·공개 배포
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
