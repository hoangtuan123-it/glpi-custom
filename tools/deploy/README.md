# Production deployment

This deployment uses the official GLPI Apache image, MariaDB, and named Docker volumes. The app port is bound to loopback; terminate HTTPS with a host-level reverse proxy before exposing the service publicly.

## Initial install

1. Install Docker Engine and the Docker Compose plugin on a supported Ubuntu LTS server.
2. Check out the exact IT Central release to deploy.
3. Copy `.env.example` to `.env`, set unique database passwords, and protect the file:

   ```sh
   cp .env.example .env
   chmod 600 .env
   openssl rand -hex 32
   ```

4. Configure the host reverse proxy and TLS certificate. Allow inbound SSH and HTTPS only; do not publish MariaDB.
5. Start the fresh installation:

   ```sh
   docker compose up -d
   ```

Compose builds the application image and waits for MariaDB before starting the app. Check startup with `docker compose ps` and review logs with `docker compose logs -f app db`. The app port is bound to `127.0.0.1`, so configure the reverse proxy before accessing it externally. The first install creates the built-in `admin` account; change its default password before allowing user access.

For upgrades, use `./tools/deploy/deploy.sh` instead of `docker compose up -d`. It backs up the database, rebuilds the image without layer cache, runs the database update, and verifies app health and schema status.

## Backups and restore

Create a compressed, permission-restricted database backup:

```sh
./tools/deploy/backup-db.sh
```

Restore requires an explicit confirmation and makes a safety database backup first:

```sh
./tools/deploy/restore-db.sh /path/to/it-central-db-backup.sql.gz
```

These scripts cover MariaDB only. Back up the `glpi_data` volume separately; it contains configuration, uploaded documents, and other application files. Store backups encrypted and off-host.

## Updates and rollback

Run `./tools/deploy/deploy.sh` from the exact release checkout. It stops the app before database migration and leaves it stopped if migration fails. For rollback, restore a matching database backup and `glpi_data` snapshot, then deploy the matching previous source release. Database rollback without the matching files and app version is not supported.

The compose file does not configure a public TLS proxy, SMTP, external identity providers, off-host backups, or horizontal scaling. Configure and validate those separately for the target installation.
