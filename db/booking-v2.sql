-- ============================================================
--  БРОНЮВАННЯ, версія 2
--
--  1. Бронь із сайту одразу підтверджена: гість отримав номер,
--     власник лише скасовує, якщо щось не так.
--  2. База сама не дає датам перетнутися — неважливо, звідки
--     прийшла бронь: із сайту, з адмінки чи кнопкою «Повернути».
--     Раніше перевіряв лише сайт, і бронь, записана в адмінці
--     вручну, могла лягти поверх чужої.
--
--  Виконати один раз у Supabase → SQL Editor (після booking.sql).
--  Повторний запуск безпечний.
-- ============================================================

-- ---------- 1) Старі «нові» броні — підтверджені ----------
--  Робимо ДО того, як зʼявиться сторож нижче: інакше він перевіряв
--  би кожну таку бронь і міг зупинити весь файл на старому перетині.
update public.bookings set status = 'confirmed', updated_at = now()
where status = 'new';

-- ---------- 2) Сторож: жодна бронь поверх зайнятих дат ----------
create or replace function public.bookings_guard() returns trigger
language plpgsql security definer set search_path = public as
$fn$
declare
  v_units int;
  v_peak  int;
begin
  -- скасовану можна зберігати будь-коли — вона нічого не займає
  if new.status = 'cancelled' then return new; end if;

  if new.date_in is null or new.date_out is null or new.date_out <= new.date_in then
    raise exception 'BAD_DATES' using hint = 'Виїзд має бути пізніше за заїзд';
  end if;

  -- Дві броні того самого номера в ту саму мить — перевіряємо по черзі,
  -- інакше обидві побачили б вільні дати й лягли разом.
  perform pg_advisory_xact_lock(hashtext(new.site_id::text || ':' || new.room_key));

  v_units := coalesce(public.room_units(new.site_id, new.room_key), 1);

  -- найзавантаженіша ніч серед обраних, без самої цієї броні
  select coalesce(max(taken), 0) into v_peak
  from (
    select sum(b.rooms_count) as taken
    from public.bookings b
    cross join lateral generate_series(b.date_in, b.date_out - 1, interval '1 day') as g(d)
    where b.site_id = new.site_id
      and b.room_key = new.room_key
      and b.status <> 'cancelled'
      and b.id is distinct from new.id
      and g.d >= new.date_in and g.d < new.date_out
    group by g.d
  ) t;

  if v_peak + greatest(1, coalesce(new.rooms_count, 1)) > v_units then
    raise exception 'ROOM_BUSY' using hint = 'На ці дати в цьому номері вже немає вільних місць';
  end if;
  return new;
end
$fn$;

drop trigger if exists bookings_guard on public.bookings;
create trigger bookings_guard
  before insert or update of status, date_in, date_out, room_key, rooms_count
  on public.bookings
  for each row execute function public.bookings_guard();

-- ---------- 3) Оформлення з сайту: одразу підтверджено ----------
--  Повертає {ok:true, id, ref} або {ok:false, why:'busy'|'dates'}.
--  Вільні місця перевіряє сторож вище — тут лише ловимо його відмову.
create or replace function public.place_booking(
  p_site     bigint,
  p_room     text,
  p_in       date,
  p_out      date,
  p_adults   int,
  p_children int,
  p_rooms    int,
  p_guest    jsonb,
  p_extras   jsonb,
  p_total    numeric
) returns jsonb
language plpgsql security definer set search_path = public as
$fn$
declare
  v_name text;
  v_ref  text;
  v_id   bigint;
begin
  if p_in is null or p_out is null or p_out <= p_in or p_in < current_date then
    return jsonb_build_object('ok', false, 'why', 'dates');
  end if;

  select title into v_name
  from public.items
  where site_id = p_site and collection = 'rooms' and extra->>'key' = p_room
  limit 1;

  v_ref := 'F-' || to_char(now() at time zone 'Europe/Kyiv', 'DDMM') || '-' ||
           lpad((floor(random() * 900) + 100)::text, 3, '0');

  begin
    insert into public.bookings
      (site_id, ref, room_key, room_name, rooms_count, date_in, date_out,
       adults, children, guest, extras, total, status, source)
    values
      (p_site, v_ref, p_room, coalesce(v_name, p_room), greatest(1, coalesce(p_rooms, 1)),
       p_in, p_out,
       greatest(1, coalesce(p_adults, 1)), greatest(0, coalesce(p_children, 0)),
       coalesce(p_guest, '{}'::jsonb), coalesce(p_extras, '{}'::jsonb),
       coalesce(p_total, 0), 'confirmed', 'site')
    returning id into v_id;
  exception when raise_exception then
    if sqlerrm = 'ROOM_BUSY' then return jsonb_build_object('ok', false, 'why', 'busy'); end if;
    if sqlerrm = 'BAD_DATES' then return jsonb_build_object('ok', false, 'why', 'dates'); end if;
    raise;
  end;

  perform public.booking_ping(v_id);
  return jsonb_build_object('ok', true, 'id', v_id, 'ref', v_ref);
end
$fn$;

grant execute on function public.place_booking(bigint, text, date, date, int, int, int, jsonb, jsonb, numeric)
  to anon, authenticated;

select 'Готово: броні з сайту одразу підтверджені, перетин дат база не пустить.' as "бронювання v2";
