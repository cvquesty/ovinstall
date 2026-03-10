#!/bin/bash
#
# =============================================================================
# OpenVox Installer - r10k Component
# =============================================================================
# r10k is a Puppet code deployment tool that manages Git-based environments.
# It requires:
#   - A Git control repository (control repo) with Puppet code
#   - The remote URL to that repository
# 
# IMPORTANT: r10k is ONLY installed as part of server installations.
# It cannot be installed standalone on agent machines.
# =============================================================================

# =============================================================================
# SECTION: r10k Installation
# =============================================================================
# Installs r10k Ruby gem and configures it with the control repo URL.
# The control repo URL is required and must be provided either via:
#   - Config file (r10k_remote key)
#   - Interactive prompt
#   - Command-line argument

install_r10k() {
    log_info "=========================================="
    log_info "Installing r10k"
    log_info "=========================================="
    
    # Validate required parameters
    if [[ -z "$r10k_remote" ]]; then
        log_fatal "r10k requires a control repository URL (r10k_remote)"
    fi
    
    log_info "Control repository: $r10k_remote"
    
    # Install r10k via gem
    install_r10k_package
    
    # Configure r10k
    configure_r10k
    
    log_info "r10k installation complete"
}

# =============================================================================
# SECTION: Install r10k Package
# =============================================================================
# Install r10k Ruby gem. Uses Puppet's bundled gem if available,
# otherwise uses system gem.

install_r10k_package() {
    log_info "Installing r10k gem..."
    
    # Check for Puppet's bundled gem first (preferred)
    if [[ -x /opt/puppetlabs/puppet/bin/gem ]]; then
        log_debug "Using Puppet bundled gem"
        /opt/puppetlabs/puppet/bin/gem install r10k
    elif command -v gem &>/dev/null; then
        log_debug "Using system gem"
        gem install r10k
    else
        log_fatal "Ruby gem command not found"
    fi
    
    log_info "r10k gem installed"
}

# =============================================================================
# SECTION: Configure r10k
# =============================================================================
# Create r10k configuration file at /etc/puppetlabs/r10k/r10k.yaml
# This configures:
#   - cachedir: where r10k caches Git repos
#   - sources: Git remotes to deploy (control repo)
#   - basedir: where environments are created

configure_r10k() {
    log_info "Configuring r10k..."
    
    # Create r10k config directory
    local r10k_dir="/etc/puppetlabs/r10k"
    mkdir -p "$r10k_dir"
    
    # Determine basedir based on Puppet version
    # PE uses different paths than FOSS
    local basedir="/etc/puppetlabs/code/environments"
    if [[ -d "/etc/puppet/environments" ]]; then
        basedir="/etc/puppet/environments"
    fi
    
    # Create r10k.yaml configuration
    # This tells r10k where to clone from and where to put environments
    cat > "${r10k_dir}/r10k.yaml" << EOF
---
# r10k configuration for OpenVox

# Cache directory for Git repositories
# r10k caches cloned repos here to speed up subsequent runs
cachedir: '/var/cache/r10k'

# Git sources to deploy
# This maps a name (e.g., 'control') to a Git remote URL
sources:
  control:
    # The Git remote URL - REQUIRED
    remote: '${r10k_remote}'
    
    # Where to create environments (branches become subdirectories)
    basedir: '${basedir}'
    
    # Optional: prefix for environment names
    # prefix: ''

# Proxy settings (if needed)
# proxy: 'http://proxy.example.com:8080'
EOF

    log_info "r10k configured at ${r10k_dir}/r10k.yaml"
    
    # Create cache directory
    mkdir -p /var/cache/r10k
    
    # Set permissions
    if [[ -d /var/cache/r10k ]]; then
        chmod 755 /var/cache/r10k
    fi
}

# =============================================================================
# SECTION: Deploy Environments (Post-Install)
# =============================================================================
# Run r10k to deploy environments from the control repo.
# This is typically run after initial installation to pull down
# the Puppet code from the control repository.

deploy_environments() {
    log_info "Deploying environments with r10k..."
    
    # Use Puppet's r10k if available, otherwise system r10k
    local r10k_cmd=""
    if [[ -x /opt/puppetlabs/puppet/bin/r10k ]]; then
        r10k_cmd="/opt/puppetlabs/puppet/bin/r10k"
    elif command -v r10k &>/dev/null; then
        r10k_cmd="r10k"
    else
        log_warn "r10k command not found, skipping environment deployment"
        return 0
    fi
    
    # Deploy all environments
    # The -p flag also deploys modules from the Puppetfile
    if [[ "$DRY_RUN" != "true" ]]; then
        $r10k_cmd deploy environment -p
    else
        log_info "Dry-run: would run: $r10k_cmd deploy environment -p"
    fi
    
    log_info "Environment deployment complete"
}
