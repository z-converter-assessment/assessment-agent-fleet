# Changelog

본 repo 의 주요 변경 사항.

형식: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) 기반.
버전: [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- 프로젝트 초기 셋업
- `docs/architecture/`, `docs/operations/`, `docs/adr/`, `docs/commit.md` 문서 골격
- `terraform/` OpenStack provisioning 골격 (modules/vm, environments/{staging,prod})
- `ansible/` agent install + env + systemd unit 골격 (roles, playbooks, inventory)
- `scripts/tf-output-to-inventory.sh`: terraform output -> ansible inventory 변환
- `.github/workflows/lint.yml`: terraform / ansible lint CI
- `.github/dependabot.yml`: github-actions / terraform 의존성 자동 갱신
- `.editorconfig`, `terraform/.terraform-version`, `ansible/.ansible-lint`
