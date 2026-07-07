import type { RoleName } from "../utils/roles.js";

declare global {
  namespace Express {
    interface Request {
      user?: {
        id: string;
        email: string;
        familyId: string | null;
        roles: RoleName[];
      };
    }
  }
}

export {};
