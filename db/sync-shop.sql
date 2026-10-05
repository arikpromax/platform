-- Обмін із УкрСкладом — програмою обліку магазину (Just shop).
--
-- Головна по товарах, кількості й цінах — програма в магазині. Ключ кожного
-- рядка — ID товару в УкрСкладі: там кожен розмір окремий товар. Артикул і
-- розмір потрібні лише раз — щоб зчепити новий ID з карткою на сайті; далі
-- назви й розміри в УкрСкладі можна правити, звʼязок не загубиться.
--
-- Скрипт магазину:
--   1. шле залишки        → sync_stock: абсолютна кількість («тепер 2», не «−1»),
--                           тож повтор чи втрачене повідомлення нічого не ламає.
--                           Тригер шле змінені рядки, уночі — повний перелік (full):
--                           чого в ньому немає, того немає й на сайті.
--                           У відповідь — маркер: що прийняли й скільки тепер на сайті.
--   2. забирає замовлення → orders_for_shop: оплачені й з накладеним платежем,
--                           а також скасування й повернення;
--   3. підтверджує        → sync_ack.
-- Поки програма не забрала замовлення з сайту, сайт сам віднімає його від
-- кількості, яку прислав магазин, — так одну річ не продадуть двічі.
--
-- Функції викликає лише бот (службовим ключем) після перевірки ключа обміну
-- SYNC_KEY. Ні сайт, ні адмінка їх напряму не бачать.
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

-- ---------- 2) ID УкрСкладу на кожному розмірі ----------
alter table public.stock add column if not exists ext_id text;
create unique index if not exists stock_site_ext_id on public.stock (site_id, ext_id) where ext_id is not null;

-- ---------- 3) Помічники ----------
-- Розмір до одного вигляду для порівняння: «44,0» = «44», кирилична «М» = латинська «M»,
-- «38/42» = «38-42»; «ONE SIZE», «MISC», «25L», порожній — це «Універсальний» (UNI)
create or replace function public.sync_size(p text) returns text
language sql immutable as
$fn$
  select case
    when s in ('', 'ONE SIZE', 'ONESIZE', 'OS', 'MISC', 'MISK', 'UNI', 'UNIVERSAL', 'NAN',
               'УНІВЕРСАЛЬНИЙ', 'УНИВЕРСАЛЬНЫЙ')
      or s ~ '^[0-9]+ ?L$' then 'UNI'
    else regexp_replace(
           replace(replace(regexp_replace(translate(s, 'МХАСЕТОРНКВ', 'MXACETOPHKB'), '\s+', '', 'g'), ',', '.'), '/', '-'),
           '\.0+$', '')
  end
  from (select upper(btrim(coalesce(p, ''))) as s) t
$fn$;

-- Так розмір пишемо на сайті, коли заводимо новий
create or replace function public.sync_size_label(p text) returns text
language sql immutable as
$fn$ select case when public.sync_size(p) = 'UNI' then 'Універсальний' else public.sync_size(p) end $fn$;

-- Артикул до одного вигляду: у костюма два артикули через «__» у будь-якому порядку.
-- Окремі штани з костюма — інший артикул, з костюмом їх не плутаємо.
create or replace function public.sync_sku(p text) returns text
language sql immutable as
$fn$
  select coalesce(string_agg(x, '__' order by x), '')
    from unnest(regexp_split_to_array(upper(btrim(coalesce(p, ''))), '[_[:space:]/+]+')) x
   where x <> ''
$fn$;

-- Число з тексту; незрозуміле — null, а не помилка на весь обмін
create or replace function public.sync_dec(p text) returns numeric
language sql immutable as
$fn$
  select case when v ~ '^-?[0-9]+(\.[0-9]+)?$' then v::numeric end
    from (select replace(regexp_replace(coalesce(p, ''), '\s+', '', 'g'), ',', '.') as v) t
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
    when x ~ '(костюм|комплект|club set)'                             then 'kostiumy'
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

-- Старий обмін за артикулом більше не потрібен
drop function if exists public.sync_stock(bigint, jsonb, boolean);

