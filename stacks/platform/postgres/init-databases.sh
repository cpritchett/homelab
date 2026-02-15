#!/bin/sh
###############################################################################
# PostgreSQL — Create application databases on first boot
#
# This script runs once via /docker-entrypoint-initdb.d/ when the data
# directory is empty (first start). Each app gets its own database.
###############################################################################

set -eu

create_db() {
    db_name="$1"
    echo "Creating database: ${db_name}"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-SQL
        CREATE DATABASE "${db_name}";
        GRANT ALL PRIVILEGES ON DATABASE "${db_name}" TO "${POSTGRES_USER}";
SQL
}

# Arr databases (main + log per app)
create_db "sonarr-main"
create_db "sonarr-log"
create_db "radarr-main"
create_db "radarr-log"
create_db "prowlarr-main"
create_db "prowlarr-log"

# Grafana
create_db "grafana"

echo "All application databases created successfully"
