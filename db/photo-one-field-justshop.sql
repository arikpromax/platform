-- ============================================================
--  Just shop: одне поле «Фото» замість двох
--
--  Виконати один раз: Supabase → SQL Editor → Run.
--  Повторний запуск безпечний.
--
--  Було два поля: «Фото» на один знімок і «Ще фото» на решту.
--  Власник питав, яке з них головне, і де додавати наступне.
--  Тепер одне: перше фото в списку і є головним, решта йдуть
--  на сторінку товару. Порядок міняється стрілками, тож
--  зробити головним інший кадр — це посунути його на початок.
--
--  ЧАСТИНА 1. Перенести наявне головне фото на початок списку.
--  ЧАСТИНА 2. Прибрати окреме поле й перейменувати список.
-- ============================================================

-- ---------- ЧАСТИНА 1: фото ----------

-- головне фото стає першим у списку (якщо його там ще нема)
update public.items i
   set extra = jsonb_set(
         coalesce(i.extra, '{}'::jsonb),
         '{photos}',
         to_jsonb(i.image_url) || coalesce(i.extra->'photos', '[]'::jsonb))
 where i.site_id = 106
   and i.collection = 'products'
   and coalesce(i.image_url, '') <> ''
   and not (coalesce(i.extra->'photos', '[]'::jsonb) @> to_jsonb(i.image_url));

-- окреме поле головного фото більше не потрібне
update public.items
   set image_url = ''
 where site_id = 106
   and collection = 'products'
   and coalesce(image_url, '') <> '';

-- ---------- ЧАСТИНА 2: картка товару ----------

update public.sites s
   set config = jsonb_set(config, '{collections}', (
     select jsonb_agg(
       case
         when c->>'key' = 'products'
         then jsonb_set(c, '{fields}', (
                select coalesce(jsonb_agg(
                         case
                           when f->>'key' = 'photos'
                           then f || jsonb_build_object(
                                  'name', 'Фото',
                                  'hint', 'Перше фото — головне: саме воно стоїть на плитці в каталозі. Решта показуються на сторінці товару квадратиками під ним, покупець їх гортає. Щоб зробити головним інший кадр, посуньте його на початок стрілками.')
                           else f
                         end), '[]'::jsonb)
                  from jsonb_array_elements(c->'fields') f
                 where f->>'key' <> 'image'))
         else c
       end)
     from jsonb_array_elements(config->'collections') c))
 where s.slug = 'justshop';

-- ---------- Перевірка ----------

-- усі фото мають лежати в списку, окреме поле — порожнє
select count(*) filter (where coalesce(image_url, '') <> '')                      as "лишилось в окремому полі",
       count(*) filter (where jsonb_array_length(coalesce(extra->'photos', '[]'::jsonb)) > 0) as "товарів із фото",
       count(*)                                                                    as "усього"
  from public.items where site_id = 106 and collection = 'products';

-- поля картки товару по порядку
select f->>'key' as "поле", f->>'name' as "підпис", f->>'type' as "тип"
  from public.sites s,
       jsonb_array_elements(s.config->'collections') c,
       jsonb_array_elements(c->'fields') f
 where s.slug = 'justshop' and c->>'key' = 'products';
