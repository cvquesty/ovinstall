# ovinstall usage tutorial

Step-by-step guide for the bash installer in this repository (`v0.3.0`). Commands below match `bin/ovinstall` and `bin/ovinstall-maintenance` only.

## Prerequisites

- Root or `sudo`
- bash 4.0+, curl, and (for r10k / GUI) git
- Supported OS (RHEL-family 8+ / Fedora 42+, Debian 11–12, Ubuntu 22.04 / 24.04)
- About 15 GB free on `/`
- Network access to Vox Pupuli repos and (as needed) GitHub
- For server installs: a resolvable FQDN

## 1. Clone the installer

```bash
git clone https://github.com/cvquesty/ovinstall.git
cd ovinstall
```

## 2. Interactive install (default)

Prompts for server hostname (when installing a server), r10k control-repo URL (when r10k is selected), and GUI port (when GUI is selected).

```bash
sudo ./bin/ovinstall
```

Default mode is `complete` (agent + server + PuppetDB + r10k + OpenBolt + GUI) unless you pass flags or a config `install_mode`.

## 3. Preview with dry-run

```bash
sudo ./bin/ovinstall --dry-run
sudo ./bin/ovinstall --mode server --dry-run
```

No packages are installed; the script prints the planned component set.

## 4. Non-interactive install with a config file

```bash
sudo mkdir -p /etc/openvox
sudo cp etc/openvox.conf.example /etc/openvox/openvox.conf
sudoedit /etc/openvox/openvox.conf
```

Minimum for a server-style install:

```ini
server_hostname = openvox.example.com
r10k_remote = git@github.com:yourorg/control-repo.git
non_interactive = true
install_mode = complete
```

Then:

```bash
sudo ./bin/ovinstall --config /etc/openvox/openvox.conf --non-interactive
```

Keys actually read by `load_config` are listed in the README Configuration section. Keys present only in the example file (for example `download_cache_*`, `server_role`) are ignored today.

## 5. Installation modes

| Goal | Command |
|------|---------|
| Agent only | `sudo ./bin/ovinstall --agent` |
| Server (agent + Puppet Server + PuppetDB + r10k) | `sudo ./bin/ovinstall --server` |
| Everything including OpenBolt + GUI | `sudo ./bin/ovinstall --mode complete --non-interactive` |

`--agent` implies `--non-interactive`. You can also combine component flags such as `--gui` or `--openbolt` with an explicit selection.

## 6. Verbose logging and log file

```bash
sudo ./bin/ovinstall --verbose
tail -f /var/log/openvox/install.log
```

## 7. After install

- Review `/var/log/openvox/install.log`
- On a server, sign certificates if needed: `puppetserver ca sign --all`
- Apply catalog: `puppet agent -t`
- If GUI was installed, open `https://<server_hostname>:<gui_port>` (default port `4567`) and check `/opt/openvox-gui/config/.credentials`

## 8. Maintenance health check

```bash
sudo ./bin/ovinstall-maintenance --health
sudo ./bin/ovinstall-maintenance --status
```

Other maintenance actions (`--backup`, `--restore`, `--mode`, `--tune`, `--add` / `--remove`) are documented in the README Maintenance section. Prefer `--health` / `--status` first on a live host.

## 9. Common failures

| Symptom | What to check |
|---------|----------------|
| Cannot reach yum/apt.voxpupuli.org | Outbound HTTPS, proxy, DNS |
| Server hostname is required | Set `server_hostname` or answer the prompt |
| r10k requires control repository URL | Set `r10k_remote` |
| Insufficient disk space | Free space on `/` (15 GB) |
| Must be run as root | Re-run with `sudo` |

## See also

- [README](../README.md) — full CLI and config reference
- [etc/openvox.conf.example](../etc/openvox.conf.example) — annotated example file
- [TECHNICAL_DESIGN.md](../TECHNICAL_DESIGN.md) — as-built vs future design notes
