#!/bin/bash
#
# OpenVox Installer - Agent Installation
#

install_agent() {
    log_info "=========================================="
    log_info "Installing OpenVox Agent"
    log_info "=========================================="
    
    # Install agent package
    case "$PACKAGE_MANAGER" in
        yum)
            yum install -y openvox-agent
            ;;
        apt)
            apt-get install -y openvox-agent
            ;;
    esac
    
    # Configure agent
    configure_agent
    
    log_info "OpenVox Agent installed successfully"
}

configure_agent() {
    log_info "Configuring OpenVox Agent..."
    
    # Set server hostname if provided
    if [[ -n "${server_hostname:-}" ]]; then
        log_info "Setting agent server to: $server_hostname"
        puppet config set server "$server_hostname" --section agent
    fi
    
    # Set agent certname if provided
    if [[ -n "${certname:-}" && "$certname" != "auto" ]]; then
        log_info "Setting agent certname to: $certname"
        puppet config set certname "$certname" --section agent
    fi
    
    # Configure run interval (default: 30 minutes)
    local runinterval="${runinterval:-30m}"
    puppet config set runinterval "$runinterval" --section agent
    
    # Enable agent if requested
    if [[ "${enable_agent:-false}" == "true" ]]; then
        systemctl enable puppet
    fi
    
    log_info "Agent configuration complete"
}
