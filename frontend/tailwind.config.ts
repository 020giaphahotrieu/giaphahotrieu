import type { Config } from "tailwindcss";

export default {
  darkMode: "class",
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        heritage: {
          50: "#f8f5ef",
          100: "#efe6d6",
          500: "#9b6a3e",
          700: "#5c3a20",
          900: "#2a1b12"
        },
        jade: {
          500: "#1c7c6b",
          700: "#11584d"
        }
      },
      boxShadow: {
        soft: "0 14px 40px rgba(36, 26, 15, 0.08)"
      }
    }
  },
  plugins: []
} satisfies Config;
