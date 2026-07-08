# Production Deployment

Target: Ubuntu 24 VPS, domain `giaphahotrieu.vn`, PM2, Nginx, Let's Encrypt.

The deployment script:

- Installs Node.js 20, pnpm, PM2, Nginx, Certbot, SQLite and UFW.
- Builds frontend and backend.
- Creates an idempotent production admin with `admin@example.com / Admin@123456`.
- Starts backend with PM2 and enables startup after reboot.
- Serves frontend from Nginx.
- Proxies `/api` and `/uploads` to backend port `4000`.
- Requests and installs SSL using Let's Encrypt.
- Enables firewall rules for SSH and Nginx.
- Tests health and login endpoints.

Run from the project root:

```bash
chmod +x scripts/production/bootstrap-vps.sh
CERTBOT_EMAIL=admin@giaphahotrieu.vn ./scripts/production/bootstrap-vps.sh
```
