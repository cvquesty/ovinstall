# OpenVox Automated Installer - Project Plan

## Project Overview

**Project Name:** ovinstall  
**Type:** Bash-based automated installation tool  
**Purpose:** Fully automated installation of the complete OpenVox server stack (Agent, Server, PuppetDB, r10k, OpenBolt, OpenVox-GUI) using yum.voxpupuli.org and apt.voxpupuli.org repositories  
**Configuration:** INI-style configuration file  
**Target Users:** System administrators deploying OpenVox infrastructure

---

## Scope

### Components to Install

| Component | Package Name | Description |
|-----------|--------------|-------------|
| OpenVox Agent | `openvox-agent` | Ruby-based agent for configuration management |
| OpenVox Server | `openvox-server` | PuppetServer (JRuby + Jetty) for catalog compilation |
| PuppetDB | `puppetdb` (or `openvoxdb`) | PostgreSQL-backed data warehouse |
| r10k | `r10k` | Git-to-environment deployer |
| OpenBolt | `openbolt` | Agentless orchestration tool |
| OpenVox-GUI | Git clone + install script | Web management UI |

### Supported Platforms

#### RHEL-based
- RHEL 8, 9, 10
- CentOS 8+
- Rocky Linux 8+
- AlmaLinux 8+
- Fedora 42+

#### Debian-based
- Debian 11 (Bullseye)
- Debian 12 (Bookworm)
- Ubuntu 22.04 (Jammy)
- Ubuntu 24.04 (Noble)

---

## Architecture

### Installation Modes

| CLI Mode | Components |
|----------|------------|
| `agent` | Agent only — connects to an existing server |
| `server` | Agent + Server + PuppetDB + r10k |
| `complete` | All of the above + OpenBolt + OpenVox-GUI |

### Configuration File Structure

The installer uses a **flat `key = value`** format (no INI sections).
See `etc/openvox.conf.example` for the authoritative reference.

```ini
# General
install_mode = complete
non_interactive = false

# Network
server_hostname = openvox.example.com

# r10k
r10k_remote = git@github.com:org/control-repo.git

# PuppetDB
puppetdb_database = internal
puppetdb_password = changeme
puppetdb_db_host = localhost
puppetdb_db_port = 5432
puppetdb_db_name = puppetdb
puppetdb_db_user = puppetdb

# OpenVox-GUI
gui_port = 4567

# Agent
certname = auto
runinterval = 30m

# Server
jvm_memory = 2g

# Security
firewall = false
selinux = permissive

# Logging
log_level = info
```

---

## Installation Phases

### Phase 1: Pre-Install Checks

- [ ] Verify OS version and architecture
- [ ] Check for sufficient disk space (15GB recommended)
- [ ] Verify network connectivity to voxpupuli.org
- [ ] Check for conflicting packages (puppet, pe-* packages)
- [ ] Validate configuration file syntax
- [ ] Check for root/sudo access
- [ ] Verify DNS resolution

### Phase 2: Repository Setup

- [ ] Detect OS family and version
- [ ] Download and install appropriate release package
  - RHEL: `openvox8-release-el-{8|9|10}.noarch.rpm`
  - Debian/Ubuntu: `openvox8-release-{codename}.deb`
- [ ] Import GPG keys
- [ ] Update package lists

### Phase 3: Component Installation

#### Agent Installation
- [ ] Install `openvox-agent` package
- [ ] Configure `puppet.conf`
- [ ] Set up SSL certificate handling
- [ ] Enable and start puppet service (optional)

#### Server Installation
- [ ] Install `openvox-server` package
- [ ] Configure PuppetServer memory (JAVA_ARGS)
- [ ] Configure server SSL certificates
- [ ] Enable and start `puppetserver` service

#### PuppetDB Installation
- [ ] Install `puppetdb` package
- [ ] Install and configure PostgreSQL (internal) or connect to external
- [ ] Configure PuppetDB SSL
- [ ] Update `puppet.conf` to use PuppetDB
- [ ] Enable and start `puppetdb` service

#### r10k Installation
- [ ] Install `r10k` gem or package
- [ ] Configure r10k.yaml
- [ ] Set up SSH keys for Git access
- [ ] Create initial Puppetfile
- [ ] Run initial r10k deployment

#### OpenBolt Installation
- [ ] Install `openbolt` package
- [ ] Configure bolt.yaml
- [ ] Configure SSH for bolt connections
- [ ] Set up inventory file

#### OpenVox-GUI Installation
- [ ] Install system dependencies (Python 3.10+, pip, venv)
- [ ] Clone openvox-gui repository
- [ ] Run install.sh with configuration
- [ ] Configure GUI to connect to local OpenVox Server
- [ ] Set up systemd service
- [ ] Configure SSL/TLS

### Phase 4: Post-Install Configuration

- [ ] Configure firewall rules (if enabled)
- [ ] Configure SELinux (if RHEL)
- [ ] Run initial Puppet agent run
- [ ] Verify all services are running
- [ ] Sign agent certificates (if autosign disabled)
- [ ] Run health checks

### Phase 5: Verification

- [ ] Verify all services are running
- [ ] Test agent-server connectivity
- [ ] Test PuppetDB connectivity
- [ ] Test r10k deployment
- [ ] Test OpenBolt connectivity
- [ ] Test OpenVox-GUI web interface
- [ ] Generate installation report

---

## File Structure

