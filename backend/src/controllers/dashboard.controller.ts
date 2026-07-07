import { dashboardService } from "../services/dashboard.service.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { sendSuccess } from "../utils/apiResponse.js";

export const dashboardController = {
  overview: asyncHandler(async (req, res) => {
    const data = await dashboardService.getOverview(req.user?.familyId);
    sendSuccess(res, data);
  })
};
