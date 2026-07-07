import { FormEvent, useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useNavigate } from "react-router-dom";
import { createMember } from "../services/api";
import { PageHeader } from "../components/ui/PageHeader";

export function MemberFormPage() {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [form, setForm] = useState({
    fullName: "",
    givenName: "",
    generation: 1,
    gender: "UNKNOWN",
    lifeStatus: "LIVING",
    birthPlace: "",
    biography: ""
  });

  const mutation = useMutation({
    mutationFn: createMember,
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ["members"] });
      navigate("/members");
    }
  });

  function onSubmit(event: FormEvent) {
    event.preventDefault();
    mutation.mutate(form as never);
  }

  return (
    <div>
      <PageHeader title="Thêm thành viên" description="Biểu mẫu tối giản cho người lớn tuổi, tách dữ liệu quan trọng và tránh nhập rối." />
      <form className="surface grid gap-4 p-6 md:grid-cols-2" onSubmit={onSubmit}>
        <label className="text-sm font-medium">Họ tên<input className="input mt-1" value={form.fullName} onChange={(e) => setForm({ ...form, fullName: e.target.value })} required /></label>
        <label className="text-sm font-medium">Tên gọi<input className="input mt-1" value={form.givenName} onChange={(e) => setForm({ ...form, givenName: e.target.value })} /></label>
        <label className="text-sm font-medium">Đời<input className="input mt-1" type="number" min={1} value={form.generation} onChange={(e) => setForm({ ...form, generation: Number(e.target.value) })} /></label>
        <label className="text-sm font-medium">Nơi sinh<input className="input mt-1" value={form.birthPlace} onChange={(e) => setForm({ ...form, birthPlace: e.target.value })} /></label>
        <label className="text-sm font-medium">Giới tính<select className="input mt-1" value={form.gender} onChange={(e) => setForm({ ...form, gender: e.target.value })}><option value="MALE">Nam</option><option value="FEMALE">Nữ</option><option value="OTHER">Khác</option><option value="UNKNOWN">Chưa rõ</option></select></label>
        <label className="text-sm font-medium">Trạng thái<select className="input mt-1" value={form.lifeStatus} onChange={(e) => setForm({ ...form, lifeStatus: e.target.value })}><option value="LIVING">Còn sống</option><option value="DECEASED">Đã mất</option><option value="UNKNOWN">Chưa rõ</option></select></label>
        <label className="text-sm font-medium md:col-span-2">Tiểu sử<textarea className="input mt-1 min-h-28" value={form.biography} onChange={(e) => setForm({ ...form, biography: e.target.value })} /></label>
        <div className="md:col-span-2"><button className="btn-primary" type="submit" disabled={mutation.isPending}>{mutation.isPending ? "Đang lưu..." : "Lưu thành viên"}</button></div>
      </form>
    </div>
  );
}
