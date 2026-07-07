import type { Response } from "express";

export function sendSuccess<T>(res: Response, data: T, message = "Success", status = 200) {
  return res.status(status).json({ success: true, message, data });
}

export function sendError(res: Response, message: string, status = 400, errors: unknown[] = []) {
  return res.status(status).json({ success: false, message, errors });
}
