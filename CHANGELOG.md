# Changelog

All notable changes to **ovinstall** are documented here.

Format inspired by [Keep a Changelog](https://keepachangelog.com/). Version numbers match the installer banner (`bin/ovinstall`).

## [0.3.0] — 2026-09

### Added
- Fail-closed OS/arch gating, service/port verification, and PuppetDB terminus file asserts
- Release-package URL HEAD checks and `wait_for_port` instead of fixed sleeps
- GitHub Actions CI (`bash -n`, shellcheck on entrypoints, platform container syntax matrix)
- Security hardening for PuppetDB passwords, GUI repo allowlist, and Bolt host-key defaults
- Docs: USAGE tutorial, LICENSE (Apache 2.0), TECHNICAL_DESIGN as-built vs future banner

### Changed
- r10k-only ownership of `/etc/puppetlabs/code/environments` (deprecated dual `deploy_control_repo` path)
- Single `r10k deploy environment -p` (removed duplicate Puppetfile deploy pass)
- `--verbose` sets debug logging only (no global `set -x`)

### Fixed
- PuppetDB `routes.yaml` / `puppetdb.conf` wiring so storeconfigs is not silent-no-op
