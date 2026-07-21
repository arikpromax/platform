-- ============================================================
--  SUSHI SHARK: обмеження керувань за роллю
--   • «Категорії» — бачить лише власник платформи (admin), клієнт не бачить.
--     Навіть admin не може додати/видалити категорію (жорстко звʼязані з кодом сайту).
--   • «Режим роботи» — клієнт може вмикати «Вихідний», але не додавати/видаляти картки.
--  Оновлює ТІЛЬКИ конфіг. Запускати у SQL Editor проєкту platform
-- ============================================================

update public.sites
set config = jsonb_set(
  config,
  '{collections}',
  (
    select jsonb_agg(
      case
        when c ->> 'key' = 'cats'
          then c || '{"adminOnly": true, "noAdd": true, "noDelete": true}'::jsonb
        when c ->> 'key' = 'settings'
          then c || '{"noAdd": true, "noDelete": true}'::jsonb
        else c
      end
    )
    from jsonb_array_elements(config #> '{collections}') c
  )
)
where slug = 'sushishark';
