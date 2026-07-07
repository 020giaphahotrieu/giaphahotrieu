import bcrypt from "bcryptjs";
import jwt, { type SignOptions } from "jsonwebtoken";
import { prisma } from "../config/prisma.js";
import { env } from "../config/env.js";
import { AppError } from "../utils/errors.js";
import { userRepository } from "../repositories/user.repository.js";

function signToken(userId: string) {
  const options: SignOptions = { expiresIn: env.jwtExpiresIn as SignOptions["expiresIn"] };
  return jwt.sign({ sub: userId }, env.jwtSecret, options);
}

function toSafeUser(user: Awaited<ReturnType<typeof userRepository.findByEmail>>) {
  if (!user) return null;
  return {
    id: user.id,
    email: user.email,
    displayName: user.displayName,
    familyId: user.familyId,
    familyName: user.family?.name,
    roles: user.roles.map((item) => item.role.name)
  };
}

export const authService = {
  async login(email: string, password: string) {
    const user = await userRepository.findByEmail(email);
    if (!user) throw new AppError("Invalid email or password", 401);

    const valid = await bcrypt.compare(password, user.passwordHash);
    if (!valid) throw new AppError("Invalid email or password", 401);

    return { token: signToken(user.id), user: toSafeUser(user) };
  },

  async register(input: { email: string; password: string; displayName: string; familyName?: string }) {
    const existing = await userRepository.findByEmail(input.email);
    if (existing) throw new AppError("Email is already registered", 409);

    const passwordHash = await bcrypt.hash(input.password, 12);
    const viewerRole = await prisma.role.findUnique({ where: { name: "VIEWER" } });
    if (!viewerRole) throw new AppError("System roles have not been seeded", 500);

    const user = await prisma.$transaction(async (tx) => {
      const family = input.familyName
        ? await tx.family.create({ data: { name: input.familyName } })
        : await tx.family.findFirst();

      return tx.user.create({
        data: {
          email: input.email,
          passwordHash,
          displayName: input.displayName,
          familyId: family?.id,
          roles: { create: { roleId: viewerRole.id } }
        },
        include: { roles: { include: { role: true } }, family: true }
      });
    });

    return { token: signToken(user.id), user: toSafeUser(user) };
  },

  async me(userId: string) {
    const user = await userRepository.findById(userId);
    if (!user) throw new AppError("User not found", 404);
    return toSafeUser(user);
  }
};
