# 🏗️ OpenVox Installer — Technical Design Document

> *A production-ready, modular installer for OpenVox infrastructure.*
>
> *From zero to fully-deployed OpenVox server in a single command.*

---

## Executive Summary

This document describes the technical design for a production-ready OpenVox installer. The installer provisions a complete OpenVox infrastructure including:

1. **Repository configuration** (yum/apt for voxpupuli.org)
2. **Package installation** (OpenVox Server, Agent, OpenVoxDB)
3. **Service configuration** (puppetserver, puppetdb, puppet agent)
4. **Control repo integration** (clone, configure hiera)
5. **r10k deployment** (install, configure, deploy Puppetfile per environment)
6. **Initial agent run** (complete configuration)
7. **Modular architecture** (future catalog compilers, CA-only mode)
8. **Client download caching** (for fleet deployment)
9. **Maintenance tooling** (scale infrastructure up/down)

**Target Audience:** System administrators deploying OpenVox at scale.

**Design Principles:**
- **Modular** — each component is independently testable and replaceable
- **Idempotent** — safe to re-run; detects existing state
- **Production-ready** — proper error handling, logging, rollback
- **Extensible** — easy to add catalog compilers, CA-only mode
- **Well-documented** — every option explained, voxdocs style

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Module Structure](#2-module-structure)
3. [Installation Flow](#3-installation-flow)
4. [Repository Configuration](#4-repository-configuration)
5. [Component Installation](#5-component-installation)
6. [Service Configuration](#6-service-configuration)
7. [Control Repo Integration](#7-control-repo-integration)
8. [Hiera Configuration](#8-hiera-configuration)
9. [r10k and Puppetfile Deployment](#9-r10k-and-puppetfile-deployment)
10. [Modularity for Future Growth](#10-modularity-for-future-growth)
11. [Client Platform Support](#11-client-platform-support)
12. [Download Caching](#12-download-caching)
13. [Maintenance Script](#13-maintenance-script)
14. [Security Considerations](#14-security-considerations)
15. [Error Handling and Rollback](#15-error-handling-and-rollback)
16. [Configuration Reference](#16-configuration-reference)

---

## 1. Architecture Overview

### 1.1 High-Level Design

```
┌─────────────────────────────────────────────────────────────────────┐
│                        OpenVox Installer                            │
├─────────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌───────────┐ │
│  │   CLI/      │  │   Config    │  │   State     │  │   Logging │ │
│  │   Parser    │  │   Parser    │  │   Manager   │  │   System  │ │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └─────┬─────┘ │
│         │                │                │               │       │
│         └────────────────┴────────────────┴───────────────┘       │
│                              │                                      │
│                              ▼                                      │
│  ┌─────────────────────────────────────────────────────────────────┐│
│  │                      Orchestrator                               ││
│  │  (Coordinates all installation phases, handles errors)          ││
│  └─────────────────────────────────────────────────────────────────┘│
│                              │                                      │
│         ┌────────────────────┼────────────────────┐                 │
│         │                    │                    │                 │
│         ▼                    ▼                    ▼                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐             │
│  │   Repo      │    │  Package    │    │  Config     │             │
│  │   Module    │    │  Module     │    │  Module     │             │
│  └─────────────┘    └─────────────┘    └─────────────┘             │
│         │                    │                    │                 │
│         └────────────────────┴────────────────────┘                 │
│                              │                                      │
│         ┌────────────────────┼────────────────────┐                 │
│         │                    │                    │                 │
│         ▼                    ▼                    ▼                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐             │
│  │  Control    │    │   r10k      │    │  Maintenance│             │
│  │  Repo       │    │   Module    │    │  Module     │             │
│  │  Module     │    │             │    │             │             │
│  └─────────────┘    └─────────────┘    └─────────────┘             │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────────┐│
│  │                   Platform Modules                              ││
│  │  (client-platforms, download-cache, os-detection)               ││
│  └─────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────┘
```

### 1.2 Component Layers

| Layer | Purpose |
|-------|---------|
| **CLI Layer** | Parse arguments, load config, dispatch to orchestrator |
| **Orchestrator** | Coordinate phases, manage state, handle errors |
| **Core Modules** | Repo, Package, Config, Control Repo, r10k |
| **Platform Modules** | Client platforms, download caching, OS detection |
| **Maintenance** | Scale infrastructure up/down |

### 1.3 Design Principles

1. **Modularity** — Each module is a self-contained unit with clear interfaces
2. **Idempotency** — Every operation checks current state before acting
3. **Composability** — Modules can be combined for different deployment modes
4. **Extensibility** — New roles (catalog compiler, CA-only) are plugins
5. **Observability** — Structured logging, progress reporting, health checks

---

## 2. Module Structure

### 2.1 Directory Layout

```
openvox-installer/
├── bin/
│   └── openvox-installer          # Main entry point (Python or bash)
│
├── lib/
│   ├── core/
│   │   ├── __init__.py
│   │   ├── orchestrator.py        # Phase coordination
│   │   ├── config.py              # Configuration parsing
│   │   ├── state.py               # Installation state tracking
│   │   └── logging.py             # Structured logging
│   │
│   ├── modules/
│   │   ├── repo.py                # Yum/apt repo configuration
│   │   ├── packages.py            # Package installation
│   │   ├── config.py              # Service configuration
│   │   ├── control_repo.py        # Control repo + hiera setup
│   │   ├── r10k.py                # r10k installation + deployment
│   │   └── agent_run.py           # Initial puppet agent -t
│   │
│   ├── platform/
│   │   ├── os_detect.py           # OS family detection
│   │   ├── hardware_detect.py     # CPU/RAM detection
│   │   ├── client_platforms.py    # Client platform support
│   │   └── download_cache.py      # Download caching proxy
│   │
│   └── maintenance/
│       ├── scale.py               # Scale infrastructure
│       ├── health_check.py        # Verify installation
│       └── backup.py              # Configuration backups
│
├── etc/
│   ├── openvox.conf.example       # Example configuration
│   └── templates/                 # Config templates
│       ├── puppet.conf.j2
│       ├── puppetserver.conf.j2
│       ├── puppetdb.conf.j2
│       ├── r10k.yaml.j2
│       └── hiera.yaml.j2
│
├── docs/
│   ├── INSTALLATION.md
│   ├── CONFIGURATION.md
│   └── TROUBLESHOOTING.md
│
├── tests/
│   ├── unit/
│   └── integration/
│
├── CHANGELOG.md
├── LICENSE.md
├── README.md
└── TECHNICAL_DESIGN.md            # This document
```

### 2.2 Module Interfaces

Each module exposes a consistent interface:

```python
class Module:
    def __init__(self, config: Config, state: State):
        self.config = config
        self.state = state

    def check(self) -> CheckResult:
        """Check if this module needs to run."""
        pass

    def apply(self) -> ApplyResult:
        """Apply the module's configuration."""
        pass

    def rollback(self) -> RollbackResult:
        """Rollback changes if apply fails."""
        pass
```

### 2.3 State Management

The installer tracks installation state in a JSON file (e.g., `/var/lib/openvox-installer/state.json`):

```json
{
  "version": "0.1.0",
  "phases": {
    "repo_configured": "2026-03-24T10:00:00Z",
    "packages_installed": "2026-03-24T10:05:00Z",
    "services_configured": "2026-03-24T10:10:00Z",
    "control_repo_deployed": "2026-03-24T10:15:00Z",
    "r10k_deployed": "2026-03-24T10:20:00Z",
    "agent_run_complete": "2026-03-24T10:25:00Z"
  },
  "config_hash": "sha256:...",
  "components": {
    "openvox-agent": "8.25.0",
    "openvox-server": "8.12.1",
    "puppetdb": "8.x"
  }
}
```

---

## 3. Installation Flow

```
START
  │
  ▼
┌──────────────────────────┐
│  Parse CLI Arguments     │
│  Load Configuration      │
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│  Pre-Flight Checks       │
│  • OS version            │
│  • Disk space            │
│  • Network connectivity  │
│  • No conflicting pkgs   │
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│  Phase 1: Repo Setup     │
│  • Detect OS             │
│  • Install release pkg   │
│  • Import GPG keys       │
│  • Update package lists  │
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│  Phase 2: Install Pkgs   │
│  • openvox-agent         │
│  • openvox-server        │
│  • puppetdb              │
│  • r10k                  │
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│  Phase 3: Configure      │
│  • puppet.conf           │
│  • puppetserver.conf     │
│  • puppetdb.conf         │
│  • Connect all three     │
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│  Phase 4: Control Repo   │
│  • Clone control_repo    │
│  • Configure hiera       │
│  • Set up environments   │
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│  Phase 5: r10k Deploy    │
│  • Configure r10k.yaml   │
│  • Deploy Puppetfile     │
│  • Per-environment mods  │
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│  Phase 6: Finalize       │
│  • puppet agent -t       │
│  • Health checks         │
│  • Report generation     │
└────────────┬─────────────┘
             │
             ▼
         COMPLETE
```

---

## 4. Repository Configuration

### 4.1 Repo Module (`lib/modules/repo.py`)

**Responsibilities:**
- Detect OS family and version
- Download appropriate release package from voxpupuli.org
- Import GPG keys
- Configure repository
- Update package lists

**Release Package URLs:**

| OS | URL |
|----|-----|
| RHEL 8 | `https://yum.voxpupuli.org/openvox8-release-el-8.noarch.rpm` |
| RHEL 9 | `https://yum.voxpupuli.org/openvox8-release-el-9.noarch.rpm` |
| RHEL 10 | `https://yum.voxpupuli.org/openvox8-release-el-10.noarch.rpm` |
| Debian 11 | `https://apt.voxpupuli.org/openvox8-release-bullseye.deb` |
| Debian 12 | `https://apt.voxpupuli.org/openvox8-release-bookworm.deb` |
| Ubuntu 22.04 | `https://apt.voxpupuli.org/openvox8-release-jammy.deb` |
| Ubuntu 24.04 | `https://apt.voxpupuli.org/openvox8-release-noble.deb` |

**Implementation:**

```python
class RepoModule(Module):
    def check(self) -> CheckResult:
        # Check if voxpupuli repo is configured
        if self._os_family == "rhel":
            return CheckResult(
                needed=not Path("/etc/yum.repos.d/voxpupuli-openvox.repo").exists()
            )
        else:
            return CheckResult(
                needed=not Path("/etc/apt/sources.list.d/voxpupuli-openvox.list").exists()
            )

    def apply(self) -> ApplyResult:
        # Download release package
        # Install package (rpm -i or dpkg -i)
        # Update cache (yum update or apt update)
        pass
```

---

## 5. Component Installation

### 5.1 Package Module (`lib/modules/packages.py`)

**Packages to Install:**

| Component | RHEL Package | Debian Package |
|-----------|--------------|----------------|
| OpenVox Agent | `openvox-agent` | `openvox-agent` |
| OpenVox Server | `openvox-server` | `openvox-server` |
| OpenVoxDB | `puppetdb` | `puppetdb` |
| r10k | `r10k` | `r10k` |

**Installation Strategy:**

1. Use system package manager (yum/dnf or apt)
2. Install in dependency order (agent → server → db → r10k)
3. Verify installation with `rpm -q` or `dpkg -l`

```python
def install_packages(packages: List[str]) -> InstallResult:
    if os_family == "rhel":
        cmd = ["yum", "install", "-y"] + packages
    else:
        cmd = ["apt-get", "install", "-y"] + packages

    result = subprocess.run(cmd, capture_output=True, text=True)
    return InstallResult(success=result.returncode == 0, output=result.stdout)
```

---

## 6. Service Configuration

### 6.1 Configuration Module (`lib/modules/config.py`)

**Configuration Files:**

| File | Purpose |
|------|---------|
| `/etc/puppetlabs/puppet/puppet.conf` | Agent + server base config |
| `/etc/puppetlabs/puppetserver/conf.d/puppetserver.conf` | JRuby, environments |
| `/etc/puppetlabs/puppetdb/conf.d/puppetdb.conf` | DB settings, connections |
| `/etc/sysconfig/puppetserver` | JVM heap, Java args |
| `/etc/sysconfig/puppetdb` | JVM heap for PuppetDB |

**Key Configuration Steps:**

1. **puppet.conf** — Set server, certname, environment, runinterval
2. **Connect Server to PuppetDB:**
   ```ini
   [main]
   storeconfigs = true
   storeconfigs_backend = puppetdb

   [master]
   reports = puppetdb
   ```
3. **Configure PuppetDB routes:**
   ```yaml
   # /etc/puppetlabs/puppet/routes.yaml
   master:
     facts:
       terminus: puppetdb
       cache: yaml
   ```
4. **JVM Heap** (from ovtune principles):
   ```bash
   JAVA_ARGS="-Xms4g -Xmx4g -Djruby.logger.class=..."
   ```

### 6.2 Connecting Components

After configuration, the components connect as:

```
┌─────────────┐     ┌─────────────────┐     ┌─────────────┐
│   Agent     │────▶│  OpenVox Server │────▶│  OpenVoxDB  │
│             │ SSL │                 │ SSL │             │
│ puppet -t   │     │ catalog compile │     │ facts,      │
│             │     │ reports         │     │ reports     │
└─────────────┘     └─────────────────┘     └─────────────┘
```

---

## 7. Control Repo Integration

### 7.1 Control Repo Module (`lib/modules/control_repo.py`)

**Responsibilities:**
- Clone control repo from supplied URL
- Configure environments directory structure
- Set up hiera configuration

**Configuration Flow:**

```python
def deploy_control_repo(config: Config) -> DeployResult:
    # 1. Clone control repo to /etc/puppetlabs/code/environments
    repo_url = config.control_repo_url  # e.g., git@github.com:org/control-repo.git
    environments_dir = "/etc/puppetlabs/code/environments"

    # Clone with r10k or git
    subprocess.run(["git", "clone", repo_url, environments_dir])

    # 2. Configure hiera.yaml
    configure_hiera(config)

    # 3. Ensure environment directories exist
    for env in config.environments:
        Path(f"{environments_dir}/{env}/modules").mkdir(parents=True, exist_ok=True)
```

### 7.2 Supported Control Repo Structure

```
control-repo/
├── Puppetfile              # r10k module declarations
├── hiera.yaml              # Hiera 5 config (or template)
├── environment.conf        # Per-environment settings
├── site.pp                 # Site manifest
├── manifests/              # Global manifests
├── data/                   # Hiera data
│   ├── common.yaml
│   └── nodes/
├── site/                   # Site-specific code
│   └── profile/
└── environments/           # (optional) per-env overrides
    ├── production/
    └── development/
```

---

## 8. Hiera Configuration

### 8.1 Hiera Module (`lib/modules/hiera.py`)

**Responsibilities:**
- Configure `/etc/puppetlabs/puppet/hiera.yaml`
- Set up hiera data directory
- Configure lookup functions

**Default Hiera Configuration:**

```yaml
# /etc/puppetlabs/puppet/hiera.yaml
version: 5

defaults:
  datadir: data
  data_hash: yaml_data

hierarchy:
  - name: "Per-node data"
    path: "nodes/%{trusted.certname}.yaml"

  - name: "Per-environment data"
    path: "%{environment}.yaml"

  - name: "Common data"
    path: "common.yaml"
```

**Integration with Control Repo:**

If control repo contains `hiera.yaml`, use it. Otherwise, install default and configure `datadir` to point to control repo's `data/` directory.

---

## 9. r10k and Puppetfile Deployment

### 9.1 r10k Module (`lib/modules/r10k.py`)

**Responsibilities:**
- Install r10k gem or package
- Configure `/etc/puppetlabs/r10k/r10k.yaml`
- Deploy Puppetfile for each environment

**r10k Configuration:**

```yaml
# /etc/puppetlabs/r10k/r10k.yaml
sources:
  control:
    remote: "git@github.com:org/control-repo.git"
    basedir: "/etc/puppetlabs/code/environments"

cachedir: "/var/cache/r10k"

postrun: []
```

**Puppetfile Deployment:**

For each environment, r10k reads `Puppetfile` and installs modules to `$moduledir`:

```ruby
# Puppetfile (in control-repo root or per-environment)
forge 'https://forge.voxpupuli.org'

mod 'puppetlabs/stdlib', '9.6.0'
mod 'puppetlabs/concat', '9.0.2'

mod 'profile',
  :git => 'https://github.com/org/profile.git',
  :ref => 'main'
```

**Deployment Command:**

```bash
r10k deploy environment -p
```

This deploys all environments and their modules to the respective `modules/` directories.

### 9.2 Per-Environment Module Deployment

```
environments/
├── production/
│   ├── Puppetfile
│   ├── environment.conf
│   └── modules/           # Populated by r10k
│       ├── stdlib/
│       ├── concat/
│       └── profile/
├── development/
│   ├── Puppetfile
│   └── modules/
└── common/                # Shared modules (optional)
    └── modules/
```

---

## 10. Modularity for Future Growth

### 10.1 Extension Points

The installer is designed to support:

1. **Catalog Compilers** — Dedicated servers for catalog compilation
2. **CA-Only Mode** — Main server handles only certificate operations
3. **External PuppetDB** — Connect to remote PuppetDB cluster

### 10.2 Catalog Compiler Module (Future)

```python
# lib/modules/catalog_compiler.py

class CatalogCompilerModule(Module):
    """Configure a catalog compiler (compile master)."""

    def apply(self):
        # 1. Install openvox-server only (no PuppetDB)
        # 2. Configure puppetserver.conf:
        #    - Point to central PuppetDB
        #    - Increase JRuby instances
        #    - Disable CA operations
        # 3. Configure load balancer (optional)
        pass
```

**Configuration for Compile Master:**

```hocon
# puppetserver.conf on compile master
jruby-puppet: {
    max-active-instances: 8
    master-conf-dir: /etc/puppetlabs/puppet
    master-code-dir: /etc/puppetlabs/code
}

# puppet.conf
[main]
ca_server = puppet-ca.example.com
```

### 10.3 CA-Only Mode (Future)

```python
class CAOnlyModule(Module):
    """Convert main server to CA-only operation."""

    def apply(self):
        # 1. Disable catalog compilation on main server
        # 2. Configure puppetserver.conf:
        #    - ca: true
        #    - Disable JRuby catalog compilation
        # 3. Point agents to compile masters
        pass
```

**Configuration for CA-Only:**

```hocon
# puppetserver.conf
jruby-puppet: {
    max-active-instances: 1  # Minimal for CA operations
}

# puppet.conf on agents
[main]
server = puppet-compile1.example.com
ca_server = puppet-ca.example.com
```

### 10.4 Module Registration

New modules register via entry points or config:

```yaml
# openvox.conf
extensions:
  - catalog_compiler:
      enabled: false
      hosts: [puppet-compile1, puppet-compile2]
  - ca_only:
      enabled: false
```

---

## 11. Client Platform Support

### 11.1 Client Platforms Module (`lib/platform/client_platforms.py`)

**Supported Client Platforms:**

| Platform | Agent Package | Repo |
|----------|---------------|------|
| RHEL 8, 9, 10 | `openvox-agent` | yum.voxpupuli.org |
| AlmaLinux 8, 9 | `openvox-agent` | yum.voxpupuli.org |
| Rocky Linux 8, 9 | `openvox-agent` | yum.voxpupuli.org |
| Debian 11, 12 | `openvox-agent` | apt.voxpupuli.org |
| Ubuntu 22.04, 24.04 | `openvox-agent` | apt.voxpupuli.org |
| Fedora 42+ | `openvox-agent` | yum.voxpupuli.org |
| Windows 10/11 | `openvox-agent` (MSI) | Download from repo |
| macOS 12+ | `openvox-agent` | Homebrew or pkg |

### 11.2 Agent Bootstrap

For client platforms, the installer can generate bootstrap scripts:

```bash
# Generated by installer for RHEL clients
cat > /var/www/html/openvox-agent-bootstrap.sh << 'EOF'
#!/bin/bash
rpm -Uvh https://yum.voxpupuli.org/openvox8-release-el-9.noarch.rpm
yum install -y openvox-agent
puppet config set server openvox.example.com
puppet agent --test
EOF
```

---

## 12. Download Caching

### 12.1 Download Cache Module (`lib/platform/download_cache.py`)

**Purpose:** Cache OpenVox packages for fleet deployment, reducing load on voxpupuli.org.

**Implementation Options:**

| Option | Description |
|--------|-------------|
| **Built-in proxy** | Simple HTTP cache in installer |
| **External proxy** | Configure existing Squid/HAProxy |
| **Local mirror** | Mirror voxpupuli.org repos locally |

**Recommended: Simple HTTP Cache**

```python
class DownloadCache:
    """Cache downloaded packages for fleet deployment."""

    def __init__(self, cache_dir="/var/cache/openvox-installer"):
        self.cache_dir = Path(cache_dir)
        self.cache_dir.mkdir(parents=True, exist_ok=True)

    def get_package(self, url: str) -> Path:
        """Download package (or return cached)."""
        cache_file = self.cache_dir / url.split("/")[-1]

        if cache_file.exists():
            return cache_file

        # Download and cache
        subprocess.run(["curl", "-o", str(cache_file), url])
        return cache_file
```

**Configuration:**

```ini
# openvox.conf
[download_cache]
enabled = true
cache_dir = /var/cache/openvox-installer
max_age_days = 7
```

---

## 13. Maintenance Script

### 13.1 Maintenance Module (`lib/maintenance/scale.py`)

**Purpose:** Scale OpenVox infrastructure up or down at will.

**Commands:**

```bash
# Add a compile master
openvox-maintenance --add compile-master --host puppet-compile2

# Remove a compile master
openvox-maintenance --remove compile-master --host puppet-compile2

# Scale PuppetDB (add replica)
openvox-maintenance --add puppetdb-replica --host puppetdb2

# Check health of all components
openvox-maintenance --health

# Backup configuration
openvox-maintenance --backup --to /backups/openvox-20240324

# Restore from backup
openvox-maintenance --restore --from /backups/openvox-20240324
```

**Implementation:**

```python
class MaintenanceCLI:
    """Maintenance and scaling CLI."""

    def add_compile_master(self, host: str):
        """Register a new compile master."""
        # 1. Generate config for compile master
        # 2. Optionally bootstrap via SSH
        # 3. Update load balancer config
        # 4. Update agent puppet.conf (if centralized)

    def remove_compile_master(self, host: str):
        """Remove a compile master."""
        # 1. Drain from load balancer
        # 2. Update agent configs
        # 3. Optionally shut down remote service

    def health_check(self) -> HealthReport:
        """Check health of all OpenVox components."""
        checks = [
            self._check_puppetserver(),
            self._check_puppetdb(),
            self._check_r10k(),
            self._check_agents(),
        ]
        return HealthReport(checks=checks)
```

### 13.2 Scaling Scenarios

| Scenario | Command |
|----------|---------|
| Add compile master | `--add compile-master --host new-compile` |
| Convert to CA-only | `--mode ca-only` (stops catalog compilation) |
| Add PuppetDB replica | `--add puppetdb-replica --host new-db` |
| Increase JRuby instances | `--tune jruby +2` |
| Scale down for maintenance | `--mode maintenance` (stops services) |

---

## 14. Security Considerations

### 14.1 Certificate Handling

- Installer generates SSL certificates via `puppetserver ca setup`
- Agent certificates signed automatically (or manually if autosign disabled)
- Private keys never logged or transmitted

### 14.2 Repository Security

- GPG keys imported from voxpupuli.org
- HTTPS-only repository access
- Package verification enabled

### 14.3 Secrets Management

- Control repo URL may contain SSH keys — stored securely
- Hiera eyaml keys generated or imported
- Database passwords configurable via environment or file

### 14.4 Least Privilege

- Installer requires root/sudo
- Services run as `puppet` user post-install
- File permissions set appropriately

---

## 15. Error Handling and Rollback

### 15.1 Error Handling

| Error Type | Handling |
|------------|----------|
| Network failure | Retry with backoff, fail after N attempts |
| Package install failure | Abort, suggest manual intervention |
| Configuration error | Validate before applying, show diff |
| Service start failure | Collect logs, suggest troubleshooting |

### 15.2 Rollback

On `--apply` failure, installer can rollback:

```bash
# Automatic rollback on error
openvox-installer --apply --rollback-on-error

# Manual rollback
openvox-installer --rollback
```

Rollback restores:
- Previous sysconfig files (from `.bak` files)
- Previous HOCON configs
- Previous environment state

---

## 16. Configuration Reference

### 16.1 Complete Configuration Example

```ini
# openvox.conf — Production OpenVox Server

# ─── General ─────────────────────────────────────────────────────
install_mode = complete
non_interactive = true
log_level = info

# ─── Network ─────────────────────────────────────────────────────
server_hostname = openvox.example.com
server_port = 8140

# ─── Control Repo ────────────────────────────────────────────────
control_repo_url = git@github.com:org/openvox-control-repo.git
control_repo_branch = main

# ─── Environments ────────────────────────────────────────────────
environments = production,development,staging

# ─── r10k ────────────────────────────────────────────────────────
r10k_remote = git@github.com:org/openvox-control-repo.git
r10k_cachedir = /var/cache/r10k
r10k_postrun = true

# ─── PuppetDB ────────────────────────────────────────────────────
puppetdb_database = internal
puppetdb_password = ${PUPPETDB_PASSWORD}
puppetdb_db_host = localhost
puppetdb_db_port = 5432
puppetdb_db_name = puppetdb
puppetdb_db_user = puppetdb

# ─── OpenVox-GUI (optional) ──────────────────────────────────────
gui_enabled = true
gui_port = 4567

# ─── Agent ───────────────────────────────────────────────────────
certname = auto
runinterval = 30m
environment = production

# ─── Server ──────────────────────────────────────────────────────
jvm_memory = 4g
jruby_instances = 4

# ─── Security ────────────────────────────────────────────────────
firewall = true
selinux = enforcing
autosign = false

# ─── Download Cache ──────────────────────────────────────────────
download_cache.enabled = true
download_cache.cache_dir = /var/cache/openvox-installer
download_cache.max_age_days = 7

# ─── Extensions (future) ─────────────────────────────────────────
extensions.catalog_compiler.enabled = false
extensions.ca_only.enabled = false
```

---

## Appendix A: File Templates

### puppet.conf Template

```ini
[main]
server = {{ server_hostname }}
environment = {{ environment }}
runinterval = {{ runinterval }}
autosign = {{ autosign }}

[agent]
certname = {{ certname }}
report = true
graph = true

[server]
reports = puppetdb
storeconfigs = true
storeconfigs_backend = puppetdb
```

### r10k.yaml Template

```yaml
sources:
  control:
    remote: "{{ r10k_remote }}"
    basedir: "/etc/puppetlabs/code/environments"

cachedir: "{{ r10k_cachedir }}"
postrun:
{% if r10k_postrun %}
  - "curl -X DELETE https://{{ server_hostname }}:8140/puppet-admin-api/v1/environment-cache"
{% endif %}
```

---

## Appendix B: Related Documentation

- [VoxDocs Server Admin Guide](https://github.com/cvquesty/voxdocs/blob/main/server-admin/README.md)
- [OpenVox Tuning with OVTune](https://github.com/cvquesty/ovtune)
- [Puppet 8 Documentation Archive](https://github.com/puppetlabs/docs-archive)

---

*This document is a living specification. Update as implementation progresses.*

**Document Version:** 1.0  
**Last Updated:** 2026-03-24  
**Author:** OpenVox Community
