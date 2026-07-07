import { PageHeader } from "../components/ui/PageHeader";

type GenericPageProps = {
  title: string;
  description: string;
  items?: string[];
};

export function GenericPage({ title, description, items = [] }: GenericPageProps) {
  return (
    <div>
      <PageHeader title={title} description={description} />
      <div className="surface p-6">
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {(items.length ? items : ["Quản lý dữ liệu", "Tìm kiếm và lọc", "Phân quyền", "Xuất báo cáo", "Lịch sử thay đổi", "Thiết lập riêng tư"]).map((item) => (
            <div className="rounded-md border border-stone-200 p-4 dark:border-white/10" key={item}>
              <h2 className="font-semibold">{item}</h2>
              <p className="mt-2 text-sm leading-6 text-stone-600 dark:text-stone-300">Module đã có vị trí trong kiến trúc, route frontend và API nền để mở rộng thành tính năng đầy đủ.</p>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
