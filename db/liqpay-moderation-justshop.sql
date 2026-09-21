-- Just shop: сайт під вимоги модерації LiqPay.
--
--  1. «Накладений платіж» замість русизму «наложений» (LiqPay перевіряє грамотність).
--  2. Сторінка «Доставка й оплата»: блок про оплату карткою й окремо — повернення коштів.
--  3. Реквізити продавця й пошта підтримки — нові поля в адмінці («Контакти й підвал»).
--     Зараз там заглушки; справжні дані власник вписує в адмінці.
--  4. Короткий опис для кожного товару, в якого його немає (LiqPay вимагає опис і ціну
--     для кожної позиції). Написані власником описи не чіпаються.
--
-- Виконати один раз у Supabase → SQL Editor. Повторний запуск безпечний.

-- ---------- 1) «Накладений», а не «наложений» ----------
update public.items
   set title = replace(replace(title, 'Наложен', 'Накладен'), 'наложен', 'накладен'),
       text  = replace(replace(text,  'Наложен', 'Накладен'), 'наложен', 'накладен'),
       extra = replace(replace(extra::text, 'Наложен', 'Накладен'), 'наложен', 'накладен')::jsonb
 where site_id = 106
   and (title like '%аложен%' or text like '%аложен%' or extra::text like '%аложен%');

update public.texts
   set value = replace(replace(value, 'Наложен', 'Накладен'), 'наложен', 'накладен')
 where site_id = 106 and value like '%аложен%';

-- ---------- 2) Оплата, повернення, контакти ----------
insert into public.items (site_id, collection, title, text, extra, sort_order)
select 106, 'payment', 'Карткою на сайті',
       'Visa, Mastercard, Apple Pay чи Google Pay на захищеній сторінці LiqPay (ПриватБанк). Дані картки вводите на стороні LiqPay — ми їх не бачимо й не зберігаємо.',
       jsonb_build_object('list', 'Замовлення тримаємо за вами 10 хвилин до оплати' || chr(10) ||
                                  'Відправляємо в день оплати, якщо річ у наявності' || chr(10) ||
                                  'Повернення коштів — на ту саму картку'),
       0
 where not exists (select 1 from public.items where site_id = 106 and collection = 'payment' and title = 'Карткою на сайті');

insert into public.items (site_id, collection, title, text, extra, sort_order)
select 106, 'returns', 'Повернення коштів',
       'Не підійшла річ, а обміняти немає на що — повертаємо гроші протягом 7 днів після того, як річ приїде до нас.',
       jsonb_build_object('list', 'Оплату карткою — на ту саму картку через LiqPay' || chr(10) ||
                                  'Накладений платіж і готівку — переказом на вашу картку' || chr(10) ||
                                  'Доставку повернення речі належної якості оплачує покупець'),
       3
 where not exists (select 1 from public.items where site_id = 106 and collection = 'returns' and title = 'Повернення коштів');

update public.items
   set text = 'Карткою на сайті через LiqPay або накладеним платежем Нової Пошти — при отриманні. Для речей під запит — передоплата 50% за реквізитами в особистих, решта перед відправленням.'
 where id = 928 and site_id = 106;

-- Замовлення тепер приходять самі — пересилати текст у канал більше не треба
update public.items
   set text = 'Канал із дропами й цінами.'
 where id = 870 and site_id = 106 and text like '%надсилайте текст замовлення%';

-- ---------- 3) Реквізити продавця й пошта в адмінці ----------
update public.sites s
   set config = jsonb_set(
         jsonb_set(s.config, '{texts}', coalesce(s.config->'texts', '[]'::jsonb) || '[
           {"key": "email",          "name": "Контакти: електронна пошта підтримки"},
           {"key": "seller_name",    "name": "Продавець: ФОП, прізвище, імʼя та по батькові"},
           {"key": "seller_code",    "name": "Продавець: РНОКПП (ідентифікаційний код)"},
           {"key": "seller_address", "name": "Продавець: адреса", "multiline": true}
         ]'::jsonb),
         '{sections}',
         (select jsonb_agg(
                   case when e->>'name' = 'Контакти й підвал'
                        then jsonb_set(e, '{texts}', coalesce(e->'texts', '[]'::jsonb) ||
                                       '["email", "seller_name", "seller_code", "seller_address"]'::jsonb)
                        else e end
                   order by n)
            from jsonb_array_elements(s.config->'sections') with ordinality as t(e, n)))
 where s.id = 106
   and not (coalesce(s.config->'texts', '[]'::jsonb) @> '[{"key": "seller_name"}]'::jsonb);

insert into public.texts (site_id, key, value) values
  (106, 'email',          'justshop@example.com'),
  (106, 'seller_name',    'ФОП Прізвище Імʼя По батькові'),
  (106, 'seller_code',    '0000000000'),
  (106, 'seller_address', 'Україна, м. Київ, вул. Назва, 1')
on conflict (site_id, key) do nothing;

-- ---------- 4) Короткий опис для товарів без опису ----------
update public.items i
   set text = concat_ws(' ',
         case i.extra->>'cat'
           when 'vzuttia'    then 'Оригінальне взуття'
           when 'kurtky'     then 'Оригінальна куртка'
           when 'kofty'      then 'Оригінальна кофта'
           when 'kostiumy'   then 'Оригінальний костюм'
           when 'zhyletky'   then 'Оригінальна жилетка'
           when 'shtany'     then 'Оригінальні штани'
           when 'futbolky'   then 'Оригінальна футболка'
           when 'shorty'     then 'Оригінальні шорти'
           when 'shkarpetky' then 'Оригінальні шкарпетки'
           when 'aksesuary'  then 'Оригінальний аксесуар'
           else 'Оригінальна річ'
         end || coalesce(' ' || nullif(i.extra->>'brand', ''), '') || ' з Європи.',
         case when i.title ilike '%унісекс%' then 'Модель унісекс.'
              when i.extra->>'gender' = 'm' then 'Чоловіча модель.'
              when i.extra->>'gender' = 'w' then 'Жіноча модель.'
         end,
         case when coalesce(i.extra->>'sku', '') <> ''
              then 'Артикул ' || replace(i.extra->>'sku', '__', ' / ') || ' — за ним модель легко звірити на сайті бренду.'
         end,
         'Перед відправкою надсилаємо фото бірок, щоб ви переконалися в оригінальності.')
 where i.site_id = 106 and i.collection = 'products' and coalesce(i.text, '') = '';

-- Перевірка: товарів без опису чи без ціни має бути 0
select count(*) filter (where coalesce(text, '') = '')                  as "без опису",
       count(*) filter (where coalesce(nullif(price, ''), '0') = '0')   as "без ціни"
  from public.items where site_id = 106 and collection = 'products';
