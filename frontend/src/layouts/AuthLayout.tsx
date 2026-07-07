import { Outlet } from "react-router-dom";

export function AuthLayout() {
  return (
    <main className="min-h-screen bg-heritage-50 dark:bg-stone-950">
      <div className="grid min-h-screen lg:grid-cols-[1.1fr_0.9fr]">
        <section className="hidden bg-[url('https://images.unsplash.com/photo-1511895426328-dc8714191300?auto=format&fit=crop&w=1400&q=80')] bg-cover bg-center lg:block">
          <div className="flex h-full items-end bg-gradient-to-t from-stone-950/80 to-stone-950/10 p-12 text-white">
            <div>
              <p className="text-sm uppercase tracking-[0.2em]">Digital Family Heritage</p>
              <h1 className="mt-3 max-w-xl text-4xl font-bold leading-tight">Lưu giữ ký ức gia đình bằng một nền tảng gia phả hiện đại.</h1>
            </div>
          </div>
        </section>
        <section className="flex items-center justify-center p-6">
          <Outlet />
        </section>
      </div>
    </main>
  );
}
