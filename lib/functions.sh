#!/bin/bash
#
# =============================================================================
# ovinstall - Common Functions Library
# =============================================================================
# Provides shared utilities for all component installers:
# - Logging functions (console + file)
# - Configuration file parsing (flat key=value format)
# - OS detection and validation
# - Package management helpers
# - Repository configuration (yum/apt)
# - Firewall and SELinux helpers
# - Service verification
# =============================================================================

# Global variables for OS detection (populated by detect_os)
OS_FAMILY=""          # Operating system family: rhel, debian, ubuntu
OS_VERSION=""         # Full OS version string (e.g., "8.7", "9", "22.04")
OS_MAJOR=""           # Major OS version number (e.g., "8", "9", "22")
OS_CODENAME=""        # Debian/Ubuntu codename (e.g., "jammy", "bullseye")
ARCH=""               # System architecture (e.g., x86_64, aarch64)
PACKAGE_MANAGER=""    # Package manager command: yum, apt

# =============================================================================
# SECTION: Configuration File Parsing
# =============================================================================
# Load configuration from a flat key=value config file.
# Lines beginning with '#' are comments. Blank lines are ignored.
# Section headers like [general] are silently skipped for compatibility
# but have no effect — all keys are in a single flat namespace.
#
# Usage:
#   load_config /path/to/openvox.conf
#
# Supported keys (see etc/openvox.conf.example for full reference):
#   server_hostname, r10k_remote, gui_port, install_mode, non_interactive,
#   certname, runinterval, jvm_memory, log_level, firewall, selinux,
#   gui_repo_url, gui_repo_ref, allow_untrusted_gui_repo,
#   bolt_insecure_ssh, puppetdb_database, puppetdb_password,
#   run_final_agent

load_config() {
    local config_file="$1"

    # Config file is optional — return cleanly if absent
    if [[ ! -f "$config_file" ]]; then
        log_debug "Config file not found: $config_file (using defaults)"
        return 0
    fi

    log_info "Loading configuration from: $config_file"

    # Read config file line by line
    while IFS='=' read -r key value; do
        # Skip empty lines, comments, and INI section headers
        [[ -z "$key" || "$key" =~ ^[[:space:]]*# || "$key" =~ ^[[:space:]]*\[ ]] && continue

        # Trim leading/trailing whitespace using parameter expansion
        # (avoids xargs which can mangle backslashes and quotes)
        key="${key#"${key%%[![:space:]]*}"}"
        key="${key%"${key##*[![:space:]]}"}"
        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"

        # Skip lines with no value
        [[ -z "$value" ]] && continue

        # Map config keys to shell variables
        case "$key" in
            server_hostname)     server_hostname="$value" ;;
            r10k_remote)         r10k_remote="$value" ;;
            gui_port)            gui_port="$value" ;;
            gui_repo_url)        gui_repo_url="$value" ;;
            gui_repo_ref)        gui_repo_ref="$value" ;;
            allow_untrusted_gui_repo)
                allow_untrusted_gui_repo="$value"
                ;;
            bolt_insecure_ssh)   bolt_insecure_ssh="$value" ;;
            install_mode|mode)   INSTALL_MODE="$value" ;;
            certname)            certname="$value" ;;
            runinterval)         runinterval="$value" ;;
            jvm_memory)          jvm_memory="$value" ;;
            log_level)           LOG_LEVEL="$value" ;;
            firewall)            firewall="$value" ;;
            selinux)             selinux="$value" ;;
            puppetdb_database)   puppetdb_database="$value" ;;
            puppetdb_password)   puppetdb_password="$value" ;;
            puppetdb_db_host)    puppetdb_db_host="$value" ;;
            puppetdb_db_port)    puppetdb_db_port="$value" ;;
            puppetdb_db_name)    puppetdb_db_name="$value" ;;
            puppetdb_db_user)    puppetdb_db_user="$value" ;;
            run_final_agent)     run_final_agent="$value" ;;
            non_interactive|non-interactive)
                [[ "$value" == "true" || "$value" == "yes" ]] && NONINTERACTIVE=true
                ;;
            *)
                log_debug "Ignoring unknown config key: $key"
                ;;
        esac
    done < "$config_file"

    log_info "Configuration loaded"
}


# =============================================================================
# SECTION: Configuration Validation (SEC-005)
# =============================================================================
# Fail closed on invalid operator-supplied values before install phases run.

