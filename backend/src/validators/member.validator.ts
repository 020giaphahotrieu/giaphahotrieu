import { z } from "zod";

export const memberSchema = z.object({
  body: z.object({
    familyId: z.string().optional(),
    branchId: z.string().nullable().optional(),
    fullName: z.string().min(2),
    givenName: z.string().optional(),
    generation: z.coerce.number().int().min(1),
    gender: z.enum(["MALE", "FEMALE", "OTHER", "UNKNOWN"]).default("UNKNOWN"),
    lifeStatus: z.enum(["LIVING", "DECEASED", "UNKNOWN"]).default("UNKNOWN"),
    birthDate: z.string().datetime().optional(),
    deathDate: z.string().datetime().optional(),
    birthTime: z.string().optional(),
    birthPlace: z.string().optional(),
    biography: z.string().optional()
  })
});
