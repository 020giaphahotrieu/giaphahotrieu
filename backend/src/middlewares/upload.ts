import path from "node:path";
import multer from "multer";
import { env } from "../config/env.js";
import { AppError } from "../utils/errors.js";

const allowedTypes = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
  "video/mp4",
  "application/pdf"
]);

const storage = multer.diskStorage({
  destination: env.uploadDir,
  filename: (_req, file, cb) => {
    const safeBase = path.basename(file.originalname).replace(/[^a-zA-Z0-9.-]/g, "_");
    cb(null, `${Date.now()}-${safeBase}`);
  }
});

export const upload = multer({
  storage,
  limits: { fileSize: 20 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    if (!allowedTypes.has(file.mimetype)) {
      return cb(new AppError("Unsupported file type", 415));
    }
    return cb(null, true);
  }
});
