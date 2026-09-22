-- Обмін із програмою обліку магазину (Just shop).
--
-- Головна по товарах, кількості й цінах — програма в магазині. Її скрипт
-- раз на кілька хвилин:
--   1. надсилає залишки й ціни   → sync_stock: сайт оновлює кількість і ціну,
--                                  а нові артикули сам заводить як картки товару;
--   2. забирає замовлення сайту  → orders_for_shop: оплачені й з накладеним
--                                  платежем, а також скасування й повернення;
--   3. підтверджує, що забрав    → sync_ack.
-- Поки програма не підтвердила замовлення з сайту, сайт сам віднімає його від
-- кількості, яку прислав магазин, — так одну річ не продадуть двічі.
--
-- Функції викликає лише бот (службовим ключем) після перевірки секрету
-- SYNC_KEY_<сайт>. Ні сайт, ні адмінка їх напряму не бачать.
--
-- Виконати один раз у Supabase → SQL Editor. Повторний запуск безпечний.

-- ---------- 1) Що магазин уже забрав ----------
alter table public.orders
  add column if not exists synced_at   timestamptz,               -- коли програма магазину прийняла замовлення
  add column if not exists sync_status text not null default '',  -- з яким статусом прийняла
  add column if not exists oversold_at timestamptz;                -- коли зʼясувалось, що річ уже продали в магазині

-- Усе, що було до запуску обміну, магазину не надсилаємо — там уже розібрались вручну
update public.orders set synced_at = coalesce(synced_at, now()), sync_status = status
 where site_id = 106 and synced_at is null;

-- ---------- 2) Помічники ----------
-- Розмір до одного вигляду: «44,0» = «44», кирилична «М» = латинська «M»
create or replace function public.sync_size(p text) returns text
language sql immutable as
$fn$
  select regexp_replace(
           translate(upper(replace(btrim(coalesce(p, '')), ',', '.')), 'МХ', 'MX'),
           '\.0+$', '')
$fn$;

-- Ціна текстом без зайвих «.00»: так її зберігає адмінка
create or replace function public.sync_num(n numeric) returns text
language sql immutable as
$fn$ select case when n is null then null when n = trunc(n) then trunc(n)::bigint::text else n::text end $fn$;

-- Розділ каталогу за назвою категорії чи товару
create or replace function public.sync_cat(p_cat text, p_name text) returns text
language sql immutable as
$fn$
  select case
    when x ~ '(взут|кросів|кросов|кед|черев|бутс|сандал|шльоп|тапк)' then 'vzuttia'
    when x ~ '(куртк|пухов|вітрів|ветров|парк)'                      then 'kurtky'
    when x ~ '(костюм)'                                               then 'kostiumy'
    when x ~ '(жилет)'                                                then 'zhyletky'
    when x ~ '(кофт|худі|худи|світш|свитш|толстов|лонгслів)'          then 'kofty'
    when x ~ '(штан|брюк|джогер|джоггер|легінс)'                      then 'shtany'
    when x ~ '(футбол|майк|t-shirt|поло)'                              then 'futbolky'
    when x ~ '(шорт)'                                                 then 'shorty'
    when x ~ '(шкарп|носк|носок)'                                     then 'shkarpetky'
    else 'aksesuary'
  end
  from (select lower(coalesce(p_cat, '') || ' ' || coalesce(p_name, '')) as x) t
$fn$;

-- ---------- 3) Залишки й ціни з магазину ----------
drop function if exists public.sync_stock(bigint, jsonb, boolean);
create or replace function public.sync_stock(
  p_site bigint, p_items jsonb, p_full boolean default false, p_dry boolean default false
)
returns jsonb language plpgsql security definer set search_path = public as
$fn$
declare
  g record; r record; s record; o record;
  v_conflicts jsonb := '[]'::jsonb;
  v_item bigint; v_extra jsonb; v_sizes text[]; v_target int; v_pending int;
  v_created jsonb := '[]'::jsonb; v_changed int := 0; v_items int := 0; v_zeroed int := 0;
  v_skus text[];
