#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 1 ]]; then
    printf 'Usage: %s <backup.sql.gz>\n' "$0" >&2
    exit 2
fi

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
compose_file="$repo_dir/compose.yaml"
backup_file="$(realpath -e -- "$1")"
compose=(docker compose --project-directory "$repo_dir" -f "$compose_file")

if [[ ! -f "$backup_file" || ! -r "$backup_file" ]]; then
    printf 'Backup is not a readable file: %s\n' "$backup_file" >&2
    exit 1
fi

gzip --test "$backup_file"
"${compose[@]}" config --quiet

if [[ "${RESTORE_CONFIRM:-}" != "RESTORE" ]]; then
    read -r -p "This replaces the production database. Type RESTORE to continue: " confirmation
    if [[ "$confirmation" != "RESTORE" ]]; then
        printf 'Restore cancelled.\n' >&2
        exit 1
    fi
fi

BACKUP_DIR="${BACKUP_DIR:-$HOME/it-central-backups}" "$script_dir/backup-db.sh"
app_id="$("${compose[@]}" ps --all -q app)"
if [[ -n "$app_id" ]]; then
    "${compose[@]}" stop --timeout 30 app
fi

if ! gzip --decompress --stdout -- "$backup_file" \
    | "${compose[@]}" exec -T db sh -ec \
        'export MYSQL_PWD="$MARIADB_ROOT_PASSWORD"; exec mariadb --user=root'; then
    printf 'Database restore failed; the app remains stopped.\n' >&2
    exit 1
fi

if [[ -n "$app_id" ]]; then
    "${compose[@]}" start app
    for attempt in {1..90}; do
        health_status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$app_id")"
        if [[ "$health_status" == healthy ]]; then
            "${compose[@]}" exec -T app php /var/www/glpi/bin/console db:check --quiet
            exit 0
        fi
        if [[ "$health_status" == unhealthy ]]; then
            printf 'Restored app did not become healthy.\n' >&2
            exit 1
        fi
        sleep 2
    done
    printf 'Timed out waiting for the restored app to become healthy.\n' >&2
    exit 1
fi
