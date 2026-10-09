import { createClient, SupabaseClient } from "@supabase/supabase-js";

/* ---------- Типи платформи ---------- */

// Опис одного поля картки (з конфіга сайту)
export type FieldDef = {
  key: string;
  name: string;
  // images — кілька фото в одному полі: кнопка «Додати фото», масив у extra
  // multi-collection — список галочок із іншої колекції (напр. «які напої пропонувати»);
  // вибране зберігається як назви, кожна з нового рядка
  // heading — не поле, а заголовок блоку у формі (name — текст заголовка, hint — підрядок)
  type:
    | "text"
    | "textarea"
    | "checkbox"
    | "image"
    | "images"
    | "select"
    | "select-collection"
    | "multi-collection"
    | "heading";
  // true — поле бачить лише власник платформи; клієнт його не бачить і не може зіпсувати.
  // Значення при цьому не стирається: форма зберігає картку цілком.
  adminOnly?: boolean;
  extra?: boolean; // true — поле зберігається в items.extra, а не в окремій колонці
  from?: string; // для select-collection і multi-collection: з якої колекції брати варіанти
  // для multi-collection: показати лише картки, у яких extra[key] === value
  whereExtra?: { key: string; value: string };
  options?: { value: string; label: string }[]; // для select: готові варіанти
  hint?: string; // сірий рядок під полем: приклад або пояснення для власника
  // "code" — поруч із полем зʼявляється кнопка «Згенерувати»,
  // яка вписує випадковий код (для промокодів)
  gen?: "code";
};

// Кнопка-перемикач просто в рядку списку: вмикає прапорець в extra
// без відкривання картки. Для «винести на головну», «в банер» тощо.
export type RowToggleDef = { flag: string; label: string; title?: string };

export type CollectionDef = {
  key: string;
  name: string;
  fields: FieldDef[];
  rowToggle?: RowToggleDef;
  // ключ поля-списку (type: select), за яким ділити картки на розділи.
  // Над списком зʼявляться кнопки розділів: власник обирає розділ,
  // бачить лише його картки й додає нову одразу туди.
  groupBy?: string;
  // ключ поля в extra, яке заповнюється саме при створенні картки.
  // Потрібне для розділів меню: сайт звʼязується з ними технічним
  // кодом, а власник має додавати розділ, не знаючи про його існування.
  autoKey?: string;
  // коди, які не показуємо серед кнопок розділів: службові рядки
  // на кшталт «Усі» та розділи, що живуть окремою колекцією
  groupSkip?: string[];
  adminOnly?: boolean; // вкладку бачить лише власник платформи (роль admin)
  noAdd?: boolean; // приховати кнопку «+ Додати»
  noDelete?: boolean; // приховати кнопку «Видалити»
};
export type TextDef = { key: string; name: string; multiline?: boolean };
// Розділ адмінки «як на сайті»: групує тексти, колекції та фото одного блока сайту.
// Якщо в конфігу є sections — вкладки адмінки будуються за ними (по порядку сайту);
// якщо нема — стара поведінка (вкладка на кожну колекцію + «Тексти»).
export type SectionDef = {
  name: string;
  note?: string; // пояснення вгорі вкладки: що це за блок і де він на сайті
  texts?: string[]; // ключі текстів цього блока
  collections?: string[]; // ключі колекцій цього блока
  photos?: string[]; // слоти фото сайту (extra.slot) цього блока
  // true — вкладка стоїть ліворуч, поруч із бронюванням чи складом, без номера:
  // для того, що власник міняє щодня (ціни номерів, меню)
  pin?: boolean;
};
export type SiteConfig = {
  collections: CollectionDef[];
  texts: TextDef[];
  sections?: SectionDef[];
  // true — у адмінці зʼявляються вкладки «Склад» і «Замовлення».
  // Решта полів кажуть, де саме лежать товари й розміри цього сайту.
  stock?: boolean;
  stockCollection?: string; // колекція товарів, типово products
  stockSizes?: string; // поле в extra зі списком розмірів, типово sizes
  // назва програми обліку, з якої приходять кількість, ціни, акції й розміри
  // (напр. «УкрСклад»). Тоді в адмінці їх видно, але не міняють — обмін
  // однаково перезаписав би; товари теж заводять і прибирають там.
  stockSync?: string;
  // з якої дати замовлення йдуть у програму обліку (раніші там розібрали вручну)
  stockSyncSince?: string;
  // true — у адмінці зʼявляється вкладка «Бронювання» (готелі, номери)
  booking?: boolean;
  // true — вкладка «Підключення»: ключі Нової Пошти, оплати й обміну зі складом
  connect?: boolean;
};

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

/* ---------- Склад ---------- */

// Залишок однієї позиції: товар у конкретному розмірі (і кольорі).
// qty — скільки лежить фізично, reserved — скільки відкладено під кошики,
// тож вільно до продажу завжди qty − reserved.
export type StockRow = {
  id: number;
  site_id: number;
  item_id: number;
  size: string;
  color: string;
  qty: number;
  reserved: number;
  low_at: number; // від скількох показувати «закінчується»
  updated_at: string;
  // з обміну з програмою обліку (УкрСклад): ID розміру там і його власна ціна
  ext_id?: string | null;
  price?: number | null;
  old_price?: number | null;
};

export type MoveKind = 'in' | 'sale' | 'return' | 'writeoff' | 'fix';

// Рядок історії: що саме сталося із залишком і після чого
export type StockMove = {
  id: number;
  item_id: number;
  size: string;
  color: string;
  kind: MoveKind;
  delta: number;
  qty_after: number;
  note: string;
  order_ref: string;
  who: string;
  at: string;
};

export type OrderLine = {
  item_id: number;
  size?: string;
  color?: string;
  qty: number;
  title?: string;
  price?: number;
};

export type OrderStatus = 'new' | 'shipped' | 'done' | 'cancelled' | 'returned';

export type Order = {
  id: number;
  site_id: number;
  ref: string;
  status: OrderStatus;
  customer: Record<string, unknown>;
  lines: OrderLine[];
  total: number;
  note: string;
  created_at: string;
  updated_at: string;
  // Накладна й оплата — заповнюють бот і LiqPay (див. supabase/functions/tg-bot)
  ttn?: string;
  ttn_cost?: number | null;
  ttn_error?: string;
  np_status?: string;
  np_return_ttn?: string;
  pay_state?: string;
  pay_info?: { amount?: number; test?: boolean; card?: string };
  // обмін із програмою обліку (db/sync-shop.sql): коли й з яким статусом забрала,
  // і коли зʼясувалось, що ту саму річ уже продали в магазині
  synced_at?: string | null;
  sync_status?: string;
  oversold_at?: string | null;
};

/* ---------- Бронювання номерів ---------- */

// Заявка з сайту або бронь, записана власником телефоном.
// Дата в календарі на сайті стає зайнятою, коли розібрали всі
// номери цього типу (їхня кількість — у items.extra.units).
export type Booking = {
  id: number;
  site_id: number;
  ref: string;                 // номер для гостя: F-0110-234
  room_key: string;            // технічний код номера
  room_name: string;           // як номер звався на момент броні
  rooms_count: number;
  date_in: string;             // 2026-10-04
  date_out: string;
  adults: number;
  children: number;
  guest: { name?: string; phone?: string; via?: string; note?: string };
  extras: { sauna?: { day?: string; time?: string; hours?: number } };
  total: number;
  status: string;              // new | confirmed | cancelled
  note: string;
  source: string;              // site | phone | other
  created_at: string;
  updated_at: string;
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