_validate_hostname_value() {
    local name="$1"
    local label="$2"
    # Conservative hostname / certname charset: letters, digits, dots, hyphens
    if [[ ! "$name" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]]; then
        log_fatal "Invalid ${label}: '${name}' (allowed: letters, digits, dots, hyphens)"
    fi
    if [[ ${#name} -gt 253 ]]; then
        log_fatal "Invalid ${label}: exceeds 253 characters"
    fi
}

validate_config() {
    log_debug "Validating configuration values..."

    if [[ -n "${gui_port:-}" ]]; then
        if [[ ! "$gui_port" =~ ^[0-9]+$ ]] || [[ "$gui_port" -lt 1 || "$gui_port" -gt 65535 ]]; then
            log_fatal "Invalid gui_port: '${gui_port}' (must be integer 1-65535)"
        fi
    fi

    if [[ -n "${jvm_memory:-}" ]]; then
        if [[ ! "$jvm_memory" =~ ^[0-9]+[gGmMkK]$ ]]; then
            log_fatal "Invalid jvm_memory: '${jvm_memory}' (expected e.g. 2g, 512m)"
        fi
    fi

    if [[ -n "${server_hostname:-}" && "$server_hostname" != "auto" ]]; then
        _validate_hostname_value "$server_hostname" "server_hostname"
    fi

    if [[ -n "${certname:-}" && "$certname" != "auto" ]]; then
        _validate_hostname_value "$certname" "certname"
    fi

    if [[ -n "${r10k_remote:-}" ]]; then
        if [[ ! "$r10k_remote" =~ ^(git@[^[:space:]]+|https?://[^[:space:]]+|ssh://[^[:space:]]+)$ ]]; then
            log_fatal "Invalid r10k_remote: must look like a git URL (git@..., https://..., http://..., or ssh://...)"
        fi
    fi

    log_debug "Configuration validation passed"
}
# =============================================================================
# SECTION: Logging Functions
# =============================================================================
# Provides colored console output and optional file logging.
# Levels: DEBUG, INFO, WARN, ERROR, FATAL
#
# Console output uses ANSI colors. File output (when LOG_FILE is set)
# uses plain text with timestamps.

# Color codes for terminal output
RED='\033[0;31m'      # Error/Fatal
GREEN='\033[0;32m'    # Success/Info
YELLOW='\033[1;33m'   # Warning
BLUE='\033[0;34m'     # Debug
NC='\033[0m'          # No Color (reset)

# Internal helper: append a plain-text line to the log file (if configured)
_log_to_file() {
    local level="$1"; shift
    if [[ -n "${LOG_FILE:-}" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $*" >> "$LOG_FILE"
    fi
}

# Debug level logging — only shown when LOG_LEVEL=debug (verbose mode)
log_debug() {
    if [[ "${LOG_LEVEL:-info}" == "debug" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $*"
    fi
    _log_to_file "DEBUG" "$@"
}

# Info level logging — general informational messages
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
    _log_to_file "INFO" "$@"
}

# Warning level logging — non-fatal issues
log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
    _log_to_file "WARN" "$@"
}

# Error level logging — errors that should be addressed
log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
    _log_to_file "ERROR" "$@"
}

# Fatal error — logs the message and exits with code 1
log_fatal() {
    echo -e "${RED}[FATAL]${NC} $*" >&2
    _log_to_file "FATAL" "$@"
    exit 1
}

# =============================================================================
# SECTION: Logging Setup
# =============================================================================
# Set up file-based logging in addition to console output.
# Log file: /var/log/openvox/install.log
# Call this early in main() so all subsequent log_* calls are captured.

setup_logging() {
    mkdir -p /var/log/openvox

    LOG_FILE="/var/log/openvox/install.log"
    touch "$LOG_FILE"

    log_info "Logging to $LOG_FILE"
}

# =============================================================================
# SECTION: Privilege Check
# =============================================================================

check_privileges() {
    if [[ $EUID -ne 0 ]]; then
        log_fatal "This script must be run as root (use sudo)"
    fi
}

# =============================================================================
# SECTION: OS Detection
# =============================================================================
# Populates OS_FAMILY, OS_VERSION, OS_MAJOR, OS_CODENAME, ARCH, PACKAGE_MANAGER.

detect_os() {
    log_debug "Detecting operating system..."

    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release

        case "$ID" in
            rhel|centos|rocky|almalinux|fedora)
                OS_FAMILY="rhel"
                OS_VERSION="$VERSION_ID"
                PACKAGE_MANAGER="yum"
                ;;
            debian)
                OS_FAMILY="debian"
                OS_VERSION="$VERSION_ID"
                OS_CODENAME="${VERSION_CODENAME:-}"
                PACKAGE_MANAGER="apt"
                ;;
            ubuntu)
                OS_FAMILY="ubuntu"
                OS_VERSION="$VERSION_ID"
                OS_CODENAME="${VERSION_CODENAME:-}"
                PACKAGE_MANAGER="apt"
                ;;
            *)
                log_fatal "Unsupported OS: $ID"
                ;;
        esac
    elif [[ -f /etc/redhat-release ]]; then
        OS_FAMILY="rhel"
        OS_VERSION=$(grep -oE '[0-9]+(\.[0-9]+)?' /etc/redhat-release | head -1)
        PACKAGE_MANAGER="yum"
    else
        log_fatal "Cannot detect operating system"
    fi

    # Extract major version (e.g., "8" from "8.7", "22" from "22.04")
    OS_MAJOR="${OS_VERSION%%.*}"
    ARCH=$(uname -m)

    log_info "Detected: $OS_FAMILY $OS_VERSION ($ARCH)"
}

# =============================================================================
# SECTION: OS Compatibility Check
# =============================================================================

check_os() {
    detect_os

    local supported=false

    case "$OS_FAMILY" in
        rhel)
            # RHEL/CentOS/Rocky/Alma 8-10, Fedora 42+
            if [[ "$OS_MAJOR" =~ ^(8|9|10)$ ]] || [[ "$OS_MAJOR" -ge 42 ]]; then
                supported=true
            fi
            ;;
        debian)
            if [[ "$OS_MAJOR" =~ ^(11|12)$ ]]; then
                supported=true
            fi
            ;;
        ubuntu)
            if [[ "$OS_VERSION" =~ ^(22\.04|24\.04)$ ]]; then
                supported=true
            fi
            ;;
    esac

    if [[ "$supported" != "true" ]]; then
        log_warn "OS version $OS_FAMILY $OS_VERSION is not officially supported. Continuing anyway..."
    fi
}

