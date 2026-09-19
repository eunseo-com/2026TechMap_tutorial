# 2026TechMap_tutorial

SceneKit에서 RealityKit으로 넘어가는 이유를 이야기형 DocC 튜토리얼로 풀어내는 2026 TechMap 프로젝트입니다.

[튜토리얼 따라 하기](https://eunseo-com.github.io/2026TechMap_tutorial/)에서 새 Xcode 앱을 만들고 네 장을 차례로 진행할 수 있습니다. 기본 실습은 `ContentView.swift` 하나를 고치며, 장별 준비 파일과 정답을 내려받습니다.

본편 앱과 심화 해설은 다음 네 장으로 구성됩니다.

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

초보자 실습의 원본은 [Guides/SceneKitToRealityKit.docc](Guides/SceneKitToRealityKit.docc)입니다. 본편 앱을 설명하는 기존 [Tutorials/SceneKitToRealityKit.docc](Tutorials/SceneKitToRealityKit.docc)와 심화 문서도 보존합니다. Xcode가 설치된 macOS에서는 아래 명령으로 GitHub Pages용 정적 아카이브를 만들 수 있습니다.

```bash
bash scripts/build-docc-site.sh /tmp/SceneKitToRealityKit.doccarchive
bash scripts/verify-docc-site.sh /tmp/SceneKitToRealityKit.doccarchive
```

렌더링 검증은 Node.js 24 이상과 lockfile에 고정된 Playwright·axe를 사용합니다. 첫 실행에서 해당 Playwright 버전에 맞는 Chromium을 한 번 설치한 뒤, 로컬 정적 서버에서 11개 공개 경로를 데스크톱과 390×844 모바일 크기, light와 dark 색상 모드 조합으로 검사합니다.

```bash
npm ci --ignore-scripts
npm exec playwright -- install chromium
npm run test:docc-browser
npm run verify:docc-browser -- /tmp/SceneKitToRealityKit.doccarchive
```

마지막 명령은 각 경로의 정확한 `h1`, root의 tutorial overview 이동, SPA 렌더 뒤 수집한 same-origin 링크의 route·파일·fragment, GitHub Pages식 no-slash 디렉터리 이동까지 확인합니다. 또한 네 렌더 조합 중 console warning/error, 미처리 페이지 오류, 실패한 요청과 HTTP 4xx/5xx, axe의 `serious`·`critical` 위반이 하나라도 있으면 실패합니다. GitHub Pages workflow도 같은 명령을 artifact 업로드 전에 실행합니다.

기본 검증 뒤 아래 명령으로 초보자 읽기 페이지를 합칩니다. 기존에 공유한 튜토리얼·챕터 주소도 새 페이지로 연결합니다.

```bash
bash scripts/build-readable-guide.sh /tmp/SceneKitToRealityKit.doccarchive
python3 tools/tutorial_site/verify.py /tmp/SceneKitToRealityKit.doccarchive --base-path /2026TechMap_tutorial --docc-subdirectory guide
npm run verify:docc-browser -- /tmp/SceneKitToRealityKit.doccarchive tools/tutorial_site/browser-routes.json
```

최종 검증은 21개 경로의 84개 화면 조합과 다운로드·코드 원문·GitHub Pages 경로를 검사합니다. 따라 하기 본문은 사이트 루트와 `/chapters/2/`–`4/`, 해당 DocC 원문은 `/guide/`, 기존 심화 문서는 `/documentation/`에서 제공합니다. 자세한 재생성 절차는 [읽기 페이지 안내](tools/tutorial_site/README.md)를 참고하세요.

`main`의 카탈로그·읽기 페이지 도구 또는 배포 설정 변경은 GitHub Actions에서 정적 파일로 변환되어 기존 GitHub Pages에 공개됩니다.

<https://eunseo-com.github.io/2026TechMap_tutorial/>
