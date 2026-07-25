-- ============================================================
--  МІГРАЦІЯ v6: Кінний двір «Лелеки» — редагується ЗОВСІМ усе
--  Додає в адмінку те, що лишалось «зашитим» у сайті:
--   • банер «Кінні прогулянки»: заголовок і текст
--   • картка з телефоном у блоці номерів
--   • басейни: підзаголовки + список «Що варто знати» (нова вкладка)
--   • послуги: заголовки колонок «Для проживаючих» / «Без поселення»
--  Вміст, який ви вже редагували, не чіпає.
--  Запускати ОДИН раз у SQL Editor. Безпечно перезапускати.
-- ============================================================

-- 1) Нова колекція «Басейни — що варто знати» (додаємо, якщо ще нема)
update public.sites
set config = jsonb_set(config, '{collections}', (config->'collections') || '[
  {
    "key": "pools_info",
    "name": "Басейни — що варто знати",
    "fields": [
      {"key": "title", "name": "Пункт списку", "type": "textarea"}
    ]
  }
]'::jsonb)
where slug = 'leleki'
  and not (config->'collections') @> '[{"key": "pools_info"}]'::jsonb;

-- 2) Нові текстові поля (додаємо, якщо ще нема)
update public.sites
set config = jsonb_set(config, '{texts}', (config->'texts') || '[
  {"key": "horses_title", "name": "Кінні прогулянки: заголовок банера"},
  {"key": "horses_text", "name": "Кінні прогулянки: текст банера", "multiline": true},
  {"key": "callus_title", "name": "Номери: картка з телефоном — заголовок"},
  {"key": "callus_text", "name": "Номери: картка з телефоном — текст", "multiline": true},
  {"key": "pools_price_title", "name": "Басейни: заголовок «Вартість відвідування»"},
  {"key": "pools_price_sub", "name": "Басейни: підпис під ним (напр. Денне перебування · 9:00-20:00)"},
  {"key": "pools_info_title", "name": "Басейни: заголовок «Що варто знати»"},
  {"key": "pools_info_note", "name": "Басейни: примітка внизу блока", "multiline": true},
  {"key": "svc_live_title", "name": "Послуги: заголовок 1-ї колонки (Для проживаючих)"},
  {"key": "svc_live_sub", "name": "Послуги: підпис 1-ї колонки"},
  {"key": "svc_day_title", "name": "Послуги: заголовок 2-ї колонки (Без поселення)"},
  {"key": "svc_day_sub", "name": "Послуги: підпис 2-ї колонки"}
]'::jsonb)
where slug = 'leleki'
  and not (config->'texts') @> '[{"key": "horses_title"}]'::jsonb;

-- 3) Розділи адмінки з новими полями
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
      "texts": ["pools_title", "pools_note", "pools_price_title", "pools_price_sub", "pools_info_title", "pools_info_note"],
      "collections": ["pools", "pools_info"],
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
      "texts": ["services_title", "services_note", "svc_live_title", "svc_live_sub", "svc_day_title", "svc_day_sub"],
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

-- 4) Список «Басейни — що варто знати» (лише якщо ще порожній)
insert into public.items (site_id, collection, title, sort_order)
select 2, 'pools_info', v.title, v.ord
from (values
  ('Два басейни: великий з дитячими гірками та менший із соленою водою', 1),
  ('У вартість входить користування шезлонгом і рушником', 2),
  ('Для денного перебування рушник надається під заставу 1 000 грн', 3),
  ('Індивідуальне відвідування — за попереднім бронюванням', 4)
) as v(title, ord)
where not exists (
  select 1 from public.items where site_id = 2 and collection = 'pools_info'
);

-- 5) Початкові значення нових текстів (наявні НЕ перезаписуємо)
insert into public.texts (site_id, key, value) values
  (2, 'horses_title', 'Понад 30 коней чекають на вас'),
  (2, 'horses_text', 'Верхова їзда — серце «Лелек». Прогулянки для дорослих і дітей, спокійні коні та інструктори поруч. Замовлення та оплата — у адміністратора.'),
  (2, 'callus_title', 'Не впевнені, який обрати?'),
  (2, 'callus_text', 'Зателефонуйте — підкажемо вільні дати та допоможемо з вибором номера.'),
  (2, 'pools_price_title', 'Вартість відвідування'),
  (2, 'pools_price_sub', 'Денне перебування · 9:00–20:00'),
  (2, 'pools_info_title', 'Що варто знати'),
  (2, 'pools_info_note', 'Для проживаючих гостей відвідування басейнів — за розкладом комплексу. Уточнюйте деталі в адміністратора.'),
  (2, 'svc_live_title', 'Для проживаючих'),
  (2, 'svc_live_sub', 'Додатково до вартості номера'),
  (2, 'svc_day_title', 'Без поселення'),
  (2, 'svc_day_sub', 'Відпочинок на день · 8:00–22:00')
on conflict (site_id, key) do nothing;
