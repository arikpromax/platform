-- ============================================================
--  СКЛАД: додати або прибрати розмір прямо у вкладці «Склад»
--
--  Доповнення до migration-stock.sql. Дві функції:
--    • stock_add_size  — заводить розмір і одразу дописує його
--                        в картку товару, щоб він зʼявився й на сайті;
--    • stock_drop_size — прибирає розмір зі складу й з картки,
--                        а залишок, якщо він був, списує в історію.
--
--  Нічого наявного не змінює. Виконати ОДИН раз у Supabase → SQL Editor.
-- ============================================================

-- Список розмірів у картці товару зберігається рядком «S, M, L».
-- Ці два помічники дають з ним працювати як зі списком.
create or replace function public.stock_sizes_field(p_site bigint) returns text
language sql stable security definer set search_path = public as
$fn$ select coalesce(config->>'stockSizes', 'sizes') from sites where id = p_site $fn$;

-- ---------- Додати розмір ----------
create or replace function public.stock_add_size(p_item bigint, p_size text)
returns jsonb language plpgsql security definer set search_path = public as
$fn$
declare v_site bigint; v_size text; v_fld text; v_cur text; v_arr text[];
begin
  v_size := btrim(coalesce(p_size, ''));
  if v_size = '' or length(v_size) > 24 then
    return jsonb_build_object('ok', false, 'error', 'size');
  end if;
  select site_id into v_site from items where id = p_item;
  if v_site is null or not public.stock_can_edit(v_site) then
    return jsonb_build_object('ok', false, 'error', 'access');
  end if;

  insert into stock (site_id, item_id, size, color, qty)
  values (v_site, p_item, v_size, '', 0)
  on conflict (item_id, size, color) do nothing;

  -- дописуємо розмір у картку товару: сайт бере список саме звідти
  v_fld := public.stock_sizes_field(v_site);
  select coalesce(extra->>v_fld, '') into v_cur from items where id = p_item;
  select array_agg(btrim(x)) into v_arr
    from unnest(string_to_array(v_cur, ',')) as x where btrim(x) <> '';
  if v_arr is null or not (v_size = any(v_arr)) then
    update items
       set extra = coalesce(extra, '{}'::jsonb) ||
                   jsonb_build_object(v_fld,
                     case when coalesce(v_cur, '') = '' then v_size else v_cur || ', ' || v_size end)
     where id = p_item;
  end if;

  return jsonb_build_object('ok', true);
end
$fn$;

-- ---------- Прибрати розмір ----------
create or replace function public.stock_drop_size(p_item bigint, p_size text)
returns jsonb language plpgsql security definer set search_path = public as
$fn$
declare v_site bigint; v_size text; v_fld text; v_cur text; v_new text; s record;
begin
  v_size := btrim(coalesce(p_size, ''));
  select site_id into v_site from items where id = p_item;
  if v_site is null or not public.stock_can_edit(v_site) then
    return jsonb_build_object('ok', false, 'error', 'access');
  end if;

  select * into s from stock
   where item_id = p_item and size = v_size and color = ''
   for update;

  if found then
    -- товар, відкладений під чийсь кошик, чіпати не можна
    if s.reserved > 0 then
      return jsonb_build_object('ok', false, 'error', 'reserved', 'left', s.reserved);
    end if;
    -- залишок не зникає мовчки: спершу списання в історію
    if s.qty > 0 then
      insert into stock_moves (site_id, item_id, size, color, kind, delta, qty_after, note, who)
      values (v_site, p_item, s.size, s.color, 'writeoff', -s.qty, 0,
              'розмір прибрано зі складу', public.stock_who());
    end if;
    delete from stock where id = s.id;
  end if;

  -- і прибираємо розмір зі списку в картці товару
  v_fld := public.stock_sizes_field(v_site);
  select coalesce(extra->>v_fld, '') into v_cur from items where id = p_item;
  select string_agg(btrim(x), ', ') into v_new
    from unnest(string_to_array(v_cur, ',')) as x
   where btrim(x) <> '' and btrim(x) <> v_size;
  update items
     set extra = coalesce(extra, '{}'::jsonb) || jsonb_build_object(v_fld, coalesce(v_new, ''))
   where id = p_item;

  return jsonb_build_object('ok', true);
end
$fn$;

-- ---------- Кому дозволено ----------
revoke all on function public.stock_add_size(bigint, text) from public;
revoke all on function public.stock_drop_size(bigint, text) from public;
revoke all on function public.stock_sizes_field(bigint) from public;
grant execute on function public.stock_add_size(bigint, text) to authenticated;
grant execute on function public.stock_drop_size(bigint, text) to authenticated;
