import { prisma } from "../config/prisma.js";

export const userRepository = {
  findByEmail(email: string) {
    return prisma.user.findUnique({
      where: { email },
      include: { roles: { include: { role: true } }, family: true }
    });
  },

  findById(id: string) {
    return prisma.user.findUnique({
      where: { id },
      include: { roles: { include: { role: true } }, family: true }
    });
  }
};
