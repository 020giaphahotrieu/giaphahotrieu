import { memberService } from "../services/member.service.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { sendSuccess } from "../utils/apiResponse.js";

export const memberController = {
  list: asyncHandler(async (req, res) => {
    sendSuccess(res, await memberService.list(req.user?.familyId));
  }),

  get: asyncHandler(async (req, res) => {
    sendSuccess(res, await memberService.get(req.params.id));
  }),

  create: asyncHandler(async (req, res) => {
    sendSuccess(res, await memberService.create(req.body, req.user?.familyId), "Member created", 201);
  }),

  remove: asyncHandler(async (req, res) => {
    const force = req.query.force === "true";
    sendSuccess(res, await memberService.remove(req.params.id, force), "Member deleted");
  })
};
