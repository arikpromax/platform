-- ============================================================
--  МІГРАЦІЯ v4: Кінний двір «Лелеки» — адмінка «розділи як на сайті»
--  Вкладки адмінки тепер = блоки сайту ПО ПОРЯДКУ (1. Головний екран,
--  2. Про комплекс, 3. Номери…), і всередині кожної — ВСЕ своє:
--  тексти блока, списки блока та фото блока.
--  ВИМОГА: спершу має бути виконана міграція v3.
--  Нічого не видаляє і не перезаписує, лише додає ключ "sections" у конфіг.
--  Запускати ОДИН раз у SQL Editor. Безпечно перезапускати.
-- ============================================================

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
      "collections": ["about_points", "included"],
      "photos": ["about.jpg"]
    },
    {
      "name": "Номери та котеджі",
      "texts": ["rooms_title"],
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
      "texts": ["horse_price"],
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
