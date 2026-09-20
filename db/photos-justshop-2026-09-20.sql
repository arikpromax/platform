-- ============================================================
--  Just shop: фото товарів — 20.09.2026
--
--  Виконати один раз: Supabase → SQL Editor → Run.
--  Окрім фото, нічого не чіпає. Повторний запуск безпечний.
--
--  ЧАСТИНА 1. Прописати щойно додані картинки.
--    Файли вже лежать у теці сайту, лишилось указати їх у базі —
--    доки не вказано, товар стоїть без фото.
--
--  ЧАСТИНА 2. Поле «Ще фото» в картці товару.
--    Досі на товар було одне фото. Тепер під ним зʼявиться список,
--    куди можна докласти другий ракурс чи деталь — на сторінці
--    товару вони стануть квадратиками під головним фото.
-- ============================================================

-- ---------- ЧАСТИНА 1: 4 фото ----------

update public.items i
   set image_url = v.url
  from (values
    (988, 'https://arikpromax.github.io/justshop/img/p/FV7400-010.webp'),   -- Худі унісекс Sb Skate Fleece Pullover Ho
    (938, 'https://arikpromax.github.io/justshop/img/p/HQ4181-113.webp'),   -- Світшот Solo Swoosh Жовтий Regular Fit
    (936, 'https://arikpromax.github.io/justshop/img/p/IB3082-001.webp'),   -- Кросівки чоловічі Gato
    (1456, 'https://arikpromax.github.io/justshop/img/p/IB5673-104.webp')   -- Футболка X NOCTA MEN'S T-SHIRT
) as v(id, url)
 where i.id = v.id
   and i.site_id = 106
   and coalesce(i.image_url, '') = '';

-- ---------- ЧАСТИНА 2: поле «Ще фото» ----------
-- «Фото» стоїть у картці останнім, тож нове поле дописуємо в кінець —
-- воно опиниться одразу під ним.

update public.sites s
   set config = jsonb_set(config, '{collections}', (
     select jsonb_agg(
       case
         when c->>'key' = 'products'
          and not (c->'fields' @> '[{"key":"photos"}]'::jsonb)
         then jsonb_set(c, '{fields}',
                (c->'fields') || jsonb_build_array(jsonb_build_object(
                  'type',  'images',
                  'key',   'photos',
                  'name',  'Ще фото',
                  'extra', true,
                  'hint',  'Другий ракурс, деталь тканини, бірка, коробка. У картці товару вони стануть квадратиками під головним фото — покупець клікає й дивиться. Головним лишається фото вище, саме воно йде на плитку в каталозі.')))
         else c
       end)
     from jsonb_array_elements(config->'collections') c))
 where s.slug = 'justshop';

-- ---------- Перевірка ----------

select count(*) filter (where coalesce(image_url, '') <> '') as "товарів із фото",
       count(*)                                              as "усього"
  from public.items where site_id = 106 and collection = 'products';

select f->>'key' as "поле", f->>'name' as "підпис"
  from public.sites s,
       jsonb_array_elements(s.config->'collections') c,
       jsonb_array_elements(c->'fields') f
 where s.slug = 'justshop' and c->>'key' = 'products';
