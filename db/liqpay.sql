-- Оплата карткою на сайті через LiqPay.
--
-- Як це йде:
--   1. Покупець обирає «Карткою на сайті» й оформлює — замовлення лягає в базу
--      зі станом «чекає оплати», товар списаний, у Telegram поки нічого не йде.
--   2. Сайт відкриває сторінку LiqPay, покупець платить.
--   3. LiqPay повідомляє функцію tg-bot, вона перевіряє підпис і ставить «оплачено».
--   4. Ця зміна сама штовхає бота: ТТН + повідомлення «оплачено» в Telegram.
--   5. Не оплатили за 30 хвилин — замовлення скасовується, товар повертається на склад.
--
-- Поки в Secrets немає ключів LIQPAY_PUBLIC_<сайт> і LIQPAY_PRIVATE_<сайт>,
-- сайт цього способу оплати просто не показує.
--
-- Виконати один раз у Supabase → SQL Editor, ПІСЛЯ telegram-bot.sql. Повторний запуск безпечний.

-- ---------- 1) Оплата в самому замовленні ----------
alter table public.orders
  add column if not exists pay_state text not null default '',  -- '' — оплата не на сайті; wait, paid, failed, refunded
  add column if not exists paid_at   timestamptz,
  add column if not exists pay_info  jsonb not null default '{}'; -- сума, номер платежу LiqPay, маска картки

-- Замовлення з оплатою карткою одразу позначається «чекає оплати»
create or replace function public.orders_pay_mark() returns trigger
language plpgsql as
$fn$
begin
  if new.customer->>'payId' = 'online' and coalesce(new.pay_state, '') = '' then
    new.pay_state := 'wait';
  end if;
  return new;
end
$fn$;
drop trigger if exists orders_pay_mark on public.orders;
create trigger orders_pay_mark before insert on public.orders
  for each row execute function public.orders_pay_mark();

-- ---------- 2) Бот: неоплачене не надсилаємо, оплачене — одразу ----------
create or replace function public.orders_tg_new() returns trigger
language plpgsql security definer set search_path = public as
$fn$
begin
  if new.pay_state not in ('wait', 'failed')
     and exists (select 1 from tg_chats where site_id = new.site_id) then
    perform public.tg_ping(new.id);
  end if;
  return new;
end
$fn$;

create or replace function public.orders_tg_paid() returns trigger
language plpgsql security definer set search_path = public as
$fn$
begin
  if new.pay_state = 'paid' and old.pay_state is distinct from 'paid'
     and exists (select 1 from tg_chats where site_id = new.site_id) then
    perform public.tg_ping(new.id);
  end if;
  return new;
end
$fn$;
drop trigger if exists orders_tg_paid on public.orders;
create trigger orders_tg_paid after update of pay_state on public.orders
  for each row execute function public.orders_tg_paid();

create or replace function public.tg_sweep() returns void
language plpgsql security definer set search_path = public as
$fn$
declare o record;
begin
  for o in
    select id from orders
     where tg_sent_at is null
       and pay_state not in ('wait', 'failed')
       and created_at between now() - interval '1 day' and now() - interval '1 minute'
       and exists (select 1 from tg_chats c where c.site_id = orders.site_id)
     order by id limit 20
  loop
    perform public.tg_ping(o.id);
  end loop;
end
$fn$;

-- ---------- 3) Не оплатили за 30 хвилин — скасувати й повернути товар ----------
create or replace function public.orders_expire_unpaid() returns void
language plpgsql security definer set search_path = public as
$fn$
declare o record; l jsonb; need int; v_after int;
begin
  for o in
    select * from orders
     where status = 'new' and pay_state in ('wait', 'failed')
       and created_at < now() - interval '30 minutes'
     for update skip locked
  loop
    for l in select value from jsonb_array_elements(o.lines) loop
      need := least(greatest(coalesce((l->>'qty')::int, 1), 1), 20);
      update stock set qty = qty + need, updated_at = now()
       where site_id = o.site_id and item_id = (l->>'item_id')::bigint
         and size = coalesce(l->>'size', '') and color = coalesce(l->>'color', '')
      returning qty into v_after;
      if found then
        insert into stock_moves (site_id, item_id, size, color, kind, delta, qty_after, note, order_ref, who)
        values (o.site_id, (l->>'item_id')::bigint, coalesce(l->>'size', ''), coalesce(l->>'color', ''),
                'return', need, v_after, 'не оплачено за 30 хвилин', o.ref, 'сайт');
      end if;
    end loop;
    update orders
       set status = 'cancelled',
           note = trim(note || ' Не оплачено карткою за 30 хвилин — скасовано автоматично.'),
           updated_at = now()
     where id = o.id;
  end loop;
end
$fn$;

revoke all on function public.orders_expire_unpaid() from public, anon, authenticated;
revoke all on function public.tg_sweep() from public, anon, authenticated;

select cron.schedule('orders-expire-unpaid', '*/5 * * * *', $$select public.orders_expire_unpaid()$$);

-- ---------- 4) Тексти сайту: без оплати «на картку ФОП» ----------
-- Оплата на сайті — наложений платіж (і готівка при самовивозі). Реквізити ФОП
-- лишаються лише для передоплати речей під запит — про це домовляються в особистих.
-- Блок «Карткою на сайті» додамо, коли LiqPay запрацює з ключами замовника.
update public.items
   set title = 'Речі під запит',
       text  = 'Передоплата 50% за реквізитами — надсилаємо в особистих, коли підтвердимо модель і розмір. Решту — перед відправкою з Європи.',
       extra = extra || jsonb_build_object('list', 'Оформлюються в Telegram чи Instagram, не через кошик' || chr(10) || 'За потреби даємо чек'),
       sort_order = 2
 where id = 891 and site_id = 106 and title = 'На картку ФОП';

update public.items set sort_order = 1 where id = 890 and site_id = 106;  -- наложений платіж — першим

update public.items
   set text = 'Наложеним платежем Нової Пошти — при отриманні. Для речей під запит — передоплата 50% за реквізитами в особистих, решта перед відправленням.'
 where id = 928 and site_id = 106 and text like 'На картку ФОП%';
