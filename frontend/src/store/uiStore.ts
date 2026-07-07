import { create } from "zustand";

type UiState = {
  darkMode: boolean;
  toggleDarkMode: () => void;
};

const initialDarkMode = localStorage.getItem("dfhp_theme") === "dark";

export const useUiStore = create<UiState>((set, get) => ({
  darkMode: initialDarkMode,
  toggleDarkMode: () => {
    const next = !get().darkMode;
    localStorage.setItem("dfhp_theme", next ? "dark" : "light");
    document.documentElement.classList.toggle("dark", next);
    set({ darkMode: next });
  }
}));

document.documentElement.classList.toggle("dark", initialDarkMode);
