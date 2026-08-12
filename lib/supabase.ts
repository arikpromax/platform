import { createClient, SupabaseClient } from "@supabase/supabase-js";

/* ---------- Типи платформи ---------- */

// Опис одного поля картки (з конфіга сайту)
export type FieldDef = {
  key: string;
  name: string;
  // images — кілька фото в одному полі: кнопка «Додати фото», масив у extra
  type: "text" | "textarea" | "checkbox" | "image" | "images" | "select" | "select-collection";
  extra?: boolean; // true — поле зберігається в items.extra, а не в окремій колонці
  from?: string; // для select-collection: з якої колекції брати варіанти
  options?: { value: string; label: string }[]; // для select: готові варіанти
  hint?: string; // сірий рядок під полем: приклад або пояснення для власника
};

export type CollectionDef = {
  key: string;
  name: string;
  fields: FieldDef[];
  adminOnly?: boolean; // вкладку бачить лише власник платформи (роль admin)
  noAdd?: boolean; // приховати кнопку «+ Додати»
  noDelete?: boolean; // приховати кнопку «Видалити»
};
export type TextDef = { key: string; name: string; multiline?: boolean };
// Розділ адмінки «як на сайті»: групує тексти, колекції та фото одного блока сайту.
// Якщо в конфігу є sections — вкладки адмінки будуються за ними (по порядку сайту);
// якщо нема — стара поведінка (вкладка на кожну колекцію + «Тексти»).
// Вкладка-«вибиралка»: показує картки з інших колекцій одним списком,
// щоб позначити галочкою, які з них потрапляють у якийсь блок сайту.
// Нічого не створює і не видаляє — лише перемикає прапорець в extra.
export type PickerDef = {
  from: string[]; // з яких колекцій брати картки
  flag: string; // ключ у extra, який вмикається галочкою
  label: string; // підпис галочки
  textKey?: string; // необовʼязкове поле поруч (напр. підпис на банері)
  textLabel?: string;
  empty?: string; // що написати, коли нічого не позначено
};

export type SectionDef = {
  name: string;
  note?: string; // пояснення вгорі вкладки: що це за блок і де він на сайті
  picker?: PickerDef;
  texts?: string[]; // ключі текстів цього блока
  collections?: string[]; // ключі колекцій цього блока
  photos?: string[]; // слоти фото сайту (extra.slot) цього блока
};
export type SiteConfig = { collections: CollectionDef[]; texts: TextDef[]; sections?: SectionDef[] };

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
