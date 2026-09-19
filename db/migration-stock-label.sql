-- ============================================================
--  Just shop: підпис галочки в картці товару
--
--  Поки складу не було, галочка звалась «Є в наявності» — і тепер
--  виглядає як друга відповідь на те саме питання, що й залишки.
--  Насправді вона означає інше: рахувати товар за складом чи завжди
--  показувати його «під запит». Міняємо тільки підпис і пояснення,
--  значення в товарах лишаються як були.
-- ============================================================

update public.sites s
   set config = jsonb_set(config, '{collections}', (
     select jsonb_agg(
       case when c->>'key' = 'products'
         then jsonb_set(c, '{fields}', (
           select jsonb_agg(
             case when f->>'key' = 'stock'
               then f || jsonb_build_object(
                      'name', 'Рахувати за складом',
                      'hint', 'Знято — товар завжди показується як «під запит», скільки б не лежало на складі')
               else f end)
           from jsonb_array_elements(c->'fields') f))
         else c end)
     from jsonb_array_elements(config->'collections') c))
 where s.slug = 'justshop';

-- Перевірка: має вивести новий підпис
select f->>'name' as "підпис", f->>'hint' as "пояснення"
  from public.sites s,
       jsonb_array_elements(s.config->'collections') c,
       jsonb_array_elements(c->'fields') f
 where s.slug = 'justshop' and c->>'key' = 'products' and f->>'key' = 'stock';
