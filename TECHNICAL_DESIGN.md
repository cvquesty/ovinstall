# ovinstall — Technical Design

This document describes the installer **as it exists in this repository**: a pure-bash orchestrator plus per-component bash libraries. Nothing here describes unshipped code. Operator-facing usage lives in [README.md](README.md) and [docs/USAGE.md](docs/USAGE.md).

**Naming:** Product and subsystem names use **OpenVox**, **OpenVoxDB**, and **OpenVox-GUI**. Binaries, systemd units, paths and config keys that ship as `puppet`, `puppetserver`, `puppetdb`, `/etc/puppetlabs/...` or `puppetdb_*` are written that way on purpose. OpenVox and its packages are developed by the OpenVox / Vox Pupuli community; ovinstall only installs them.

## 1. Repository layout

| Path | Role |
|------|------|
| `bin/ovinstall` | Entry point: argument parsing, prompts, mode selection, phase orchestration |
| `bin/ovinstall-maintenance` | Health/status, backup/restore, JVM tuning, mode and scale helpers |
| `lib/functions.sh` | Logging, privilege check, OS detection/gating, disk/network preflight, `load_config` / `validate_config`, repo setup, firewall/SELinux, `wait_for_port`, service and connectivity verification |
| `lib/agent.sh` | `install_agent`, `configure_agent` (`openvox-agent`) |
| `lib/server.sh` | `install_server`, `configure_server`, `configure_puppetdb_terminus` (`openvox-server`) |
| `lib/puppetdb.sh` | OpenVoxDB install, PostgreSQL setup, password generation/validation |
| `lib/r10k.sh` | r10k gem install (pinned), `r10k.yaml`, `deploy_environments` |
| `lib/openbolt.sh` | `install_openbolt`, `configure_openbolt`, `verify_openbolt` |
| `lib/gui.sh` | OpenVox-GUI clone (repo allowlist) and its `install.sh` |
| `lib/control_repo.sh` | Control-repo clone / hiera / ownership helpers (environments are r10k-owned; see §3) |
| `etc/openvox.conf.example` | Annotated `key = value` config template |
| `.github/workflows/ci.yml` | CI (see §7) |

## 2. Entry point: `bin/ovinstall`

`main()` runs these steps in order:

1. `parse_args` — `-c/--config`, `-m/--mode agent|server|complete`, `--agent`, `--server`, `--gui`, `--openbolt`, `--non-interactive`, `-d/--dry-run`, `-f/--force`, `-s/--skip-preflight`, `-v/--verbose`, `-h/--help`
2. `print_banner`, `check_privileges` (root required), `setup_logging`
3. `run_preflight` (unless `--skip-preflight`): `check_os`, disk space, network
4. `load_config "$CONFIG_FILE"` (default `/etc/openvox/openvox.conf`)
5. `set_install_mode` — mode preset, overridden by explicit component flags
6. `prompt_for_config` (skipped with `--non-interactive`), then `validate_config`
7. `confirm_install`; with `--dry-run`, `dry_run` + `print_dry_run_summary` and exit 0
8. Phases (below), then `print_summary`

The script runs under `set -e`; a failing phase stops the install.

### Modes

| Mode | Components |
|------|------------|
| `agent` | Agent |
| `server` | Agent, Server, OpenVoxDB, r10k |
| `complete` (default) | All of the above + OpenBolt + OpenVox-GUI |

## 3. Phases

