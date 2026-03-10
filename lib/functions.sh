#!/bin/bash
#
# =============================================================================
# OpenVox Installer - Common Functions Library
# =============================================================================
# Provides shared utilities for all component installers:
# - OS detection and validation
# - Package management
# - Repository configuration
# - Logging functions
# - Configuration file parsing
# =============================================================================

# Global variables for OS detection
OS_FAMILY=""          # Operating system family: rhel, debian, ubuntu
OS_VERSION=""        # OS version number (e.g., "8", "9", "22.04")
OS_CODENAME=""       # Debian/Ubuntu codename (e.g., "jammy", "bullseye")
ARCH=""              # System architecture (e.g., x86_64, aarch64)
PACKAGE_MANAGER=""   # Package manager: yum, apt

# =============================================================================
# SECTION: Configuration File Parsing
# =============================================================================
# Load configuration from INI-style config file.
# This function reads key=value pairs from a config file and sets shell variables.
# Supports sections but currently just reads [general] section keys.
#
# Usage:
#   load_config /path/to/config.ini
#
# Config file format:
#   [general]
#   server_hostname = openvox.example.com
#   r10k_remote = git@github.com:org/control-repo.git
#   gui_port = 4567

load_config() {
    local config_file="$1"
    
    # Check if config file exists
    if [[ ! -f "$config_file" ]]; then
        log_warn "Config file not found: $config_file"
        return 0
    fi
    
    log_info "Loading configuration from: $config_file"
    
    # Read config file line by line
    # This is a simple parser that handles key=value pairs
    while IFS='=' read -r key value; do
        # Skip empty lines and comments
        [[ -z "$key" || "$key" =~ ^# ]] && continue
        
        # Trim whitespace from key and value
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        
        # Skip empty values
        [[ -z "$value" ]] && continue
        
        # Set shell variables based on config keys
        case "$key" in
            server_hostname)
                server_hostname="$value"
                ;;
            r10k_remote)
                r10k_remote="$value"
                ;;
            gui_port)
                gui_port="$value"
                ;;
            install_mode|mode)
                INSTALL_MODE="$value"
                ;;
            non_interactive|non-interactive)
                [[ "$value" == "true" || "$value" == "yes" ]] && NONINTERACTIVE=true
                ;;
        esac
    done < "$config_file"
    
    log_info "Configuration loaded"
}

# =============================================================================
# SECTION: Logging Functions
# =============================================================================
# Provides colored logging output at different levels:
# - DEBUG: Detailed debug information
# - INFO:  General informational messages
# - WARN:  Warning messages
# - ERROR: Error messages
# - FATAL: Fatal errors that cause script to exit

# Color codes for terminal output
RED='\033[0;31m'      # Error/Fatal
GREEN='\033[0;32m'    # Success/Info
YELLOW='\033[1;33m'   # Warning
BLUE='\033[0;34m'     # Debug
NC='\033[0m'          # No Color (reset)

# Debug level logging - only shown in verbose mode
log_debug() {
    [[ "$LOG_LEVEL" == "debug" ]] && echo -e "${BLUE}[DEBUG]${NC} $*"
}

# Info level logging - general informational messages
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

# Warning level logging - non-fatal issues that don't stop execution
log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

# Error level logging - errors that should be addressed
log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Fatal error - prints error and exits with code 1
log_fatal() {
    log_error "$@"
    exit 1
}

# =============================================================================
# SECTION: Logging Setup
# =============================================================================
# Set up file-based logging in addition to console output.
# Log file is created at /var/log/openvox/install.log

setup_logging() {
    # Create log directory if it doesn't exist
    mkdir -p /var/log/openvox
    
    # Set log file path
    LOG_FILE="/var/log/openvox/install.log"
    
    # Create log file if it doesn't exist
    touch "$LOG_FILE"
    
    # Log startup to file
    echo "$(date '+%Y-%m-%d %H:%M:%S') - OpenVox installation started" >> "$LOG_FILE"
    
    log_info "Logging to $LOG_FILE"
}

# Check if running as root
check_privileges() {
    if [[ $EUID -ne 0 ]]; then
        log_fatal "This script must be run as root"
    fi
}

