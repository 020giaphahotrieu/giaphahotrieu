# Production Deployment

Run this from the project root on the Ubuntu VPS after `giaphahotrieu.vn` points to the VPS IP:

```bash
chmod +x scripts/production/bootstrap-vps.sh
CERTBOT_EMAIL=admin@giaphahotrieu.vn ./scripts/production/bootstrap-vps.sh
```

The script installs Node.js, pnpm, SQLite, Nginx, Certbot, PM2, builds the app, configures reverse proxy and SSL, enables startup after reboot, opens the firewall, and verifies health/login.

Final URL:

```text
https://giaphahotrieu.vn
```
