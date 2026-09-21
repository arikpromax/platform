-- Стеження за посилками Нової Пошти.
--
-- Раз на 30 хвилин бот питає Нову Пошту про всі свої ТТН (до 100 за запит)
-- і сам веде замовлення далі:
--   здали на пошту            → статус «Відправлено», повідомлення в Telegram
--   прибула у відділення      → повідомлення; лежить 3 дні — ще одне
--   покупець забрав           → статус «Виконане»
--   відмова / строк вийшов    → повідомлення, стежимо за зворотною ТТН
--   посилка повернулась       → статус «Повернення», товар сам на склад
--   адресу змінили            → стежимо за новою ТТН
--   ТТН видалили в кабінеті   → повідомлення, замовлення без ТТН
-- Без ключа NP_KEY_<сайт> нічого не робить — запрацює саме, щойно ключ з'явиться.
--
-- Виконати один раз у Supabase → SQL Editor, ПІСЛЯ np-ttn.sql і liqpay.sql.
-- Повторний запуск безпечний.

-- ---------- 1) Що бот знає про посилку ----------
alter table public.orders
  add column if not exists np_track           text not null default '',  -- за яким номером стежимо (після переадресації — новий)
  add column if not exists np_code            int,                        -- останній код статусу НП
  add column if not exists np_status          text not null default '',  -- його текст, як пише НП
  add column if not exists np_checked_at      timestamptz,                -- коли питали востаннє
  add column if not exists np_arrived_at      timestamptz,                -- коли прибула у відділення
  add column if not exists np_stay_note_at    timestamptz,                -- коли написали «лежить 3 дні»
  add column if not exists np_refused_at      timestamptz,                -- коли побачили відмову
  add column if not exists np_return_ttn      text not null default '',  -- ТТН, якою посилка їде назад
  add column if not exists np_back_arrived_at timestamptz,                -- повернення чекає у відділенні
  add column if not exists np_final           boolean not null default false;  -- далі стежити не треба

create index if not exists orders_np_watch on public.orders (np_final, np_checked_at) where ttn <> '';

-- ---------- 2) Новий статус «Відправлено» ----------
alter table public.orders drop constraint if exists orders_status_check;
alter table public.orders add constraint orders_status_check
  check (status in ('new', 'shipped', 'done', 'cancelled', 'returned'));

-- Ядро зміни статусу: склад і журнал. Прав не перевіряє, тому викликати
-- його можуть лише set_order_status (власник з адмінки) і бот (службовий ключ).
create or replace function public.order_status_apply(
  p_order bigint, p_status text, p_who text, p_note text default ''
) returns jsonb
language plpgsql security definer set search_path = public as
$fn$
declare o record; l jsonb; need int; v_after int; back boolean; take boolean;
begin
  if p_status not in ('new', 'shipped', 'done', 'cancelled', 'returned') then
    return jsonb_build_object('ok', false, 'error', 'status');
  end if;
  select * into o from orders where id = p_order for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'order'); end if;
  if o.status = p_status then return jsonb_build_object('ok', true); end if;

  -- товар лічиться відданим, поки замовлення нове, відправлене або виконане
  back := o.status in ('new', 'shipped', 'done') and p_status in ('cancelled', 'returned');
  take := o.status in ('cancelled', 'returned') and p_status in ('new', 'shipped', 'done');

  if back or take then
    for l in select value from jsonb_array_elements(o.lines) loop
      need := least(greatest(coalesce((l->>'qty')::int, 1), 1), 20);
      update stock set qty = case when back then qty + need else greatest(0, qty - need) end,
                       updated_at = now()
       where site_id = o.site_id and item_id = (l->>'item_id')::bigint
         and size = coalesce(l->>'size', '') and color = coalesce(l->>'color', '')
      returning qty into v_after;
      if found then
        insert into stock_moves (site_id, item_id, size, color, kind, delta, qty_after, note, order_ref, who)
        values (o.site_id, (l->>'item_id')::bigint, coalesce(l->>'size', ''), coalesce(l->>'color', ''),
                case when back then 'return' else 'sale' end,
                case when back then need else -need end, v_after,
                case when coalesce(p_note, '') <> '' then p_note
                     when p_status = 'cancelled' then 'скасування замовлення'
                     when p_status = 'returned'  then 'повернення від покупця'
                     else 'замовлення поновлено' end,
                o.ref, coalesce(nullif(p_who, ''), 'сайт'));
      end if;
    end loop;
  end if;

  update orders set status = p_status, updated_at = now() where id = p_order;
  return jsonb_build_object('ok', true);
end
$fn$;
revoke all on function public.order_status_apply(bigint, text, text, text) from public, anon, authenticated;
grant execute on function public.order_status_apply(bigint, text, text, text) to service_role;

-- Власник з адмінки: та сама дія, але з перевіркою прав
create or replace function public.set_order_status(p_order bigint, p_status text)
returns jsonb language plpgsql security definer set search_path = public as
$fn$
declare s bigint;
begin
  if p_status not in ('new', 'shipped', 'done', 'cancelled', 'returned') then
    return jsonb_build_object('ok', false, 'error', 'status');
  end if;
  select site_id into s from orders where id = p_order;
  if not found then return jsonb_build_object('ok', false, 'error', 'order'); end if;
  if not public.stock_can_edit(s) then
    return jsonb_build_object('ok', false, 'error', 'access');
  end if;
  return public.order_status_apply(p_order, p_status, public.stock_who(), '');
end
$fn$;

-- ---------- 3) Раз на 30 хвилин — перевірка посилок ----------
create or replace function public.np_track_ping() returns void
language plpgsql security definer set search_path = public as
$fn$
begin
  if exists (select 1 from orders where ttn <> '' and not np_final) then
    perform net.http_post(
      url     := 'https://ortiatyxntdikaldepbp.supabase.co/functions/v1/tg-bot',
      body    := '{"track": true}'::jsonb,
      headers := '{"Content-Type": "application/json"}'::jsonb,
      timeout_milliseconds := 60000
    );
  end if;
end
$fn$;
revoke all on function public.np_track_ping() from public, anon, authenticated;

select cron.schedule('np-track', '*/30 * * * *', $$select public.np_track_ping()$$);
