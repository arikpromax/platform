-- Telegram-бот замовлень: хто отримує, запрошення, і хто штовхає бота.
--
-- Нове замовлення → тригер одразу кличе функцію tg-bot → вона шле текст
-- у всі чати, під'єднані до цього сайту. Якщо в ту мить щось не вийшло
-- (Telegram ліг, токен ще не вписаний), раз на дві хвилини підстраховка
-- пробує ще раз — протягом доби. Двічі одне замовлення не прийде: функція
-- позначає надіслане в orders.tg_sent_at.
--
-- Виконати один раз у Supabase → SQL Editor. Повторний запуск безпечний.
-- Наприкінці SQL покаже код запрошення для Just shop.

-- ---------- 1) Хто отримує замовлення ----------
create table if not exists public.tg_chats (
  chat_id  bigint not null,
  site_id  bigint not null references public.sites (id) on delete cascade,
  who      text   not null default '',        -- «Ім'я @нік» або «група …» — щоб бачити, кому йде
  added_at timestamptz not null default now(),
  primary key (chat_id, site_id)
);

-- Запрошення: посилання t.me/<бот>?start=<код>. Діє тиждень, можна кільком людям.
create table if not exists public.tg_invites (
  code    text primary key,
  site_id bigint not null references public.sites (id) on delete cascade,
  until   timestamptz not null default now() + interval '7 days'
);

-- Обидві таблиці читає лише функція службовим ключем. Політик немає навмисно:
-- ні сайт, ні адмінка не бачать, у які чати йдуть замовлення.
alter table public.tg_chats   enable row level security;
alter table public.tg_invites enable row level security;

alter table public.orders add column if not exists tg_sent_at timestamptz;
-- Старі замовлення вважаємо надісланими, щоб підстраховка не розсилала архів.
update public.orders set tg_sent_at = created_at where tg_sent_at is null and created_at < now() - interval '1 day';

-- ---------- 2) Нове замовлення → бот ----------
create extension if not exists pg_net;
create extension if not exists pg_cron with schema pg_catalog;

create or replace function public.tg_ping(p_order bigint) returns void
language plpgsql security definer set search_path = public as
$fn$
begin
  -- Запит піде лише після того, як замовлення збережеться остаточно.
  perform net.http_post(
    url     := 'https://ortiatyxntdikaldepbp.supabase.co/functions/v1/tg-bot',
    body    := jsonb_build_object('order', p_order),
    headers := '{"Content-Type": "application/json"}'::jsonb
  );
end
$fn$;
revoke all on function public.tg_ping(bigint) from public, anon, authenticated;

create or replace function public.orders_tg_new() returns trigger
language plpgsql security definer set search_path = public as
$fn$
begin
  if exists (select 1 from tg_chats where site_id = new.site_id) then
    perform public.tg_ping(new.id);
  end if;
  return new;
end
$fn$;

drop trigger if exists orders_tg_new on public.orders;
create trigger orders_tg_new after insert on public.orders
  for each row execute function public.orders_tg_new();

-- Підстраховка: усе ненадіслане за останню добу, старше хвилини
create or replace function public.tg_sweep() returns void
language plpgsql security definer set search_path = public as
$fn$
declare o record;
begin
  for o in
    select id from orders
     where tg_sent_at is null
       and created_at between now() - interval '1 day' and now() - interval '1 minute'
       and exists (select 1 from tg_chats c where c.site_id = orders.site_id)
     order by id limit 20
  loop
    perform public.tg_ping(o.id);
  end loop;
end
$fn$;
revoke all on function public.tg_sweep() from public, anon, authenticated;

select cron.schedule('tg-sweep', '*/2 * * * *', $$select public.tg_sweep()$$);

-- ---------- 3) Запрошення для Just shop ----------
insert into public.tg_invites (code, site_id)
values (replace(gen_random_uuid()::text, '-', ''), 106)
returning code as "код запрошення — надішліть його Claude";
