import { Router } from "express";
import { memberController } from "../controllers/member.controller.js";
import { authenticate, authorize } from "../middlewares/auth.js";
import { validate } from "../middlewares/validate.js";
import { memberSchema } from "../validators/member.validator.js";

export const memberRoutes = Router();

memberRoutes.use(authenticate);
memberRoutes.get("/", memberController.list);
memberRoutes.post("/", authorize("SUPER_ADMIN", "FAMILY_ADMIN", "EDITOR"), validate(memberSchema), memberController.create);
memberRoutes.get("/:id", memberController.get);
memberRoutes.delete("/:id", authorize("SUPER_ADMIN", "FAMILY_ADMIN"), memberController.remove);
