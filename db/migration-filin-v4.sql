-- ============================================================
--  «ФІЛІН» v4 — виправлення
--   • кілька фото на номер — прямо в картці номера (Фото 2, 3, 4),
--     а не окремим розділом
--   • прибрано розділ «Фото номерів» із v3 (він був зайвий)
--   • прибрано номери з назв вкладок: адмінка нумерує сама,
--     через це виходило «1. 1. Головний екран»
--  Вміст не втрачається.
--  Запускати ОДИН раз у SQL Editor. Безпечно перезапускати.
-- ============================================================

-- 1) Номери: додаємо поля «Фото 2/3/4» одразу після головного фото
update public.sites
set config = jsonb_set(
  config,
  '{collections}',
  (
    select jsonb_agg(
      case when c->>'key' = 'rooms'
        then jsonb_set(c, '{fields}', '[
          {"key": "title", "name": "Назва номера", "type": "text"},
          {"key": "text", "name": "Опис", "type": "textarea"},
          {"key": "price", "name": "Ціна за ніч (напр. від 750)", "type": "text"},
          {"key": "image_url", "name": "Головне фото", "type": "image"},
          {"key": "photo2", "name": "Фото 2", "type": "image", "extra": true},
          {"key": "photo3", "name": "Фото 3", "type": "image", "extra": true},
          {"key": "photo4", "name": "Фото 4", "type": "image", "extra": true},
          {"key": "cap", "name": "Скільки осіб (число)", "type": "text", "extra": true},
          {"key": "capw", "name": "Слово після числа (особа / особи)", "type": "text", "extra": true},
          {"key": "tags", "name": "Зручності через кому (Душ, Wi-Fi, ТВ)", "type": "text", "extra": true}
        ]'::jsonb)
        else c end
    )
    from jsonb_array_elements(config->'collections') c
  )
)
where slug = 'filin';

-- 2) Прибираємо зайвий розділ «Фото номерів» із конфіга
update public.sites
set config = jsonb_set(
  config,
  '{collections}',
  (
    select coalesce(jsonb_agg(c), '[]'::jsonb)
    from jsonb_array_elements(config->'collections') c
    where c->>'key' <> 'room_photos'
  )
)
where slug = 'filin';

-- 3) Розділ «Номери» знову містить лише номери й смугу переваг,
--    а з назв вкладок прибираємо власні номери
update public.sites
set config = jsonb_set(
  config,
  '{sections}',
  (
    select jsonb_agg(
      jsonb_set(
        jsonb_set(s, '{name}', to_jsonb(regexp_replace(s->>'name', '^\d+\.\s*', ''))),
        '{collections}',
        case when regexp_replace(s->>'name', '^\d+\.\s*', '') = 'Номери'
          then '["rooms","room_perks"]'::jsonb
          else coalesce(s->'collections', 'null'::jsonb) end
      )
    )
    from jsonb_array_elements(config->'sections') s
  )
)
where slug = 'filin';

-- 4) Прибираємо порожні ключі collections, якщо їх не було
update public.sites
set config = jsonb_set(
  config,
  '{sections}',
  (
    select jsonb_agg(
      case when s->'collections' = 'null'::jsonb then s - 'collections' else s end
    )
    from jsonb_array_elements(config->'sections') s
  )
)
where slug = 'filin';