# =============================================================================
# SECTION: Disk Space Check
# =============================================================================

check_disk_space() {
    log_debug "Checking disk space..."

    local required_mb=15000
    local available_mb
    available_mb=$(df -m / | awk 'NR==2 {print $4}')

    if [[ "$available_mb" -lt "$required_mb" ]]; then
        log_error "Insufficient disk space. Required: ${required_mb}MB, Available: ${available_mb}MB"
        return 1
    fi

    log_info "Disk space OK: ${available_mb}MB available"
}

# =============================================================================
# SECTION: Network Connectivity Check
# =============================================================================
# Uses bash built-in /dev/tcp to avoid requiring netcat.

check_network() {
    log_debug "Checking network connectivity..."

    local test_hosts=(
        "yum.voxpupuli.org"
        "apt.voxpupuli.org"
        "github.com"
    )

    for host in "${test_hosts[@]}"; do
        if ! timeout 5 bash -c "echo >/dev/tcp/$host/443" 2>/dev/null; then
            log_warn "Cannot reach $host on port 443"
        fi
    done

    log_info "Network connectivity check complete"
}

# =============================================================================
# SECTION: Preflight Checks (orchestrator)
# =============================================================================

run_preflight() {
    log_info "Running preflight checks..."
    check_os
    check_disk_space
    check_network
    log_info "Preflight checks complete"
}

# =============================================================================
# SECTION: Package Management Helpers
# =============================================================================

# Check if a package is installed
is_package_installed() {
    local package="$1"

    case "$PACKAGE_MANAGER" in
        yum)
            rpm -q "$package" &>/dev/null
            ;;
        apt)
            dpkg -s "$package" 2>/dev/null | grep -q "Status: install ok installed"
            ;;
        *)
            # Unknown package manager — assume not installed
            return 1
            ;;
    esac
}

# Install one or more packages (idempotent — skips already-installed)
install_package() {
    local packages=("$@")

    # For apt, run update once before installing any packages
    if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        apt-get update -qq
    fi

    local pkg
    for pkg in "${packages[@]}"; do
        if is_package_installed "$pkg"; then
            log_debug "Package already installed: $pkg"
        else
            log_info "Installing package: $pkg"
            case "$PACKAGE_MANAGER" in
                yum)
                    yum install -y "$pkg" || dnf install -y "$pkg"
                    ;;
                apt)
                    apt-get install -y -qq "$pkg"
                    ;;
                *)
                    log_fatal "Unknown package manager: $PACKAGE_MANAGER"
                    ;;
            esac
        fi
    done
}

