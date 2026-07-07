import { useQuery } from "@tanstack/react-query";
import { Bar, BarChart, CartesianGrid, Cell, Pie, PieChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import { getDashboard } from "../services/api";
import { fallbackDashboard } from "../utils/fallbackData";
import { PageHeader } from "../components/ui/PageHeader";
import { StatCard } from "../components/ui/StatCard";

const colors = ["#11584d", "#9b6a3e", "#1c7c6b", "#5c3a20", "#78716c"];

export function DashboardPage() {
  const { data, isError } = useQuery({ queryKey: ["dashboard"], queryFn: getDashboard });
  const dashboard = data ?? fallbackDashboard;

  return (
    <div>
      <PageHeader
        title="Dashboard tổng quan"
        description="Theo dõi quy mô dòng họ, phân bố thế hệ, giới tính, trạng thái thành viên và các sự kiện sắp tới."
      />
      {isError ? <div className="mb-4 rounded-md bg-amber-50 px-4 py-3 text-sm text-amber-800">Đang hiển thị dữ liệu mẫu vì API chưa phản hồi.</div> : null}
      <section className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard label="Tổng thành viên" value={dashboard.stats.totalMembers} helper="Bao gồm mọi thế hệ" />
        <StatCard label="Tổng số đời" value={dashboard.stats.totalGenerations} helper="Tính theo generation" />
        <StatCard label="Tổng số nhánh" value={dashboard.stats.totalBranches} helper="Chi/nhánh gia đình" />
        <StatCard label="Còn sống / Đã mất" value={`${dashboard.stats.livingMembers}/${dashboard.stats.deceasedMembers}`} helper="Theo trạng thái hồ sơ" />
      </section>

      <section className="mt-6 grid gap-6 xl:grid-cols-2">
        <div className="surface p-5">
          <h2 className="mb-4 font-semibold">Phân bố theo đời</h2>
          <div className="h-72">
            <ResponsiveContainer>
              <BarChart data={dashboard.charts.generations}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="name" />
                <YAxis allowDecimals={false} />
                <Tooltip />
                <Bar dataKey="value" fill="#11584d" radius={[6, 6, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>
        <div className="surface p-5">
          <h2 className="mb-4 font-semibold">Giới tính</h2>
          <div className="h-72">
            <ResponsiveContainer>
              <PieChart>
                <Pie data={dashboard.charts.genders} dataKey="value" nameKey="name" outerRadius={100} label>
                  {dashboard.charts.genders.map((_, index) => <Cell key={index} fill={colors[index % colors.length]} />)}
                </Pie>
                <Tooltip />
              </PieChart>
            </ResponsiveContainer>
          </div>
        </div>
      </section>

      <section className="mt-6 grid gap-6 xl:grid-cols-2">
        <div className="surface p-5">
          <h2 className="mb-4 font-semibold">Sự kiện sắp tới</h2>
          <div className="space-y-3">
            {dashboard.upcomingEvents.map((event) => (
              <div className="rounded-md border border-stone-200 p-3 dark:border-white/10" key={event.id}>
                <p className="font-medium">{event.title}</p>
                <p className="text-sm text-stone-500">{new Date(event.startsAt).toLocaleDateString("vi-VN")} · {event.location}</p>
              </div>
            ))}
          </div>
        </div>
        <div className="surface p-5">
          <h2 className="mb-4 font-semibold">Thành viên mới thêm</h2>
          <div className="grid gap-3 sm:grid-cols-2">
            {dashboard.recentMembers.map((member) => (
              <div className="flex items-center gap-3 rounded-md border border-stone-200 p-3 dark:border-white/10" key={member.id}>
                <img className="h-11 w-11 rounded-full object-cover" src={member.avatarUrl ?? "https://placehold.co/120"} alt="" />
                <div>
                  <p className="font-medium">{member.fullName}</p>
                  <p className="text-xs text-stone-500">Đời {member.generation} · {member.birthPlace ?? "Chưa rõ"}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>
    </div>
  );
}
