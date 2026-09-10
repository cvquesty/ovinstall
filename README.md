# ovinstall

Automated bash-based installer for the complete OpenVox stack (Puppet + components).

**Current version:** v0.3.0 (installer banner)

## Overview

This project provides a fully automated bash installer for deploying OpenVox infrastructure:

- **OpenVox Agent** — Puppet agent (`openvox-agent` package)
- **OpenVox Server** — Puppet Server (`openvox-server` package)
- **PuppetDB** — PostgreSQL-backed data warehouse for Puppet
- **r10k** — Git-to-environment deployer (server only)
- **OpenBolt** — Agentless orchestration tool
- **OpenVox-GUI** — Web management interface (optional)

Companion tooling: **`bin/ovinstall-maintenance`** for health checks, backup/restore, JVM tuning, and scaling helpers.

## Requirements

- **Supported Operating Systems:**
  - RHEL 8, 9, 10
  - CentOS 8+
  - Rocky Linux 8+
  - AlmaLinux 8+
  - Fedora 42+
  - Debian 11 (Bullseye), 12 (Bookworm)
  - Ubuntu 22.04 (Jammy), 24.04 (Noble)

- **System Requirements:**
  - Root/sudo access
  - bash 4.0+
  - curl
  - 15 GB free disk space
  - Internet connectivity (to reach voxpupuli.org, GitHub)
  - Valid FQDN hostname (for server installations)
  - git (for OpenVox-GUI and r10k)

## Quick Start

### Interactive Installation (Prompts for Required Values)

```bash
git clone https://github.com/cvquesty/ovinstall.git
cd ovinstall

# Run the installer — will prompt for server hostname, r10k URL, etc.
sudo ./bin/ovinstall
```

### Non-Interactive Installation (Automated/Scripted)

```bash
# With command-line flags
sudo ./bin/ovinstall --mode complete --non-interactive

# With a configuration file
sudo mkdir -p /etc/openvox
sudo cp etc/openvox.conf.example /etc/openvox/openvox.conf
# Edit the config file with your values…
sudo ./bin/ovinstall --config /etc/openvox/openvox.conf --non-interactive
```

## Installation Modes

| Mode | Agent | Server | PuppetDB | r10k | OpenBolt | GUI |
|------|-------|--------|----------|------|----------|-----|
| `agent` | ✓ | | | | | |
| `server` | ✓ | ✓ | ✓ | ✓ | | |
| `complete` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

- **`agent`** — Standalone Puppet agent only; connects to an existing Puppet Server.
- **`server`** — Full Puppet Server with PuppetDB and r10k for code deployment.
- **`complete`** — All components including OpenBolt and OpenVox-GUI.

## Usage

```bash
# Interactive (prompts for required values)
sudo ./bin/ovinstall

# Non-interactive with all defaults
sudo ./bin/ovinstall --mode complete --non-interactive

# Agent only
sudo ./bin/ovinstall --agent

# Server with r10k (requires r10k_remote in config or prompt)
sudo ./bin/ovinstall --server

# Just the GUI
sudo ./bin/ovinstall --gui

# Dry-run (preview what would be installed)
sudo ./bin/ovinstall --dry-run

# Custom config file
sudo ./bin/ovinstall --config /path/to/openvox.conf

# Verbose output for debugging
sudo ./bin/ovinstall --verbose
```

For a step-by-step walkthrough, see [docs/USAGE.md](docs/USAGE.md).

## Command-Line Options

| Option | Description |
|--------|-------------|
| `-c, --config FILE` | Path to configuration file (default: `/etc/openvox/openvox.conf`) |
| `-m, --mode MODE` | Installation mode: `agent`, `server`, `complete` |
| `--agent` | Install agent only |
| `--server` | Install server (agent + PuppetDB + r10k) |
| `--gui` | Install OpenVox-GUI |
| `--openbolt` | Install OpenBolt |
| `--non-interactive` | Run without prompting |
| `-d, --dry-run` | Show what would be done |
| `-s, --skip-preflight` | Skip preflight checks |
| `-v, --verbose` | Verbose output (debug logs + bash `set -x`) |
| `-h, --help` | Show help message |

## Configuration

### Configuration File

The installer reads a flat `key = value` config file via `load_config` in `lib/functions.sh`. Copy the example and edit:

