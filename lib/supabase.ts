import { createClient, SupabaseClient } from "@supabase/supabase-js";

/* ---------- Типи платформи ---------- */

// Опис одного поля картки (з конфіга сайту)
export type FieldDef = {
  key: string;
  name: string;
  type: "text" | "textarea" | "checkbox" | "image" | "select" | "select-collection";
  extra?: boolean; // true — поле зберігається в items.extra, а не в окремій колонці
  from?: string; // для select-collection: з якої колекції брати варіанти
  options?: { value: string; label: string }[]; // для select: готові варіанти
};

export type CollectionDef = { key: string; name: string; fields: FieldDef[] };
export type TextDef = { key: string; name: string };
export type SiteConfig = { collections: CollectionDef[]; texts: TextDef[] };

export type Site = {
  id: number;
  slug: string;
  name: string;
  paid_until: string; // дата, до якої активна підписка
  config: SiteConfig;
};

export type Item = {
  id?: number;
  site_id: number;
  collection: string;
  title: string;
  text: string;
  price: string;
  image_url: string;
  extra: Record<string, unknown>;
  sort_order: number;
};

export type Profile = {
  user_id: string;
  site_id: number | null;
  role: "owner" | "admin";
};

/* ---------- Клієнт Supabase ---------- */

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

export const isSupabaseConfigured = Boolean(url && key);

let client: SupabaseClient | null = null;

export function getSupabase(): SupabaseClient | null {
  if (!url || !key) return null;
  if (!client) client = createClient(url, key);
  return client;
}

/* ---------- Дрібні помічники дат (підписки) ---------- */

// Сьогодні у форматі YYYY-MM-DD (локальний час)
export const todayISO = () => {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
};

// 2026-07-19 -> 19.07.2026
export const fmtDate = (iso: string) => {
  const [y, m, d] = iso.split("-");
  return `${d}.${m}.${y}`;
};

// Продовжити підписку: від сьогодні або від дати закінчення (що пізніше) + N днів
export const addDaysISO = (from: string, days: number) => {
  const base = new Date(Math.max(new Date(from + "T12:00:00").getTime(), Date.now()));
  base.setDate(base.getDate() + days);
  return `${base.getFullYear()}-${String(base.getMonth() + 1).padStart(2, "0")}-${String(base.getDate()).padStart(2, "0")}`;
};
