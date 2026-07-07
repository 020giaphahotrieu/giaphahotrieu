import ReactFlow, { Background, Controls, MiniMap, type Edge, type Node } from "react-flow-renderer";
import { PageHeader } from "../components/ui/PageHeader";

const nodes: Node[] = [
  { id: "1", position: { x: 260, y: 0 }, data: { label: "Triệu Văn Khởi" } },
  { id: "2", position: { x: 80, y: 120 }, data: { label: "Triệu Minh Đức" } },
  { id: "3", position: { x: 440, y: 120 }, data: { label: "Triệu Minh Tâm" } },
  { id: "4", position: { x: 20, y: 260 }, data: { label: "Triệu Quang Huy" } },
  { id: "5", position: { x: 220, y: 260 }, data: { label: "Triệu Ngọc Linh" } },
  { id: "6", position: { x: 440, y: 260 }, data: { label: "Triệu Anh Tuấn" } },
  { id: "7", position: { x: 20, y: 400 }, data: { label: "Triệu An Nhiên" } },
  { id: "8", position: { x: 220, y: 400 }, data: { label: "Triệu Gia Bảo" } }
];

const edges: Edge[] = [
  { id: "e1-2", source: "1", target: "2" },
  { id: "e1-3", source: "1", target: "3" },
  { id: "e2-4", source: "2", target: "4" },
  { id: "e2-5", source: "2", target: "5" },
  { id: "e3-6", source: "3", target: "6" },
  { id: "e4-7", source: "4", target: "7" },
  { id: "e4-8", source: "4", target: "8" }
];

export function FamilyTreePage() {
  return (
    <div>
      <PageHeader title="Cây gia phả" description="Hiển thị cây huyết thống bằng React Flow; backend đã có quan hệ parent/spouse/child để thay thế dữ liệu tĩnh." />
      <div className="surface h-[650px] overflow-hidden">
        <ReactFlow nodes={nodes} edges={edges} fitView>
          <MiniMap />
          <Controls />
          <Background />
        </ReactFlow>
      </div>
    </div>
  );
}