| Function | What it does |
|----------|--------------|
| `phase_setup_repo` | `setup_vox_repo` → `setup_yum_repo` (RHEL family) or `setup_apt_repo` (Debian/Ubuntu). HEAD-checks the `openvox8-release` package URL on `yum.voxpupuli.org` / `apt.voxpupuli.org`, imports the GPG key before installing the RPM, uses a `signed-by` keyring on apt. EL 10 and Fedora 42+ use the EL-9 release package. |
| `phase_install_components` | In order, as selected: `install_agent`, `install_server`, `install_puppetdb` (with server), `install_r10k`, `install_openbolt`, `install_gui` |
| `phase_post_install` | `configure_firewall` (only if `firewalld` is active; opens 8140, 8081, GUI port), `configure_selinux` (warns/advises on Enforcing; does not change mode), `configure_services`, then one `r10k deploy environment -p` via `deploy_environments` when r10k is selected |
| `phase_verify` | Fail-closed. `verify_services`: `puppetserver` and `puppetdb` units active (server), `routes.yaml` and `puppetdb.conf` present in `/etc/puppetlabs/puppet` (server), GUI HTTP check on `gui_port` (default 4567), agent-only package + `/opt/puppetlabs/bin/puppet` check. `verify_connectivity`: retries `https://localhost:8140/status/v1/simple` and `:8081/status/v1/simple`. `verify_openbolt` when OpenBolt is selected. |
| `phase_finalize` | Unless `run_final_agent = false`, runs `puppet agent --test --detailed-exitcodes`; exit 0 or 2 is success, anything else fails unless `--force` |

### Server wiring (`configure_server`)

Sets `server`, `reports = puppetdb`, `storeconfigs = true`, `storeconfigs_backend = puppetdb`, `environmentpath` and `codedir` via `puppet config set`; writes JVM heap (`jvm_memory`, default `2g`) into `/etc/sysconfig/puppetserver` when present; `configure_puppetdb_terminus` writes `routes.yaml` and `puppetdb.conf` (`server_urls = https://<server_hostname>:8081`).

## 4. Platform gating (`check_os`)

`detect_os` reads `/etc/os-release`. `check_os` accepts:

- RHEL family (`rhel`, `centos`, `rocky`, `almalinux`, `fedora`): major 8, 9, 10, or ≥ 42
- Debian 11, 12
- Ubuntu 22.04, 24.04
- Architectures: `x86_64`, `amd64`, `aarch64`, `arm64`

Anything else is fatal unless `--force`. Debian/Ubuntu also require a non-empty codename. Acceptance by this gate is **not** evidence of testing; see §7.

## 5. Configuration

`load_config` parses `key = value` lines. Keys read: `install_mode`, `server_hostname`, `r10k_remote`, `gui_port`, `gui_repo_url`, `gui_repo_ref`, `allow_untrusted_gui_repo`, `bolt_insecure_ssh`, `certname`, `runinterval`, `jvm_memory`, `log_level`, `firewall`, `selinux`, `puppetdb_database`, `puppetdb_password`, `puppetdb_db_host`, `puppetdb_db_port`, `puppetdb_db_name`, `puppetdb_db_user`, `run_final_agent`. See `etc/openvox.conf.example` for defaults and the README for the full reference.

## 6. Security choices in code

- OpenVoxDB password: generated if unset and stored at `/etc/openvox/puppetdb_password` (0600); `changeme` is rejected.
- GUI repo URL must be on an allowlist unless `allow_untrusted_gui_repo` is set.
- OpenBolt host-key checking stays on unless `bolt_insecure_ssh` is set.
- r10k gem version is pinned.
- `--verbose` raises log level only; it never enables `set -x` (avoids leaking secrets).
- Maintenance backups exclude private keys unless `--include-private-keys`.

## 7. CI (`.github/workflows/ci.yml`)

Runs on pushes and PRs to `master`:

- **shell** (ubuntu-latest): `bash -n` on `bin/*` and `lib/*.sh`; `shellcheck -S warning -x bin/ovinstall bin/ovinstall-maintenance`; `./bin/ovinstall --help`
- **platform-syntax**: `bash -n` on the same files inside `rockylinux:9`, `debian:12` and `ubuntu:24.04` containers

CI does **not** install packages or run the installer end to end on any OS.

## 8. Maintenance script (`bin/ovinstall-maintenance`)

Root-only. Actions: `--health`, `--status`, `--add COMPONENT --host H` / `--remove COMPONENT --host H` (`compile-master`, `puppetdb-replica`, `ca-server`), `--mode ca-only|all-in-one|maintenance`, `--backup --to DIR`, `--restore --from DIR`, `--tune [puppetserver|puppetdb|all]`, `--verbose`. Add/remove are guidance helpers; manual steps are still required on the target host.

## 9. Not implemented

No automated rollback, no download cache/proxy, no template engine, no multi-node orchestration and no ENC setup. Treat any such item in PROJECT_PLAN.md as roadmap.