begin
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    return jsonb_build_object('ok', false, 'error', 'порожній список товарів');
  end if;

  -- вхід у зручний вигляд: по рядку на артикул і розмір
  create temp table if not exists _sync_in (
    sku text, size text, nsize text, qty int, price numeric, old_price numeric,
    name text, brand text, category text, gender text
  ) on commit drop;
  truncate _sync_in;
  insert into _sync_in
  select btrim(x->>'sku'),
         btrim(coalesce(x->>'size', '')),
         public.sync_size(x->>'size'),
         greatest(coalesce(floor(nullif(regexp_replace(coalesce(x->>'qty', ''), '[^0-9.]', '', 'g'), '')::numeric), 0), 0)::int,
         nullif(regexp_replace(coalesce(x->>'price', ''), '[^0-9.]', '', 'g'), '')::numeric,
         nullif(regexp_replace(coalesce(x->>'old_price', ''), '[^0-9.]', '', 'g'), '')::numeric,
         btrim(coalesce(x->>'name', '')),
         btrim(coalesce(x->>'brand', '')),
         btrim(coalesce(x->>'category', '')),
         lower(btrim(coalesce(x->>'gender', '')))
    from jsonb_array_elements(p_items) x
   where coalesce(btrim(x->>'sku'), '') <> '';

  select array_agg(distinct sku) into v_skus from _sync_in;

  -- Пробний прогін: нічого не міняємо, лише кажемо, що з чим зійшлося
  if p_dry then
    return jsonb_build_object(
      'ok', true, 'dry', true,
      'rows', (select count(*) from _sync_in),
      'skus', (select count(distinct sku) from _sync_in),
      'matched', (select count(distinct x.sku) from _sync_in x
                   where exists (select 1 from items i
                                  where i.site_id = p_site and i.collection = 'products'
                                    and (i.extra->>'sku' = x.sku or x.sku = any(string_to_array(i.extra->>'sku', '__'))))),
      'new', (select coalesce(jsonb_agg(q.sku), '[]'::jsonb) from (
                select distinct x.sku from _sync_in x
                 where not exists (select 1 from items i
                                    where i.site_id = p_site and i.collection = 'products'
                                      and (i.extra->>'sku' = x.sku or x.sku = any(string_to_array(i.extra->>'sku', '__'))))
                 order by x.sku limit 300) q),
      'absent', (select coalesce(jsonb_agg(jsonb_build_object('sku', q.sku, 'title', q.title)), '[]'::jsonb) from (
                   select i.extra->>'sku' as sku, i.title from items i
                    where i.site_id = p_site and i.collection = 'products'
                      and exists (select 1 from stock st where st.item_id = i.id and st.qty > 0)
                      and not exists (select 1 from _sync_in x
                                       where x.sku = i.extra->>'sku' or x.sku = any(string_to_array(i.extra->>'sku', '__')))
                    order by i.title limit 300) q),
      'new_sizes', (select coalesce(jsonb_agg(jsonb_build_object('sku', q.sku, 'size', q.size)), '[]'::jsonb) from (
                   select x.sku, x.size from _sync_in x join items i
                     on i.site_id = p_site and i.collection = 'products'
                    and (i.extra->>'sku' = x.sku or x.sku = any(string_to_array(i.extra->>'sku', '__')))
                    where not exists (select 1 from stock st where st.item_id = i.id and public.sync_size(st.size) = x.nsize)
                    order by x.sku limit 100) q)
    );
  end if;

  for g in
    select sku, max(name) as name, max(brand) as brand, max(category) as category, max(gender) as gender,
           max(price) as price, max(old_price) as old_price, sum(qty) as total
      from _sync_in group by sku
  loop
    v_items := v_items + 1;
    -- товар на сайті з цим артикулом (у костюмів артикули бувають через «__»)
    select id, extra into v_item, v_extra from items
     where site_id = p_site and collection = 'products'
       and (extra->>'sku' = g.sku or g.sku = any(string_to_array(extra->>'sku', '__')))
     order by id limit 1;

    select array_agg(size order by size) into v_sizes from _sync_in where sku = g.sku;

    if v_item is null then
      -- новий артикул: заводимо картку. Фото ще немає — на сайті її не буде,
      -- доки фото не підтягнеться з каталогу Nike або його не додадуть в адмінці.
      insert into items (site_id, collection, title, text, price, image_url, extra, sort_order)
      values (p_site, 'products',
              coalesce(nullif(g.name, ''), g.sku),
              concat_ws(' ',
                case public.sync_cat(g.category, g.name)
                  when 'vzuttia' then 'Оригінальне взуття' when 'kurtky' then 'Оригінальна куртка'
                  when 'kofty' then 'Оригінальна кофта' when 'kostiumy' then 'Оригінальний костюм'
                  when 'zhyletky' then 'Оригінальна жилетка' when 'shtany' then 'Оригінальні штани'
                  when 'futbolky' then 'Оригінальна футболка' when 'shorty' then 'Оригінальні шорти'
                  when 'shkarpetky' then 'Оригінальні шкарпетки' else 'Оригінальний аксесуар'
                end || coalesce(' ' || nullif(g.brand, ''), '') || ' з Європи.',
                'Артикул ' || g.sku || ' — за ним модель легко звірити на сайті бренду.',
                'Перед відправкою надсилаємо фото бірок, щоб ви переконалися в оригінальності.'),
              coalesce(public.sync_num(g.price), ''),
              '',
              jsonb_build_object(
                'sku', g.sku,
                'brand', g.brand,
                'cat', public.sync_cat(g.category, g.name),
                'gender', case when g.gender ~ '^(m|ч|муж|чол|men)' then 'm'
                               when g.gender ~ '^(w|ж|жін|жен|wom)' then 'w' else '' end,
                'sizes', array_to_string(v_sizes, ', '),
                'old', coalesce(public.sync_num(g.old_price), ''),
                'tag', '', 'weight', '',
                'stock', g.total > 0,
                'photos', '[]'::jsonb,
                'title_auto', true,   -- назва з програми; бот замінить її офіційною назвою Nike
                -- Nike і Jordan: фото знайде бот у каталогу Nike за артикулом
                'photo_lookup', case when (g.brand || ' ' || g.name) ~* '(nike|jordan)' then 'pending' else 'none' end),
              0)
      returning id into v_item;
      v_created := v_created || jsonb_build_array(jsonb_build_object('id', v_item, 'sku', g.sku, 'brand', g.brand));
    else
      -- відомий товар: ціна й стара ціна — з магазину; список розмірів доповнюємо
      update items
         set price = coalesce(public.sync_num(g.price), price),
             extra = extra
                     || jsonb_build_object('old', coalesce(public.sync_num(g.old_price), ''))
                     || jsonb_build_object('sizes', (
                          select string_agg(z, ', ' order by z) from (
                            select distinct btrim(z) as z
                              from unnest(string_to_array(coalesce(extra->>'sizes', ''), ',') || v_sizes) z
                             where btrim(z) <> '') q))
       where id = v_item
         and (price is distinct from coalesce(public.sync_num(g.price), price)
              or coalesce(extra->>'old', '') is distinct from coalesce(public.sync_num(g.old_price), '')
              or not (string_to_array(replace(coalesce(extra->>'sizes', ''), ' ', ''), ',') @> v_sizes));
    end if;

    -- кількість по розмірах: з магазину мінус замовлення сайту, яких магазин ще не прийняв
    for r in select * from _sync_in where sku = g.sku loop
      select coalesce(sum((l->>'qty')::int), 0) into v_pending
        from orders o, jsonb_array_elements(o.lines) l
       where o.site_id = p_site and o.synced_at is null
         and o.status in ('new', 'shipped', 'done')
         and (l->>'item_id')::bigint = v_item
         and public.sync_size(l->>'size') = r.nsize;
      v_target := greatest(r.qty - v_pending, 0);

      -- У магазині менше, ніж замовили на сайті й магазин ще не забрав:
      -- ту саму річ продали і там, і тут. Кажемо про кожне таке замовлення один раз.
      if r.qty < v_pending then
        for o in
          select distinct o2.id, o2.ref from orders o2, jsonb_array_elements(o2.lines) l2
           where o2.site_id = p_site and o2.synced_at is null and o2.oversold_at is null
             and o2.status in ('new', 'shipped', 'done')
             and (l2->>'item_id')::bigint = v_item and public.sync_size(l2->>'size') = r.nsize
        loop
          update orders set oversold_at = now() where id = o.id;
          v_conflicts := v_conflicts || jsonb_build_array(jsonb_build_object(
            'ref', o.ref, 'sku', g.sku, 'size', r.size, 'shop_qty', r.qty, 'site_orders', v_pending));
        end loop;
      end if;

      select * into s from stock
       where site_id = p_site and item_id = v_item and color = '' and public.sync_size(size) = r.nsize
       limit 1;
      if found then
        if s.qty <> v_target then
          update stock set qty = v_target, updated_at = now() where id = s.id;
          insert into stock_moves (site_id, item_id, size, color, kind, delta, qty_after, note, who)
          values (p_site, v_item, s.size, '', 'fix', v_target - s.qty, v_target, 'синхронізація з магазином', 'магазин');
          v_changed := v_changed + 1;
        end if;
      else
        insert into stock (site_id, item_id, size, color, qty) values (p_site, v_item, r.size, '', v_target);
        if v_target > 0 then
          insert into stock_moves (site_id, item_id, size, color, kind, delta, qty_after, note, who)
          values (p_site, v_item, r.size, '', 'in', v_target, v_target, 'синхронізація з магазином', 'магазин');
        end if;
        v_changed := v_changed + 1;
      end if;
    end loop;
  end loop;

  -- Повний знімок: чого немає в переліку магазину, того немає й на сайті
  if p_full then
    for s in
      select st.* from stock st join items i on i.id = st.item_id
       where st.site_id = p_site and st.qty > 0 and i.collection = 'products'
         and not exists (
           select 1 from _sync_in x
            where (x.sku = i.extra->>'sku' or x.sku = any(string_to_array(i.extra->>'sku', '__')))
              and x.nsize = public.sync_size(st.size))
    loop
      update stock set qty = 0, updated_at = now() where id = s.id;
      insert into stock_moves (site_id, item_id, size, color, kind, delta, qty_after, note, who)
      values (p_site, s.item_id, s.size, '', 'fix', -s.qty, 0, 'немає в магазині', 'магазин');
      v_zeroed := v_zeroed + 1;
    end loop;
  end if;

  return jsonb_build_object('ok', true, 'items', v_items, 'changed', v_changed,
                            'zeroed', v_zeroed, 'created', v_created, 'conflicts', v_conflicts);
