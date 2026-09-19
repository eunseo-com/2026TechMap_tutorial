# GitHub Pages 초보자 튜토리얼 게시

## 범위와 배포 대상

기존 공개 사이트 `https://eunseo-com.github.io/2026TechMap_tutorial/`를 2026-09-19에 작성·검증한 초보자 실습 네 장으로 갱신한다. 2026-09-20 후속 요청은 이 GitHub Pages의 교체를 지정했다. 별도 소유자 전용 호스팅 주소는 주 배포 대상이 아니다.

원격 main에는 본편 앱과 심화 해설의 후속 변경이 있다. main에서 분리한 작업 공간에 입문 실습만 가져오며, 이전 로컬 앱 브랜치를 통째로 병합하지 않는다. 입문 원문·예제·다운로드·이미지는 `Guides/SceneKitToRealityKit.docc`에 보존한다. 본편 앱 소스와 `Tutorials/SceneKitToRealityKit.docc`는 변경하지 않는다.

## 공개 경로

| 저장소 이름 뒤의 경로 | 내용 |
| --- | --- |
| `/` | 1장: 돼지를 소파 뒤로 움직여 보기 |
| `/chapters/2/` | 2장: 내 방 바닥에 돼지 놓기 |
| `/chapters/3/` | 3장: 상자 뒤에 돼지 숨기기 |
| `/chapters/4/` | 4장: 움직이는 돼지 멈추기 |
| `/guide/tutorials/scenekittorealitykit/` | 입문 실습의 DocC 원문·선택 학습 |
| `/guide/downloads/com.techmap.scenekittorealitykit/` | 다섯 실습 ZIP |
| `/documentation/scenekittorealitykit/` | 기존 본편 앱 심화 문서 |

예전에 공유한 `/tutorials/scenekittorealitykit/`와 그 아래 네 챕터 주소는 대응하는 새 읽기 페이지로 이동한다. HTML의 일반 링크와 meta refresh를 제공해 JavaScript가 꺼져 있어도 이동할 수 있다.

## 빌드·검증

1. 기존 본편 해설의 content gate, 12개 독립 예제 타입 검사, DocC 변환, 이미지·경로·접근성 검증을 수행한다.
2. `scripts/build-readable-guide.sh`가 입문 카탈로그를 `/2026TechMap_tutorial/guide` 경로로 변환한다. 읽기 페이지는 `/2026TechMap_tutorial` 경로를 사용한다.
3. 렌더러는 URL 속성에만 경로를 붙인다. Swift 원문은 변경하지 않는다. 두 카탈로그의 JSON·이미지가 충돌하지 않도록 입문 아카이브는 `guide/`에 둔다.
4. `tools/tutorial_site/verify.py`가 17개 실습 구간의 SDK 검사, 왕복 이동 계산 7건, 다섯 ZIP, 13개 HTML 코드 블록·복사 대상·링크·목차를 확인한다.
5. 기존 브라우저 검증기의 오류 감지 테스트 13건과 최종 21개 경로를 데스크톱·모바일 및 두 색상 모드에서 검사한다. 제목·리디렉션·내부 링크·누락 자산·접근성 오류가 배포를 막는다.
6. 기존 Pages workflow가 검증한 정적 산출물을 게시한다. 생성 아카이브는 Git에 추가하지 않는다.

## 남은 확인

실제 초보 독자의 무도움 완주·소요 시간과 2·3장의 실물 AR 관찰은 별도다. SDK·웹 검사나 게시 성공은 이를 대신하지 않는다. 최신 게시 결과와 실행 근거는 `WORK_LOG.md`에 기록한다.

## 게시 결과

2026-09-20 [PR #10](https://github.com/eunseo-com/2026TechMap_tutorial/pull/10), main `e6502e2`, [Pages 실행 35456178708](https://github.com/eunseo-com/2026TechMap_tutorial/actions/runs/35456178708)의 build·deploy 성공. 공개 21개 경로 HTTP 200, 네 읽기 페이지 제목, 5개 ZIP 원본 해시, 최신 CSS/JS, 기존 주소 이동과 실제 첫 화면을 확인했다.
