-- ============================================================
--  Just shop: поле «Артикул» у картці товару
--
--  Артикули потрапили в базу з імпорту таблиці, а руками вписати їх
--  не було де. Тим часом за артикулом:
--    • шукають товар у вкладці «Склад»;
--    • підбирається фото (файл зветься артикулом);
--    • товар звіряється з таблицею постачальника при імпорті.
--
--  Ставимо поле одразу після назви: назва → артикул → решта як була.
--  Наявні товари не змінюються, їхні артикули вже на місці.
-- ============================================================

update public.sites s
   set config = jsonb_set(config, '{collections}', (
     select jsonb_agg(
       case
         when c->>'key' = 'products'
          and not (c->'fields' @> '[{"key":"sku"}]'::jsonb)
         then jsonb_set(
                c,
                '{fields}',
                jsonb_build_array(c->'fields'->0)                 -- назва лишається першою
                || jsonb_build_array(jsonb_build_object(
                     'key', 'sku',
                     'name', 'Артикул',
                     'type', 'text',
                     'extra', true,
                     'hint', 'Код виробника з таблиці: HV0534-010. За ним шукається товар і підбирається фото'))
                || ((c->'fields') - 0))                           -- решта полів без першого
         else c end)
     from jsonb_array_elements(config->'collections') c))
 where s.slug = 'justshop';

-- Перевірка: поля картки товару по порядку
select f->>'key' as "поле", f->>'name' as "підпис"
  from public.sites s,
       jsonb_array_elements(s.config->'collections') c,
       jsonb_array_elements(c->'fields') f
 where s.slug = 'justshop' and c->>'key' = 'products';
