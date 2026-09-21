-- Галочка «Є в наявності» сама йде за складом.
--
-- На сайті тепер лише те, що є на складі. Щоб власнику не стежити за двома
-- місцями, галочка в картці товару ставиться й знімається сама:
--   продали останню одиницю (кількість по всіх розмірах стала 0) → галочка
--   знімається, річ зникає з сайту;
--   довезли й додали кількість у «Складі» → галочка ставиться, річ зʼявляється.
-- Зняти галочку вручну теж можна — тоді річ сховається, навіть якщо вона є.
--
-- Працює лише для сайтів, де ввімкнено склад (config.stock = true) — зараз це Just shop.
-- Виконати один раз у Supabase → SQL Editor. Повторний запуск безпечний.

create or replace function public.stock_flag_sync() returns trigger
language plpgsql security definer set search_path = public as
$fn$
declare
  v_site bigint := coalesce(new.site_id, old.site_id);
  v_item bigint := coalesce(new.item_id, old.item_id);
  v_now  int;
  v_was  int;
begin
  if not exists (select 1 from sites where id = v_site and coalesce((config->>'stock')::boolean, false)) then
    return null;
  end if;
  select coalesce(sum(qty), 0) into v_now from stock where site_id = v_site and item_id = v_item;
  -- скільки було до цієї зміни: зараз мінус нове плюс старе
  v_was := v_now - coalesce(new.qty, 0) + coalesce(old.qty, 0);

  if v_now <= 0 and v_was > 0 then
    update items set extra = jsonb_set(extra, '{stock}', 'false'::jsonb)
     where id = v_item and site_id = v_site and extra->'stock' is distinct from 'false'::jsonb;
  elsif v_now > 0 and v_was <= 0 then
    update items set extra = jsonb_set(extra, '{stock}', 'true'::jsonb)
     where id = v_item and site_id = v_site and extra->'stock' is distinct from 'true'::jsonb;
  end if;
  return null;
end
$fn$;
revoke all on function public.stock_flag_sync() from public, anon, authenticated;

drop trigger if exists stock_flag_sync on public.stock;
create trigger stock_flag_sync after insert or update of qty or delete on public.stock
  for each row execute function public.stock_flag_sync();

-- Один раз вирівняти вже наявне: галочка = чи є хоч одна одиниця
update public.items i
   set extra = jsonb_set(i.extra, '{stock}', to_jsonb(s.total > 0))
  from (select item_id, sum(qty) as total from public.stock where site_id = 106 group by item_id) s
 where i.id = s.item_id and i.site_id = 106 and i.collection = 'products'
   and i.extra->'stock' is distinct from to_jsonb(s.total > 0);

-- Підказка біля галочки в адмінці — щоб було ясно, звідки вона береться
update public.sites s
   set config = jsonb_set(s.config, '{collections}', (
         select jsonb_agg(
                  case when c->>'key' = 'products'
                       then jsonb_set(c, '{fields}', (
                              select jsonb_agg(
                                       case when f->>'key' = 'stock'
                                            then f || jsonb_build_object('hint',
                                              'Ставиться й знімається сама за «Складом»: продали останню одиницю — знімається, і річ зникає з сайту; додали кількість у «Складі» — ставиться. Зняти вручну — сховати річ із сайту.')
                                            else f end
                                       order by fn)
                                from jsonb_array_elements(c->'fields') with ordinality as ff(f, fn)))
                       else c end
                  order by cn)
           from jsonb_array_elements(s.config->'collections') with ordinality as cc(c, cn)))
 where s.id = 106;

-- Перевірка: скільки товарів зараз на сайті, а скільки сховано
select count(*) filter (where (extra->>'stock')::boolean)     as "на сайті",
       count(*) filter (where not (extra->>'stock')::boolean) as "сховано"
  from public.items where site_id = 106 and collection = 'products';
