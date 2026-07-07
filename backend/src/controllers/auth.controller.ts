import { authService } from "../services/auth.service.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { sendSuccess } from "../utils/apiResponse.js";

export const authController = {
  login: asyncHandler(async (req, res) => {
    const result = await authService.login(req.body.email, req.body.password);
    sendSuccess(res, result, "Logged in successfully");
  }),

  register: asyncHandler(async (req, res) => {
    const result = await authService.register(req.body);
    sendSuccess(res, result, "Registered successfully", 201);
  }),

  me: asyncHandler(async (req, res) => {
    const result = await authService.me(req.user!.id);
    sendSuccess(res, result);
  })
};
