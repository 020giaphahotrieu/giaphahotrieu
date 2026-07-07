import { prisma } from "../config/prisma.js";
import { AppError } from "../utils/errors.js";

export const memberService = {
  list(familyId?: string | null) {
    return prisma.member.findMany({
      where: familyId ? { familyId } : {},
      include: { branch: true, translations: true },
      orderBy: [{ generation: "asc" }, { fullName: "asc" }]
    });
  },

  async get(id: string) {
    const member = await prisma.member.findUnique({
      where: { id },
      include: {
        branch: true,
        translations: true,
        relationshipsA: { include: { toMember: true } },
        relationshipsB: { include: { fromMember: true } },
        events: true,
        media: { include: { media: true } },
        numerologyReports: true,
        baziReports: true,
        astrologyReports: true
      }
    });
    if (!member) throw new AppError("Member not found", 404);
    return member;
  },

  async create(input: {
    familyId?: string;
    branchId?: string | null;
    fullName: string;
    givenName?: string;
    generation: number;
    gender: "MALE" | "FEMALE" | "OTHER" | "UNKNOWN";
    lifeStatus: "LIVING" | "DECEASED" | "UNKNOWN";
    birthDate?: string;
    deathDate?: string;
    birthTime?: string;
    birthPlace?: string;
    biography?: string;
  }, currentFamilyId?: string | null) {
    const familyId = input.familyId ?? currentFamilyId;
    if (!familyId) throw new AppError("familyId is required", 422);

    return prisma.member.create({
      data: {
        familyId,
        branchId: input.branchId ?? undefined,
        fullName: input.fullName,
        givenName: input.givenName,
        generation: input.generation,
        gender: input.gender,
        lifeStatus: input.lifeStatus,
        birthDate: input.birthDate ? new Date(input.birthDate) : undefined,
        deathDate: input.deathDate ? new Date(input.deathDate) : undefined,
        birthTime: input.birthTime,
        birthPlace: input.birthPlace,
        biography: input.biography
      }
    });
  },

  async remove(id: string, force = false) {
    const relationCount = await prisma.relationship.count({
      where: { OR: [{ fromMemberId: id }, { toMemberId: id }] }
    });
    if (relationCount > 0 && !force) {
      throw new AppError("Member has important relationships. Confirm deletion with force=true.", 409);
    }
    return prisma.member.delete({ where: { id } });
  }
};
