import type { RequestHandler } from "express";
import { sendError } from "../utils/apiResponse.js";

export const notFound: RequestHandler = (req, res) => {
  sendError(res, `Route ${req.method} ${req.path} not found`, 404);
};
