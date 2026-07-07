import { create } from "zustand";
import type { User } from "../types";

type AuthState = {
  token: string | null;
  user: User | null;
  setSession: (token: string, user: User) => void;
  clearSession: () => void;
};

const storedToken = localStorage.getItem("dfhp_token");
const storedUser = localStorage.getItem("dfhp_user");

export const useAuthStore = create<AuthState>((set) => ({
  token: storedToken,
  user: storedUser ? (JSON.parse(storedUser) as User) : null,
  setSession: (token, user) => {
    localStorage.setItem("dfhp_token", token);
    localStorage.setItem("dfhp_user", JSON.stringify(user));
    set({ token, user });
  },
  clearSession: () => {
    localStorage.removeItem("dfhp_token");
    localStorage.removeItem("dfhp_user");
    set({ token: null, user: null });
  }
}));
