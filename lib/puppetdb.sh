#!/bin/bash
#
# =============================================================================
# ovinstall - PuppetDB Installation
# =============================================================================
# Installs and configures PuppetDB with a PostgreSQL backend.
# By default uses an internal (local) PostgreSQL instance.
# Requires: functions.sh (logging, package helpers, OS detection)
# =============================================================================

install_puppetdb() {
    log_info "=========================================="
    log_info "Installing PuppetDB"
    log_info "=========================================="

    # Install PostgreSQL if using internal database
    local db_type="${puppetdb_database:-internal}"
    if [[ "$db_type" == "internal" ]]; then
        install_postgresql
    fi

    install_package puppetdb

    configure_puppetdb

    log_info "Starting PuppetDB..."
    systemctl start puppetdb
    sleep 5  # Give PuppetDB time to initialize

    log_info "PuppetDB installed successfully"
}

install_postgresql() {
    log_info "Installing PostgreSQL..."

    case "$OS_FAMILY" in
        rhel)
            install_package postgresql-server postgresql-contrib
            # initdb may already have been run — ignore failure
            postgresql-setup --initdb 2>/dev/null || true
            systemctl enable postgresql
            systemctl start postgresql
            ;;
        debian|ubuntu)
            install_package postgresql postgresql-contrib
            systemctl enable postgresql
            systemctl start postgresql
            ;;
    esac

    # Create PuppetDB database and user (ignore errors if they already exist)
    local db_pass="${puppetdb_password:-changeme}"
    su - postgres -c "psql -c \"CREATE USER puppetdb WITH PASSWORD '${db_pass}';\"" 2>/dev/null || true
    su - postgres -c "psql -c \"CREATE DATABASE puppetdb OWNER puppetdb;\"" 2>/dev/null || true
    su - postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE puppetdb TO puppetdb;\"" 2>/dev/null || true

    log_info "PostgreSQL installed and configured"
}

configure_puppetdb() {
    log_info "Configuring PuppetDB..."

    local pdb_conf="/etc/puppetlabs/puppetdb/conf.d"
    local db_host="${puppetdb_db_host:-localhost}"
    local db_port="${puppetdb_db_port:-5432}"
    local db_name="${puppetdb_db_name:-puppetdb}"
    local db_user="${puppetdb_db_user:-puppetdb}"
    local db_pass="${puppetdb_password:-changeme}"

    # Update database.ini if it exists (installed by the puppetdb package)
    if [[ -f "$pdb_conf/database.ini" ]]; then
        sed -i "s/^.*subname.*=.*/subname = \/\/$db_host:$db_port\/$db_name/" "$pdb_conf/database.ini"
        sed -i "s/^.*username.*=.*/username = $db_user/" "$pdb_conf/database.ini"
        sed -i "s/^.*password.*=.*/password = $db_pass/" "$pdb_conf/database.ini"
    fi

    # PuppetDB uses PuppetServer's SSL certificates by default
    log_info "PuppetDB SSL configured (using PuppetServer certificates)"

    # Restart PuppetDB to pick up configuration changes
    systemctl restart puppetdb 2>/dev/null || true

    log_info "PuppetDB configuration complete"
}
