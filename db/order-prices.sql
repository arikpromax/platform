-- Ціна в замовленні — з бази, а не з браузера.
--
-- Досі place_order брав ціни рядків і суму замовлення такими, як їх прислав
-- браузер. Звичайний покупець цього не помітить, але будь-хто, хто вміє
-- відправити запит сам, міг оформити кросівки за 1 грн: з такою сумою пішла б
-- і оплата LiqPay, і накладений платіж у ТТН.
--
-- Тепер ціну й назву кожного рядка база бере з картки товару, а суму рахує
-- сама. Ціна фіксується в момент замовлення: зміниться потім — у вже
-- оформленому замовленні лишиться та, за якою купили.
-- Сигнатура та сама, тож сайт міняти не треба; у відповідь додано total.
--
-- Виконати один раз у Supabase → SQL Editor. Повторний запуск безпечний.

create or replace function public.place_order(
  p_site bigint, p_token uuid, p_lines jsonb, p_customer jsonb, p_total numeric
) returns jsonb
language plpgsql security definer set search_path = public as
$fn$
declare l jsonb; s record; it record; need int; short jsonb := '[]'::jsonb;
        v_id bigint; v_ref text; v_after int;
        v_lines jsonb := '[]'::jsonb; v_total numeric := 0; v_price numeric;
begin
  if not exists (select 1 from sites where id = p_site and paid_until >= current_date) then
    return jsonb_build_object('ok', false, 'error', 'site');
  end if;
  if jsonb_typeof(p_lines) <> 'array'
     or jsonb_array_length(p_lines) = 0 or jsonb_array_length(p_lines) > 50
     or length(coalesce(p_customer::text, '')) > 4000 then
    return jsonb_build_object('ok', false, 'error', 'lines');
  end if;

  -- Ціна й назва кожного рядка — з картки товару цього ж сайту
  for l in select value from jsonb_array_elements(p_lines) loop
    need := least(greatest(coalesce((l->>'qty')::int, 1), 1), 20);
    select * into it from items
     where id = (l->>'item_id')::bigint and site_id = p_site and collection = 'products';
    if not found then
      return jsonb_build_object('ok', false, 'error', 'item', 'item_id', l->>'item_id');
    end if;
    v_price := nullif(regexp_replace(coalesce(it.price, ''), '[^0-9.]', '', 'g'), '')::numeric;
    if v_price is null or v_price <= 0 then
      return jsonb_build_object('ok', false, 'error', 'price', 'item_id', it.id);
    end if;
    v_lines := v_lines || jsonb_build_array(jsonb_build_object(
      'item_id', it.id,
      'size',    coalesce(l->>'size', ''),
      'color',   coalesce(l->>'color', ''),
      'qty',     need,
      'title',   btrim(coalesce(nullif(it.extra->>'brand', '') || ' ', '') || it.title),
      'price',   v_price));
    v_total := v_total + v_price * need;
  end loop;

  perform public.stock_release_expired();
  perform public.stock_drop_hold(p_token);   -- своє відкладене зараз стане продажем

  for l in select value from jsonb_array_elements(v_lines) loop
    need := (l->>'qty')::int;
    select * into s from stock
     where site_id = p_site and item_id = (l->>'item_id')::bigint
       and size = l->>'size' and color = l->>'color'
     for update;
    if found and s.qty - s.reserved < need then
      short := short || jsonb_build_array(jsonb_build_object(
        'item_id', s.item_id, 'size', s.size,
        'title', l->>'title', 'left', greatest(s.qty - s.reserved, 0)));
    end if;
  end loop;

  if jsonb_array_length(short) > 0 then
    return jsonb_build_object('ok', false, 'short', short);
  end if;

  insert into orders (site_id, ref, status, customer, lines, total)
  values (p_site, '', 'new', coalesce(p_customer, '{}'::jsonb), v_lines, v_total)
  returning id into v_id;
  v_ref := to_char(now(), 'DDMM') || '-' || lpad(v_id::text, 4, '0');
  update orders set ref = v_ref where id = v_id;

  for l in select value from jsonb_array_elements(v_lines) loop
    need := (l->>'qty')::int;
    update stock set qty = qty - need, updated_at = now()
     where site_id = p_site and item_id = (l->>'item_id')::bigint
       and size = l->>'size' and color = l->>'color'
    returning qty into v_after;
    if found then
      insert into stock_moves (site_id, item_id, size, color, kind, delta, qty_after, note, order_ref, who)
      values (p_site, (l->>'item_id')::bigint, l->>'size', l->>'color',
              'sale', -need, v_after, 'замовлення з сайту', v_ref, 'сайт');
    end if;
  end loop;

  return jsonb_build_object('ok', true, 'ref', v_ref, 'id', v_id, 'total', v_total);
end
$fn$;
