# 위키 참고 자료의 DocC Article 이관 설계

## 목적

`https://github.com/eunseo-com/2026TechMap_tutorial/wiki`의 SceneKit·RealityKit·비교와 마이그레이션·실기기 카메라 진단 4페이지에는 4개 튜토리얼 챕터의 서사에 담지 않은 참고용 표·체크리스트·실패 기록이 있다. 튜토리얼은 의도적으로 서사 중심을 유지하므로, 이 참고 자료를 DocC Article로 옮겨 GitHub Pages 사이트에서도 볼 수 있게 한다.

## 확인한 근거

- `Tutorials/SceneKitToRealityKit.docc/Tutorials/`의 4개 `.tutorial` 파일은 이미 Chapter 1–4 서사, `Cylinder_Tree` 자산명, 실제 코드(`RealityHideARView`, `RealityHidePlanner`, `RealityRevealMonitor`, `RunAwayComponent`)를 반영하고 있다. 이 설계는 그 내용을 바꾸지 않는다.
- 위키의 참고 표·체크리스트·진단 기록은 이 저장소가 실제로 구현한 흐름(`docs/superpowers/specs/2026-08-19-c3-reality-escape-docc-content-design.md`)과 같은 근거를 설명하므로, 별도 출처 표기 없이 그대로 참고 문서로 옮길 수 있다.
- DocC 카탈로그는 `@Tutorials` 루트만 있고 심볼 그래프가 없는 튜토리얼 전용 번들이라, 느슨한 Article은 `@Metadata { @TechnologyRoot }`로 표시해야 큐레이션되어 링크가 해석된다. `@Resources` 목록만으로는 큐레이션되지 않는다.

## 정보 구조

```text
Tutorials/SceneKitToRealityKit.docc/
├── SceneKitToRealityKit.tutorial   # 각 챕터 본문에 해당 Article 인라인 링크 + @Resources 목록 추가
├── Tutorials/                      # 기존 4개 챕터, 변경 없음
└── Articles/                       # 신규
    ├── SceneGraphDeepDive.md       # SceneKit 위키 페이지: 씬 그래프, 좌표 변환, 컴포넌트, 디버깅 표, 체크포인트
    ├── RealityKitECS.md            # RealityKit 위키 페이지: ECS 구분표, Component/System 예시, 앵커, 뷰 선택, 체크리스트
    ├── MigrationWorksheet.md       # 비교와 마이그레이션 위키 페이지: 4관점 표, 번역 표, 6단계 워크시트, 최종 질문
    └── DeviceCameraDiagnostics.md  # 실기기 카메라 진단 위키 페이지: 증상 → 배제 7가지 → 확인된 경계 → 해결 → 남은 검증
```

각 Article은 `@Metadata { @TechnologyRoot }`로 독립 루트 페이지가 되고, 관련 챕터 본문에서 인라인 `<doc:>` 링크로 큐레이션되며, 루트 `.tutorial`의 `@Resources`에서 한 번에 모아 보여준다.

## 검증

`scripts/build-docc-site.sh`로 로컬 변환 시 링크 미해석 경고 없이 통과해야 한다. `xcrun docc preview`로 튜토리얼 목차·4개 Article 페이지·상호 링크가 실제로 렌더링되는지 확인한다.

## 건드리지 않는 것

- 기존 4개 `.tutorial` 파일의 서사·코드 스니펫 참조는 각 챕터 본문에 Article 링크 한 줄을 추가하는 것 외에는 바꾸지 않는다.
- `docc-site`류의 별도 배포 셸은 이 저장소에 없다 — GitHub Actions(`deploy-docc.yml`)가 `main` 푸시 시 자동 빌드·배포한다. 이 설계는 로컬 검증까지만 다루고, 실제 배포(푸시)는 별도로 확인받는다.
