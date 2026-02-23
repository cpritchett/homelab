#!/bin/sh
###############################################################################
# Migrate arr app data from SQLite to PostgreSQL
#
# Dumps each table from SQLite as CSV, then uses COPY FROM STDIN to load
# into the corresponding Postgres table. Skips VersionInfo (managed by
# FluentMigrator) and empty tables.
#
# Usage: sudo sh scripts/migrate-sqlite-to-postgres.sh
# Must run on barbary (needs access to docker and SQLite files)
###############################################################################
set -eu

PG_CID=$(docker ps -q -f name=platform_postgres_postgresql)
TMPDIR="/tmp/arr_migrate_$$"
mkdir -p "$TMPDIR"

migrate_db() {
    SQLITE_FILE="$1"
    PG_DB="$2"
    PG_USER="$3"
    APP_NAME="$4"

    echo ""
    echo "=========================================="
    echo " Migrating $APP_NAME -> $PG_DB"
    echo "=========================================="

    if [ ! -f "$SQLITE_FILE" ]; then
        echo "  ERROR: $SQLITE_FILE not found"
        return 1
    fi

    TABLES=$(sqlite3 "$SQLITE_FILE" \
        "SELECT name FROM sqlite_master
         WHERE type='table'
           AND name != 'VersionInfo'
           AND name NOT LIKE 'sqlite_%'
         ORDER BY name;")

    TOTAL=0
    ERRORS=0

    for TABLE in $TABLES; do
        COUNT=$(sqlite3 "$SQLITE_FILE" "SELECT COUNT(*) FROM \"$TABLE\";")
        if [ "$COUNT" -eq 0 ]; then
            continue
        fi

        printf "  %-30s %6d rows... " "$TABLE" "$COUNT"

        # Build quoted column list for Postgres
        COLS=$(sqlite3 "$SQLITE_FILE" "PRAGMA table_info(\"$TABLE\");" \
            | cut -d'|' -f2 \
            | sed 's/.*/"&"/' \
            | paste -sd, -)

        # Export to CSV
        CSV="$TMPDIR/${APP_NAME}_${TABLE}.csv"
        sqlite3 -header -csv "$SQLITE_FILE" "SELECT * FROM \"$TABLE\";" > "$CSV"

        # Truncate Postgres table
        docker exec "$PG_CID" \
            psql -U "$PG_USER" -d "$PG_DB" -q \
            -c "TRUNCATE \"$TABLE\" CASCADE;" 2>/dev/null || true

        # COPY from CSV via stdin
        RESULT=$(docker exec -i "$PG_CID" \
            psql -U "$PG_USER" -d "$PG_DB" \
            -c "COPY \"$TABLE\" ($COLS) FROM STDIN WITH (FORMAT csv, HEADER true, NULL '');" \
            < "$CSV" 2>&1)

        if echo "$RESULT" | grep -qi "error"; then
            echo "FAIL"
            echo "$RESULT" | grep -i error | head -2 | sed 's/^/      /'
            ERRORS=$((ERRORS + 1))
        else
            echo "OK"
            TOTAL=$((TOTAL + COUNT))
        fi

        rm -f "$CSV"
    done

    # Reset auto-increment sequences
    echo "  Resetting sequences..."
    for TABLE in $TABLES; do
        HAS_SEQ=$(docker exec "$PG_CID" \
            psql -U "$PG_USER" -d "$PG_DB" -tAc \
            "SELECT 1 FROM pg_class WHERE relname = '${TABLE}_Id_seq';" \
            2>/dev/null || true)
        if [ "$HAS_SEQ" = "1" ]; then
            docker exec "$PG_CID" \
                psql -U "$PG_USER" -d "$PG_DB" -q \
                -c "SELECT setval('\"${TABLE}_Id_seq\"', COALESCE((SELECT MAX(\"Id\") FROM \"$TABLE\"), 0) + 1, false);" \
                2>/dev/null || true
        fi
    done

    echo "  === $APP_NAME: $TOTAL rows migrated, $ERRORS errors ==="
}

# Migrate main databases (log DBs don't contain user data worth migrating)
migrate_db "/mnt/apps01/appdata/media/sonarr/config/sonarr.db" "sonarr-main" "sonarr" "sonarr"
migrate_db "/mnt/apps01/appdata/media/radarr/config/radarr.db" "radarr-main" "radarr" "radarr"
migrate_db "/mnt/apps01/appdata/media/prowlarr/config/prowlarr.db" "prowlarr-main" "prowlarr" "prowlarr"

rm -rf "$TMPDIR"
echo ""
echo "=== All migrations complete ==="
