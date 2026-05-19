# ADR — Architecture Decision Records

본 repo의 의사결정 history. 새 결정마다 새 파일 추가. 기존 결정은 수정하지 않고 Superseded 표기로 대체.

## 파일 명명
`NNNN-제목.md` (NNNN: 0001 부터 4자리 zero-padded)

## 템플릿

```
# NNNN. 제목

- Status: Proposed | Accepted | Superseded by NNNN | Deprecated
- Date: YYYY-MM-DD

## Context
결정이 필요한 배경.

## Decision
선택한 안.

## Consequences
선택의 결과와 트레이드오프.

## Alternatives
검토한 대안과 탈락 사유.
```

## 목록
- [0001-tooling.md](0001-tooling.md) — Terraform + Ansible 선택