end
$fn$;

-- ---------- 4) Замовлення для магазину ----------
-- Нові (оплачені карткою або з накладеним платежем) і ті, чий статус змінився
-- після того, як магазин їх забрав (скасування, повернення)
create or replace function public.orders_for_shop(p_site bigint)
returns jsonb language sql stable security definer set search_path = public as
$fn$
  select coalesce(jsonb_agg(jsonb_build_object(
           'ref', o.ref,
           'created_at', o.created_at,
           'status', o.status,
           'is_new', o.synced_at is null,
           'pay', coalesce(o.customer->>'payId', ''),
           'paid', o.pay_state = 'paid',
           'total', o.total,
           'customer', jsonb_build_object(
             'name', o.customer->>'name', 'phone', o.customer->>'phone',
             'delivery', o.customer->>'delivery', 'city', o.customer->>'city',
             'branch', o.customer->>'branch', 'comment', o.customer->>'comment'),
           'ttn', o.ttn,
           'lines', (select jsonb_agg(jsonb_build_object(
                        'sku', i.extra->>'sku', 'size', l->>'size', 'qty', (l->>'qty')::int,
                        'price', (l->>'price')::numeric, 'title', l->>'title'))
                       from jsonb_array_elements(o.lines) l
                       left join items i on i.id = (l->>'item_id')::bigint))
           order by o.id), '[]'::jsonb)
    from orders o
   where o.site_id = p_site
     and (
       (o.synced_at is null and o.status in ('new', 'shipped', 'done')
        and o.pay_state not in ('wait', 'failed'))
       or (o.synced_at is not null and o.sync_status is distinct from o.status)
     )
