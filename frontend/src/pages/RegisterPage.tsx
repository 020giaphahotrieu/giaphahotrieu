import { FormEvent, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { register } from "../services/api";
import { useAuthStore } from "../store/authStore";

export function RegisterPage() {
  const navigate = useNavigate();
  const setSession = useAuthStore((state) => state.setSession);
  const [form, setForm] = useState({ email: "", password: "", displayName: "", familyName: "" });
  const [error, setError] = useState("");

  async function onSubmit(event: FormEvent) {
    event.preventDefault();
    try {
      const result = await register(form);
      setSession(result.token, result.user);
      navigate("/");
    } catch {
      setError("Không tạo được tài khoản. Email có thể đã tồn tại hoặc backend chưa chạy.");
    }
  }

  return (
    <form onSubmit={onSubmit} className="surface w-full max-w-md p-8">
      <h1 className="text-3xl font-bold text-stone-950 dark:text-white">Đăng ký</h1>
      <p className="mt-2 text-sm text-stone-600 dark:text-stone-300">Tài khoản mới mặc định có quyền Viewer.</p>
      {error ? <div className="mt-4 rounded-md bg-red-50 px-3 py-2 text-sm text-red-700">{error}</div> : null}
      {[
        ["displayName", "Họ tên"],
        ["familyName", "Tên dòng họ"],
        ["email", "Email"],
        ["password", "Mật khẩu"]
      ].map(([key, label]) => (
        <label key={key} className="mt-4 block text-sm font-medium">
          {label}
          <input
            className="input mt-1"
            type={key === "password" ? "password" : key === "email" ? "email" : "text"}
            value={form[key as keyof typeof form]}
            onChange={(event) => setForm((prev) => ({ ...prev, [key]: event.target.value }))}
            required={key !== "familyName"}
          />
        </label>
      ))}
      <button className="btn-primary mt-6 w-full" type="submit">Tạo tài khoản</button>
      <p className="mt-4 text-center text-sm text-stone-600 dark:text-stone-300">
        Đã có tài khoản? <Link className="font-semibold text-jade-700" to="/login">Đăng nhập</Link>
      </p>
    </form>
  );
}
