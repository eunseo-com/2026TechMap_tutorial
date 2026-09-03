# AI 협업 가이드

이 저장소의 사람이 읽는 문서가 Claude와 Codex의 공통 기준이다. 로컬 대화 메모리나 다른 프로젝트의 상태를 기준으로 삼지 않는다.

## 시작 순서

작업을 시작하기 전에 아래 순서로 읽는다.

1. `docs/PROJECT_CONTEXT.md`
2. `docs/WORK_LOG.md`
3. `씬킷에서_리얼리티킷으로_컨셉노트.md` (현재 브랜치에 없으면 부재 사실을 `docs/LEARNING_LOG.md`에 기록하고 승인된 설계 명세를 대체 근거로 사용)
4. 관련 설계 명세: `docs/superpowers/specs/`
5. 관련 실행 계획: `docs/superpowers/plans/`

구현 전에 `git fetch --prune origin`과 `git status --short`로 원격 변경과 작업 트리를 확인한다. 다른 사람이 만들었거나 아직 추적하지 않은 파일은 사용자의 명시적 요청 없이 이동·삭제·스테이징하지 않는다.

## 현재 범위

- 사용자가 Chapter 2–4 확장을 승인했다. 최종 범위는 **C3 SceneKit 닫힌 세계 → RealityKit 현실 준비 → 실제 물체 뒤 숨기·이동 재발견 → SceneKit/RealityKit 비교·완료**의 네 챕터다.
- 정확한 상태 전이·수치·오류·DocC·검증 경계는 `docs/superpowers/specs/2026-08-29-four-chapter-experience-and-docc-design.md`를 따른다.
- 구현 단위와 검증·커밋 순서는 `docs/superpowers/plans/2026-08-29-four-chapter-experience-and-docc-implementation.md`의 13개 태스크를 따른다.
- 이전 Chapter 1 설계·계획과 방·가짜 소파 구현은 변경 이유와 SceneKit 개념을 설명하는 참고 기준으로 보존한다. 승인된 4개 챕터 계획 밖으로 범위를 넓히지 않는다.

## 협업 규칙

- 의사결정, 변경 이유, 다음 작업에 필요한 정보는 Git으로 추적되는 Markdown 문서에 기록한다.
- 의미 있는 작업 단위가 끝나면 검증 결과와 다음 시작점을 `docs/WORK_LOG.md`의 현재 인수인계·작업 이력에 갱신하고, 결과물과 같은 커밋에 포함한다.
- `.claude/`와 대용량 Apple 샘플 사본은 로컬 참고물이다. 그 내용을 사용해 결정을 내렸다면 결론과 출처를 저장소 문서에 요약한다.
- 계획의 태스크 단위로 검증하고 커밋한다. 커밋 메시지·트레일러·PR 제목·PR 본문에는 작업자·도구·모델·AI 생성 표기를 넣지 않으며, `Co-Authored-By`를 사용하지 않는다.
- 생성물(Xcode 프로젝트, 빌드 산출물, DerivedData)은 추적하지 않는다.
