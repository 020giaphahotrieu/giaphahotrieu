const path = require("node:path");

const root = __dirname;

module.exports = {
  apps: [
    {
      name: "giaphahotrieu-api",
      cwd: root,
      script: "backend/dist/src/server.js",
      exec_mode: "fork",
      instances: 1,
      autorestart: true,
      max_memory_restart: "512M",
      env_production: {
        NODE_ENV: "production",
        PORT: process.env.PORT || "4000",
        CLIENT_URL: process.env.CLIENT_URL || "https://giaphahotrieu.vn",
        DATABASE_URL: process.env.DATABASE_URL || `file:${path.join(root, "database/family-heritage.db")}`,
        UPLOAD_DIR: process.env.UPLOAD_DIR || path.join(root, "uploads"),
        JWT_SECRET: process.env.JWT_SECRET,
        JWT_EXPIRES_IN: process.env.JWT_EXPIRES_IN || "7d"
      }
    }
  ]
};
