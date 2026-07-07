import type { RequestHandler } from "express";
import type { ZodSchema } from "zod";
import { AppError } from "../utils/errors.js";

export function validate(schema: ZodSchema): RequestHandler {
  return (req, _res, next) => {
    const result = schema.safeParse({
      body: req.body,
      params: req.params,
      query: req.query
    });

    if (!result.success) {
      return next(new AppError("Validation failed", 422, result.error.issues));
    }

    req.body = result.data.body ?? req.body;
    req.params = result.data.params ?? req.params;
    req.query = result.data.query ?? req.query;
    return next();
  };
}
