import type { DashboardData, Member } from "../types";

export const fallbackMembers: Member[] = [
  { id: "1", fullName: "Triệu Văn Khởi", generation: 1, gender: "MALE", lifeStatus: "DECEASED", birthPlace: "Bắc Ninh", avatarUrl: "https://placehold.co/240x240?text=Khoi" },
  { id: "2", fullName: "Nguyễn Thị An", generation: 1, gender: "FEMALE", lifeStatus: "DECEASED", birthPlace: "Hà Nội", avatarUrl: "https://placehold.co/240x240?text=An" },
  { id: "3", fullName: "Triệu Minh Đức", generation: 2, gender: "MALE", lifeStatus: "LIVING", birthPlace: "Hà Nội", avatarUrl: "https://placehold.co/240x240?text=Duc" },
  { id: "4", fullName: "Triệu Quang Huy", generation: 3, gender: "MALE", lifeStatus: "LIVING", birthPlace: "Hà Nội", avatarUrl: "https://placehold.co/240x240?text=Huy" },
  { id: "5", fullName: "Triệu An Nhiên", generation: 4, gender: "FEMALE", lifeStatus: "LIVING", birthPlace: "Hà Nội", avatarUrl: "https://placehold.co/240x240?text=Nhien" }
];

export const fallbackDashboard: DashboardData = {
  stats: {
    totalMembers: 22,
    totalGenerations: 4,
    totalBranches: 3,
    maleMembers: 12,
    femaleMembers: 10,
    livingMembers: 19,
    deceasedMembers: 3
  },
  upcomingEvents: [
    { id: "e1", title: "Họp mặt gia đình mùa thu", type: "REUNION", startsAt: new Date().toISOString(), location: "Nhà thờ họ" },
    { id: "e2", title: "Ngày giỗ Triệu Thanh Bình", type: "DEATH_ANNIVERSARY", startsAt: "2026-11-02T08:00:00.000Z", location: "Hà Nội" }
  ],
  recentMembers: fallbackMembers,
  charts: {
    generations: [
      { name: "Đời 1", value: 2 },
      { name: "Đời 2", value: 5 },
      { name: "Đời 3", value: 7 },
      { name: "Đời 4", value: 8 }
    ],
    genders: [
      { name: "Nam", value: 12 },
      { name: "Nữ", value: 10 }
    ],
    lifeStatus: [
      { name: "Còn sống", value: 19 },
      { name: "Đã mất", value: 3 }
    ],
    branches: [
      { name: "Chi trưởng", value: 13 },
      { name: "Chi thứ hai", value: 6 },
      { name: "Nhánh phương Nam", value: 3 }
    ]
  }
};
