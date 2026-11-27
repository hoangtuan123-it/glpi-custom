#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
compose_file="$repo_dir/compose.yaml"
compose=(docker compose --project-directory "$repo_dir" -f "$compose_file")

"${compose[@]}" config --quiet
"${compose[@]}" up -d db

db_id="$("${compose[@]}" ps -q db)"
if [[ -z "$db_id" ]]; then
    printf 'Database container was not created.\n' >&2
    exit 1
fi

for attempt in {1..90}; do
    db_health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$db_id")"
    if [[ "$db_health" == healthy ]]; then
        break
    fi
    if [[ "$db_health" == unhealthy ]]; then
        printf 'Database did not become healthy.\n' >&2
        exit 1
    fi
    sleep 2
done
if [[ "$db_health" != healthy ]]; then
    printf 'Timed out waiting for the database to become healthy.\n' >&2
    exit 1
fi

BACKUP_DIR="${BACKUP_DIR:-$HOME/it-central-backups}" "$script_dir/backup-db.sh"
"${compose[@]}" build --pull --no-cache app

app_id="$("${compose[@]}" ps --all -q app)"
if [[ -n "$app_id" ]]; then
    "${compose[@]}" stop --timeout 30 app
fi

"${compose[@]}" run --rm --no-deps app php /var/www/glpi/bin/console database:update --no-interaction
"${compose[@]}" up -d --no-build app

app_id="$("${compose[@]}" ps -q app)"
if [[ -z "$app_id" ]]; then
    printf 'Application container was not created.\n' >&2
    exit 1
fi

for attempt in {1..90}; do
    app_health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$app_id")"
    if [[ "$app_health" == healthy ]]; then
        "${compose[@]}" exec -T app php /var/www/glpi/bin/console db:check --quiet
        exit 0
    fi
    if [[ "$app_health" == unhealthy ]]; then
        printf 'Application did not become healthy.\n' >&2
        exit 1
    fi
    sleep 2
done

printf 'Timed out waiting for the application to become healthy.\n' >&2
exit 1
