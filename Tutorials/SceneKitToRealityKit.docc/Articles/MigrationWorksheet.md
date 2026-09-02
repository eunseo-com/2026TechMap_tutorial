# SceneKit에서 RealityKit으로 — 세계관 번역 워크시트

마이그레이션은 API 이름을 일대일로 치환하는 작업이 아니다. 기존 기능이 어떤 세계를 전제로 하고, 좌표와 앞뒤 관계를 어디서 얻으며, 누가 수명을 책임지는지 먼저 적어야 한다.

## 네 축으로 현재 구현 읽기

비교 순서는 앱의 비교 화면과 같은 `world`, `coordinates`, `visibility`, `responsibilities`다.

| 축 | SceneKit closed world | RealityKit·ARKit reality connection | 옮기기 전 질문 |
| --- | --- | --- | --- |
| `world` | 개발자가 `SCNScene`과 노드를 구성한다 | ARKit이 camera·plane·mesh를 관찰하고 RealityKit scene이 virtual content와 함께 사용한다 | 세계의 사실이 에셋에 있는가, 매번 달라지는 실제 공간에 있는가? |
| `coordinates` | scene 원점과 부모 `SCNNode` transform이 기준이다 | tracking world transform과 유효한 anchor·floor region이 기준이다 | hardcoded local 좌표를 어떤 관찰 snapshot으로 바꿀 것인가? |
| `visibility` | 선언한 geometry와 camera의 depth 관계가 결정한다 | 선언한 Entity에 더해 ARKit이 관찰한 실제 mesh가 occlusion에 참여한다 | 보이지 않음을 한 ray가 아니라 어떤 안정 조건으로 판정할 것인가? |
| `responsibilities` | 한 `SCNNode`가 geometry·physics·action과 계층을 함께 다룰 수 있다 | Entity·Component·System, coordinator와 순수 정책에 책임을 나눈다 | framework object, 규칙, 수명 정리를 어디에 둘 것인가? |

SceneKit에서 현실 공간을 쓰려면 ARKit을 명시적으로 연결하고 좌표·anchor·rendering 경계를 설계해야 한다. RealityKit 역시 raw sensor semantic을 스스로 발명하지 않으며 ARKit observation을 사용한다.

## 네 chapter가 고정한 production 계약

| 번호 | Chapter | 경험 계약 | 아직 실기기에서 볼 것 |
| --- | --- | --- | --- |
| 1 | Chapter 1 | narration 전 tap 거부, C3 `HideTree`, 0.40초 one-shot 발견, `1.5배 → 1.0배`, 0.70초 fade | 실제 장면 연출과 handoff 체감 |
| 2 | Chapter 2 | valid-layout session start, mesh AND classified floor readiness, 20초 scan, 10초 interruption, CTA 전 tap 잠금, same-session 전환 | 실제 mesh/floor 진행과 marker |
| 3 | Chapter 3 | 0.18m, 0.90m, floor inset, view-space 5점, hide center+4/5×두 frame, 0.15m/15° latch, reveal center+3/5×두 frame | LiDAR occlusion·reveal·replay |
| 4 | Chapter 4 | 네 비교 축, reason별 정직한 요약, 완료·Chapter 3 재시도·전체 reset | AR teardown과 실제 lifecycle |

## 완료와 우회 진입을 분리하기

`ComparisonEntryReason`은 다음 일곱 경우를 보존한다.

- `completedHide`: 실제 hide·reveal 경로를 끝낸 경우
- `cameraDenied`: 사용자가 카메라 권한을 거부한 경우
- `cameraRestricted`: 시스템 정책으로 카메라를 쓸 수 없는 경우
- `lidarUnavailable`: 필요한 scene reconstruction을 지원하지 않는 경우
- `sessionFailed`: AR session이 실패한 경우
- `scanTimedOut`: mesh와 floor가 제한 시간 안에 모두 준비되지 않은 경우
- `assetFailed`: 돼지 asset을 해당 cycle에서 불러오지 못한 경우

`completedHide`만 성공 체험을 요약한다. 나머지 여섯 reason은 우회 이유, 가능한 복구와 남은 실기기 대기를 함께 보여 줘야 한다.

## 단계별 마이그레이션 워크시트

1. **world inventory** — scene에 선언된 모델과 runtime에 관찰할 실제 공간 데이터를 나눈다.
2. **coordinate authority** — local transform, world transform, anchor와 immutable snapshot 가운데 각 계산의 기준을 적는다.
3. **visibility contract** — rendering occlusion과 게임 성공 판정을 분리하고 sample·frame·deadline 조건을 수치로 정한다.
4. **responsibility map** — Entity/Component/System, coordinator, 순수 policy, UI state가 소유할 일을 나눈다.
5. **lifetime map** — view, session, AR generation, hide cycle과 cancellable callback의 종료 시점을 적는다.
6. **verification split** — type-check·단위 정책·generic build와 실제 기기 관찰 항목을 별도 목록으로 만든다.

## 스스로 답할 질문

- 이 기능은 선언된 3D 장면만으로 충분한가, 실제 공간 관찰이 필요한가?
- camera와 target의 좌표는 어느 시점의 어느 snapshot에서 왔는가?
- 한 frame의 우연한 결과를 성공으로 오해하지 않도록 어떤 연속 조건이 필요한가?
- retry가 이전 anchor·task·callback을 남기지 않는가?
- 권한이나 기기 조건으로 우회했을 때 실제 체험을 완료한 것처럼 보이지 않는가?
- 자동 검증과 실기기 대기를 명시적으로 나누었는가?

## 현재 검증 경계

문서 source와 snippet type-check, generic iPhoneOS build, local DocC convert가 성공하더라도 실제 배포와 LiDAR 경험이 완료된 것은 아니다. 실제 크기·floor fit·scan 표시·4/5 hide·3/5 reveal·replay·before/after 증거는 모두 실기기 대기이며, 공개 route·언어·theme·desktop/mobile 접근성은 후속 배포 검증 범위다.

## 관련 문서

- <doc:01-ClosedWorld>
- <doc:02-OpeningTheDoor>
- <doc:03-RealHideAndSeek>
- <doc:04-Comparison>
- <doc:SceneGraphDeepDive>
- <doc:RealityKitECS>
- <doc:DeviceCameraDiagnostics>
