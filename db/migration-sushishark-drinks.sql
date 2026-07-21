-- ============================================================
--  SUSHI SHARK: поле «Безкоштовних напоїв» для кожної позиції
--  0 — напоїв нема; 1/2/3 — сайт спитає стільки напоїв при додаванні в кошик.
--  Запускати у SQL Editor проєкту platform
-- ============================================================

-- 1) Додаємо поле-вибір у форму меню
update public.sites
set config = jsonb_set(
  config,
  '{collections,0,fields}',
  (config #> '{collections,0,fields}') || '[
    {
      "key": "drinks",
      "name": "Безкоштовних напоїв (для сетів)",
      "type": "select",
      "extra": true,
      "options": [
        {"value": "", "label": "Немає"},
        {"value": "1", "label": "1 напій"},
        {"value": "2", "label": "2 напої"},
        {"value": "3", "label": "3 напої"},
        {"value": "4", "label": "4 напої"}
      ]
    }
  ]'::jsonb
)
where slug = 'sushishark';

-- 2) Липневому сету (промо) ставимо 2 безкоштовні напої — як було
update public.items
set extra = extra || '{"drinks":"2"}'::jsonb
where site_id = 3 and collection = 'menu' and (extra ->> 'promo') = 'true';