$fn$;

-- ---------- 5) Магазин підтвердив, що забрав ----------
drop function if exists public.sync_ack(bigint, text[]);
create or replace function public.sync_ack(p_site bigint, p_refs text[], p_short text[] default '{}')
returns jsonb language plpgsql security definer set search_path = public as
$fn$
declare v_acked jsonb; v_short jsonb;
begin
  with done as (
    update orders set synced_at = coalesce(synced_at, now()), sync_status = status
     where site_id = p_site and ref = any(p_refs)
    returning ref
  ) select coalesce(jsonb_agg(ref), '[]'::jsonb) into v_acked from done;

  -- Замовлення, які програма не змогла провести, бо товару вже немає
  with bad as (
    update orders set oversold_at = now()
     where site_id = p_site and ref = any(p_short) and oversold_at is null
    returning ref
  ) select coalesce(jsonb_agg(ref), '[]'::jsonb) into v_short from bad;

  return jsonb_build_object('ok', true, 'acked', v_acked, 'short', v_short);
end
$fn$;

revoke all on function public.sync_stock(bigint, jsonb, boolean, boolean) from public, anon, authenticated;
revoke all on function public.orders_for_shop(bigint) from public, anon, authenticated;
revoke all on function public.sync_ack(bigint, text[], text[]) from public, anon, authenticated;
grant execute on function public.sync_stock(bigint, jsonb, boolean, boolean) to service_role;
grant execute on function public.orders_for_shop(bigint) to service_role;
grant execute on function public.sync_ack(bigint, text[], text[]) to service_role;
