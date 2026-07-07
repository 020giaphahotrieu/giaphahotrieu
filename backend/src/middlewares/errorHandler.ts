import type { ErrorRequestHandler } from "express";
import { Prisma } from "@prisma/client";
import { AppError } from "../utils/errors.js";
import { sendError } from "../utils/apiResponse.js";

export const errorHandler: ErrorRequestHandler = (err, _req, res, _next) => {
  if (err instanceof AppError) {
    return sendError(res, err.message, err.statusCode, err.errors);
  }

  if (err instanceof Prisma.PrismaClientKnownRequestError) {
    return sendError(res, "Database request failed", 400, [{ code: err.code, meta: err.meta }]);
  }

  console.error(err);
  return sendError(res, "Internal server error", 500);
};
