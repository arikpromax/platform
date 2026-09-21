-- Накладні Нової Пошти з Telegram-бота.
--
-- Бот створює ТТН сам, щойно приходить замовлення з доставкою у відділення
-- чи поштомат, і пише її номер у тому ж повідомленні. Поки в Secrets немає
-- ключа NP_KEY_<сайт>, він лише повідомляє, що Нова Пошта не підключена, а
-- під замовленням лишає кнопку «Створити ТТН» — вона спрацює, щойно ключ з'явиться.
--
-- Виконати один раз у Supabase → SQL Editor. Повторний запуск безпечний.

-- ---------- 1) Накладна в самому замовленні ----------
alter table public.orders
  add column if not exists ttn       text not null default '',   -- номер: 20451234567890
  add column if not exists ttn_ref   text not null default '',   -- внутрішній код НП, щоб скасувати й друкувати
  add column if not exists ttn_cost  numeric,                     -- вартість доставки за НП
  add column if not exists ttn_date  text not null default '',   -- коли прибуде, як каже НП
  add column if not exists ttn_error text not null default '',   -- чому не вийшло — видно в боті
  add column if not exists ttn_lock  timestamptz;                -- від подвійного натискання

-- ---------- 2) Налаштування відправлення для кожного сайту ----------
create table if not exists public.np_settings (
  site_id            bigint primary key references public.sites (id) on delete cascade,
  auto               boolean not null default true,     -- створювати ТТН одразу, без кнопки
  sender_city        text not null default '',          -- звідки відправляємо: «Київ»
  sender_branch      text not null default '',          -- номер відділення: «12»
  cod_mode           text not null default 'transfer'   -- наложений платіж:
                     check (cod_mode in ('transfer', 'control')),
                                                         --   transfer — грошовий переказ (без договору)
                                                         --   control  — «контроль оплати» (за договором з НП)
  description        text not null default 'Одяг та взуття',
  -- далі заповнює сам бот за ключем НП; стерти — і він знайде заново
  sender_city_ref    text not null default '',
  sender_wh_ref      text not null default '',
  sender_ref         text not null default '',
  sender_contact_ref text not null default '',
  sender_phone       text not null default ''
);
-- Читає лише функція службовим ключем. Ні сайт, ні адмінка сюди не дивляться.
alter table public.np_settings enable row level security;

insert into public.np_settings (site_id) values (106) on conflict (site_id) do nothing;

-- ---------- 3) Коли знатимете, звідки відправляти ----------
-- Впишіть місто й номер відділення і виконайте цей рядок окремо:
--
--   update public.np_settings
--      set sender_city = 'Київ', sender_branch = '12',
--          sender_city_ref = '', sender_wh_ref = ''
--    where site_id = 106;
--
-- Якщо уклали з НП договір на «контроль оплати»:
--
--   update public.np_settings set cod_mode = 'control' where site_id = 106;
