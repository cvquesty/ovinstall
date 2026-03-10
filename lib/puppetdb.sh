#!/bin/bash
#
# OpenVox Installer - PuppetDB Installation
#

install_puppetdb() {
    log_info "=========================================="
    log_info "Installing PuppetDB"
    log_info "=========================================="
    
    # Install PostgreSQL if using internal database
    local db_type="${puppetdb_database:-internal}"
    
    if [[ "$db_type" == "internal" ]]; then
        install_postgresql
    fi
    
    # Install PuppetDB package
    case "$PACKAGE_MANAGER" in
        yum)
            yum install -y puppetdb
            ;;
        apt)
            apt-get install -y puppetdb
            ;;
    esac
    
    # Configure PuppetDB
    configure_puppetdb
    
    # Start PuppetDB
    if [[ "$DRY_RUN" != "true" ]]; then
        log_info "Starting PuppetDB..."
        systemctl start puppetdb
        sleep 5
    fi
    
    log_info "PuppetDB installed successfully"
}

install_postgresql() {
    log_info "Installing PostgreSQL..."
    
    case "$OS_FAMILY" in
        rhel)
            yum install -y postgresql-server postgresql-contrib
            postgresql-setup --initdb || true
            systemctl enable postgresql
            systemctl start postgresql
            ;;
        debian|ubuntu)
            apt-get install -y postgresql postgresql-contrib
            systemctl enable postgresql
            systemctl start postgresql
            ;;
    esac
    
    # Create PuppetDB database
    su - postgres -c "psql -c \"CREATE USER puppetdb WITH PASSWORD '${puppetdb_password:-changeme}';\"" 2>/dev/null || true
    su - postgres -c "psql -c \"CREATE DATABASE puppetdb OWNER puppetdb;\"" 2>/dev/null || true
    su - postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE puppetdb TO puppetdb;\"" 2>/dev/null || true
    
    log_info "PostgreSQL installed and configured"
}

configure_puppetdb() {
    log_info "Configuring PuppetDB..."
    
    local pdb_conf="/etc/puppetlabs/puppetdb/conf.d"
    
    # Configure database connection
    local db_type="${puppetdb_database:-internal}"
    local db_host="${puppetdb_db_host:-localhost}"
    local db_port="${puppetdb_db_port:-5432}"
    local db_name="${puppetdb_db_name:-puppetdb}"
    local db_user="${puppetdb_db_user:-puppetdb}"
    local db_pass="${puppetdb_password:-changeme}"
    
    # Update database.ini
    if [[ -f "$pdb_conf/database.ini" ]]; then
        sed -i "s/^.*subname.*=.*/subname = \/\/$db_host:$db_port\/$db_name/" "$pdb_conf/database.ini"
        sed -i "s/^.*username.*=.*/username = $db_user/" "$pdb_conf/database.ini"
        sed -i "s/^.*password.*=.*/password = $db_pass/" "$pdb_conf/database.ini"
    fi
    
    # Configure SSL
    local pdb_ssl="${puppetdb_ssl:-true}"
    if [[ "$pdb_ssl" == "true" ]]; then
        # PuppetDB uses server's SSL cert by default
        log_info "PuppetDB SSL configured (using PuppetServer certificates)"
    fi
    
    # Restart PuppetDB to apply changes
    if [[ "$DRY_RUN" != "true" ]]; then
        systemctl restart puppetdb
    fi
    
    log_info "PuppetDB configuration complete"
}
