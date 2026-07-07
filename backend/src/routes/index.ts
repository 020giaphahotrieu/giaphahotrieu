import { Router } from "express";
import { authRoutes } from "./auth.routes.js";
import { memberRoutes } from "./member.routes.js";
import { dashboardController } from "../controllers/dashboard.controller.js";
import { contentController } from "../controllers/content.controller.js";
import { authenticate, authorize } from "../middlewares/auth.js";
import { upload } from "../middlewares/upload.js";
import { prisma } from "../config/prisma.js";
import { sendSuccess } from "../utils/apiResponse.js";

export const apiRoutes = Router();

apiRoutes.get("/health", (_req, res) => sendSuccess(res, { status: "ok", service: "family-heritage-api" }));
apiRoutes.use("/auth", authRoutes);
apiRoutes.get("/dashboard", authenticate, dashboardController.overview);
apiRoutes.use("/members", memberRoutes);
apiRoutes.get("/families", authenticate, contentController.families);
apiRoutes.get("/events", authenticate, contentController.events);
apiRoutes.get("/relationships", authenticate, contentController.relationships);
apiRoutes.get("/analytics", authenticate, contentController.analytics);

apiRoutes.post(
  "/media/upload",
  authenticate,
  authorize("SUPER_ADMIN", "FAMILY_ADMIN", "EDITOR"),
  upload.single("file"),
  async (req, res, next) => {
    try {
      const file = req.file!;
      const media = await prisma.mediaFile.create({
        data: {
          familyId: req.user!.familyId!,
          type: file.mimetype.startsWith("image/") ? "IMAGE" : file.mimetype.startsWith("video/") ? "VIDEO" : "DOCUMENT",
          url: `/uploads/${file.filename}`,
          fileName: file.originalname,
          mimeType: file.mimetype,
          size: file.size
        }
      });
      sendSuccess(res, media, "File uploaded", 201);
    } catch (error) {
      next(error);
    }
  }
);

apiRoutes.get("/export", authenticate, authorize("SUPER_ADMIN", "FAMILY_ADMIN"), async (req, res, next) => {
  try {
    const familyId = req.user?.familyId;
    const [family, members, relationships, events] = await Promise.all([
      familyId ? prisma.family.findUnique({ where: { id: familyId } }) : null,
      prisma.member.findMany({ where: familyId ? { familyId } : {} }),
      prisma.relationship.findMany({ where: familyId ? { familyId } : {} }),
      prisma.event.findMany({ where: familyId ? { familyId } : {} })
    ]);
    sendSuccess(res, { family, members, relationships, events }, "Export ready");
  } catch (error) {
    next(error);
  }
});

apiRoutes.post("/backup", authenticate, authorize("SUPER_ADMIN", "FAMILY_ADMIN"), async (req, res, next) => {
  try {
    const backup = await prisma.backup.create({
      data: {
        familyId: req.user?.familyId,
        fileName: `backup-${new Date().toISOString()}.json`,
        status: "COMPLETED",
        note: "Logical backup record created. Wire this to object storage for production."
      }
    });
    sendSuccess(res, backup, "Backup created", 201);
  } catch (error) {
    next(error);
  }
});