# =============================================================================
# SECTION: Repository Setup
# =============================================================================

# Setup Vox Pupuli package repository (dispatches to yum or apt)
setup_vox_repo() {
    log_info "Setting up Vox Pupuli repository..."

    case "$OS_FAMILY" in
        rhel)
            setup_yum_repo
            ;;
        debian|ubuntu)
            setup_apt_repo
            ;;
    esac
}

# Setup YUM repository for RHEL-family systems
setup_yum_repo() {
    local repo_rpm=""

    # Determine correct RPM based on OS major version
    # RHEL 10 and Fedora 42+ currently use the EL-9 release package
    case "$OS_MAJOR" in
        8|9)
            repo_rpm="openvox8-release-el-${OS_MAJOR}.noarch.rpm"
            ;;
        10)
            # RHEL 10 — use EL-9 package until a dedicated one is available
            repo_rpm="openvox8-release-el-9.noarch.rpm"
            ;;
        *)
            if [[ "$OS_MAJOR" -ge 42 ]]; then
                # Fedora 42+ — use EL-9 package
                repo_rpm="openvox8-release-el-9.noarch.rpm"
            else
                log_fatal "Unsupported RHEL-family version: $OS_VERSION"
            fi
            ;;
    esac

    if is_package_installed "openvox8-release"; then
        log_debug "Repository already configured"
        return 0
    fi

    local repo_url="https://yum.voxpupuli.org/$repo_rpm"
    local gpg_key_url="https://yum.voxpupuli.org/RPM-GPG-KEY-VoxPupuli"
    log_info "Installing repository package: $repo_url"

    local tmp_dir="/tmp/openvox-repo"
    mkdir -p "$tmp_dir"

    # SEC-006: import GPG key before installing the release RPM
    log_info "Importing Vox Pupuli RPM GPG key before release package install"
    if ! rpm --import "$gpg_key_url"; then
        log_fatal "Failed to import GPG key: $gpg_key_url"
    fi

    if curl -fsSL -o "${tmp_dir}/${repo_rpm}" "$repo_url"; then
        rpm -ivh "${tmp_dir}/${repo_rpm}"
    else
        log_fatal "Failed to download repository package: $repo_url"
    fi

    yum clean metadata

    rm -rf "$tmp_dir"
    log_info "YUM repository configured successfully"
}

# Setup APT repository for Debian/Ubuntu systems
# Uses the modern signed-by keyring approach (apt-key is deprecated)
setup_apt_repo() {
    local repo_deb="openvox8-release-${OS_CODENAME}.deb"

    if is_package_installed "openvox8-release"; then
        log_debug "Repository already configured"
        return 0
    fi

    local repo_url="https://apt.voxpupuli.org/$repo_deb"
    log_info "Installing repository package: $repo_url"

    local tmp_dir="/tmp/openvox-repo"
    mkdir -p "$tmp_dir"

    if curl -fsSL -o "${tmp_dir}/${repo_deb}" "$repo_url"; then
        dpkg -i "${tmp_dir}/${repo_deb}"
    else
        log_fatal "Failed to download repository package: $repo_url"
    fi

    # Import GPG key using modern keyring (apt-key is deprecated).
    # Key source: https://apt.voxpupuli.org/GPG-KEY (Vox Pupuli archive signing key).
    local keyring_dir="/usr/share/keyrings"
    mkdir -p "$keyring_dir"
    curl -fsSL https://apt.voxpupuli.org/GPG-KEY \
        | gpg --dearmor -o "${keyring_dir}/voxpupuli-archive-keyring.gpg" 2>/dev/null

    apt-get update -qq

    rm -rf "$tmp_dir"
    log_info "APT repository configured successfully"
}

# =============================================================================
# SECTION: Firewall Configuration
# =============================================================================
# Opens ports only for the components being installed.

