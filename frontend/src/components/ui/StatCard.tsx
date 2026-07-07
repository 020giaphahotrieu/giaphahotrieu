type StatCardProps = {
  label: string;
  value: number | string;
  helper?: string;
};

export function StatCard({ label, value, helper }: StatCardProps) {
  return (
    <div className="surface p-5">
      <p className="text-sm font-medium text-stone-500 dark:text-stone-400">{label}</p>
      <p className="mt-2 text-3xl font-bold text-stone-950 dark:text-stone-50">{value}</p>
      {helper ? <p className="mt-1 text-xs text-stone-500 dark:text-stone-400">{helper}</p> : null}
    </div>
  );
}