# Detect operating system
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
                OS_CODENAME="$VERSION_CODENAME"
                PACKAGE_MANAGER="apt"
                ;;
            ubuntu)
                OS_FAMILY="ubuntu"
                OS_VERSION="$VERSION_ID"
                OS_CODENAME="$VERSION_CODENAME"
                PACKAGE_MANAGER="apt"
                ;;
            *)
                log_fatal "Unsupported OS: $ID"
                ;;
        esac
    elif [[ -f /etc/redhat-release ]]; then
        OS_FAMILY="rhel"
        if grep -q "CentOS" /etc/redhat-release; then
            OS_VERSION=$(grep -oE '[0-9]+\.[0-9]+' /etc/redhat-release | head -1)
        fi
        PACKAGE_MANAGER="yum"
    else
        log_fatal "Cannot detect operating system"
    fi
    
    ARCH=$(uname -m)
    
    log_info "Detected: $OS_FAMILY $OS_VERSION ($ARCH)"
}

# Check OS compatibility
check_os() {
    detect_os
    
    local supported=false
    
    case "$OS_FAMILY" in
        rhel)
            if [[ "$OS_VERSION" =~ ^8|^9|^10 ]] || [[ "$OS_VERSION" -ge 42 ]]; then
                supported=true
            fi
            ;;
        debian)
            if [[ "$OS_VERSION" =~ ^11|^12 ]]; then
                supported=true
            fi
            ;;
        ubuntu)
            if [[ "$OS_VERSION" =~ ^22\.04|^24\.04 ]]; then
                supported=true
            fi
            ;;
    esac
    
    if [[ "$supported" != "true" ]]; then
        log_warn "Unsupported OS version. Continuing anyway..."
    fi
}

# Check disk space
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

# Check network connectivity
check_network() {
    log_debug "Checking network connectivity..."
    
    local test_hosts=(
        "yum.voxpupuli.org"
        "apt.voxpupuli.org"
        "github.com"
    )
    
    for host in "${test_hosts[@]}"; do
        if ! timeout 5 bash -c "nc -z $host 443" 2>/dev/null; then
            log_warn "Cannot reach $host"
        fi
    done
    
    log_info "Network connectivity check complete"
}

# Check if package is installed
is_package_installed() {
    local package="$1"
    
    case "$PACKAGE_MANAGER" in
        yum)
            rpm -q "$package" &>/dev/null
            ;;
        apt)
            dpkg -l "$package" &>/dev/null
            ;;
    esac
}

# Install package(s)
install_package() {
    local packages=("$@")
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
                    apt-get update -qq
                    apt-get install -y -qq "$pkg"
                    ;;
            esac
        fi
    done
}

# Setup Vox Pupuli repository
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

# Setup YUM repository
setup_yum_repo() {
    local repo_rpm=""
    
    # Determine correct RPM for RHEL version
    case "$OS_VERSION" in
        8*|9*)
            repo_rpm="openvox8-release-el-${OS_VERSION%%.*}.noarch.rpm"
            ;;
        10*)
            repo_rpm="openvox8-release-el-9.noarch.rpm"
            ;;
        42*)
            repo_rpm="openvox8-release-el-9.noarch.rpm"
            ;;
        *)
            log_fatal "Unsupported RHEL version: $OS_VERSION"
            ;;
    esac
    
    local repo_url="https://yum.voxpupuli.org/$repo_rpm"
    
    log_info "Installing repository package: $repo_url"
    
    if is_package_installed "openvox8-release"; then
        log_debug "Repository already configured"
        return 0
    fi
    
    # Download and install
    local tmp_dir="/tmp/openvox-repo"
    mkdir -p "$tmp_dir"
    
    if curl -fsSL -o "${tmp_dir}/${repo_rpm}" "$repo_url"; then
        rpm -ivh "${tmp_dir}/${repo_rpm}"
    else
        log_fatal "Failed to download repository package"
    fi
    
    # Import GPG key
    rpm --import https://yum.voxpupuli.org/RPM-GPG-KEY-VoxPupuli
    
    # Clean yum cache
    yum clean metadata
    
    rm -rf "$tmp_dir"
    
    log_info "YUM repository configured successfully"
}