-- ---------- 4) Залишки й ціни з магазину ----------
-- Рядок від магазину: {id, sku, size, qty, price, sale, name, brand, category, gender}
--   id    — ID товару в УкрСкладі (обовʼязково);
--   sku, size, name — лише щоб зчепити новий ID; далі не потрібні;
--   price — роздрібна ціна; sale — «Ціна Акція»: якщо є й менша за роздрібну,
--           на сайті роздрібна перекреслена, а продають за акційною.
create or replace function public.sync_apply(p_site bigint, p_items jsonb, p_full boolean)
returns jsonb language plpgsql security definer set search_path = public as
$fn$
declare
  r record; s record; v_ord record; g record;
  v_item bigint; v_stock bigint; v_have int; v_known int;
  v_target int; v_pending int; v_base numeric; v_sale numeric; v_cur numeric;
  v_linked int := 0; v_added int := 0; v_changed int := 0; v_zeroed int := 0;
  v_created jsonb := '[]'::jsonb; v_problems jsonb := '[]'::jsonb;
  v_conflicts jsonb := '[]'::jsonb; v_prices jsonb := '[]'::jsonb;
begin
  if jsonb_typeof(p_items) is distinct from 'array' or jsonb_array_length(p_items) = 0 then
    return jsonb_build_object('ok', false, 'error', 'порожній список товарів');
  end if;
  -- тригер і нічна звірка можуть зійтися в часі — нехай ідуть по черзі
  perform pg_advisory_xact_lock(7106, p_site::int);

  -- скільки розмірів уже зчеплено й є в наявності — щоб не прийняти обрізаний повний перелік
  select count(*) into v_have from stock where site_id = p_site and ext_id is not null and qty > 0;

  create temp table if not exists _sync_in (
    n int, ext text, sku text, size text, nsize text, qty int, price numeric, sale numeric,
    name text, brand text, category text, gender text, stock_id bigint, how text
  ) on commit drop;
  truncate _sync_in;

  -- той самий ID двічі в одному надсиланні — беремо останній
  insert into _sync_in (n, ext, sku, size, nsize, qty, price, sale, name, brand, category, gender)
  select distinct on (ext) n, ext, sku, size, public.sync_size(size), qty, price, sale,
         -- «Кросівки Nike Air Max 90 Black, 42.5» → без розміру в кінці
         case when name ~ ',[^,]*$'
               and (public.sync_size(substring(name from ',([^,]*)$')) = public.sync_size(size)
                    or lower(btrim(substring(name from ',([^,]*)$'))) = 'nan')
              then btrim(regexp_replace(name, '\s*,[^,]*$', '')) else name end,
         brand, category, gender
    from (
      select x.n::int as n,
             btrim(coalesce(x.v->>'id', '')) as ext,
             btrim(coalesce(x.v->>'sku', '')) as sku,
             btrim(coalesce(x.v->>'size', '')) as size,
             case when public.sync_dec(x.v->>'qty') is not null
                  then greatest(floor(public.sync_dec(x.v->>'qty')), 0)::int end as qty,
             nullif(public.sync_dec(x.v->>'price'), 0) as price,
             nullif(public.sync_dec(x.v->>'sale'), 0) as sale,
             btrim(regexp_replace(coalesce(x.v->>'name', ''), '\s+', ' ', 'g')) as name,
             btrim(coalesce(x.v->>'brand', '')) as brand,
             btrim(coalesce(x.v->>'category', '')) as category,
             lower(btrim(coalesce(x.v->>'gender', ''))) as gender
        from jsonb_array_elements(p_items) with ordinality as x(v, n)
    ) q
   where ext <> ''
   order by ext, n desc;

  -- рядки, які не можемо прийняти, — у маркер, решта йде далі
  select v_problems || coalesce(jsonb_agg(jsonb_build_object('n', x.n, 'why', 'немає id')), '[]'::jsonb)
    into v_problems
    from jsonb_array_elements(p_items) with ordinality as x(v, n)
   where btrim(coalesce(x.v->>'id', '')) = '';
  select v_problems || coalesce(jsonb_agg(jsonb_build_object('id', ext, 'why', 'незрозуміла кількість')), '[]'::jsonb)
    into v_problems from _sync_in where qty is null;
  delete from _sync_in where qty is null;

  -- 1. Відомі ID — одразу на свій розмір
  update _sync_in x set stock_id = st.id, how = 'id'
    from stock st where st.site_id = p_site and st.ext_id = x.ext;
  select count(*) into v_known from _sync_in where how = 'id';

  -- Повний перелік, у якому немає й половини відомих товарів, — найімовірніше,
  -- вивантаження обірвалось. Нічого не обнуляємо, кажемо про це.
  if p_full and v_have >= 20 and v_known < v_have / 2 then
    return jsonb_build_object('ok', false, 'error', 'full_small',
      'message', 'у повному переліку лише ' || v_known || ' відомих ID з ' || v_have || ' — нічого не змінено');
  end if;

  -- 2. Нові ID — шукаємо картку за артикулом і розмір на ній
  for r in select * from _sync_in where stock_id is null order by n loop
    v_item := null;
    if public.sync_sku(r.sku) <> '' then
      select id into v_item from items
       where site_id = p_site and collection = 'products'
         and public.sync_sku(extra->>'sku') = public.sync_sku(r.sku)
       order by id limit 1;
    end if;

    if v_item is null then
      if public.sync_sku(r.sku) = '' then
        v_problems := v_problems || jsonb_build_array(jsonb_build_object('id', r.ext, 'why', 'новий ID без артикула'));
        continue;
      end if;
      -- новий артикул — заводимо картку. Фото Nike і Jordan знайде бот, назву зробить
      -- офіційною; до того на сайті стоїть заглушка «Фото згодом».
      insert into items (site_id, collection, title, text, price, image_url, extra, sort_order)
      select p_site, 'products', coalesce(nullif(r.name, ''), r.sku),
             concat_ws(' ',
               case public.sync_cat(r.category, r.name)
                 when 'vzuttia' then 'Оригінальне взуття' when 'kurtky' then 'Оригінальна куртка'
                 when 'kofty' then 'Оригінальна кофта' when 'kostiumy' then 'Оригінальний костюм'
                 when 'zhyletky' then 'Оригінальна жилетка' when 'shtany' then 'Оригінальні штани'
                 when 'futbolky' then 'Оригінальна футболка' when 'shorty' then 'Оригінальні шорти'
                 when 'shkarpetky' then 'Оригінальні шкарпетки' else 'Оригінальний аксесуар'
               end || coalesce(' ' || nullif(b.brand, ''), '') || ' з Європи.',
               case b.gender when 'm' then 'Чоловіча модель.' when 'w' then 'Жіноча модель.' end,
               'Артикул ' || replace(public.sync_sku(r.sku), '__', ' + ') || ' — за ним модель легко звірити на сайті бренду.',
               'Перед відправкою надсилаємо фото бірок, щоб ви переконалися в оригінальності.'),
             coalesce(public.sync_num(coalesce(r.sale, r.price)), ''),
             '',
             jsonb_build_object(
               'sku', public.sync_sku(r.sku),
               'brand', b.brand,
               'cat', public.sync_cat(r.category, r.name),
               'gender', b.gender,
               'sizes', '',
               'old', case when r.sale is not null and r.price > r.sale then public.sync_num(r.price) else '' end,
               'tag', '', 'weight', '', 'stock', true,
               'photos', '[]'::jsonb,
               'title_auto', true,
               'photo_lookup', case when b.brand in ('Nike', 'Jordan') then 'pending' else 'none' end),
             0
        from (select coalesce(nullif(r.brand, ''),
                case when r.name ~* 'jordan' then 'Jordan'
                     when r.name ~* 'nike' then 'Nike'
                     when r.name ~* 'new balance' then 'New Balance'
                     when r.name ~ '\mON\M' or r.name ~* '(on running|\mcloud)' then 'On'
                     else '' end) as brand,
                     case when r.gender ~ '^(m|ч|муж|чол|men)' then 'm'
                          when r.gender ~ '^(w|ж|жін|жен|wom)' then 'w'
                          when r.name ~* '(жіноч|женск|women|wmns)' then 'w'
                          when r.name ~* '(чолові|мужск|\mmen)' then 'm' else '' end as gender) b
      returning id into v_item;
      v_created := v_created || jsonb_build_array(jsonb_build_object('item', v_item, 'sku', public.sync_sku(r.sku), 'id', r.ext));
    end if;

    -- вільний (ще не зчеплений) рядок цього розміру
    select id into v_stock from stock
     where item_id = v_item and color = '' and ext_id is null and public.sync_size(size) = r.nsize
     order by qty desc, id limit 1;
    if found then
      update stock set ext_id = r.ext where id = v_stock;
      update _sync_in set stock_id = v_stock, how = 'link' where ext = r.ext;
      v_linked := v_linked + 1;
      continue;
    end if;

    -- розмір уже зчеплений з іншим ID: у програмі дві картки на одну річ
    select ext_id into s from stock
     where item_id = v_item and color = '' and public.sync_size(size) = r.nsize limit 1;
    if found then
      v_problems := v_problems || jsonb_build_array(jsonb_build_object(
        'id', r.ext, 'why', 'цей артикул і розмір уже має ID ' || s.ext_id));
      continue;
    end if;

    -- нового розміру на картці ще немає — додаємо
    insert into stock (site_id, item_id, size, color, qty, ext_id)
    values (p_site, v_item, public.sync_size_label(r.size), '', 0, r.ext)
    returning id into v_stock;
    update items
       set extra = extra || jsonb_build_object('sizes', (
             select string_agg(z, ', ' order by z) from (
               select distinct btrim(z) as z
                 from unnest(string_to_array(coalesce(extra->>'sizes', ''), ',') || array[public.sync_size_label(r.size)]) z
                where btrim(z) <> '') q))
     where id = v_item;
    update _sync_in set stock_id = v_stock, how = 'new' where ext = r.ext;
    v_added := v_added + 1;
  end loop;

  -- 3. Кількість: з магазину мінус замовлення сайту, яких магазин ще не забрав
  for r in select x.*, st.item_id, st.size as site_size, st.qty as site_qty
             from _sync_in x join stock st on st.id = x.stock_id loop
    select coalesce(sum((l->>'qty')::int), 0) into v_pending
      from orders o, jsonb_array_elements(o.lines) l
     where o.site_id = p_site and o.synced_at is null
       and o.status in ('new', 'shipped', 'done')
       and (l->>'item_id')::bigint = r.item_id
       and public.sync_size(l->>'size') = public.sync_size(r.site_size);
    v_target := greatest(r.qty - v_pending, 0);

    -- У магазині менше, ніж замовили на сайті й магазин ще не забрав:
    -- ту саму річ продали і там, і тут. Кажемо про кожне таке замовлення один раз.
    if r.qty < v_pending then
      for v_ord in
        select distinct o2.id, o2.ref from orders o2, jsonb_array_elements(o2.lines) l2
         where o2.site_id = p_site and o2.synced_at is null and o2.oversold_at is null
           and o2.status in ('new', 'shipped', 'done')
           and (l2->>'item_id')::bigint = r.item_id
           and public.sync_size(l2->>'size') = public.sync_size(r.site_size)
      loop
        update orders set oversold_at = now() where id = v_ord.id;
        v_conflicts := v_conflicts || jsonb_build_array(jsonb_build_object(
          'ref', v_ord.ref, 'id', r.ext, 'sku', (select extra->>'sku' from items where id = r.item_id), 'size', r.site_size, 'shop_qty', r.qty, 'site_orders', v_pending));
      end loop;
    end if;

    if r.site_qty <> v_target then
      update stock set qty = v_target, updated_at = now() where id = r.stock_id;
      insert into stock_moves (site_id, item_id, size, color, kind, delta, qty_after, note, who)
      values (p_site, r.item_id, r.site_size, '', 'fix', v_target - r.site_qty, v_target,
              'синхронізація з магазином', 'магазин');
      v_changed := v_changed + 1;
    end if;
  end loop;

  -- 4. Ціни — по картці. Якщо розміри однієї картки прийшли з різною ціною,
  --    лишаємо поточну, коли вона серед них, і кажемо про це в маркері.
  for g in
    select st.item_id, array_agg(distinct x.price) filter (where x.price is not null) as prices,
           min(x.sale) filter (where x.sale is not null) as sale,
           min(x.sku) as sku
      from _sync_in x join stock st on st.id = x.stock_id
     group by st.item_id
  loop
    continue when g.prices is null;
    select coalesce(public.sync_dec(nullif(extra->>'old', '')), public.sync_dec(price)) into v_cur
      from items where id = g.item_id;
    v_base := case when v_cur = any(g.prices) then v_cur
                   else (select max(p) from unnest(g.prices) p) end;
    if array_length(g.prices, 1) > 1 then
      v_prices := v_prices || jsonb_build_array(jsonb_build_object('sku', g.sku, 'prices', to_jsonb(g.prices), 'kept', v_base));
    end if;
    v_sale := case when g.sale is not null and g.sale < v_base then g.sale end;
    update items
       set price = public.sync_num(coalesce(v_sale, v_base)),
           extra = extra || jsonb_build_object('old', case when v_sale is not null then public.sync_num(v_base) else '' end)
     where id = g.item_id
       and (price is distinct from public.sync_num(coalesce(v_sale, v_base))
            or coalesce(extra->>'old', '') is distinct from
               case when v_sale is not null then public.sync_num(v_base) else '' end);
  end loop;

  -- 5. Повний перелік: чого в ньому немає, того немає й на сайті (картки не видаляємо)
  if p_full then
    for s in
      select st.* from stock st join items i on i.id = st.item_id
       where st.site_id = p_site and st.qty > 0 and i.collection = 'products'
         and not exists (select 1 from _sync_in x where x.stock_id = st.id)
    loop
      update stock set qty = 0, updated_at = now() where id = s.id;
      insert into stock_moves (site_id, item_id, size, color, kind, delta, qty_after, note, who)
      values (p_site, s.item_id, s.size, '', 'fix', -s.qty, 0, 'немає в магазині', 'магазин');
      v_zeroed := v_zeroed + 1;
    end loop;
  end if;

  -- Маркер: що прийняли й скільки тепер на сайті по кожному ID
  return jsonb_build_object(
    'ok', true,
    'received', jsonb_array_length(p_items),
    'accepted', (select count(*) from _sync_in where stock_id is not null),
    'linked', v_linked, 'new_sizes', v_added, 'changed', v_changed, 'zeroed', v_zeroed,
    'created', v_created, 'prices', v_prices, 'problems', v_problems, 'conflicts', v_conflicts,
    'rows', (select coalesce(jsonb_agg(jsonb_build_object('id', x.ext, 'qty', st.qty) order by x.n), '[]'::jsonb)
               from _sync_in x join stock st on st.id = x.stock_id));
