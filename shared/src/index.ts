export type ApiResponse<T> = {
  success: boolean;
  message: string;
  data?: T;
  errors?: unknown[];
};

export const DEFAULT_ADMIN = {
  email: "admin@example.com",
  password: "Admin@123456"
} as const;

export const ROLES = [
  "SUPER_ADMIN",
  "FAMILY_ADMIN",
  "EDITOR",
  "MEMBER",
  "VIEWER"
] as const;

export type RoleName = (typeof ROLES)[number];
