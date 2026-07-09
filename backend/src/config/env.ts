import "dotenv/config";

const nodeEnv = process.env.NODE_ENV ?? "development";
const jwtSecret = process.env.JWT_SECRET ?? "";

// Fail fast instead of silently running production with the dev secret.
if (nodeEnv === "production" && jwtSecret.length < 16) {
  throw new Error("JWT_SECRET must be set (at least 16 characters) when NODE_ENV=production");
}

export const env = {
  nodeEnv,
  host: process.env.HOST ?? "0.0.0.0",
  port: Number(process.env.PORT ?? 4000),
  databaseUrl: process.env.DATABASE_URL ?? "file:../database/family-heritage.db",
  jwtSecret: jwtSecret || "dev-only-change-me",
  jwtExpiresIn: process.env.JWT_EXPIRES_IN ?? "7d",
  clientUrl: process.env.CLIENT_URL ?? "http://localhost:5173",
  clientUrls: (process.env.CLIENT_URL ?? "http://localhost:5173")
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean),
  uploadDir: process.env.UPLOAD_DIR ?? "../uploads"
};
