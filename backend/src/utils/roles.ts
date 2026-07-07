export const ROLES = {
  SUPER_ADMIN: "SUPER_ADMIN",
  FAMILY_ADMIN: "FAMILY_ADMIN",
  EDITOR: "EDITOR",
  MEMBER: "MEMBER",
  VIEWER: "VIEWER"
} as const;

export type RoleName = keyof typeof ROLES;

export const ROLE_LEVEL: Record<RoleName, number> = {
  SUPER_ADMIN: 100,
  FAMILY_ADMIN: 80,
  EDITOR: 60,
  MEMBER: 30,
  VIEWER: 10
};

export function hasAnyRole(userRoles: RoleName[], allowed: RoleName[]) {
  return userRoles.some((role) => allowed.includes(role));
}
