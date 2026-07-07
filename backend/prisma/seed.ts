import bcrypt from "bcryptjs";
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

const roles = [
  ["SUPER_ADMIN", "Quản trị toàn bộ hệ thống"],
  ["FAMILY_ADMIN", "Quản trị toàn bộ dữ liệu một dòng họ"],
  ["EDITOR", "Thêm và sửa thành viên, sự kiện, tư liệu"],
  ["MEMBER", "Xem dữ liệu và đề xuất chỉnh sửa"],
  ["VIEWER", "Chỉ xem dữ liệu được cho phép"]
] as const;

const permissions = [
  "system.manage",
  "family.manage",
  "member.create",
  "member.update",
  "member.delete",
  "member.read",
  "event.manage",
  "media.manage",
  "export.manage",
  "backup.manage"
];

const members = [
  ["M001", "Triệu Văn Khởi", "Khởi", 1, "MALE", "DECEASED", "1930-02-10", "2001-07-20", "05:30", "Từ Sơn, Bắc Ninh", "Vị thủy tổ đời gần nhất trong dữ liệu mẫu."],
  ["M002", "Nguyễn Thị An", "An", 1, "FEMALE", "DECEASED", "1933-06-14", "2008-01-12", "07:15", "Gia Lâm, Hà Nội", "Người gìn giữ nhiều ký ức gia đình."],
  ["M003", "Triệu Minh Đức", "Đức", 2, "MALE", "LIVING", "1956-01-05", null, "09:00", "Hà Nội", "Trưởng chi thứ nhất."],
  ["M004", "Lê Thị Mai", "Mai", 2, "FEMALE", "LIVING", "1958-03-19", null, null, "Hải Dương", "Phu nhân của ông Đức."],
  ["M005", "Triệu Minh Tâm", "Tâm", 2, "MALE", "LIVING", "1960-11-22", null, null, "Hà Nội", "Trưởng chi thứ hai."],
  ["M006", "Phạm Thị Lan", "Lan", 2, "FEMALE", "LIVING", "1962-09-04", null, "13:20", "Nam Định", "Phu nhân của ông Tâm."],
  ["M007", "Triệu Minh Hòa", "Hòa", 2, "FEMALE", "LIVING", "1965-05-09", null, null, "Hà Nội", "Chi nhánh ngoại tộc trong dữ liệu mẫu."],
  ["M008", "Triệu Quang Huy", "Huy", 3, "MALE", "LIVING", "1982-04-12", null, "21:10", "Hà Nội", "Đại diện thế hệ thứ ba."],
  ["M009", "Trần Thu Hà", "Hà", 3, "FEMALE", "LIVING", "1984-10-30", null, null, "Hà Nội", "Phu nhân của Huy."],
  ["M010", "Triệu Quang Minh", "Minh", 3, "MALE", "LIVING", "1985-08-21", null, null, "Đà Nẵng", "Thành viên chi thứ nhất."],
  ["M011", "Triệu Ngọc Linh", "Linh", 3, "FEMALE", "LIVING", "1988-12-02", null, "03:40", "TP.HCM", "Thành viên chi thứ nhất."],
  ["M012", "Triệu Anh Tuấn", "Tuấn", 3, "MALE", "LIVING", "1987-06-18", null, null, "Hà Nội", "Thành viên chi thứ hai."],
  ["M013", "Đỗ Minh Châu", "Châu", 3, "FEMALE", "LIVING", "1989-02-27", null, null, "Hải Phòng", "Phu nhân của Tuấn."],
  ["M014", "Triệu Thanh Bình", "Bình", 3, "MALE", "DECEASED", "1990-07-07", "2020-11-02", null, "Hà Nội", "Dữ liệu mẫu cho ngày giỗ."],
  ["M015", "Triệu An Nhiên", "Nhiên", 4, "FEMALE", "LIVING", "2010-01-16", null, "06:05", "Hà Nội", "Thế hệ thứ tư."],
  ["M016", "Triệu Gia Bảo", "Bảo", 4, "MALE", "LIVING", "2012-05-28", null, null, "Hà Nội", "Thế hệ thứ tư."],
  ["M017", "Triệu Minh Anh", "Anh", 4, "FEMALE", "LIVING", "2014-09-09", null, null, "Đà Nẵng", "Thế hệ thứ tư."],
  ["M018", "Triệu Khánh Nam", "Nam", 4, "MALE", "LIVING", "2015-12-24", null, "23:15", "Hà Nội", "Thế hệ thứ tư."],
  ["M019", "Triệu Hải Đăng", "Đăng", 4, "MALE", "LIVING", "2017-03-03", null, null, "Hải Phòng", "Thế hệ thứ tư."],
  ["M020", "Triệu Tuệ Lâm", "Lâm", 4, "FEMALE", "LIVING", "2019-08-15", null, null, "TP.HCM", "Thế hệ thứ tư."],
  ["M021", "Triệu Bảo Ngọc", "Ngọc", 4, "FEMALE", "LIVING", "2021-10-01", null, "10:45", "Hà Nội", "Thế hệ thứ tư."],
  ["M022", "Triệu Phúc Khang", "Khang", 4, "MALE", "LIVING", "2023-04-20", null, null, "Hà Nội", "Thế hệ thứ tư."]
] as const;

