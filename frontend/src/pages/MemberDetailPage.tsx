import { useParams } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { api } from "../services/api";
import type { ApiResponse, Member } from "../types";
import { fallbackMembers } from "../utils/fallbackData";
import { PageHeader } from "../components/ui/PageHeader";

async function fetchMember(id: string) {
  const response = await api.get<ApiResponse<Member>>(`/members/${id}`);
  return response.data.data;
}

export function MemberDetailPage() {
  const { id = "" } = useParams();
  const { data } = useQuery({ queryKey: ["member", id], queryFn: () => fetchMember(id), enabled: Boolean(id) });
  const member = data ?? fallbackMembers.find((item) => item.id === id) ?? fallbackMembers[0];

  return (
    <div>
      <PageHeader title={member.fullName} description={`Hồ sơ đời ${member.generation}, thuộc ${member.branch?.name ?? "nhánh chưa xác định"}.`} />
      <div className="grid gap-6 lg:grid-cols-[280px_1fr]">
        <div className="surface p-5">
          <img className="aspect-square w-full rounded-lg object-cover" src={member.avatarUrl ?? "https://placehold.co/400"} alt="" />
          <div className="mt-4 space-y-2 text-sm">
            <p><strong>Giới tính:</strong> {member.gender}</p>
            <p><strong>Trạng thái:</strong> {member.lifeStatus}</p>
            <p><strong>Nơi sinh:</strong> {member.birthPlace ?? "Chưa rõ"}</p>
          </div>
        </div>
        <div className="surface p-6">
          <h2 className="text-lg font-semibold">Tiểu sử</h2>
          <p className="mt-3 leading-7 text-stone-700 dark:text-stone-300">{member.biography ?? "Chưa có tiểu sử chi tiết."}</p>
          <h2 className="mt-8 text-lg font-semibold">Phiên âm và bản dịch</h2>
          <div className="mt-3 grid gap-3 md:grid-cols-2">
            {(member.translations ?? []).map((translation) => (
              <div className="rounded-md border border-stone-200 p-3 dark:border-white/10" key={translation.locale}>
                <p className="font-medium">{translation.locale.toUpperCase()} · {translation.fullName}</p>
                <p className="mt-1 text-xs text-stone-500">IPA {translation.ipa ?? "N/A"} · Pinyin {translation.pinyin ?? "N/A"}</p>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
