# OpenVox Installer

Automated bash-based installer for the complete OpenVox stack (Puppet + components).

## Overview

This project provides a fully automated bash installer for deploying OpenVox servers with all components:
- OpenVox Agent (Puppet agent)
- OpenVox Server (Puppet Server)
- PuppetDB
- r10k (Puppet code deployment - server only)
- OpenVox-GUI (optional)

## Requirements

- **Supported Operating Systems:**
  - RHEL 8, 9, 10
  - CentOS 8+
  - Rocky Linux 8+
  - AlmaLinux 8+
  - Fedora 42+
  - Debian 11, 12
  - Ubuntu 22.04, 24.04

- **System Requirements:**
  - Root/sudo access
  - 15GB free disk space
  - Internet connectivity (to reach voxpupuli.org, GitHub)
  - Valid FQDN hostname (for server installations)

## Quick Start

### Interactive Installation (Prompts for Required Values)

```bash
# Clone or download this repository
git clone https://github.com/cvquesty/openvox-installer.git
cd openvox-installer

# Run the installer (will prompt for required values)
sudo ./bin/openvox-installer
```

### Non-Interactive Installation (Automated/Scripted)

```bash
# With command-line flags
sudo ./bin/openvox-installer --mode complete --non-interactive

# With configuration file
sudo cp etc/openvox.conf.example /etc/openvox/openvox.conf
# Edit the config file with your values
sudo ./bin/openvox-installer --config /etc/openvox/openvox.conf
```

## Installation Modes

| Mode | Agent | Server | PuppetDB | r10k | GUI |
|------|-------|--------|----------|------|-----|
| `agent` | ✓ | | | | |
| `server` | ✓ | ✓ | ✓ | ✓ | |
| `complete` | ✓ | ✓ | ✓ | ✓ | ✓ |

**Notes:**
- `agent`: Standalone Puppet agent only - connects to existing Puppet Server
- `server`: Full Puppet Server with PuppetDB and r10k for code deployment
- `complete`: All components including OpenVox-GUI

## Usage

```bash
# Interactive installation (prompts for required values like server_hostname, r10k_remote)
sudo ./bin/openvox-installer

# Non-interactive with all defaults
sudo ./bin/openvox-installer --mode complete --non-interactive

# Install only the agent
sudo ./bin/openvox-installer --agent

# Install server with r10k (requires r10k_remote in config)
sudo ./bin/openvox-installer --server

# Install just the GUI
sudo ./bin/openvox-installer --gui

# Dry-run (preview what would be installed)
sudo ./bin/openvox-installer --dry-run

# With custom configuration file
sudo ./bin/openvox-installer --config /path/to/custom.conf

# Verbose output (for debugging)
sudo ./bin/openvox-installer --verbose
```

## Command-Line Options

| Option | Description |
|--------|-------------|
| `-c, --config FILE` | Path to configuration file |
| `-m, --mode MODE` | Installation mode: agent, server, complete |
| `--agent` | Install agent only (non-interactive) |
| `--server` | Install server (includes r10k) |
| `--gui` | Install OpenVox-GUI |
| `--non-interactive` | Run without prompting |
| `-d, --dry-run` | Show what would be done |
| `-f, --force` | Force installation even if already installed |
| `-s, --skip-preflight` | Skip preflight checks |
| `-v, --verbose` | Verbose output |
| `-h, --help` | Show help message |

## Configuration

### Configuration File

Edit `/etc/openvox/openvox.conf` (or use `-c` to specify a custom path):

```ini
[general]
server_hostname = openvox.example.com
r10k_remote = git@github.com:yourorg/control-repo.git
gui_port = 4567

[general]
non-interactive = true
```

### Interactive Prompts

If running interactively (without `--non-interactive`), you will be prompted for:

1. **Server hostname** (FQDN) - Required for server installations
2. **r10k control repository URL** - Required if installing r10k (server mode)
3. **GUI port** - Optional, defaults to 4567

### r10k Configuration

**Important:** r10k is a server-only component that requires a Git control repository.

The control repository URL can be provided via:
- Configuration file: `r10k_remote = git@github.com:org/control-repo.git`
- Interactive prompt (when running without `--non-interactive`)

Example control repo URLs:
- SSH: `git@github.com:yourorg/control-repo.git`
- HTTPS: `https://github.com/yourorg/control-repo.git`