```bash
sudo mkdir -p /etc/openvox
sudo cp etc/openvox.conf.example /etc/openvox/openvox.conf
```

Only the keys listed below are applied. Unknown keys are logged at debug level and ignored.

### Keys accepted by `load_config`

| Key | Aliases | Description |
|-----|---------|-------------|
| `server_hostname` | | FQDN of the Puppet server (required for server installs) |
| `r10k_remote` | | Git URL for the control repository (required when installing r10k) |
| `gui_port` | | OpenVox-GUI listen port (default in installer: `4567`) |
| `gui_repo_url` | | Git URL for OpenVox-GUI clone (default: `https://github.com/cvquesty/openvox-gui.git`) |
| `install_mode` | `mode` | Installation mode: `agent`, `server`, or `complete` |
| `certname` | | Agent certificate name; use `auto` to let Puppet use the hostname |
| `runinterval` | | Agent run interval (e.g. `30m`, `1h`) |
| `jvm_memory` | | Puppet Server JVM heap (`-Xms`/`-Xmx`), e.g. `2g` |
| `log_level` | | Logging level: `debug`, `info`, `warning`, `error` |
| `firewall` | | Documented for firewalld configuration preference (parsed into shell; see note) |
| `selinux` | | Documented SELinux preference: `enforcing`, `permissive`, `disabled` (parsed into shell; see note) |
| `puppetdb_database` | | `internal` (local PostgreSQL) or `external` |
| `puppetdb_password` | | Password for the PuppetDB PostgreSQL user |
| `puppetdb_db_host` | | External DB host (when `puppetdb_database = external`) |
| `puppetdb_db_port` | | External DB port |
| `puppetdb_db_name` | | External DB name |
| `puppetdb_db_user` | | External DB user |
| `non_interactive` | `non-interactive` | If `true` or `yes`, skip interactive prompts |

**Note on `firewall` / `selinux`:** Both keys are accepted by `load_config`. Current `configure_firewall` runs when `firewalld` is active (opens ports for selected components). Current `configure_selinux` warns when SELinux is Enforcing on RHEL-family hosts; it does not rewrite mode from the config value alone.

### Reserved / example-only keys

These appear in `etc/openvox.conf.example` for future growth but are **not** parsed by `load_config` (they are ignored):

| Key | Notes |
|-----|-------|
| `download_cache_enabled` | Example only — not loaded |
| `download_cache_dir` | Example only — not loaded |
| `download_cache_max_age_days` | Example only — not loaded |
| `server_role` | Example only — not loaded |
| `compile_masters` | Example only — not loaded |
| `environments` | Example only — not loaded |
| `run_final_agent` | Example only — **conf key not wired**. Phase finalize checks the **environment variable** `run_final_agent` (default treat as true; skip agent run if set to `false`) |

Example minimal config:

```ini
server_hostname = openvox.example.com
r10k_remote = git@github.com:yourorg/control-repo.git
gui_port = 4567
non_interactive = true
```

See [etc/openvox.conf.example](etc/openvox.conf.example) for annotated comments.

### Interactive Prompts

When running interactively (without `--non-interactive`), you will be prompted for:

1. **Server hostname** (FQDN) — Required for server installations
2. **r10k control repository URL** — Required if installing r10k (server mode)
3. **GUI port** — Optional, defaults to 4567

### r10k Configuration

r10k is a server-only component that requires a Git control repository.

**Recommended model:** r10k alone owns `/etc/puppetlabs/code/environments` (deploy via `lib/r10k.sh`). Do not treat a second git clone into that basedir as the preferred setup.

The control repository URL can be provided via:
- Config file: `r10k_remote = git@github.com:org/control-repo.git`
- Interactive prompt (when running without `--non-interactive`)

Example URLs:
- SSH: `git@github.com:yourorg/control-repo.git`
- HTTPS: `https://github.com/yourorg/control-repo.git`

## Maintenance (`ovinstall-maintenance`)

`bin/ovinstall-maintenance` manages post-install health, backups, JVM tuning, and scaling helpers.

