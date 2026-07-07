import type { RequestHandler } from "express";
import jwt from "jsonwebtoken";
import { env } from "../config/env.js";
import { prisma } from "../config/prisma.js";
import { AppError } from "../utils/errors.js";
import type { RoleName } from "../utils/roles.js";
import { hasAnyRole } from "../utils/roles.js";

type JwtPayload = {
  sub: string;
};

export const authenticate: RequestHandler = async (req, _res, next) => {
  const header = req.headers.authorization;
  const token = header?.startsWith("Bearer ") ? header.slice(7) : undefined;

  if (!token) {
    return next(new AppError("Authentication token is required", 401));
  }

  try {
    const decoded = jwt.verify(token, env.jwtSecret) as JwtPayload;
    const user = await prisma.user.findUnique({
      where: { id: decoded.sub },
      include: { roles: { include: { role: true } } }
    });

    if (!user || !user.isActive) {
      return next(new AppError("User is inactive or no longer exists", 401));
    }

    req.user = {
      id: user.id,
      email: user.email,
      familyId: user.familyId,
      roles: user.roles.map((item) => item.role.name as RoleName)
    };
    return next();
  } catch {
    return next(new AppError("Invalid or expired authentication token", 401));
  }
};

export function authorize(...roles: RoleName[]): RequestHandler {
  return (req, _res, next) => {
    if (!req.user) return next(new AppError("Authentication required", 401));
    if (!hasAnyRole(req.user.roles, roles)) return next(new AppError("Permission denied", 403));
    return next();
  };
}
