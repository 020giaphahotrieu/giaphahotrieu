import i18n from "i18next";
import { initReactI18next } from "react-i18next";

i18n.use(initReactI18next).init({
  resources: {
    vi: {
      translation: {
        appName: "Gia phả số",
        dashboard: "Tổng quan",
        members: "Thành viên",
        tree: "Cây gia phả",
        events: "Sự kiện",
        settings: "Cài đặt"
      }
    },
    en: {
      translation: {
        appName: "Family Heritage",
        dashboard: "Dashboard",
        members: "Members",
        tree: "Family Tree",
        events: "Events",
        settings: "Settings"
      }
    }
  },
  lng: "vi",
  fallbackLng: "vi",
  interpolation: { escapeValue: false }
});

export default i18n;
