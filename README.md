# ovinstall

Automated bash-based installer for the complete OpenVox stack (Puppet + components).

## Overview

This project provides a fully automated bash installer for deploying OpenVox infrastructure:

- **OpenVox Agent** — Puppet agent (`openvox-agent` package)
- **OpenVox Server** — Puppet Server (`openvox-server` package)
- **PuppetDB** — PostgreSQL-backed data warehouse for Puppet
- **r10k** — Git-to-environment deployer (server only)
- **OpenBolt** — Agentless orchestration tool
- **OpenVox-GUI** — Web management interface (optional)

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

## Command-Line Options

| Option | Description |
|--------|-------------|
| `-c, --config FILE` | Path to configuration file (default: `/etc/openvox/openvox.conf`) |
| `-m, --mode MODE` | Installation mode: `agent`, `server`, `complete` |
| `--agent` | Install agent only (implies `--non-interactive`) |
| `--server` | Install server (agent + PuppetDB + r10k) |
| `--gui` | Install OpenVox-GUI |
| `--openbolt` | Install OpenBolt |
| `--non-interactive` | Run without prompting |
| `-d, --dry-run` | Show what would be done |
| `-f, --force` | Force installation even if already installed |
| `-s, --skip-preflight` | Skip preflight checks |
| `-v, --verbose` | Verbose output |
| `-h, --help` | Show help message |

## Configuration

### Configuration File

The installer reads a flat `key = value` config file. Copy the example and edit:

```bash
sudo mkdir -p /etc/openvox
sudo cp etc/openvox.conf.example /etc/openvox/openvox.conf
```

Example contents:

```ini
# Required for server installs
server_hostname = openvox.example.com
r10k_remote = git@github.com:yourorg/control-repo.git

# Optional
gui_port = 4567
non_interactive = true
```

See [etc/openvox.conf.example](etc/openvox.conf.example) for the full list of supported keys.

### Interactive Prompts

When running interactively (without `--non-interactive`), you will be prompted for:

1. **Server hostname** (FQDN) — Required for server installations
2. **r10k control repository URL** — Required if installing r10k (server mode)
3. **GUI port** — Optional, defaults to 4567

### r10k Configuration

r10k is a server-only component that requires a Git control repository.

The control repository URL can be provided via:
- Config file: `r10k_remote = git@github.com:org/control-repo.git`
- Interactive prompt (when running without `--non-interactive`)

Example URLs:
- SSH: `git@github.com:yourorg/control-repo.git`
- HTTPS: `https://github.com/yourorg/control-repo.git`

## Project Structure

```
ovinstall/
├── bin/
│   └── ovinstall       # Main entry point
├── lib/
│   ├── functions.sh            # Common functions (logging, OS detection, repos, etc.)
│   ├── agent.sh                # OpenVox Agent installer
│   ├── server.sh               # OpenVox Server (PuppetServer) installer
│   ├── puppetdb.sh             # PuppetDB installer
│   ├── r10k.sh                 # r10k installer (server only)
│   ├── openbolt.sh             # OpenBolt installer
│   └── gui.sh                  # OpenVox-GUI installer
├── etc/
│   └── openvox.conf.example    # Example configuration file
├── PROJECT_PLAN.md
└── README.md
```

## How It Works

### Installation Phases

1. **Preflight Checks** (`run_preflight`)
   - OS detection and compatibility check
   - Root privilege verification
   - Disk space check (15 GB minimum)
   - Network connectivity check (voxpupuli.org, GitHub)

2. **Repository Setup** (`phase_setup_repo`)
   - Configures Vox Pupuli package repository (yum or apt)
   - Imports GPG keys for package verification

3. **Component Installation** (`phase_install_components`)
   - Installs selected components based on mode/flags
   - Uses `install_package` helper for idempotent installs

4. **Post-Install Configuration** (`phase_post_install`)
   - Configures firewall rules (if firewalld is active)
   - SELinux advice (RHEL only)
   - Enables services
   - Deploys r10k environments

5. **Verification** (`phase_verify`)
   - Checks that installed services are running
   - Tests HTTPS connectivity to PuppetServer and PuppetDB

### Component Details

#### OpenVox Agent
- Installs `openvox-agent` package from Vox Pupuli
- Configures agent to connect to server (if `server_hostname` is set)
- Does NOT require r10k or server components

#### OpenVox Server (PuppetServer)
- Installs `openvox-server` package
- Configures server hostname, JVM heap, and PuppetDB integration
- Starts the `puppetserver` service

#### PuppetDB
- Installs `puppetdb` package
- Sets up internal PostgreSQL database (or connects to an external one)
- Starts the `puppetdb` service

#### r10k (Server Only)
- Installs r10k Ruby gem via Puppet's bundled gem
- Creates config at `/etc/puppetlabs/r10k/r10k.yaml`
- Deploys environments from the control repository

#### OpenBolt
- Installs `openbolt` package
- Creates `bolt-project.yaml` and `inventory.yaml` configuration

#### OpenVox-GUI
- Clones the GitHub repository to `/opt/openvox-gui`
- Runs the GUI's built-in `install.sh` installer

## Documentation

- [Project Plan](PROJECT_PLAN.md) — Detailed project specifications and roadmap
- [Configuration Reference](etc/openvox.conf.example) — All supported config keys

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

Apache License 2.0 — See LICENSE file

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
# Test hook
