#!/bin/bash
#
# =============================================================================
# ovinstall - Server Installation
# =============================================================================
# Installs and configures openvox-server (PuppetServer).
# Requires: functions.sh (logging, package helpers, OS detection)
# =============================================================================

install_server() {
    log_info "=========================================="
    log_info "Installing OpenVox Server"
    log_info "=========================================="

    install_package openvox-server

    configure_server

    log_info "Starting PuppetServer..."
    systemctl start puppetserver
    sleep 10  # Give the JVM time to initialize

    log_info "OpenVox Server installed successfully"
}

configure_server() {
    log_info "Configuring OpenVox Server..."

    # Configure server hostname
    if [[ -n "${server_hostname:-}" ]]; then
        log_info "Setting server hostname to: $server_hostname"
        puppet config set server "$server_hostname" --section main
    fi

    # Configure Java heap memory (-Xmx = max heap, -Xms = initial heap)
    local jvm_mem="${jvm_memory:-2g}"
    if [[ -f /etc/sysconfig/puppetserver ]]; then
        sed -i "s/^JAVA_ARGS=.*/JAVA_ARGS=\"-Xmx${jvm_mem} -Xms${jvm_mem} -Djruby.logger.class=org.jruby.RubyDefaultLog\"/" /etc/sysconfig/puppetserver
    fi

    # PuppetDB integration (server mode always includes PuppetDB)
    puppet config set reports puppetdb --section main
    puppet config set storeconfigs true --section main
    puppet config set storeconfigs_backend puppetdb --section main

    # Configure environmentpath and codedir
    puppet config set environmentpath /etc/puppetlabs/code/environments --section main
    puppet config set codedir /etc/puppetlabs/code --section main

    log_info "Server configuration complete"
}