end
$fn$;

-- Те саме з пробним прогоном: dry — робимо все, показуємо результат і відкочуємо
create or replace function public.sync_stock(
  p_site bigint, p_items jsonb, p_full boolean default false, p_dry boolean default false
)
returns jsonb language plpgsql security definer set search_path = public as
$fn$
declare v jsonb;
begin
  if not p_dry then return public.sync_apply(p_site, p_items, p_full); end if;
  begin
    v := public.sync_apply(p_site, p_items, p_full);
    raise exception using errcode = 'P0001', message = 'sync-dry-rollback';
  exception when raise_exception then
    if sqlerrm <> 'sync-dry-rollback' then raise; end if;
  end;
  return v || jsonb_build_object('dry', true);
end
$fn$;

-- ---------- 5) Замовлення для магазину ----------
-- Нові (оплачені карткою або з накладеним платежем) і ті, чий статус змінився
-- після того, як магазин їх забрав (скасування, повернення). У кожному рядку —
-- ID УкрСкладу, за яким програма робить розхідну накладну.
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
                        'id', (select st.ext_id from stock st
                                where st.item_id = (l->>'item_id')::bigint and st.color = ''
                                  and public.sync_size(st.size) = public.sync_size(l->>'size')
                                order by st.ext_id is null, st.id limit 1),
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

-- ---------- 6) Магазин підтвердив, що забрав ----------
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

revoke all on function public.sync_apply(bigint, jsonb, boolean) from public, anon, authenticated;
revoke all on function public.sync_stock(bigint, jsonb, boolean, boolean) from public, anon, authenticated;
revoke all on function public.orders_for_shop(bigint) from public, anon, authenticated;
revoke all on function public.sync_ack(bigint, text[], text[]) from public, anon, authenticated;
grant execute on function public.sync_apply(bigint, jsonb, boolean) to service_role;
grant execute on function public.sync_stock(bigint, jsonb, boolean, boolean) to service_role;
grant execute on function public.orders_for_shop(bigint) to service_role;
grant execute on function public.sync_ack(bigint, text[], text[]) to service_role;
