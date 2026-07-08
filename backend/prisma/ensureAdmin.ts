import bcrypt from "bcryptjs";
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

const roleDefinitions = [
  ["SUPER_ADMIN", "Quản trị toàn bộ hệ thống"],
  ["FAMILY_ADMIN", "Quản trị toàn bộ dữ liệu một dòng họ"],
  ["EDITOR", "Thêm và sửa thành viên, sự kiện, tư liệu"],
  ["MEMBER", "Xem dữ liệu và đề xuất chỉnh sửa"],
  ["VIEWER", "Chỉ xem dữ liệu được cho phép"]
] as const;

const permissionActions = [
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

async function main() {
  const adminEmail = process.env.ADMIN_EMAIL ?? "admin@example.com";
  const adminPassword = process.env.ADMIN_PASSWORD ?? "Admin@123456";
  const familyName = process.env.DEFAULT_FAMILY_NAME ?? "Họ Triệu Văn";

  const roleIds = new Map<string, string>();
  for (const [name, description] of roleDefinitions) {
    const role = await prisma.role.upsert({
      where: { name },
      create: { name, description },
      update: { description }
    });
    roleIds.set(name, role.id);
  }

  const permissionIds = new Map<string, string>();
  for (const action of permissionActions) {
    const permission = await prisma.permission.upsert({
      where: { action },
      create: { action },
      update: {}
    });
    permissionIds.set(action, permission.id);
  }

  for (const permissionId of permissionIds.values()) {
    await prisma.rolePermission.upsert({
      where: {
        roleId_permissionId: {
          roleId: roleIds.get("SUPER_ADMIN")!,
          permissionId
        }
      },
      create: {
        roleId: roleIds.get("SUPER_ADMIN")!,
        permissionId
      },
      update: {}
    });
  }

  const family =
    (await prisma.family.findFirst({ where: { name: familyName } })) ??
    (await prisma.family.create({
      data: {
        name: familyName,
        originPlace: "Việt Nam",
        description: "Dòng họ mặc định được tạo khi khởi tạo production."
      }
    }));

  const passwordHash = await bcrypt.hash(adminPassword, 12);
  const admin = await prisma.user.upsert({
    where: { email: adminEmail },
    create: {
      email: adminEmail,
      passwordHash,
      displayName: "Super Admin",
      familyId: family.id,
      isActive: true
    },
    update: {
      passwordHash,
      displayName: "Super Admin",
      familyId: family.id,
      isActive: true
    }
  });

  await prisma.userRole.upsert({
    where: {
      userId_roleId: {
        userId: admin.id,
        roleId: roleIds.get("SUPER_ADMIN")!
      }
    },
    create: {
      userId: admin.id,
      roleId: roleIds.get("SUPER_ADMIN")!
    },
    update: {}
  });

  console.log(`Production admin ready: ${adminEmail}`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