```
ovinstall/
├── bin/
│   └── ovinstall       # Main installer script (entry point)
├── etc/
│   └── openvox.conf.example    # Example configuration file
├── lib/
│   ├── functions.sh            # Common functions (logging, OS detection, repos)
│   ├── agent.sh                # OpenVox Agent installation
│   ├── server.sh               # OpenVox Server installation
│   ├── puppetdb.sh             # PuppetDB installation
│   ├── r10k.sh                 # r10k installation (server only)
│   ├── openbolt.sh             # OpenBolt installation
│   └── gui.sh                  # OpenVox-GUI installation
├── PROJECT_PLAN.md
└── README.md
```

---

## Installation Flow

```
START
  │
  ▼
┌──────────────────┐
│  Parse Config    │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Pre-Flight     │──── ERROR ────► ABORT
│  Checks         │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Setup Repo      │──── ERROR ────► ABORT
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Install Agent  │──── ERROR ────► ABORT
└────────┬─────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
 YES        NO
    │         │
    ▼         ▼
 Install   Skip
 Server     │
    │         │
    ▼         ▼
 Install   Skip
 PuppetDB   │
    │         │
    ▼         ▼
 Install   Skip
 r10k       │
    │         │
    ▼         ▼
 Install   Skip
 OpenBolt   │
    │         │
    ▼         ▼
 Install   Skip
 GUI       │
    │         │
    ▼         ▼
┌──────────────────┐
│  Post-Install   │
│  Configuration │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Health Check   │
└────────┬─────────┘
         │
         ▼
      COMPLETE
```

---

## Command Line Interface

```bash
# Interactive install (prompts for required values)
sudo ./bin/ovinstall

# Specify custom config
sudo ./bin/ovinstall -c /path/to/openvox.conf

# Install specific components
sudo ./bin/ovinstall --agent
sudo ./bin/ovinstall --server
sudo ./bin/ovinstall --gui
sudo ./bin/ovinstall --openbolt

# Installation modes
sudo ./bin/ovinstall --mode agent
sudo ./bin/ovinstall --mode server
sudo ./bin/ovinstall --mode complete

# Dry-run mode (show what would happen)
sudo ./bin/ovinstall --dry-run

# Skip preflight checks
sudo ./bin/ovinstall --skip-preflight

# Force reinstallation
sudo ./bin/ovinstall --force

# Non-interactive mode (no prompts)
sudo ./bin/ovinstall --non-interactive

# Show help
./bin/ovinstall --help
```

---

## Error Handling

- Each phase should be atomic and rollback-capable
- Log all actions to `/var/log/openvox/install.log`
- Provide clear error messages with remediation steps
- Support `--force` to override certain checks
- Support `--dry-run` to preview actions

---

## Dependencies

### System Dependencies
- bash >= 4.0
- curl/wget
- gnupg2
- apt-get (Debian) or yum/dnf (RHEL)
- systemd
- openssh-client

### For OpenVox-GUI
- Python >= 3.10
- pip
- venv module
- PostgreSQL client (for external DB)

---

## Future Enhancements (Phase 2)

- [ ] Support for high availability (multiple primaries)
- [ ] Backup and restore functionality
- [ ] Migration tools from Puppet Enterprise
- [ ] Container-based installation (Docker/Podman)
- [ ] Ansible integration
- [ ] Terraform modules
- [ ] Kubernetes operator
- [ ] Upgrade in-place functionality
- [ ] Multi-node orchestration support
- [ ] External node classifier (ENC) setup

---

## Testing Plan

1. **Unit Tests** - Test individual functions
2. **Integration Tests** - Test on clean VMs for each OS
3. **Upgrade Tests** - Test migration from previous versions
4. **Rollback Tests** - Verify rollback works correctly

### Test Matrix

| OS | Agent | Server | PuppetDB | r10k | OpenBolt | GUI |
|----|-------|--------|----------|------|----------|-----|
| RHEL 8 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| RHEL 9 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Rocky 9 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Ubuntu 22.04 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Ubuntu 24.04 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Debian 12 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

---

## Documentation

Current documentation:
- `README.md` — Overview, quick start, full option reference, troubleshooting
- `PROJECT_PLAN.md` — This file; project specs, roadmap, and test plan
- `etc/openvox.conf.example` — Annotated configuration file reference

Future documentation (Phase 2):
- `CHANGELOG.md` — Release notes
- `LICENSE` — Apache 2.0 license file
- `CONTRIBUTING.md` — How to contribute

---

## References

- OpenVox Documentation: https://github.com/cvquesty/voxdocs
- Vox Pupuli Repos: https://yum.voxpupuli.org, https://apt.voxpupuli.org
- OpenVox Project: https://github.com/openvoxproject
- OpenVox-GUI: https://github.com/cvquesty/openvox-gui
- Puppet docs-archive: https://github.com/puppetlabs/docs-archive

---

## Timeline Estimate

| Phase | Description | Estimated Time |
|-------|-------------|----------------|
| 1 | Core installer framework | 1 week |
| 2 | Agent + Server + PuppetDB | 1 week |
| 3 | r10k + OpenBolt | 3 days |
| 4 | OpenVox-GUI integration | 1 week |
| 5 | Testing and documentation | 1 week |
| **Total** | | **~5 weeks** |

---

## Notes

- This project differs from puppet-openvox_bootstrap (Bolt-based) by using pure bash
- Configuration is handled via INI file rather than command-line arguments or Hiera
- All packages are sourced from official Vox Pupuli repositories
- OpenVox-GUI must be installed on the same server as OpenVox Server (per GUI requirements)

---

*Project Plan created: 2026-03-10*  
*Ready for review and additional feature suggestions*
