# 앱 화면 컨셉 이미지 — 2026-09-07

모드: 내장 이미지 생성 도구의 기존 이미지 편집. 실제 앱 실행 화면/실기기 캡처가 아닌 설명용 컨셉이다.
기존 네 가로 챕터 그림은 보존하고, 네 세로 화면의 빈 UI를 코드에 있는 문구와 작은 안내로 교체한다.
카메라 장면, 크기, 메시·가림은 예시이며 실측 증거가 아니다. 최종 이미지 검토와 채택 여부는 아래에 기록한다.

## 채택 결과

네 화면 모두 1024×1536 PNG이며 기존 세로 이미지 경로에 저장했다. 원 생성물은 그대로 보존했다.
한글 문구, 낮은 설명창, 작은 돼지, 바닥 채움 제거, 비교 카드 두 축과 세 CTA를 눈으로 확인했다.
진행 표시의 모양·위치, 서체·줄바꿈, 방의 생김새는 구현을 설명하기 위한 재구성으로 픽셀 단위 일치가 아니다.
Chapter 4의 완료 문구는 정상 완료 경로의 **화면 예시**이며 실제 기기 검증 완료를 뜻하지 않는다.
Chapter 3의 보이는 돼지 일부는 찾는 장면의 개념 표현으로 4/5 가림·3/5 발견 기준을 측정한 증거가 아니다.

| 챕터 | 프로젝트 저장 경로 | SHA-256 |
| --- | --- | --- |
| 1 | `Tutorials/SceneKitToRealityKit.docc/Resources/app-screen-chapter-1-closed-world.png` | `7c1e109d2295516eff624cc7b997649841106ecbf7e4b4a439f5bf2929e4562b` |
| 2 | `Tutorials/SceneKitToRealityKit.docc/Resources/app-screen-chapter-2-scanning.png` | `b58047bf3a1099f21c43a5f14d4f3ba93cd25279757d7f6dae5e2ce0d168c372` |
| 3 | `Tutorials/SceneKitToRealityKit.docc/Resources/app-screen-chapter-3-searching.png` | `1b77ea6f2f3325cbdbe4666a4ec361a627ac7900f9cf31e55056edbe583be68a` |
| 4 | `Tutorials/SceneKitToRealityKit.docc/Resources/app-screen-chapter-4-comparison.png` | `b316972dc9d3ddceba0dc60d1a7f2e631a8f4a88401d81281aa089a1243457d2` |

## Chapter 1

Use case: ui-mockup. Asset: polished Korean iOS educational app screen CONCEPT for Chapter 1 of a SceneKit/RealityKit tutorial. Edit target: supplied portrait image. Preserve its beautiful low-poly floating island, blue sky, green tree, flowers and gentle sunlight. Output portrait 1024x1536, no phone frame. Replace ALL blank placeholder UI. Top LEFT small black 76%-opaque capsule with white semibold exact text "1/4 · 닫힌 세계" and four TINY 9x4-like progress ticks inside, only first yellow. Top right small black circular question-mark help button. Keep upper UI within 8% of image height. Put small gray low-poly pig on the grass beside the tree, fully visible, height about one fifth of the trunk, not huge. Remove huge bottom blank panel. In its place at y around 82% a low black translucent rounded caption, height only 5% of image, with white readable Korean exact text "아, 나 좀 그만 쳐다보지. 나 숨고 싶어…". No other text. Refined crisp Korean typography, no faux text lines, no broad progress bar, no scan mesh, no dotted routes, no invented buttons or labels. Preserve the reference's illustrated atmosphere. Scene stays dominant and unobstructed. This is illustrative UI not a device capture.

## Chapter 2

