-- ============================================================
--  МІГРАЦІЯ v6: Кінний двір «Лелеки» — редаговані банер «Кінні
--  прогулянки» (заголовок + текст) і картка «Не впевнені, який
--  обрати?» у блоці номерів.
--  Вміст сайту не чіпає. Запускати ОДИН раз. Безпечно перезапускати.
-- ============================================================

-- 1) Додаємо 4 нові текстові поля у конфіг (лише якщо їх ще нема)
update public.sites
set config = jsonb_set(config, '{texts}', (config->'texts') || '[
  {"key": "horses_title", "name": "Кінні прогулянки: заголовок банера"},
  {"key": "horses_text", "name": "Кінні прогулянки: текст банера", "multiline": true},
  {"key": "callus_title", "name": "Номери: картка з телефоном — заголовок"},
  {"key": "callus_text", "name": "Номери: картка з телефоном — текст", "multiline": true}
]'::jsonb)
where slug = 'leleki'
  and not (config->'texts') @> '[{"key": "horses_title"}]'::jsonb;

-- 2) Оновлюємо розділи: нові поля у «Номери та котеджі» і «Кінні прогулянки»
update public.sites
set config = config || '{
  "sections": [
    {
      "name": "Головний екран",
      "texts": ["hero_eyebrow", "hero_title", "hero_accent", "hero_sub", "stat_horses", "stat_pools", "check_in", "check_out", "marquee"],
      "photos": ["hero.jpg"]
    },
    {
      "name": "Про комплекс",
      "texts": ["about_title", "about_text"],
      "collections": ["about_points"],
      "photos": ["about.jpg"]
    },
    {
      "name": "Номери та котеджі",
      "texts": ["rooms_title", "callus_title", "callus_text"],
      "collections": ["room_cards"],
      "photos": ["room-standard.jpg", "room-family.jpg", "room-fireplace.jpg", "room-cottage.jpg", "room-lux.jpg"]
    },
    {
      "name": "Ціни на проживання",
      "texts": ["prices_title", "tourist_tax"],
      "collections": ["price_rows"]
    },
    {
      "name": "Басейни",
      "texts": ["pools_title", "pools_note"],
      "collections": ["pools"],
      "photos": ["pool-1.jpg", "pool-2.jpg"]
    },
    {
      "name": "Масаж",
      "texts": ["massage_title", "massage_note"],
      "collections": ["massage"]
    },
    {
      "name": "Галерея",
      "texts": ["gallery_title"],
      "collections": ["gallery"]
    },
    {
      "name": "Кінні прогулянки",
      "texts": ["horses_title", "horses_text", "horse_price"],
      "photos": ["horses.jpg"]
    },
    {
      "name": "Послуги",
      "texts": ["services_title", "services_note"],
      "collections": ["svc_live", "svc_day"]
    },
    {
      "name": "Умови та правила",
      "texts": ["rules_title"],
      "collections": ["rules"]
    },
    {
      "name": "Бронювання",
      "texts": ["booking_title", "booking_note"]
    },
    {
      "name": "Контакти",
      "texts": ["contacts_title", "phone", "address1", "address2", "distance", "insta_handle", "insta_url", "insta_rest_handle", "insta_rest_url", "insta_aqua_handle", "insta_aqua_url", "maps_url"]
    }
  ]
}'::jsonb
where slug = 'leleki';

-- 3) Початкові значення нових текстів (наявні не перезаписуємо)
insert into public.texts (site_id, key, value) values
  (2, 'horses_title', 'Понад 30 коней чекають на вас'),
  (2, 'horses_text', 'Верхова їзда — серце «Лелек». Прогулянки для дорослих і дітей, спокійні коні та інструктори поруч. Замовлення та оплата — у адміністратора.'),
  (2, 'callus_title', 'Не впевнені, який обрати?'),
  (2, 'callus_text', 'Зателефонуйте — підкажемо вільні дати та допоможемо з вибором номера.')
on conflict (site_id, key) do nothing;