# Setup APT repository
setup_apt_repo() {
    local repo_deb=""
    
    # Determine correct DEB for Debian/Ubuntu version
    case "$OS_FAMILY" in
        debian)
            repo_deb="openvox8-release-${OS_CODENAME}.deb"
            ;;
        ubuntu)
            repo_deb="openvox8-release-${OS_CODENAME}.deb"
            ;;
    esac
    
    local repo_url="https://apt.voxpupuli.org/$repo_deb"
    
    log_info "Installing repository package: $repo_url"
    
    if is_package_installed "openvox8-release"; then
        log_debug "Repository already configured"
        return 0
    fi
    
    # Download and install
    local tmp_dir="/tmp/openvox-repo"
    mkdir -p "$tmp_dir"
    
    if curl -fsSL -o "${tmp_dir}/${repo_deb}" "$repo_url"; then
        dpkg -i "${tmp_dir}/${repo_deb}"
    else
        log_fatal "Failed to download repository package"
    fi
    
    # Import GPG key
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 6E709C1BF8FCF7D1
    
    # Update package lists
    apt-get update -qq
    
    rm -rf "$tmp_dir"
    
    log_info "APT repository configured successfully"
}

# Configure firewall
configure_firewall() {
    log_info "Configuring firewall..."
    
    # Check if firewalld is running
    if systemctl is-active --quiet firewalld 2>/dev/null; then
        log_info "Configuring firewalld rules..."
        
        # Open required ports
        firewall-cmd --permanent --add-port=8140/tcp   # PuppetServer
        firewall-cmd --permanent --add-port=8081/tcp   # PuppetDB
        firewall-cmd --permanent --add-port=4567/tcp   # OpenVox-GUI
        firewall-cmd --reload
        
        log_info "Firewall rules added"
    else
        log_debug "Firewalld not running, skipping firewall configuration"
    fi
}

# Configure SELinux
configure_selinux() {
    # Only relevant for RHEL-based systems
    if [[ "$OS_FAMILY" != "rhel" ]]; then
        return 0
    fi
    
    log_info "Configuring SELinux..."
    
    if command -v getenforce &>/dev/null; then
        local selinux_status
        selinux_status=$(getenforce 2>/dev/null || echo "Unknown")
        
        if [[ "$selinux_status" == "Enforcing" ]]; then
            log_warn "SELinux is enforcing. You may need to set appropriate contexts."
            log_info "Run: semanage fcontext -a -t puppet_var_t '/var/log/openvox(/.*)?'"
        fi
    fi
}

# Configure services
configure_services() {
    log_info "Configuring services..."
    
    # Enable services (but don't start yet if in dry-run)
    if [[ "$DRY_RUN" != "true" ]]; then
        if [[ "$INSTALL_SERVER" == "true" ]]; then
            systemctl enable puppetserver 2>/dev/null || true
        fi
        if [[ "$INSTALL_PUPPETDB" == "true" ]]; then
            systemctl enable puppetdb 2>/dev/null || true
        fi
    fi
}

# Verify services
verify_services() {
    log_info "Verifying services..."
    
    local services=()
    
    [[ "$INSTALL_SERVER" == "true" ]] && services+=("puppetserver")
    [[ "$INSTALL_PUPPETDB" == "true" ]] && services+=("puppetdb")
    [[ "$INSTALL_GUI" == "true" ]] && services+=("openvox-gui")
    
    for svc in "${services[@]}"; do
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            log_info "Service $svc is running"
        else
            log_warn "Service $svc is not running (may need to be started)"
        fi
    done
}

# Verify connectivity
verify_connectivity() {
    log_info "Verifying connectivity..."
    
    # Test PuppetServer
    if [[ "$INSTALL_SERVER" == "true" ]]; then
        if curl -sk https://localhost:8140/puppet/v3/ 2>/dev/null; then
            log_info "PuppetServer is reachable"
        else
            log_warn "PuppetServer is not yet responding (normal on first run)"
        fi
    fi
    
    # Test PuppetDB
    if [[ "$INSTALL_PUPPETDB" == "true" ]]; then
        if curl -sk https://localhost:8081/pdb/query/v4/version 2>/dev/null; then
            log_info "PuppetDB is reachable"
        else
            log_warn "PuppetDB is not yet responding (normal on first run)"
        fi
    fi
}