Use case: ui-mockup. Asset: polished Korean iOS AR-scanning tutorial screen CONCEPT. Edit target: supplied portrait image. Preserve the warm low-poly living room, sofa, lamp, wooden floor and sunlight. Portrait 1024x1536 no phone frame. Replace all current UI and the dense scan visualization. Top LEFT small black 76%-opaque capsule, white semibold exact text "2/4 · 현실 열기", four TINY progress ticks inside only first two yellow. Top RIGHT small black circle with white question mark. Immediately below header two SMALL dark chips: mint check + exact text "공간 12개 영역"; mint check + "바닥 확인됨". UI top combined <=10% height. The central camera room must be clearly visible: sparse thin cyan triangle EDGES on limited measured sofa/wall patches, sparse thin yellow triangle EDGES on some floor patches, no filled polygons, no yellow carpet fill, no lattice covering entire room, no glowing nodes. Keep most surfaces unobstructed. No pig in Chapter 2. Bottom small dark rounded guidance bar of 4% height with white exact text "바닥과 공간을 찾았어. 준비되면 시작해줘." Then yellow rounded primary button below of 5% height, black exact text "숨바꼭질 시작". Keep bottom group within10% height with margin. Crisp accurate Korean, comfortable margins. No fake labels identifying furniture, no scan percentage, no giant panels, no dummy lines, no invented controls. This is an illustration of measured surface feedback, not an actual AR scan.

## Chapter 3

Use case: ui-mockup. Asset: polished Korean iOS AR hide-and-seek tutorial screen CONCEPT. Edit target: supplied portrait image. Preserve the beautiful warm low-poly living room with sofa arm, lamp, wood floor, small gray pig partly visible from behind the left edge of sofa. Pig stays very small relative to sofa, about 18cm against 80cm sofa, never fills camera; do not enlarge it. Portrait 1024x1536, no phone frame. Replace ALL existing blank UI with compact real app guidance. Top LEFT small black 76%-opaque capsule, exact white Korean label "3/4 · 현실 숨바꼭질", with four TINY progress ticks inside first three yellow. Top RIGHT black circular white question-mark help button. No giant top bar. Bottom dark translucent rounded guidance card only6% image height, modest left/right margins, exact Korean in two readable lines: "옆으로 움직이거나 카메라 방향을 바꿔" and "피기를 찾아봐." The middle90% of room remains visually open. No route line, no reticle in searching phase, no scan mesh, no arrows, no discovery button, no percentage, no object bounding boxes, no placeholder text lines. Crisp accurate Korean typography. This is a UI illustration after hiding while searching, not proof of actual five-point occlusion.

## Chapter 4

Use case: ui-mockup. Asset: polished Korean iOS tutorial Chapter 4 comparison screen CONCEPT. Edit target: supplied portrait image; preserve deep navy-to-teal palette, yellow CTA, blue SceneKit/mint RealityKit comparison accents, but replace all blank skeleton bars with legible accurate interface and simplify layout. Portrait1024x1536 no phone frame. Top left small black capsule exact "4/4 · 두 세계 비교" and four TINY yellow progress ticks, top right question-mark circle. Main left-aligned content below: small gold "CHAPTER 4 · COMPARISON"; bold white title "두 세계의 책임을 비교해봐"; smaller white subtitle "같은 피기를 움직여도 세계, 좌표, 앞뒤 관계를 만드는 주체는 달라." Rounded dark teal summary with mint check, title "현실 숨바꼭질을 끝냈어", supporting copy "실제 물체 뒤로 숨기고, 직접 움직여 피기를 다시 찾는 흐름까지 완료했어." Next two dark rounded comparison cards, each question then TWO SIDE-BY-SIDE answer panels: first question "세계를 어디서 얻는가?", blue label "SCENEKIT · 닫힌 세계" answer "개발자가 노드와 좌표로 구성한다.", mint label "REALITYKIT · 현실 연결" answer "AR session이 관찰한 현실 공간을 함께 사용한다."; second question "위치의 기준은 무엇인가?", same labels, respective answers "장면 원점과 부모 노드가 기준이다." and "현실의 추적 좌표와 anchor가 기준이다." Generous readable text, not tiny cramped. Remaining questions are offscreen scroll content, do not cram extra cards. Bottom dark fixed action area with THREE full-width buttons stacked vertically: yellow primary black text "튜토리얼 완료"; outlined secondary white "Chapter 3 다시 하기"; subdued tertiary white "처음부터 다시 보기". No dummy blank lines, no decorative charts, no invented metrics. This illustrates completed-route design, not verified device completion.
