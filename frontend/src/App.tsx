import { Navigate, Route, Routes } from "react-router-dom";
import { AppLayout } from "./layouts/AppLayout";
import { AuthLayout } from "./layouts/AuthLayout";
import { ProtectedRoute } from "./components/ProtectedRoute";
import { DashboardPage } from "./pages/DashboardPage";
import { FamilyTreePage } from "./pages/FamilyTreePage";
import { LoginPage } from "./pages/LoginPage";
import { RegisterPage } from "./pages/RegisterPage";
import { MembersPage } from "./pages/MembersPage";
import { MemberFormPage } from "./pages/MemberFormPage";
import { MemberDetailPage } from "./pages/MemberDetailPage";
import { GenericPage } from "./pages/GenericPage";

export default function App() {
  return (
    <Routes>
      <Route element={<AuthLayout />}>
        <Route path="/login" element={<LoginPage />} />
        <Route path="/register" element={<RegisterPage />} />
      </Route>
      <Route element={<ProtectedRoute />}>
        <Route element={<AppLayout />}>
          <Route index element={<DashboardPage />} />
          <Route path="/family-home" element={<GenericPage title="Trang chủ dòng họ" description="Không gian giới thiệu nguồn gốc, truyền thống, câu chuyện và các nhánh chính của dòng họ." items={["Nguồn gốc", "Gia huấn", "Nhà thờ họ", "Trưởng chi", "Tư liệu nổi bật", "Dòng thời gian"]} />} />
          <Route path="/tree" element={<FamilyTreePage />} />
          <Route path="/members" element={<MembersPage />} />
          <Route path="/members/new" element={<MemberFormPage />} />
          <Route path="/members/:id" element={<MemberDetailPage />} />
          <Route path="/relationships" element={<GenericPage title="Quan hệ gia đình" description="Quản lý cha mẹ, vợ chồng, con cái, anh chị em và các quan hệ đặc biệt." />} />
          <Route path="/events" element={<GenericPage title="Sự kiện" description="Theo dõi sinh nhật, ngày giỗ, họp mặt, lễ cưới, lễ tưởng niệm và sự kiện riêng." />} />
          <Route path="/calendar" element={<GenericPage title="Lịch gia đình" description="Lịch dương/âm kết hợp cho sự kiện dòng họ, sinh nhật và ngày giỗ." />} />
          <Route path="/media" element={<GenericPage title="Thư viện ảnh, video, tài liệu" description="Quản lý album, tư liệu số, giấy tờ lịch sử và liên kết tư liệu với từng thành viên." />} />
          <Route path="/analysis" element={<GenericPage title="Phân tích cá nhân" description="Module tham khảo văn hóa: lịch âm, Can Chi, con giáp, thần số học, Bát tự, Kinh Dịch, 12 cung hoàng đạo." />} />
          <Route path="/compare" element={<GenericPage title="So sánh hai thành viên" description="Đối chiếu quan hệ huyết thống, thế hệ, chi nhánh, dữ liệu sinh và các chỉ số tham khảo." />} />
          <Route path="/export" element={<GenericPage title="Xuất dữ liệu" description="Chuẩn bị xuất JSON/CSV/PDF và gói backup phục vụ lưu trữ dài hạn." />} />
          <Route path="/import" element={<GenericPage title="Nhập dữ liệu" description="Nhập dữ liệu từ CSV/JSON với kiểm tra trùng lặp, định dạng ngày và quan hệ gia đình." />} />
          <Route path="/settings" element={<GenericPage title="Cài đặt" description="Ngôn ngữ, IPA/Pinyin, lịch mặc định, giao diện sáng/tối, riêng tư, backup và xuất dữ liệu." items={["Ngôn ngữ mặc định", "Bật/tắt IPA", "Bật/tắt Pinyin", "Lịch dương/âm", "Quyền riêng tư", "Backup tự động"]} />} />
          <Route path="/admin/users" element={<GenericPage title="Quản trị người dùng" description="Quản lý tài khoản, vai trò Super Admin, Family Admin, Editor, Member, Viewer và quyền truy cập." />} />
          <Route path="/backup" element={<GenericPage title="Sao lưu và phục hồi" description="Tạo backup logic, ghi nhận lịch sử backup và chuẩn bị phục hồi dữ liệu." />} />
          <Route path="/about" element={<GenericPage title="Giới thiệu dòng họ" description="Trang nội dung dài hạn cho lịch sử, văn hóa, nhân vật tiêu biểu và di sản gia đình." />} />
        </Route>
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
