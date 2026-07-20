-- ============================================================
--  SUSHI SHARK: додати вибір «Позиція фото» (коли фото розтягнуте)
--  Оновлює ТІЛЬКИ конфіг. Запускати у SQL Editor проєкту platform
-- ============================================================

update public.sites
set config = jsonb_set(
  config,
  '{collections,0,fields}',
  (config #> '{collections,0,fields}') || '[
    {
      "key": "pos",
      "name": "Позиція фото (коли розтягнуте)",
      "type": "select",
      "extra": true,
      "options": [
        {"value": "", "label": "Центр (за замовчуванням)"},
        {"value": "center top", "label": "Верх"},
        {"value": "center bottom", "label": "Низ"},
        {"value": "left center", "label": "Ліворуч"},
        {"value": "right center", "label": "Праворуч"},
        {"value": "50% 35%", "label": "Трохи вище центру"},
        {"value": "50% 65%", "label": "Трохи нижче центру"}
      ]
    }
  ]'::jsonb
)
where slug = 'sushishark';
