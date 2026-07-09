const fs = require("node:fs");
const path = require("node:path");

const root = __dirname;

// PM2 does not load dotenv files. Read backend/.env directly so that
// `pm2 startOrReload ecosystem.config.cjs --env production` always picks up
// the environment written by the deployment scripts, regardless of the shell
// it runs from (bootstrap, cron, manual SSH session, resurrect after reboot).
function parseEnvFile(filePath) {
  const values = {};
  let raw;
  try {
    raw = fs.readFileSync(filePath, "utf8");
  } catch {
    return values;
  }
  for (const line of raw.split(/\r?\n/)) {
    const match = line.match(/^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$/);
    if (!match) continue;
    let value = match[2];
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    } else {
      const comment = value.indexOf(" #");
      if (comment !== -1) value = value.slice(0, comment).trimEnd();
    }
    values[match[1]] = value;
  }
  return values;
}

const fileEnv = parseEnvFile(path.join(root, "backend", ".env"));

// Precedence: explicit process environment > backend/.env > safe defaults.
const overridableKeys = [
  "PORT",
  "HOST",
  "CLIENT_URL",
  "DATABASE_URL",
  "UPLOAD_DIR",
  "JWT_SECRET",
  "JWT_EXPIRES_IN",
  "ADMIN_EMAIL",
  "ADMIN_PASSWORD",
  "DEFAULT_FAMILY_NAME"
];
const processEnv = {};
for (const key of overridableKeys) {
  if (process.env[key] !== undefined && process.env[key] !== "") {
    processEnv[key] = process.env[key];
  }
}

const appEnv = {
  HOST: "127.0.0.1",
  PORT: "4000",
  CLIENT_URL: "https://giaphahotrieu.vn",
  DATABASE_URL: `file:${path.join(root, "database", "family-heritage.db")}`,
  UPLOAD_DIR: path.join(root, "uploads"),
  JWT_EXPIRES_IN: "7d",
  ...fileEnv,
  ...processEnv,
  NODE_ENV: "production"
};

module.exports = {
  apps: [
    {
      name: "giaphahotrieu-api",
      cwd: root,
      script: "backend/dist/src/server.js",
      exec_mode: "fork",
      instances: 1,
      autorestart: true,
      min_uptime: "10s",
      max_restarts: 20,
      exp_backoff_restart_delay: 200,
      kill_timeout: 8000,
      max_memory_restart: "512M",
      time: true,
      merge_logs: true,
      out_file: path.join(root, "logs", "pm2-api-out.log"),
      error_file: path.join(root, "logs", "pm2-api-error.log"),
      env: appEnv,
      env_production: appEnv
    }
  ]
};
