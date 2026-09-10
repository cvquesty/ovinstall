#!/bin/bash
#
# =============================================================================
# ovinstall - PuppetDB Installation
# =============================================================================
# Installs and configures PuppetDB with a PostgreSQL backend.
# By default uses an internal (local) PostgreSQL instance.
# Requires: functions.sh (logging, package helpers, OS detection)
#
# SEC-001 / SEC-002: never default to changeme; generate or validate passwords;
# prefer safe charset + dollar-quoting / atomic 0600 database.ini writes.
# =============================================================================

# Alphanumeric password (hex) — safe for SQL dollar-quoting and INI values
_generate_puppetdb_password() {
    if command -v openssl &>/dev/null; then
        openssl rand -hex 24
    else
        head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n' | head -c 48
    fi
}

# Safe charset: alphanumeric plus ._- ; min length 12; reject empty/changeme
_validate_puppetdb_password() {
    local pass="$1"
    if [[ -z "$pass" || "$pass" == "changeme" ]]; then
        return 1
    fi
    if [[ ${#pass} -lt 12 ]]; then
        return 1
    fi
    if [[ ! "$pass" =~ ^[A-Za-z0-9._-]+$ ]]; then
        return 1
    fi
    return 0
}

# Resolve puppetdb_password: reuse persisted file on re-run; generate when empty/changeme;
# validate operator-supplied values.
ensure_puppetdb_password() {
    local persist_dir="/etc/openvox"
    local persist_file="${persist_dir}/puppetdb_password"

    # Prefer an existing on-disk secret when the operator did not supply one
    if [[ -z "${puppetdb_password:-}" || "$puppetdb_password" == "changeme" ]]; then
        if [[ -f "$persist_file" ]]; then
            local existing
            existing="$(tr -d '\r\n' < "$persist_file")"
            if _validate_puppetdb_password "$existing"; then
                puppetdb_password="$existing"
                log_info "Reusing PuppetDB database password from ${persist_file} (not logged)."
                return 0
            fi
            log_warn "Ignoring invalid password file at ${persist_file}; generating a new one."
        fi

        puppetdb_password="$(_generate_puppetdb_password)"
        mkdir -p "$persist_dir"
        umask 077
        printf '%s\n' "$puppetdb_password" > "$persist_file"
        chmod 0600 "$persist_file"
        log_info "Generated PuppetDB database password (not logged). Stored at ${persist_file} (mode 0600)."
        return 0
    fi

    if ! _validate_puppetdb_password "$puppetdb_password"; then
        log_fatal "Invalid puppetdb_password: must be at least 12 characters, charset [A-Za-z0-9._-] only, and must not be empty or 'changeme'."
    fi
}

install_puppetdb() {
    log_info "=========================================="
    log_info "Installing PuppetDB"
    log_info "=========================================="

    ensure_puppetdb_password

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

    local db_user="${puppetdb_db_user:-puppetdb}"
    local db_name="${puppetdb_db_name:-puppetdb}"

    if [[ ! "$db_user" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || [[ ! "$db_name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
        log_fatal "Invalid puppetdb_db_user/db_name (alphanumeric/underscore only)"
    fi

    # Password already charset-validated; still use dollar-quoting (no shell SQL interpolation of untrusted strings)
    local sql_file
    sql_file=$(mktemp /tmp/ovinstall-pdb-XXXXXX.sql)
    chmod 0600 "$sql_file"
    cat > "$sql_file" <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${db_user}') THEN
    CREATE ROLE ${db_user} LOGIN PASSWORD \$ovpw\$${puppetdb_password}\$ovpw\$;
  ELSE
    ALTER ROLE ${db_user} PASSWORD \$ovpw\$${puppetdb_password}\$ovpw\$;
  END IF;
END
\$\$;
SQL

    if ! su - postgres -c "psql -v ON_ERROR_STOP=1 -f ${sql_file}"; then
        rm -f "$sql_file"
        log_fatal "Failed to create/update PostgreSQL role for PuppetDB"
    fi
    rm -f "$sql_file"

    su - postgres -c "createdb -O ${db_user} ${db_name}" 2>/dev/null || true
    su - postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE ${db_name} TO ${db_user};\"" 2>/dev/null || true

    log_info "PostgreSQL installed and configured"
}

configure_puppetdb() {
    log_info "Configuring PuppetDB..."

    local pdb_conf="/etc/puppetlabs/puppetdb/conf.d"
    local db_host="${puppetdb_db_host:-localhost}"
    local db_port="${puppetdb_db_port:-5432}"
    local db_name="${puppetdb_db_name:-puppetdb}"
    local db_user="${puppetdb_db_user:-puppetdb}"

    mkdir -p "$pdb_conf"

    # Atomic write — avoid unescaped sed of the raw password
    local tmp_ini
    tmp_ini=$(mktemp /tmp/ovinstall-database.ini.XXXXXX)
    chmod 0600 "$tmp_ini"
    cat > "$tmp_ini" <<EOF
[database]
classname = org.postgresql.Driver
subprotocol = postgresql
subname = //${db_host}:${db_port}/${db_name}
username = ${db_user}
password = ${puppetdb_password}
EOF

    if id puppetdb &>/dev/null; then
        install -m 0600 -o puppetdb -g puppetdb "$tmp_ini" "$pdb_conf/database.ini" 2>/dev/null \
            || install -m 0600 "$tmp_ini" "$pdb_conf/database.ini"
    else
        install -m 0600 "$tmp_ini" "$pdb_conf/database.ini"
    fi
    rm -f "$tmp_ini"
    chmod 0600 "$pdb_conf/database.ini" 2>/dev/null || true

    # PuppetDB uses PuppetServer's SSL certificates by default
    log_info "PuppetDB SSL configured (using PuppetServer certificates)"

    # Restart PuppetDB to pick up configuration changes
    systemctl restart puppetdb 2>/dev/null || true

    log_info "PuppetDB configuration complete (database.ini mode 0600)"
}
