#!/bin/sh
###############################################################################
# PostgreSQL — Create application users + databases on first boot
#
# This script runs once via /docker-entrypoint-initdb.d/ when the data
# directory is empty (first start). Each app gets its own user + databases.
# All statements are idempotent (safe to re-run).
###############################################################################

set -eu

create_user_and_dbs() {
    app_user="$1"
    app_pass="$2"
    main_db="$3"
    log_db="$4"

    echo "Creating user: ${app_user}"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-SQL
        DO \$\$
        BEGIN
            IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${app_user}') THEN
                CREATE USER "${app_user}" WITH PASSWORD '${app_pass}';
            ELSE
                ALTER USER "${app_user}" WITH PASSWORD '${app_pass}';
            END IF;
        END
        \$\$;
SQL

    for db_name in "$main_db" "$log_db"; do
        echo "Creating database: ${db_name} (owner: ${app_user})"
        psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-SQL
            SELECT 'CREATE DATABASE "${db_name}" OWNER "${app_user}"'
            WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${db_name}')
            \gexec
            GRANT ALL PRIVILEGES ON DATABASE "${db_name}" TO "${app_user}";
SQL
    done
}

create_user_and_db() {
    app_user="$1"
    app_pass="$2"
    db_name="$3"

    echo "Creating user: ${app_user}"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-SQL
        DO \$\$
        BEGIN
            IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${app_user}') THEN
                CREATE USER "${app_user}" WITH PASSWORD '${app_pass}';
            ELSE
                ALTER USER "${app_user}" WITH PASSWORD '${app_pass}';
            END IF;
        END
        \$\$;
SQL

    echo "Creating database: ${db_name} (owner: ${app_user})"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-SQL
        SELECT 'CREATE DATABASE "${db_name}" OWNER "${app_user}"'
        WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${db_name}')
        \gexec
        GRANT ALL PRIVILEGES ON DATABASE "${db_name}" TO "${app_user}";
SQL
}

create_db() {
    db_name="$1"
    echo "Creating database: ${db_name}"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-SQL
        SELECT 'CREATE DATABASE "${db_name}"'
        WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${db_name}')
        \gexec
        GRANT ALL PRIVILEGES ON DATABASE "${db_name}" TO "${POSTGRES_USER}";
SQL
}

# Arr databases — per-service users
create_user_and_dbs "${SONARR_POSTGRES_USER}" "${SONARR_POSTGRES_PASS}" "sonarr-main" "sonarr-log"
create_user_and_dbs "${RADARR_POSTGRES_USER}" "${RADARR_POSTGRES_PASS}" "radarr-main" "radarr-log"
create_user_and_dbs "${PROWLARR_POSTGRES_USER}" "${PROWLARR_POSTGRES_PASS}" "prowlarr-main" "prowlarr-log"

# Seerr (media request management)
create_user_and_db "${SEERR_POSTGRES_USER}" "${SEERR_POSTGRES_PASS}" "seerr"

# Grafana (uses shared homelab user)
create_db "grafana"

echo "All application users and databases created successfully"
