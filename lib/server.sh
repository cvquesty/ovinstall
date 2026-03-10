#!/bin/bash
#
# OpenVox Installer - Server Installation
#

install_server() {
    log_info "=========================================="
    log_info "Installing OpenVox Server"
    log_info "=========================================="
    
    # Install server package
    case "$PACKAGE_MANAGER" in
        yum)
            yum install -y openvox-server
            ;;
        apt)
            apt-get install -y openvox-server
            ;;
    esac
    
    # Configure server
    configure_server
    
    # Start server
    if [[ "$DRY_RUN" != "true" ]]; then
        log_info "Starting PuppetServer..."
        systemctl start puppetserver
        sleep 10  # Give server time to start
    fi
    
    log_info "OpenVox Server installed successfully"
}

configure_server() {
    log_info "Configuring OpenVox Server..."
    
    # Configure server hostname
    if [[ -n "${server_hostname:-}" ]]; then
        log_info "Setting server hostname to: $server_hostname"
        puppet config set server "$server_hostname" --section main
    fi
    
    # Configure Java heap memory
    local jvm_mem="${jvm_memory:-2g}"
    if [[ -f /etc/sysconfig/puppetserver ]]; then
        sed -i "s/^JAVA_ARGS=.*/JAVA_ARGS=\"-Xm${jvm_mem} -Xms${jvm_mem} -Djruby.logger.class=org.jruby.RubyDefaultLog\"/" /etc/sysconfig/puppetserver
    fi
    
    # Configure reports (store to PuppetDB)
    if [[ "$INSTALL_PUPPETDB" == "true" ]]; then
        puppet config set reports puppetdb --section main
    fi
    
    # Configure stored configs
    puppet config set storeconfigs true --section main
    puppet config_set storeconfigs_backend puppetdb --section main
    
    # Configure environmentpath
    puppet config set environmentpath /etc/puppetlabs/code/environments --section main
    
    # Configure codedir
    puppet config set codedir /etc/puppetlabs/code --section main
    
    log_info "Server configuration complete"
}
