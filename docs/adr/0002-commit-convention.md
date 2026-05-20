# 0002. commit message 규칙

- Status: Accepted
- Date: 2026-05-19

## Context
협업 시 commit history 가독성과 자동화 (changelog 생성, semver bump 등) 를 위해 일관된 commit message 규칙 필요.

## Decision
type prefix 5개 (feat, fix, chore, refactor, test) 와 한글 설명. 세부 규칙은 `docs/commit.md`.

## Consequences
- type 분류가 5개로 단일화되어 의사결정 단순
- 한글 설명으로 코드 리뷰 진입 장벽 낮춤
- 표준 Conventional Commits 의 `docs:`, `build:`, `ci:` 등 미사용. 자동화 도구 적용 시 type 매핑 필요

## Alternatives
- 표준 Conventional Commits (type 10여 개): 분류 모호함 증가
- 자유 형식: 자동화 불가, 일관성 결여
- gitmoji: 이모지 사용 (글로벌 정책 위배)
