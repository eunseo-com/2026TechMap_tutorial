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
- Chapter 1 설계: [ClosedWorld design](docs/superpowers/specs/2026-08-10-ch1-scenekit-closed-world-design.md)
- Chapter 1 구현 계획: [ClosedWorld implementation plan](docs/superpowers/plans/2026-08-10-ch1-closed-world-implementation.md)

Claude와 Codex를 포함한 작업자는 [AGENTS.md](AGENTS.md)를 먼저 읽습니다.

## DocC 웹 문서

Chapter 1의 `ClosedWorld` DocC 카탈로그는 [Tutorials/SceneKitToRealityKit.docc](Tutorials/SceneKitToRealityKit.docc)에 있습니다. Xcode가 설치된 macOS에서는 아래 명령으로 GitHub Pages용 정적 아카이브를 만들 수 있습니다.

```bash
bash scripts/build-docc-site.sh /tmp/SceneKitToRealityKit.doccarchive
```

`main`의 카탈로그 또는 배포 설정 변경은 GitHub Actions에서 정적 파일로 변환되어 GitHub Pages에 공개됩니다.

<https://eunseo-com.github.io/2026TechMap_tutorial/>