async function main() {
  await prisma.$transaction([
    prisma.auditLog.deleteMany(),
    prisma.backup.deleteMany(),
    prisma.setting.deleteMany(),
    prisma.astrologyReport.deleteMany(),
    prisma.iChingReport.deleteMany(),
    prisma.baziReport.deleteMany(),
    prisma.numerologyReport.deleteMany(),
    prisma.zodiacData.deleteMany(),
    prisma.canChiData.deleteMany(),
    prisma.lunarDateData.deleteMany(),
    prisma.memberMedia.deleteMany(),
    prisma.document.deleteMany(),
    prisma.mediaFile.deleteMany(),
    prisma.album.deleteMany(),
    prisma.eventTranslation.deleteMany(),
    prisma.event.deleteMany(),
    prisma.children.deleteMany(),
    prisma.spouse.deleteMany(),
    prisma.relationship.deleteMany(),
    prisma.memberTranslation.deleteMany(),
    prisma.member.deleteMany(),
    prisma.familyBranch.deleteMany(),
    prisma.userRole.deleteMany(),
    prisma.rolePermission.deleteMany(),
    prisma.user.deleteMany(),
    prisma.permission.deleteMany(),
    prisma.role.deleteMany(),
    prisma.family.deleteMany()
  ]);

  const permissionRows = await Promise.all(
    permissions.map((action) => prisma.permission.create({ data: { action } }))
  );

  const roleRows = new Map<string, string>();
  for (const [name, description] of roles) {
    const role = await prisma.role.create({ data: { name, description } });
    roleRows.set(name, role.id);
  }

  for (const permission of permissionRows) {
    await prisma.rolePermission.create({
      data: { roleId: roleRows.get("SUPER_ADMIN")!, permissionId: permission.id }
    });
  }

  const family = await prisma.family.create({
    data: {
      name: "Họ Triệu Văn",
      originPlace: "Bắc Ninh, Việt Nam",
      description: "Dòng họ mẫu dùng để kiểm thử nền tảng gia phả số."
    }
  });

  const branchMain = await prisma.familyBranch.create({
    data: { familyId: family.id, name: "Chi trưởng", description: "Nhánh trưởng của dòng họ." }
  });
  const branchSecond = await prisma.familyBranch.create({
    data: { familyId: family.id, name: "Chi thứ hai", description: "Nhánh thứ hai của dòng họ." }
  });
  const branchModern = await prisma.familyBranch.create({
    data: { familyId: family.id, name: "Nhánh phương Nam", description: "Nhánh sinh sống tại miền Nam." }
  });

  const memberByCode = new Map<string, string>();
  for (const item of members) {
    const [code, fullName, givenName, generation, gender, lifeStatus, birthDate, deathDate, birthTime, birthPlace, biography] = item;
    const member = await prisma.member.create({
      data: {
        familyId: family.id,
        branchId: generation <= 2 ? branchMain.id : code === "M012" || code === "M013" || code === "M019" ? branchSecond.id : code === "M020" ? branchModern.id : branchMain.id,
        code,
        fullName,
        givenName,
        generation,
        gender,
        lifeStatus,
        birthDate: birthDate ? new Date(`${birthDate}T00:00:00.000Z`) : undefined,
        deathDate: deathDate ? new Date(`${deathDate}T00:00:00.000Z`) : undefined,
        birthTime: birthTime ?? undefined,
        birthPlace: birthPlace ?? undefined,
        biography,
        avatarUrl: `https://placehold.co/240x240?text=${encodeURIComponent(givenName)}`
      }
    });
    memberByCode.set(code, member.id);

    await prisma.memberTranslation.create({
      data: {
        memberId: member.id,
        locale: "vi",
        fullName,
        pinyin: code.startsWith("M00") ? "Zhao" : null,
        ipa: "/t͡ɕəw˧/",
        biography: `${biography} (bản dịch mẫu tiếng Việt)`
      }
    });
  }

  const parentChildPairs = [
    ["M001", "M003"], ["M002", "M003"], ["M001", "M005"], ["M002", "M005"], ["M001", "M007"], ["M002", "M007"],
    ["M003", "M008"], ["M004", "M008"], ["M003", "M010"], ["M004", "M010"], ["M003", "M011"], ["M004", "M011"],
    ["M005", "M012"], ["M006", "M012"], ["M005", "M014"], ["M006", "M014"],
    ["M008", "M015"], ["M009", "M015"], ["M008", "M016"], ["M009", "M016"],
    ["M010", "M017"], ["M012", "M018"], ["M013", "M018"], ["M012", "M019"], ["M013", "M019"],
    ["M011", "M020"], ["M008", "M021"], ["M009", "M021"], ["M010", "M022"]
  ];

  for (const [parent, child] of parentChildPairs) {
    const parentId = memberByCode.get(parent)!;
    const childId = memberByCode.get(child)!;
    await prisma.children.create({ data: { parentId, childId } });
    await prisma.relationship.create({
      data: {
        familyId: family.id,
        fromMemberId: parentId,
        toMemberId: childId,
        type: "PARENT"
      }
    });
  }

  for (const [a, b] of [["M001", "M002"], ["M003", "M004"], ["M005", "M006"], ["M008", "M009"], ["M012", "M013"]]) {
    await prisma.spouse.create({ data: { memberAId: memberByCode.get(a)!, memberBId: memberByCode.get(b)! } });
    await prisma.relationship.create({
      data: { familyId: family.id, fromMemberId: memberByCode.get(a)!, toMemberId: memberByCode.get(b)!, type: "SPOUSE" }
    });
  }

  const nextMonth = new Date();
  nextMonth.setMonth(nextMonth.getMonth() + 1);

  const eventRows = [
    ["Họp mặt gia đình mùa thu", "REUNION", nextMonth, "Nhà thờ họ", null],
    ["Sinh nhật Triệu An Nhiên", "BIRTHDAY", new Date("2026-01-16T09:00:00.000Z"), "Hà Nội", "M015"],
    ["Ngày giỗ Triệu Thanh Bình", "DEATH_ANNIVERSARY", new Date("2026-11-02T08:00:00.000Z"), "Hà Nội", "M014"]
  ] as const;

  for (const [title, type, startsAt, location, code] of eventRows) {
    const event = await prisma.event.create({
      data: {
        familyId: family.id,
        memberId: code ? memberByCode.get(code) : undefined,
        title,
        type,
        startsAt,
        location,
        description: "Sự kiện mẫu phục vụ kiểm thử lịch gia đình."
      }
    });
    await prisma.eventTranslation.create({
      data: { eventId: event.id, locale: "en", title: `${title} (sample)`, description: "Sample translated event." }
    });
  }

  for (const code of ["M008", "M015", "M018"]) {
    const memberId = memberByCode.get(code)!;
    await prisma.lunarDateData.create({ data: { memberId, solarDate: new Date(), lunarDay: 15, lunarMonth: 8, lunarYear: 2026 } });
    await prisma.canChiData.create({ data: { memberId, yearStem: "Bính", yearBranch: "Ngọ", monthStem: "Đinh", dayStem: "Mậu", hourStem: "Canh" } });
    await prisma.zodiacData.create({ data: { memberId, chineseZodiac: "Ngọ", westernZodiac: "Aries", description: "Dữ liệu tham khảo mẫu." } });
  }

  await prisma.numerologyReport.create({
    data: { memberId: memberByCode.get("M008")!, lifePath: 6, expression: 3, report: "Báo cáo thần số học mẫu, chỉ dùng tham khảo văn hóa." }
  });
  await prisma.baziReport.create({
    data: { memberId: memberByCode.get("M015")!, pillars: "Canh Dần / Kỷ Sửu / Bính Thân / Tân Mão", summary: "Báo cáo Bát tự mẫu." }
  });
  await prisma.astrologyReport.create({
    data: { memberId: memberByCode.get("M018")!, sunSign: "Sagittarius", moonSign: "Taurus", summary: "Báo cáo chiêm tinh mẫu." }
  });
  await prisma.iChingReport.create({
    data: { familyId: family.id, question: "Định hướng phát triển tư liệu gia đình?", hexagram: "Gia Nhân", summary: "Quẻ mẫu cho module Kinh Dịch." }
  });

  await prisma.album.create({
    data: { familyId: family.id, title: "Tư liệu họ Triệu", description: "Album mẫu cho ảnh, video và tài liệu." }
  });

  await prisma.setting.createMany({
    data: [
      { familyId: family.id, key: "defaultLanguage", value: "vi" },
      { familyId: family.id, key: "showIpa", value: "true" },
      { familyId: family.id, key: "showPinyin", value: "true" },
      { familyId: family.id, key: "defaultCalendar", value: "both" },
      { familyId: family.id, key: "theme", value: "light" }
    ]
  });

  const passwordHash = await bcrypt.hash("Admin@123456", 12);
  const admin = await prisma.user.create({
    data: {
      email: "admin@example.com",
      passwordHash,
      displayName: "Super Admin",
      familyId: family.id
    }
  });
  await prisma.userRole.create({ data: { userId: admin.id, roleId: roleRows.get("SUPER_ADMIN")! } });

  console.log("Seed completed");
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