## Project Structure

```
openvox-installer/
├── bin/
│   └── openvox-installer      # Main entry point
├── lib/
│   ├── functions.sh           # Common functions (OS detection, logging, etc.)
│   ├── agent.sh               # Agent installer
│   ├── server.sh             # Server (PuppetServer) installer
│   ├── puppetdb.sh           # PuppetDB installer
│   ├── r10k.sh               # r10k installer (server only)
│   ├── openbolt.sh           # OpenBolt installer
│   └── gui.sh                # OpenVox-GUI installer
├── etc/
│   └── openvox.conf.example  # Example configuration
└── README.md
```

## How It Works

### Installation Phases

1. **Preflight Checks**
   - OS detection and compatibility check
   - Root privilege verification
   - Disk space check (requires 15GB)
   - Network connectivity check (to voxpupuli.org, GitHub)

2. **Repository Setup**
   - Configures Vox Pupuli package repository
   - Imports GPG keys for package verification

3. **Component Installation**
   - Installs selected components based on mode/flags
   - Uses appropriate package manager (yum/dnf for RHEL, apt for Debian/Ubuntu)

4. **Post-Install Configuration**
   - Configures Puppet Server settings
   - Configures r10k with control repo URL
   - Sets up firewall rules (optional)
   - Configures SELinux (RHEL only)

5. **Verification**
   - Checks that installed services are running
   - Tests connectivity to services

### Component Details

#### OpenVox Agent
- Installs `puppet-agent` package from Vox Pupuli
- Configures agent to connect to server (if specified)
- Does NOT require r10k or server components

#### OpenVox Server (PuppetServer)
- Installs `puppetserver` package
- Configures server hostname and DNS alt names
- Enables and starts the puppetserver service

#### PuppetDB
- Installs `puppetdb` package and dependencies
- Configures database (embedded PostgreSQL by default)
- Enables and starts puppetdb service

#### r10k (Server Only)
- Installs r10k Ruby gem
- Creates configuration at `/etc/puppetlabs/r10k/r10k.yaml`
- Requires control repository URL
- Can deploy environments from Git branches

#### OpenVox-GUI
- Clones GitHub repository
- Runs the GUI's built-in installer
- Installs Python dependencies if needed

## Documentation

- [Project Plan](PROJECT_PLAN.md) - Detailed project specifications
- [Configuration Reference](etc/openvox.conf.example) - All config options

## Documentation Sources

- OpenVox Docs: https://github.com/cvquesty/voxdocs
- Vox Pupuli: https://voxpupuli.org
- r10k Documentation: https://github.com/puppetlabs/r10k
- OpenVox Project: https://github.com/openvoxproject
- OpenVox-GUI: https://github.com/cvquesty/openvox-gui

## Differences from puppet-openvox_bootstrap

This project differs from the Bolt-based approach:
- **Pure bash** - No Bolt/Puppet required to run the installer
- **Interactive mode** - Prompts for required values by default
- **INI config** - Simple configuration file format
- **Modular** - Each component has its own installer script
- **Server-only r10k** - r10k cannot be installed on standalone agents

## Troubleshooting

### Verbose Output

Run with `--verbose` flag to see detailed debug information:

```bash
sudo ./bin/openvox-installer --verbose
```

### Log File

Check the installation log for details:

```bash
tail -f /var/log/openvox/install.log
```

### Common Issues

1. **"Cannot reach yum.voxpupuli.org"** - Check network/firewall settings
2. **"Server hostname is required"** - Provide via config file or interactive prompt
3. **"r10k requires control repository URL"** - Provide r10k_remote in config or prompt
4. **"Insufficient disk space"** - Ensure at least 15GB available

## License

Apache License 2.0 - See LICENSE file

## AI Disclosure

| Contribution Type | Percentage |
|-------------------|------------|
| AI Assisted       | 100%       |
| Human Written     | 0%         |

**AI Models Used:**
- OpenClaw (primary agent - running on Ollama with minimax-m2.5:cloud model)
- GitHub CLI (gh) for repository operations

**Notes:**
- Initial skeleton and documentation created by AI assistant
- Jerald (human) provided project requirements and design decisions
- All commits include "Assisted by AI tools" in commit messages

## Author

CVQuesty
