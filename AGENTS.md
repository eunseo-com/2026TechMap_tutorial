# AI 협업 가이드

이 저장소의 사람이 읽는 문서가 Claude와 Codex의 공통 기준이다. 로컬 대화 메모리나 다른 프로젝트의 상태를 기준으로 삼지 않는다.

## 시작 순서

작업을 시작하기 전에 아래 순서로 읽는다.

1. `docs/PROJECT_CONTEXT.md`
2. `씬킷에서_리얼리티킷으로_컨셉노트.md`
3. 관련 설계 명세: `docs/superpowers/specs/`
4. 관련 실행 계획: `docs/superpowers/plans/`

구현 전에 `git fetch --prune origin`과 `git status --short`로 원격 변경과 작업 트리를 확인한다. 다른 사람이 만들었거나 아직 추적하지 않은 파일은 사용자의 명시적 요청 없이 이동·삭제·스테이징하지 않는다.

## 현재 범위

- 현재 승인된 구현 범위는 Chapter 1, `ClosedWorld`이다.
- 앱은 SwiftUI + SceneKit으로 시작하고, Tuist로 Xcode 프로젝트를 생성한다.
- 구현 단위와 검증 명령은 `docs/superpowers/plans/2026-08-10-ch1-closed-world-implementation.md`를 따른다.
- Chapter 2~4의 상세 구현은 아직 설계 대상이 아니다. Chapter 1 범위를 넓히지 않는다.

## 협업 규칙

- 의사결정, 변경 이유, 다음 작업에 필요한 정보는 Git으로 추적되는 Markdown 문서에 기록한다.
- `.claude/`와 대용량 Apple 샘플 사본은 로컬 참고물이다. 그 내용을 사용해 결정을 내렸다면 결론과 출처를 저장소 문서에 요약한다.
- 계획의 태스크 단위로 검증하고 커밋한다. 커밋 메시지에는 AI 저자 표시나 `Co-Authored-By` 트레일러를 넣지 않는다.
- 생성물(Xcode 프로젝트, 빌드 산출물, DerivedData)은 추적하지 않는다. 해당 제외 규칙은 구현 계획의 Task 1을 따른다.
