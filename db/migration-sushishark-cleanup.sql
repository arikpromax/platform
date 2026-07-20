-- ============================================================
--  SUSHI SHARK: прибрати старі поля «Розтягнути фото» і «Позиція фото»
--  Тепер фото кадрується панеллю обрізки — ці поля не потрібні.
--  Оновлює ТІЛЬКИ конфіг. Запускати у SQL Editor проєкту platform
-- ============================================================

update public.sites
set config = jsonb_set(
  config,
  '{collections,0,fields}',
  (
    select jsonb_agg(f)
    from jsonb_array_elements(config #> '{collections,0,fields}') f
    where f ->> 'key' not in ('fill', 'pos')
  )
)
where slug = 'sushishark';
