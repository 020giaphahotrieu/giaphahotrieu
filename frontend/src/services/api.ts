import axios from "axios";
import type { ApiResponse, DashboardData, Member, User } from "../types";
import { useAuthStore } from "../store/authStore";

export const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL ?? "http://localhost:4000/api"
});

api.interceptors.request.use((config) => {
  const token = useAuthStore.getState().token;
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

export async function login(email: string, password: string) {
  const response = await api.post<ApiResponse<{ token: string; user: User }>>("/auth/login", { email, password });
  return response.data.data;
}

export async function register(input: { email: string; password: string; displayName: string; familyName?: string }) {
  const response = await api.post<ApiResponse<{ token: string; user: User }>>("/auth/register", input);
  return response.data.data;
}

export async function getDashboard() {
  const response = await api.get<ApiResponse<DashboardData>>("/dashboard");
  return response.data.data;
}

export async function getMembers() {
  const response = await api.get<ApiResponse<Member[]>>("/members");
  return response.data.data;
}

export async function createMember(member: Partial<Member>) {
  const response = await api.post<ApiResponse<Member>>("/members", member);
  return response.data.data;
}
