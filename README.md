# Digital Family Heritage Platform

Nền tảng gia phả số chuyên nghiệp để quản lý dòng họ, thành viên, quan hệ huyết thống, lịch sử gia tộc, sự kiện, tư liệu và các module tham khảo văn hóa như lịch âm, Can Chi, con giáp, thần số học, Bát tự, Kinh Dịch và 12 cung hoàng đạo.

## Tính năng chính

- Authentication bằng JWT, mật khẩu mã hóa bcrypt.
- RBAC với vai trò: Super Admin, Family Admin, Editor, Member, Viewer.
- Dashboard thống kê thành viên, thế hệ, nhánh, giới tính, trạng thái sống/mất, sự kiện sắp tới.
- Quản lý thành viên, hồ sơ chi tiết, phiên âm IPA/Pinyin, nhánh gia đình.
- Cây gia phả bằng React Flow.
- Trang sự kiện, lịch gia đình, thư viện media, phân tích cá nhân, so sánh, import/export, settings, quản trị, backup.
- Prisma schema mở rộng cho Users, Roles, Permissions, Families, Members, Relationships, Events, Media, Documents, Reports, AuditLogs, Backups, Settings.
- Seed data mẫu gồm 1 dòng họ, 4 thế hệ, 22 thành viên, quan hệ cha mẹ/vợ chồng/con cái, sự kiện, bản dịch và dữ liệu phân tích mẫu.

## Công nghệ

- Frontend: React, TypeScript, Tailwind CSS, React Router, TanStack Query, Zustand, react-i18next, Recharts, React Flow.
- Backend: Node.js, Express.js, TypeScript, Prisma ORM, SQLite local dev, JWT, bcrypt, multer, zod.
- Database production khuyến nghị: PostgreSQL. Bản local dùng SQLite để chạy nhanh.

## Cấu trúc thư mục

```txt
frontend/    React app
backend/     Express API, Prisma, seed
shared/      Kiểu dữ liệu và constants dùng chung
docs/        API documentation
scripts/     Backup/restore utilities
uploads/     File upload local
database/    SQLite database local
modules/     Kiến trúc domain module mở rộng
```

## Cài đặt

Yêu cầu Node.js 20+ và pnpm 9+.

```bash
cp .env.example .env
cp backend/.env.example backend/.env
cp frontend/.env.example frontend/.env
pnpm install
```

## Cấu hình database

Mặc định `.env.example` dùng SQLite:

```env
DATABASE_URL="file:../../database/family-heritage.db"
```

Để chuyển sang PostgreSQL sau này, đổi `datasource db.provider` trong `backend/prisma/schema.prisma` thành `postgresql` và đặt:

```env
DATABASE_URL="postgresql://user:password@localhost:5432/family_heritage"
```

## Migration và seed

```bash
pnpm db:migrate
pnpm db:seed
```

Local SQLite migration dùng SQL trong `backend/prisma/migrations/20260708000000_init/migration.sql` để chạy ổn định. Prisma schema vẫn là nguồn thiết kế chính; khi dùng PostgreSQL production có thể chuyển lại Prisma migrate workflow chuẩn.

Tài khoản admin mặc định:

- Email: `admin@example.com`
- Password: `Admin@123456`

## Chạy local

Chạy backend:

```bash
pnpm dev:backend
```

Chạy frontend:

```bash
pnpm dev:frontend
```

Hoặc chạy cả hai:

```bash
pnpm dev
```

URL mặc định:

- Frontend: `http://localhost:5173`
- Backend: `http://localhost:4000/api`
- Health check: `http://localhost:4000/api/health`

Frontend dùng `VITE_API_URL="/api"` và Vite proxy `/api` sang `http://127.0.0.1:4000`, nên khi mở bằng IP server trong mạng cũng không bị browser gọi nhầm `localhost` của máy người dùng.

## Build production

```bash
pnpm build
pnpm --filter @dfhp/backend start
```

Triển khai cơ bản:

1. Tạo database PostgreSQL production.
2. Cấu hình `DATABASE_URL`, `JWT_SECRET`, `CLIENT_URL`, `UPLOAD_DIR`.
3. Chạy `pnpm install --frozen-lockfile`, `pnpm db:migrate`, `pnpm build`.
4. Serve `frontend/dist` bằng Nginx/CDN và chạy backend bằng PM2/Systemd/container.
5. Đưa uploads sang object storage như S3/R2 khi lên production.

## Backup và restore

SQLite local:

```bash
bash scripts/backup-sqlite.sh
bash scripts/restore-sqlite.sh database/backups/family-heritage-YYYYMMDD-HHMMSS.db
```

API có endpoint bước đầu:

- `POST /api/backup`
- `GET /api/export`

## API

Xem [docs/API.md](docs/API.md).

Response chuẩn:

```json
{
  "success": true,
  "message": "Success",
  "data": {}
}
```

Error chuẩn:

```json
{
  "success": false,
  "message": "Error message",
  "errors": []
}
```

## Ghi chú giới hạn kỹ thuật

- Module lịch âm, Can Chi, Bát tự, Kinh Dịch, chiêm tinh hiện có schema, route và dữ liệu mẫu; engine tính toán chuyên sâu cần bổ sung bằng thư viện/thuật toán đã kiểm chứng.
- Upload local phù hợp dev; production nên dùng object storage, antivirus scanning và signed URL.
- React Flow hiện dùng cây mẫu ở frontend; bước tiếp theo là chuyển quan hệ từ `/api/relationships` thành node/edge động.
- SQLite phù hợp phát triển local; production nên dùng PostgreSQL.

## Roadmap

- GEDCOM import/export.
- Tree layout động theo nhánh, đời và quan hệ hôn phối.
- Audit log đầy đủ cho mọi thao tác ghi.
- Workflow đề xuất chỉnh sửa cho vai trò Member.
- PDF family book export.
- Calendar engine âm/dương có kiểm thử theo vùng thời gian.
- Backup mã hóa, scheduled backup và restore wizard.
- Tìm kiếm nâng cao theo tên, đời, chi, ngày sinh, nơi sinh.