```bash
sudo ./bin/ovinstall-maintenance --health
sudo ./bin/ovinstall-maintenance --status
sudo ./bin/ovinstall-maintenance --add compile-master --host puppet-compile2.example.com
sudo ./bin/ovinstall-maintenance --remove compile-master --host puppet-compile2.example.com
sudo ./bin/ovinstall-maintenance --mode ca-only
sudo ./bin/ovinstall-maintenance --mode all-in-one
sudo ./bin/ovinstall-maintenance --mode maintenance
sudo ./bin/ovinstall-maintenance --backup --to /backups/openvox-$(date +%Y%m%d)
sudo ./bin/ovinstall-maintenance --restore --from /backups/openvox-20240324
sudo ./bin/ovinstall-maintenance --tune
sudo ./bin/ovinstall-maintenance --tune puppetserver
sudo ./bin/ovinstall-maintenance --verbose --health
sudo ./bin/ovinstall-maintenance --help
```

| Action | Description |
|--------|-------------|
| `--health` | Check Puppet Server, PuppetDB, agent enablement, r10k, disk, CA cert |
| `--add COMPONENT --host H` | Generate/add guidance for a component on host `H` |
| `--remove COMPONENT --host H` | Remove-component helper (warns that manual cleanup is required) |
| `--mode MODE` | Change server mode: `ca-only`, `all-in-one`, or `maintenance` |
| `--backup --to DIR` | Backup `/etc/puppetlabs`, `/var/lib/puppet`, `/var/log/puppetlabs`, and r10k.yaml |
| `--restore --from DIR` | Restore from a previous backup directory (interactive confirm) |
| `--tune [COMPONENT]` | Tune JVM heap for `puppetserver`, `puppetdb`, or `all` (default) |
| `--status` | Show infrastructure status (mode heuristics, environments, certs) |
| `--verbose` | More verbose logging |
| `--help` / `-h` | Show help |

**Components** for `--add` / `--remove`:

| Component | Meaning |
|-----------|---------|
| `compile-master` | Catalog compiler server (`catalog-compiler` accepted as alias on add) |
| `puppetdb-replica` | PuppetDB replica for HA |
| `ca-server` | CA-only server |

**Modes** for `--mode`:

| Mode | Behavior |
|------|----------|
| `ca-only` | Reduce JVM / JRuby for CA-only operation |
| `all-in-one` | Restore fuller heap for CA + catalog compilation |
| `maintenance` | Stop `puppetserver` and `puppetdb` for maintenance |

## Project Structure

```
ovinstall/
├── bin/
│   ├── ovinstall                 # Main installer entry point
│   └── ovinstall-maintenance     # Health, backup, tune, scale helpers
├── lib/
│   ├── functions.sh              # Logging, load_config, OS, repos, firewall/SELinux
│   ├── agent.sh                  # OpenVox Agent installer
│   ├── server.sh                 # OpenVox Server (PuppetServer) installer
│   ├── puppetdb.sh               # PuppetDB installer
│   ├── r10k.sh                   # r10k installer + environment deploy
│   ├── openbolt.sh               # OpenBolt installer
│   ├── gui.sh                    # OpenVox-GUI installer
│   └── control_repo.sh           # Control repo / Hiera helpers (deprecated dual-path vs r10k)
├── etc/
│   └── openvox.conf.example      # Annotated example configuration
├── docs/
│   └── USAGE.md                  # Concrete usage tutorial
├── LICENSE                       # Apache License 2.0
├── PROJECT_PLAN.md               # Roadmap and specs
├── TECHNICAL_DESIGN.md           # Design document (as-built + aspirational)
└── README.md
```

## How It Works

### Installation Phases

`bin/ovinstall` runs **preflight**, then **five phases**:

0. **Preflight** (`run_preflight`, unless `--skip-preflight`)
   - OS detection and compatibility check
   - Disk space check (15 GB minimum)
   - Network connectivity check (voxpupuli.org / repos)

1. **Repository Setup** (`phase_setup_repo`)
   - Configures Vox Pupuli package repository (yum or apt)
   - Imports GPG keys for package verification

2. **Component Installation** (`phase_install_components`)
   - Installs selected components based on mode/flags
   - Agent → Server → PuppetDB → r10k → OpenBolt → GUI (as selected)

3. **Post-Install Configuration** (`phase_post_install`)
   - `configure_firewall` / `configure_selinux` / `configure_services`
   - If r10k selected: `deploy_environments` + `deploy_puppetfile_per_environment`
   - If server + `r10k_remote` set: may call `deploy_control_repo` (as-built dual path; **deprecated** — prefer r10k-only environments ownership)

