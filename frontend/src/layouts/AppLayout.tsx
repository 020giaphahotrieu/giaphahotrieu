import { NavLink, Outlet, useNavigate } from "react-router-dom";
import { CalendarDays, Database, FileDown, Home, Image, LogOut, Moon, Network, Settings, Shield, Sun, Users } from "lucide-react";
import clsx from "clsx";
import { useAuthStore } from "../store/authStore";
import { useUiStore } from "../store/uiStore";

const navItems = [
  { to: "/", label: "Dashboard", icon: Home },
  { to: "/family-home", label: "Dòng họ", icon: Network },
  { to: "/tree", label: "Cây gia phả", icon: Network },
  { to: "/members", label: "Thành viên", icon: Users },
  { to: "/events", label: "Sự kiện", icon: CalendarDays },
  { to: "/media", label: "Tư liệu", icon: Image },
  { to: "/analysis", label: "Phân tích", icon: Database },
  { to: "/export", label: "Xuất/Nhập", icon: FileDown },
  { to: "/admin/users", label: "Quản trị", icon: Shield },
  { to: "/settings", label: "Cài đặt", icon: Settings }
];

export function AppLayout() {
  const navigate = useNavigate();
  const user = useAuthStore((state) => state.user);
  const clearSession = useAuthStore((state) => state.clearSession);
  const darkMode = useUiStore((state) => state.darkMode);
  const toggleDarkMode = useUiStore((state) => state.toggleDarkMode);

  return (
    <div className="min-h-screen bg-heritage-50 text-stone-900 dark:bg-stone-950 dark:text-stone-100">
      <aside className="fixed inset-y-0 left-0 z-20 hidden w-72 border-r border-heritage-100 bg-white/95 px-4 py-5 dark:border-white/10 dark:bg-stone-900 lg:block">
        <div className="mb-8">
          <p className="text-xs font-semibold uppercase tracking-[0.18em] text-jade-700 dark:text-jade-500">Digital Family</p>
          <h2 className="mt-1 text-xl font-bold text-stone-950 dark:text-white">Heritage Platform</h2>
        </div>
        <nav className="space-y-1">
          {navItems.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) =>
                clsx(
                  "flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition",
                  isActive ? "bg-heritage-100 text-heritage-900 dark:bg-white/10 dark:text-white" : "text-stone-600 hover:bg-heritage-50 dark:text-stone-300 dark:hover:bg-white/5"
                )
              }
            >
              <item.icon size={18} />
              {item.label}
            </NavLink>
          ))}
        </nav>
      </aside>

      <div className="lg:pl-72">
        <header className="sticky top-0 z-10 border-b border-heritage-100 bg-white/85 backdrop-blur dark:border-white/10 dark:bg-stone-900/85">
          <div className="flex min-h-16 items-center justify-between gap-3 px-4 sm:px-6 lg:px-8">
            <div>
              <p className="text-sm font-semibold">{user?.familyName ?? "Họ Triệu Văn"}</p>
              <p className="text-xs text-stone-500 dark:text-stone-400">{user?.displayName ?? "Super Admin"} · {user?.roles?.[0] ?? "SUPER_ADMIN"}</p>
            </div>
            <div className="flex items-center gap-2">
              <button className="rounded-md border border-stone-200 p-2 dark:border-white/10" onClick={toggleDarkMode} aria-label="Toggle theme">
                {darkMode ? <Sun size={18} /> : <Moon size={18} />}
              </button>
              <button
                className="rounded-md border border-stone-200 p-2 dark:border-white/10"
                onClick={() => {
                  clearSession();
                  navigate("/login");
                }}
                aria-label="Logout"
              >
                <LogOut size={18} />
              </button>
            </div>
          </div>
          <nav className="flex gap-2 overflow-x-auto px-4 pb-3 lg:hidden">
            {navItems.slice(0, 7).map((item) => (
              <NavLink key={item.to} to={item.to} className="whitespace-nowrap rounded-md bg-heritage-100 px-3 py-1.5 text-xs font-semibold dark:bg-white/10">
                {item.label}
              </NavLink>
            ))}
          </nav>
        </header>
        <main className="px-4 py-6 sm:px-6 lg:px-8">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
