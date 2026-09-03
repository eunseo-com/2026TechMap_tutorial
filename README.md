# 2026TechMap_tutorial

SceneKit에서 RealityKit으로 넘어가는 이유를 이야기형 DocC 튜토리얼로 풀어내는 2026 TechMap 프로젝트입니다.

현재 카탈로그는 다음 네 장으로 구성됩니다.

1. C3의 닫힌 SceneKit 세계와 가상 카메라
2. 카메라 권한과 AR 세션으로 여는 현실 공간
3. LiDAR 메쉬·수직 면 탭·오클루전으로 실제 물체 뒤에 숨기
4. 노드 세계와 Entity–Component–System(ECS) 사고방식 비교

Chapter 3의 실제 가구 가림과 재발견은 LiDAR 지원 실기기에서 직접 확인해야 합니다. Simulator의 빌드·테스트 통과만으로 이를 대신하지 않습니다.

## 시작하기

- 작업 맥락과 현재 진행 상태: [docs/PROJECT_CONTEXT.md](docs/PROJECT_CONTEXT.md)
- 전체 이야기와 의도: [씬킷에서_리얼리티킷으로_컨셉노트.md](씬킷에서_리얼리티킷으로_컨셉노트.md)
- 승인된 4개 챕터 설계: [four-chapter experience and DocC design](docs/superpowers/specs/2026-08-29-four-chapter-experience-and-docc-design.md)
- 승인된 13-태스크 구현 계획: [four-chapter experience and DocC implementation plan](docs/superpowers/plans/2026-08-29-four-chapter-experience-and-docc-implementation.md)

Claude와 Codex를 포함한 작업자는 [AGENTS.md](AGENTS.md)를 먼저 읽습니다.

## DocC 웹 문서

공개 네 챕터 DocC 카탈로그의 유일한 공개·검증 원본은 [Tutorials/SceneKitToRealityKit.docc](Tutorials/SceneKitToRealityKit.docc)입니다. Xcode가 설치된 macOS에서는 아래 명령으로 GitHub Pages용 정적 아카이브를 만들 수 있습니다.

```bash
bash scripts/build-docc-site.sh /tmp/SceneKitToRealityKit.doccarchive
bash scripts/verify-docc-site.sh /tmp/SceneKitToRealityKit.doccarchive
```

렌더링 검증은 Node.js 20 이상과 lockfile에 고정된 Playwright·axe를 사용합니다. 첫 실행에서 해당 Playwright 버전에 맞는 Chromium을 한 번 설치한 뒤, 로컬 정적 서버에서 11개 공개 경로를 데스크톱과 390×844 모바일 크기, light와 dark 색상 모드 조합으로 검사합니다.

```bash
npm ci --ignore-scripts
npm exec playwright -- install chromium
npm run test:docc-browser
npm run verify:docc-browser -- /tmp/SceneKitToRealityKit.doccarchive
```

마지막 명령은 각 경로의 정확한 `h1`, root의 tutorial overview 이동, SPA 렌더 뒤 수집한 same-origin 링크의 route·파일·fragment, GitHub Pages식 no-slash 디렉터리 이동까지 확인합니다. 또한 네 렌더 조합 중 console warning/error, 미처리 페이지 오류, 실패한 요청과 HTTP 4xx/5xx, axe의 `serious`·`critical` 위반이 하나라도 있으면 실패합니다. GitHub Pages workflow도 같은 명령을 artifact 업로드 전에 실행합니다.

`main`의 카탈로그 또는 배포 설정 변경은 GitHub Actions에서 정적 파일로 변환되어 GitHub Pages에 공개됩니다.

<https://eunseo-com.github.io/2026TechMap_tutorial/>
