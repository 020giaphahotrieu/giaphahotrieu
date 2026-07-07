import { prisma } from "../config/prisma.js";

export const dashboardService = {
  async getOverview(familyId?: string | null) {
    const where = familyId ? { familyId } : {};
    const now = new Date();
    const next90 = new Date(now.getTime() + 90 * 24 * 60 * 60 * 1000);

    const [
      totalMembers,
      generations,
      branches,
      maleMembers,
      femaleMembers,
      livingMembers,
      deceasedMembers,
      upcomingEvents,
      recentMembers,
      generationGroups,
      genderGroups,
      statusGroups,
      branchGroups
    ] = await Promise.all([
      prisma.member.count({ where }),
      prisma.member.groupBy({ by: ["generation"], where, _count: true, orderBy: { generation: "asc" } }),
      prisma.familyBranch.count({ where: familyId ? { familyId } : {} }),
      prisma.member.count({ where: { ...where, gender: "MALE" } }),
      prisma.member.count({ where: { ...where, gender: "FEMALE" } }),
      prisma.member.count({ where: { ...where, lifeStatus: "LIVING" } }),
      prisma.member.count({ where: { ...where, lifeStatus: "DECEASED" } }),
      prisma.event.findMany({
        where: { ...(familyId ? { familyId } : {}), startsAt: { gte: now, lte: next90 } },
        orderBy: { startsAt: "asc" },
        take: 8
      }),
      prisma.member.findMany({ where, orderBy: { createdAt: "desc" }, take: 6 }),
      prisma.member.groupBy({ by: ["generation"], where, _count: true }),
      prisma.member.groupBy({ by: ["gender"], where, _count: true }),
      prisma.member.groupBy({ by: ["lifeStatus"], where, _count: true }),
      prisma.member.groupBy({ by: ["branchId"], where, _count: true })
    ]);

    const branchNames = await prisma.familyBranch.findMany({
      where: familyId ? { familyId } : {},
      select: { id: true, name: true }
    });
    const branchNameById = new Map(branchNames.map((branch) => [branch.id, branch.name]));

    return {
      stats: {
        totalMembers,
        totalGenerations: generations.length,
        totalBranches: branches,
        maleMembers,
        femaleMembers,
        livingMembers,
        deceasedMembers
      },
      upcomingEvents,
      recentMembers,
      charts: {
        generations: generationGroups.map((item) => ({ name: `Đời ${item.generation}`, value: item._count })),
        genders: genderGroups.map((item) => ({ name: item.gender, value: item._count })),
        lifeStatus: statusGroups.map((item) => ({ name: item.lifeStatus, value: item._count })),
        branches: branchGroups.map((item) => ({
          name: item.branchId ? branchNameById.get(item.branchId) ?? "Không rõ" : "Chưa phân nhánh",
          value: item._count
        }))
      }
    };
  }
};
