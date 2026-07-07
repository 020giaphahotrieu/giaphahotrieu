import { prisma } from "../config/prisma.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { sendSuccess } from "../utils/apiResponse.js";

export const contentController = {
  families: asyncHandler(async (_req, res) => {
    sendSuccess(res, await prisma.family.findMany({ include: { branches: true } }));
  }),

  events: asyncHandler(async (req, res) => {
    sendSuccess(
      res,
      await prisma.event.findMany({
        where: req.user?.familyId ? { familyId: req.user.familyId } : {},
        orderBy: { startsAt: "asc" },
        include: { member: true, translations: true }
      })
    );
  }),

  relationships: asyncHandler(async (req, res) => {
    sendSuccess(
      res,
      await prisma.relationship.findMany({
        where: req.user?.familyId ? { familyId: req.user.familyId } : {},
        include: { fromMember: true, toMember: true }
      })
    );
  }),

  analytics: asyncHandler(async (req, res) => {
    const memberId = String(req.query.memberId ?? "");
    const member = memberId ? await prisma.member.findUnique({ where: { id: memberId } }) : null;
    sendSuccess(res, {
      member,
      lunar: "Module lunar ready for real calendar engine integration",
      canchi: "Module canchi ready",
      zodiac: "Module zodiac ready",
      numerology: "Module numerology ready",
      bazi: "Module bazi ready",
      iching: "Module iching ready",
      astrology: "Module astrology ready"
    });
  })
};