4. **Verification** (`phase_verify`)
   - `verify_services` / `verify_connectivity`
   - `verify_openbolt` when OpenBolt was installed

5. **Finalize** (`phase_finalize`)
   - Runs `puppet agent --test` unless environment `run_final_agent=false`
   - Prints completion guidance (`print_summary`)

### Component Details

#### OpenVox Agent
- Installs `openvox-agent` package from Vox Pupuli
- Configures agent to connect to server (if `server_hostname` is set)
- Applies `certname` / `runinterval` when provided
- Does NOT require r10k or server components

#### OpenVox Server (PuppetServer)
- Installs `openvox-server` package
- Configures server hostname, JVM heap (`jvm_memory`), and PuppetDB integration
- Starts the `puppetserver` service

#### PuppetDB
- Installs `puppetdb` package
- Sets up internal PostgreSQL database (or connects to an external one via `puppetdb_*` keys)
- Starts the `puppetdb` service

#### r10k (Server Only)
- Installs r10k Ruby gem via Puppet's bundled gem
- Creates config at `/etc/puppetlabs/r10k/r10k.yaml`
- Deploys environments and per-environment Puppetfiles from the control repository

#### Control repository helpers
- `lib/control_repo.sh` still exists on current tree. **Preferred:** r10k-only ownership of environments. A second clone into the environments basedir is deprecated / non-recommended; staging (if needed) should stay outside r10k’s basedir (e.g. `/var/lib/ovinstall/`).

#### OpenBolt
- Installs `openbolt` package
- Creates `bolt-project.yaml` and `inventory.yaml` configuration

#### OpenVox-GUI
- Clones the GitHub repository (or `gui_repo_url`) to `/opt/openvox-gui`
- Runs the GUI's built-in `install.sh` installer

## Documentation

- [Project Plan](PROJECT_PLAN.md) — Specs, roadmap, and implementation annotations
- [Technical Design](TECHNICAL_DESIGN.md) — Architecture (as-built bash + aspirational design)
- [Usage Tutorial](docs/USAGE.md) — Concrete commands for install and maintenance
- [Configuration Example](etc/openvox.conf.example) — Annotated conf file (includes reserved keys)
- [LICENSE](LICENSE) — Apache License 2.0

## External References

- OpenVox Docs: https://github.com/cvquesty/voxdocs
- Vox Pupuli: https://voxpupuli.org
- r10k Documentation: https://github.com/puppetlabs/r10k
- OpenVox Project: https://github.com/openvoxproject
- OpenVox-GUI: https://github.com/cvquesty/openvox-gui

## Differences from puppet-openvox_bootstrap

This project differs from the Bolt-based approach:
- **Pure bash** — No Bolt/Puppet required to run the installer
- **Interactive mode** — Prompts for required values by default
- **Flat config file** — Simple `key = value` format
- **Modular** — Each component has its own installer script in `lib/`
- **Server-only r10k** — r10k cannot be installed on standalone agents

## Troubleshooting

### Verbose Output

```bash
sudo ./bin/ovinstall --verbose
```

### Log File

All log messages are written to `/var/log/openvox/install.log`:

```bash
tail -f /var/log/openvox/install.log
```

### Common Issues

| Error | Solution |
|-------|----------|
| "Cannot reach yum.voxpupuli.org" | Check network/firewall settings |
| "Server hostname is required" | Provide via config file or interactive prompt |
| "r10k requires control repository URL" | Set `r10k_remote` in config or answer prompt |
| "Insufficient disk space" | Ensure at least 15 GB available on `/` |
| "This script must be run as root" | Use `sudo` |

## License

Apache License 2.0 — See [LICENSE](LICENSE) file

## AI Disclosure

| Contribution Type | Percentage |
|-------------------|------------|
| AI Assisted       | 66%        |
| Human Written     | 34%        |

**AI Models Used:**
- OpenClaw (primary agent — running on Ollama with minimax-m2.5:cloud model)
- GitHub CLI (gh) for repository operations

**Notes:**
- Initial skeleton and documentation created by AI assistant
- Jerald (human) provided project requirements and design decisions
- All commits include "Assisted by AI tools" in commit messages

## Author

CVQuesty
