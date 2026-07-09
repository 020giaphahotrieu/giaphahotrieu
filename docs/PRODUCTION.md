# Production Deployment

The canonical guide lives at the repository root: [PRODUCTION.md](../PRODUCTION.md).

Quick reference:

```bash
# Everything, on a fresh or existing Ubuntu 24.04 VPS:
bash <(curl -fsSL https://raw.githubusercontent.com/020giaphahotrieu/giaphahotrieu/main/scripts/production/install.sh)

# Enable HTTPS once DNS points to the server:
pnpm ssl:enable

# Resume an interrupted deployment:
pnpm deploy:resume
```
