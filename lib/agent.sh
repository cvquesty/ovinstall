#!/bin/bash
#
# =============================================================================
# ovinstall - Agent Installation
# =============================================================================
# Installs and configures openvox-agent (Puppet agent).
# Requires: functions.sh (logging, package helpers)
# =============================================================================

install_agent() {
    log_info "=========================================="
    log_info "Installing OpenVox Agent"
    log_info "=========================================="

    install_package openvox-agent

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

    # Set agent certname (skip if 'auto' — Puppet will use the hostname)
    if [[ -n "${certname:-}" && "$certname" != "auto" ]]; then
        log_info "Setting agent certname to: $certname"
        puppet config set certname "$certname" --section agent
    fi

    # Configure run interval (default: 30 minutes)
    local run_interval="${runinterval:-30m}"
    puppet config set runinterval "$run_interval" --section agent

    # Enable the puppet agent service if requested
    if [[ "${enable_agent:-false}" == "true" ]]; then
        systemctl enable puppet
    fi

    log_info "Agent configuration complete"
}
