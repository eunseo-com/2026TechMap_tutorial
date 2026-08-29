# DocC GitHub Pages 배포 설계

## 사용자 지시와 범위

사용자 요청에 따라 Chapter 1의 검증된 DocC 카탈로그를 앱 구현 순서보다 먼저 이 저장소에서 공개한다. 현재 내용은 `ClosedWorld` 한 챕터만 포함하며, Chapter 2~4를 추가하지 않는다.

## 정적 배포 경계

- DocC 변환 결과인 HTML·CSS·JavaScript·JSON·이미지 파일만 GitHub Pages에 제공한다.
- 배포 환경에서 Swift 앱이나 Node 서버는 실행하지 않는다.
- 원본 카탈로그와 빌드 스크립트는 Git으로 추적하고, 변환 산출물은 GitHub Actions 아티팩트로만 전달한다.

## 파일과 경로 계약

- 원본 카탈로그: `Tutorials/SceneKitToRealityKit.docc`
- 빌드 명령: `scripts/build-docc-site.sh [output-path]`
- 공개 주소: `https://eunseo-com.github.io/2026TechMap_tutorial/`
- `docc convert`는 프로젝트 페이지 하위 경로에서 리소스가 깨지지 않도록 `--hosting-base-path /2026TechMap_tutorial`을 사용한다.
- 루트 주소는 `Web/index.html`로 `tutorials/scenekittorealitykit/`에 이동시킨다. 튜토리얼 전용 DocC 카탈로그의 일반 루트가 표시하는 찾을 수 없음 화면을 공개 시작 화면으로 사용하지 않는다.

## 배포 계약

- `.github/workflows/deploy-docc.yml`은 `main`의 DocC와 배포 설정 변경, 또는 수동 실행에 반응한다.
- DocC 변환은 Xcode가 포함된 macOS runner에서 수행한다.
- 작업은 루트 HTML과 튜토리얼 JSON이 생성됐는지 검사한 뒤 GitHub Pages 아티팩트를 배포한다.
- GitHub Pages의 Source는 GitHub Actions로 설정한다.
