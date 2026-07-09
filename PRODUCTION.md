# Production Deployment — giaphahotrieu.vn

Target: Ubuntu 24.04 VPS · nginx · PM2 · SQLite · Let's Encrypt.

## One command

On a brand-new VPS (or an existing one — the installer finds the clone and updates it):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/020giaphahotrieu/giaphahotrieu/main/scripts/production/install.sh)
```

That is everything. The installer clones/updates the repository (preserving the
production database and `.env` files), then runs `scripts/production/bootstrap-vps.sh`,
which installs Node.js, pnpm, PM2, nginx, certbot, sqlite3, ufw, creates swap on
small machines, writes environment files (secrets are generated once and then
preserved), migrates/seeds the database, builds everything, publishes the
frontend, configures nginx, starts the API under PM2 with boot persistence,
enables the firewall, and verifies health.

## DNS and HTTPS

The deployment **never fails because of DNS**. Before requesting a certificate
it checks (with retries and exponential backoff): NS delegation, A/AAAA records,
resolution, whether it matches this server's IP, CAA policy — and it reports
SERVFAIL / NXDOMAIN / missing A record / wrong IP / nameserver mismatch precisely.

* DNS ready → the certificate is issued automatically and the site goes live on HTTPS.
* DNS not ready → the deployment **completes on HTTP** and prints the exact records
  to create. Once DNS points to the server, upgrade with:

```bash
pnpm ssl:enable
```

`ssl:enable` only verifies DNS, obtains the Let's Encrypt certificate, switches
nginx to HTTPS and reloads — nothing is reinstalled. Renewals run automatically
via `certbot.timer` with an nginx reload hook.

Required records at the DNS provider (OneShield panel — create the zone first
if the panel says the domain does not exist):

```text
A    @      162.4.176.162
A    www    162.4.176.162
```

## Day-2 commands (run in the repository root on the VPS)

| Command | Purpose |
|---|---|
| `pnpm deploy` | Full redeploy (pull latest code, rebuild, reload — idempotent) |
| `pnpm deploy:resume` | Resume an interrupted deployment (skips completed build stages) |
| `pnpm ssl:enable` | Verify DNS and enable/expand HTTPS |
| `pm2 status` / `pm2 logs giaphahotrieu-api` | Service status / logs |
| `bash scripts/backup-sqlite.sh` | Manual database backup (automatic backups run on every deploy) |

## Configuration

Everything is environment-overridable (see `scripts/production/lib/config.sh`):
`DOMAIN`, `WWW_DOMAIN` (empty disables www), `CERTBOT_EMAIL`, `ADMIN_EMAIL`,
`ADMIN_PASSWORD`, `SERVER_IPV4`, `DNS_MAX_ATTEMPTS`, `SKIP_SSL=1`, …

Secrets live in `backend/.env` (mode 600) and survive redeployments:
`JWT_SECRET` is generated once; the initial admin password is generated on the
first deploy — read it with `grep ADMIN_PASSWORD backend/.env`. Redeploys never
reset a changed admin password (use `ADMIN_RESET_PASSWORD=1 pnpm admin:ensure`
if you ever lose access).

## Behaviour guarantees

* **Idempotent** — running the bootstrap repeatedly never breaks the server.
* **DNS/SSL failures are warnings**, never deployment failures; HTTP mode is the fallback.
* **The SQLite database and uploads are never touched by git syncs** — the
  scripts back up the DB before every pull and on every deploy
  (`database/backups/`, last 14 kept).
* Every stage logs `START / SUCCESS / WARNING / FAILED`; full logs in `logs/`.
