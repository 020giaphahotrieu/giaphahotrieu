import { Router } from "express";
import { authController } from "../controllers/auth.controller.js";
import { authenticate } from "../middlewares/auth.js";
import { validate } from "../middlewares/validate.js";
import { loginSchema, registerSchema } from "../validators/auth.validator.js";

export const authRoutes = Router();

authRoutes.post("/login", validate(loginSchema), authController.login);
authRoutes.post("/register", validate(registerSchema), authController.register);
authRoutes.get("/me", authenticate, authController.me);