configure_firewall() {
    log_info "Configuring firewall..."

    # SEC-012: explicit firewall=false skips rules even if firewalld is active.
    # Unset keeps today's behavior (configure when firewalld is active).
    local fw_setting="${firewall:-}"
    if [[ "$fw_setting" == "false" || "$fw_setting" == "no" || "$fw_setting" == "0" ]]; then
        log_info "Skipping firewall configuration (firewall=${fw_setting})"
        return 0
    fi

    if ! systemctl is-active --quiet firewalld 2>/dev/null; then
        if [[ "$fw_setting" == "true" || "$fw_setting" == "yes" || "$fw_setting" == "1" ]]; then
            log_warn "firewall=true but firewalld is not active; no rules applied"
        else
            log_debug "firewalld not running, skipping firewall configuration"
        fi
        return 0
    fi

    log_info "Configuring firewalld rules..."

    # Open ports only for components that are being installed
    if [[ "$INSTALL_SERVER" == "true" ]]; then
        firewall-cmd --permanent --add-port=8140/tcp   # PuppetServer
        firewall-cmd --permanent --add-port=8081/tcp   # PuppetDB
    fi

    if [[ "$INSTALL_GUI" == "true" ]]; then
        firewall-cmd --permanent --add-port="${gui_port:-4567}/tcp"  # OpenVox-GUI
    fi

    firewall-cmd --reload
    log_info "Firewall rules added"
}

# =============================================================================
# SECTION: SELinux Configuration
# =============================================================================

configure_selinux() {
    # Only relevant for RHEL-based systems
    if [[ "$OS_FAMILY" != "rhel" ]]; then
        return 0
    fi

    log_info "Configuring SELinux..."

    local desired="${selinux:-}"
    if [[ -n "$desired" ]]; then
        desired="$(echo "$desired" | tr '[:upper:]' '[:lower:]')"
        case "$desired" in
            enforcing|permissive|disabled)
                if command -v setenforce &>/dev/null || command -v getenforce &>/dev/null; then
                    case "$desired" in
                        enforcing)
                            setenforce 1 2>/dev/null || log_warn "Could not set SELinux to enforcing (may require reboot/config)"
                            ;;
                        permissive)
                            setenforce 0 2>/dev/null || log_warn "Could not set SELinux to permissive"
                            ;;
                        disabled)
                            log_warn "selinux=disabled requested: runtime disable is limited; set SELINUX=disabled in /etc/selinux/config and reboot to fully disable"
                            setenforce 0 2>/dev/null || true
                            ;;
                    esac
                    log_info "SELinux desired mode: $desired (current: $(getenforce 2>/dev/null || echo unknown))"
                else
                    log_warn "SELinux tools not available; cannot apply selinux=${desired}"
                fi
                ;;
            *)
                log_fatal "Invalid selinux value: '${selinux}' (expected enforcing, permissive, or disabled)"
                ;;
        esac
        return 0
    fi

    # Unset: keep warn-only advice when enforcing
    if command -v getenforce &>/dev/null; then
        local selinux_status
        selinux_status=$(getenforce 2>/dev/null || echo "Unknown")

        if [[ "$selinux_status" == "Enforcing" ]]; then
            log_warn "SELinux is enforcing. You may need to set appropriate contexts."
            log_info "Run: semanage fcontext -a -t puppet_var_t '/var/log/openvox(/.*)?'"
        fi
    fi
}

# =============================================================================
# SECTION: Service Management
# =============================================================================

configure_services() {
    log_info "Configuring services..."

    if [[ "$INSTALL_SERVER" == "true" ]]; then
        systemctl enable puppetserver 2>/dev/null || true
        systemctl enable puppetdb 2>/dev/null || true
    fi
}

# =============================================================================
# SECTION: Verification
# =============================================================================

verify_services() {
    log_info "Verifying services..."

    local services=()

    [[ "$INSTALL_SERVER" == "true" ]] && services+=("puppetserver" "puppetdb")
    [[ "$INSTALL_GUI" == "true" ]]    && services+=("openvox-gui")

    for svc in "${services[@]}"; do
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            log_info "Service $svc is running"
        else
            log_warn "Service $svc is not running (may need to be started)"
        fi
    done
}

verify_connectivity() {
    log_info "Verifying connectivity..."

    # Test PuppetServer
    if [[ "$INSTALL_SERVER" == "true" ]]; then
        if curl -sk https://localhost:8140/puppet/v3/ 2>/dev/null; then
            log_info "PuppetServer is reachable"
        else
            log_warn "PuppetServer is not yet responding (normal on first startup)"
        fi

        # Test PuppetDB
        if curl -sk https://localhost:8081/pdb/query/v4/version 2>/dev/null; then
            log_info "PuppetDB is reachable"
        else
            log_warn "PuppetDB is not yet responding (normal on first startup)"
        fi
    fi
}
