import type { ReactNode } from "react";

type PageHeaderProps = {
  title: string;
  description?: string;
  action?: ReactNode;
};

export function PageHeader({ title, description, action }: PageHeaderProps) {
  return (
    <div className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
      <div>
        <h1 className="text-2xl font-bold tracking-tight text-stone-950 dark:text-stone-50">{title}</h1>
        {description ? <p className="mt-1 max-w-3xl text-sm leading-6 text-stone-600 dark:text-stone-300">{description}</p> : null}
      </div>
      {action}
    </div>
  );
}
