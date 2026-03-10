# OpenVox Automated Installer - Project Plan

## Project Overview

**Project Name:** openvox-installer  
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

1. **Standalone Agent** - Agent only, connects to existing server
2. **Full Server** - Agent + Server + PuppetDB
3. **Complete Stack** - Full Server + r10k + OpenBolt + OpenVox-GUI

### Configuration File Structure

```ini
[general]
install_mode = full_server  ; standalone_agent | full_server | complete_stack
environment = production
offline_mode = false

[network]
server_hostname = openvox.example.com
server_ip = 192.168.1.10
agent_server = openvox.example.com
dns_servers = 8.8.8.8,8.8.4.4
ntp_server = pool.ntp.org

[openvox]
agent_version = 8.25.0
server_version = 8.12.1

[puppetdb]
database = internal  ; internal | external
db_host = localhost
db_port = 5432
db_name = puppetdb
db_user = puppetdb
db_password = changeme

[r10k]
remote = git@github.com:org/control-repo.git
private_key = /etc/puppetlabs/puppetserver/ssh/id_rsa
r10k_version = 5.0.2

[openbolt]
install = true
openbolt_version = 5.3.0

[openvox_gui]
install = true
gui_port = 4567
gui_host = 0.0.0.0
gui_ssl = true
gui_cert = /etc/puppetlabs/puppet/ssl/certs/openvox.example.com.pem
gui_key = /etc/puppetlabs/puppet/ssl/private_keys/openvox.example.com.pem

[security]
firewall = true
selinux = permissive  ; enforcing | permissive | disabled (RHEL)
certname = auto  ; auto uses hostname
autosign = false

[backup]
enable = true
backup_dir = /var/backups/openvox

[logging]
log_level = notice  ; debug | info | notice | warning | err
syslog = false
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
openvox-installer/
├── bin/
│   └── openvox-installer          # Main installer script
├── etc/
│   └── openvox.conf.example       # Example configuration
├── lib/
│   ├── functions.sh               # Common functions
│   ├── repo.sh                    # Repository setup
│   ├── agent.sh                   # Agent installation
│   ├── server.sh                  # Server installation
│   ├── puppetdb.sh                # PuppetDB installation
│   ├── r10k.sh                    # r10k installation
│   ├── openbolt.sh                # OpenBolt installation
│   └── gui.sh                     # OpenVox-GUI installation
├── scripts/
│   ├── preflight.sh               # Pre-installation checks
│   ├── postinstall.sh             # Post-installation tasks
│   └── healthcheck.sh            # Health verification
├── templates/
│   ├── puppet.conf.agent.template
│   ├── puppet.conf.server.template
│   ├── r10k.yaml.template
│   ├── bolt.yaml.template
│   └── openvox-gui.ini.template
├── CHANGELOG.md
├── README.md
├── LICENSE
└── CONTRIBUTING.md
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
# Install with default options (requires root)
sudo ./openvox-installer

# Specify custom config
sudo ./openvox-installer -c /path/to/custom.conf

# Install specific components only
sudo ./openvox-installer --agent-only
sudo ./openvox-installer --server-only
sudo ./openvox-installer --gui-only

# Dry-run mode (show what would happen)
sudo ./openvox-installer --dry-run

# Skip preflight checks
sudo ./openvox-installer --skip-preflight

# Force reinstallation
sudo ./openvox-installer --force

# Unattended mode (no prompts)
sudo ./openvox-installer --unattended

# Show help
./openvox-installer --help
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

## Documentation Requirements

- README.md - Overview and quick start
- INSTALL.md - Detailed installation guide
- CONFIG.md - Configuration file reference
- UPGRADE.md - Upgrade instructions
- TROUBLESHOOTING.md - Common issues and solutions
- CONTRIBUTING.md - How to contribute

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
