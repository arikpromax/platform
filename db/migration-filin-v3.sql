-- ============================================================
--  «ФІЛІН» v3 — кілька фото на один номер
--  Додає колекцію «Фото номерів»: скільки завгодно знімків,
--  кожен привʼязаний до свого номера. Вони показуються в перегляді,
--  який відкривається кліком по рядку номера на сайті.
--  Запускати ОДИН раз у SQL Editor. Безпечно перезапускати.
-- ============================================================

-- 1) Нова колекція (додаємо, якщо ще нема)
update public.sites
set config = jsonb_set(config, '{collections}', (config->'collections') || '[
  {
    "key": "room_photos",
    "name": "Фото номерів",
    "fields": [
      {"key": "image_url", "name": "Фото", "type": "image"},
      {"key": "room", "name": "До якого номера", "type": "select-collection", "from": "rooms", "extra": true},
      {"key": "title", "name": "Підпис, необовʼязково", "type": "text"}
    ]
  }
]'::jsonb)
where slug = 'filin'
  and not (config->'collections') @> '[{"key": "room_photos"}]'::jsonb;

-- 2) Показуємо її в розділі «Номери», одразу після самих номерів
update public.sites
set config = jsonb_set(
  config,
  '{sections}',
  (
    select jsonb_agg(
      case
        when s->>'name' = 'Номери'
          then jsonb_set(s, '{collections}', '["rooms","room_photos","room_perks"]'::jsonb)
        else s
      end
    )
    from jsonb_array_elements(config->'sections') s
  )
)
where slug = 'filin';
