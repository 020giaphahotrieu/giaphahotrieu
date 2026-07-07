import { Link } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { Plus } from "lucide-react";
import { getMembers } from "../services/api";
import { fallbackMembers } from "../utils/fallbackData";
import { PageHeader } from "../components/ui/PageHeader";

export function MembersPage() {
  const { data } = useQuery({ queryKey: ["members"], queryFn: getMembers });
  const members = data ?? fallbackMembers;

  return (
    <div>
      <PageHeader
        title="Danh sách thành viên"
        description="Quản lý hồ sơ, đời, nhánh, trạng thái sống/mất và thông tin phiên âm tinh tế."
        action={<Link className="btn-primary gap-2" to="/members/new"><Plus size={16} />Thêm thành viên</Link>}
      />
      <div className="surface overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[760px] text-left text-sm">
            <thead className="bg-heritage-100 text-xs uppercase text-stone-600 dark:bg-white/5 dark:text-stone-300">
              <tr>
                <th className="px-4 py-3">Thành viên</th>
                <th className="px-4 py-3">Đời</th>
                <th className="px-4 py-3">Giới tính</th>
                <th className="px-4 py-3">Trạng thái</th>
                <th className="px-4 py-3">Nhánh</th>
                <th className="px-4 py-3">Nơi sinh</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-stone-100 dark:divide-white/10">
              {members.map((member) => (
                <tr key={member.id} className="hover:bg-heritage-50 dark:hover:bg-white/5">
                  <td className="px-4 py-3">
                    <Link className="flex items-center gap-3" to={`/members/${member.id}`}>
                      <img className="h-10 w-10 rounded-full object-cover" src={member.avatarUrl ?? "https://placehold.co/120"} alt="" />
                      <span>
                        <span className="block font-semibold">{member.fullName}</span>
                        <span className="text-xs text-stone-500">{member.translations?.[0]?.ipa} {member.translations?.[0]?.pinyin}</span>
                      </span>
                    </Link>
                  </td>
                  <td className="px-4 py-3">{member.generation}</td>
                  <td className="px-4 py-3">{member.gender}</td>
                  <td className="px-4 py-3">{member.lifeStatus}</td>
                  <td className="px-4 py-3">{member.branch?.name ?? "Chưa phân nhánh"}</td>
                  <td className="px-4 py-3">{member.birthPlace ?? "Chưa rõ"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
