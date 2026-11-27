#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
compose_file="$repo_dir/compose.yaml"
backup_dir="${BACKUP_DIR:-$HOME/it-central-backups}"
compose=(docker compose --project-directory "$repo_dir" -f "$compose_file")

"${compose[@]}" config --quiet
mkdir -p -- "$backup_dir"
chmod 700 -- "$backup_dir"
umask 077

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup_file="$backup_dir/it-central-db-$timestamp-$$.sql.gz"
temporary_file="$(mktemp "$backup_dir/.it-central-db.XXXXXX")"
trap 'rm -f -- "$temporary_file"' EXIT

"${compose[@]}" exec -T db sh -ec \
    'export MYSQL_PWD="$MARIADB_ROOT_PASSWORD"; exec mariadb-dump --user=root --single-transaction --quick --routines --events --triggers --hex-blob --add-drop-database --databases "$MARIADB_DATABASE"' \
    | gzip --stdout > "$temporary_file"
gzip --test "$temporary_file"
mv -- "$temporary_file" "$backup_file"
chmod 600 -- "$backup_file"
trap - EXIT

printf '%s\n' "$backup_file"
