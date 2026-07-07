export type ApiResponse<T> = {
  success: boolean;
  message: string;
  data: T;
  errors?: unknown[];
};

export type User = {
  id: string;
  email: string;
  displayName: string;
  familyId: string | null;
  familyName?: string;
  roles: string[];
};

export type Member = {
  id: string;
  code?: string;
  fullName: string;
  givenName?: string;
  generation: number;
  gender: "MALE" | "FEMALE" | "OTHER" | "UNKNOWN";
  lifeStatus: "LIVING" | "DECEASED" | "UNKNOWN";
  birthDate?: string;
  deathDate?: string;
  birthPlace?: string;
  avatarUrl?: string;
  biography?: string;
  branch?: { id: string; name: string };
  translations?: Array<{ locale: string; fullName: string; ipa?: string; pinyin?: string }>;
};

export type DashboardData = {
  stats: Record<string, number>;
  upcomingEvents: Array<{ id: string; title: string; type: string; startsAt: string; location?: string }>;
  recentMembers: Member[];
  charts: {
    generations: Array<{ name: string; value: number }>;
    genders: Array<{ name: string; value: number }>;
    lifeStatus: Array<{ name: string; value: number }>;
    branches: Array<{ name: string; value: number }>;
  };
};
