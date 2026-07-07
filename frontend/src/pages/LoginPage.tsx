import { FormEvent, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { login } from "../services/api";
import { useAuthStore } from "../store/authStore";

export function LoginPage() {
  const navigate = useNavigate();
  const setSession = useAuthStore((state) => state.setSession);
  const [email, setEmail] = useState("admin@example.com");
  const [password, setPassword] = useState("Admin@123456");
  const [error, setError] = useState("");

  async function onSubmit(event: FormEvent) {
    event.preventDefault();
    setError("");
    try {
      const result = await login(email, password);
      setSession(result.token, result.user);
      navigate("/");
    } catch {
      setError("Không đăng nhập được. Hãy kiểm tra backend, database seed hoặc thông tin tài khoản.");
    }
  }

  return (
    <form onSubmit={onSubmit} className="surface w-full max-w-md p-8">
      <p className="text-sm font-semibold uppercase tracking-[0.18em] text-jade-700">Gia phả số</p>
      <h1 className="mt-2 text-3xl font-bold text-stone-950 dark:text-white">Đăng nhập</h1>
      <p className="mt-2 text-sm text-stone-600 dark:text-stone-300">Tài khoản mẫu: admin@example.com / Admin@123456</p>
      {error ? <div className="mt-4 rounded-md bg-red-50 px-3 py-2 text-sm text-red-700">{error}</div> : null}
      <label className="mt-6 block text-sm font-medium">Email</label>
      <input className="input mt-1" value={email} onChange={(event) => setEmail(event.target.value)} type="email" required />
      <label className="mt-4 block text-sm font-medium">Mật khẩu</label>
      <input className="input mt-1" value={password} onChange={(event) => setPassword(event.target.value)} type="password" required />
      <button className="btn-primary mt-6 w-full" type="submit">Đăng nhập</button>
      <p className="mt-4 text-center text-sm text-stone-600 dark:text-stone-300">
        Chưa có tài khoản? <Link className="font-semibold text-jade-700" to="/register">Đăng ký</Link>
      </p>
    </form>
  );
}
