-- ============================================================
--  ПІДКЛЮЧЕННЯ TELEGRAM-БОТА ДЛЯ «ФІЛІНА» (сайт 108)
--
--  Таблиці tg_chats і tg_invites уже створив db/telegram-bot.sql —
--  вони спільні для всіх сайтів платформи. Тут лише:
--    1) бронь не стукає в бота, поки жоден чат не підключено;
--    2) код запрошення, щоб підключити свій чат або групу.
--
--  Виконати у Supabase → SQL Editor. Повторний запуск безпечний:
--  видасть новий код, старий просто протухне через тиждень.
-- ============================================================

-- ---------- 1) Не стукати в бота, поки нема кому ----------
--  Інакше підстраховка кожні дві хвилини марно повторювала б
--  надсилання броней, яких нікому отримати.
create or replace function public.booking_ping(p_booking bigint) returns void
language plpgsql security definer set search_path = public as
$fn$
declare v_site bigint;
begin
  select site_id into v_site from public.bookings where id = p_booking;
  if v_site is null then return; end if;
  if not exists (select 1 from public.tg_chats where site_id = v_site) then
    -- Чатів ще немає. Лишаємо бронь непозначеною: щойно власник
    -- підключить свій чат, підстраховка дошле її сама.
    return;
  end if;

  perform net.http_post(
    url     := 'https://ortiatyxntdikaldepbp.supabase.co/functions/v1/tg-bot',
    body    := jsonb_build_object('booking', p_booking),
    headers := '{"Content-Type": "application/json"}'::jsonb
  );
exception when others then
  null;   -- бот недоступний: бронь збережена, підстраховка спробує ще раз
end
$fn$;

revoke all on function public.booking_ping(bigint) from public, anon, authenticated;

-- ---------- 2) Код запрошення ----------
--  Діє тиждень. Одним кодом можна підключити кілька чатів —
--  наприклад, телефон власника й спільну групу адміністраторів.
insert into public.tg_invites (code, site_id)
values (replace(gen_random_uuid()::text, '-', ''), (select id from public.sites where slug = 'filin'))
returning code as "код запрошення — підставити в посилання t.me/ВАШ_БОТ?start=КОД";
