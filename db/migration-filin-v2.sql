-- ============================================================
--  «ФІЛІН» v2 — адмінка стає простішою
--   • прибрано технічні поля, які власник ніколи не змінює
--     (латинські ключі, службові посилання)
--   • прибрано написи на кнопках і назви, які не змінюються
--   • ціни номерів більше не містять ₴ (адмінка сама дописує «грн»,
--     сайт сам дописує «₴» — раніше виходило «від 600 ₴ грн»)
--  Вміст НЕ втрачається: старі значення лишаються в базі,
--  вони просто більше не показуються в адмінці.
--  Запускати ОДИН раз у SQL Editor. Безпечно перезапускати.
-- ============================================================

-- 1) Ціни номерів: прибрати ₴ (адмінка й сайт дописують валюту самі)
update public.items
set price = btrim(replace(replace(price, '₴', ''), '  ', ' '))
where site_id = 4 and collection = 'rooms' and price like '%₴%';

-- 2) Новий, коротший конфіг адмінки
update public.sites set config = '{
  "collections": [
    {
      "key": "about_cards",
      "name": "Три картки під заголовком",
      "fields": [
        {"key": "title", "name": "Заголовок (напр. Мотель)", "type": "text"},
        {"key": "text", "name": "Опис", "type": "textarea"},
        {"key": "icon", "name": "Значок", "type": "select", "extra": true,
         "options": [
           {"value": "bed", "label": "Ліжко"},
           {"value": "steam", "label": "Пара"},
           {"value": "car", "label": "Авто"},
           {"value": "wifi", "label": "Wi-Fi"},
           {"value": "shower", "label": "Душ"},
           {"value": "key", "label": "Ключ"},
           {"value": "fork", "label": "Виделка"}
         ]}
      ]
    },
    {
      "key": "rooms",
      "name": "Номери",
      "fields": [
        {"key": "title", "name": "Назва номера", "type": "text"},
        {"key": "text", "name": "Опис", "type": "textarea"},
        {"key": "price", "name": "Ціна за ніч (напр. від 750)", "type": "text"},
        {"key": "image_url", "name": "Фото номера", "type": "image"},
        {"key": "cap", "name": "Скільки осіб (число)", "type": "text", "extra": true},
        {"key": "capw", "name": "Слово після числа (особа / особи)", "type": "text", "extra": true},
        {"key": "tags", "name": "Зручності через кому (Душ, Wi-Fi, ТВ)", "type": "text", "extra": true}
      ]
    },
    {
      "key": "room_perks",
      "name": "Смуга переваг під номерами",
      "fields": [
        {"key": "title", "name": "Текст (напр. Безкоштовний Wi-Fi)", "type": "text"},
        {"key": "icon", "name": "Значок", "type": "select", "extra": true,
         "options": [
           {"value": "wifi", "label": "Wi-Fi"},
           {"value": "shower", "label": "Душ"},
           {"value": "car", "label": "Парковка"},
           {"value": "key", "label": "Ключ"},
           {"value": "fork", "label": "Виделка"},
           {"value": "bed", "label": "Ліжко"},
           {"value": "steam", "label": "Пара"}
         ]}
      ]
    },
    {
      "key": "sauna_perks",
      "name": "Позначки сауни",
      "fields": [
        {"key": "title", "name": "Текст (напр. Кімната відпочинку)", "type": "text"}
      ]
    },
    {
      "key": "gallery",
      "name": "Стрічка фото «Як у нас»",
      "fields": [
        {"key": "image_url", "name": "Фото", "type": "image"},
        {"key": "title", "name": "Підпис під фото", "type": "text"}
      ]
    },
    {
      "key": "hours",
      "name": "Графік у контактах",
      "fields": [
        {"key": "title", "name": "Назва рядка (напр. Рецепція)", "type": "text"},
        {"key": "text", "name": "Значення (напр. 07:00 – 23:00)", "type": "text"}
      ]
    },
    {
      "key": "menu_cats",
      "name": "Розділи меню",
      "fields": [
        {"key": "title", "name": "Назва розділу (напр. Перші страви)", "type": "text"},
        {"key": "note", "name": "Підпис праворуч, необовʼязково (напр. 07:00 – 11:00)", "type": "text", "extra": true}
      ]
    },
    {
      "key": "menu_items",
      "name": "Страви",
      "fields": [
        {"key": "image_url", "name": "Фото страви", "type": "image"},
        {"key": "title", "name": "Назва страви", "type": "text"},
        {"key": "text", "name": "Короткий опис", "type": "textarea"},
        {"key": "price", "name": "Ціна, лише число (напр. 110)", "type": "text"},
        {"key": "cat", "name": "У якому розділі меню", "type": "select-collection", "from": "menu_cats", "extra": true},
        {"key": "weight", "name": "Вага або обʼєм (напр. 350 г)", "type": "text", "extra": true},
        {"key": "tag", "name": "Позначка", "type": "select", "extra": true,
         "options": [
           {"value": "", "label": "— без позначки —"},
           {"value": "хіт", "label": "хіт"},
           {"value": "нове", "label": "нове"},
           {"value": "гостро", "label": "гостро"},
           {"value": "пост", "label": "пісне"}
         ]}
      ]
    },
    {
      "key": "kitchen_facts",
      "name": "Чотири факти про кухню",
      "fields": [
        {"key": "title", "name": "Велике значення (напр. 07:00)", "type": "text"},
        {"key": "text", "name": "Підпис під ним (напр. Відчиняємось)", "type": "text"}
      ]
    },
    {
      "key": "site_photos",
      "name": "Фото сайту",
      "noAdd": true,
      "noDelete": true,
      "fields": [
        {"key": "title", "name": "Де це фото", "type": "text"},
        {"key": "image_url", "name": "Фото", "type": "image"}
      ]
    }
  ],

  "texts": [
    {"key": "hero_title_1", "name": "Заголовок, перший рядок"},
    {"key": "hero_title_2", "name": "Заголовок, другий рядок (курсивом)"},
    {"key": "hero_sub_strong", "name": "Підзаголовок: перші слова жирним"},
    {"key": "hero_sub", "name": "Підзаголовок: далі", "multiline": true},
    {"key": "open_time", "name": "О котрій відчиняєтесь (напр. 07:00)"},
    {"key": "close_time", "name": "О котрій зачиняєтесь (напр. 23:00)"},
    {"key": "phone1", "name": "Телефон 1"},
    {"key": "phone2", "name": "Телефон 2"},

    {"key": "about_title_1", "name": "Заголовок, перший рядок"},
    {"key": "about_title_2", "name": "Заголовок, другий рядок (курсивом)"},
    {"key": "about_text", "name": "Текст під заголовком", "multiline": true},

    {"key": "rooms_title", "name": "Заголовок розділу"},
    {"key": "rooms_text", "name": "Текст під заголовком", "multiline": true},

    {"key": "sauna_title_1", "name": "Заголовок розділу"},
    {"key": "sauna_text", "name": "Текст про сауну", "multiline": true},

    {"key": "photos_title", "name": "Заголовок розділу"},
    {"key": "photos_text", "name": "Текст під заголовком"},

    {"key": "book_title", "name": "Заголовок розділу"},
    {"key": "book_text", "name": "Текст під заголовком", "multiline": true},
    {"key": "book_hint", "name": "Примітка під формою", "multiline": true},

    {"key": "cafe_title_1", "name": "Заголовок банера, початок"},
    {"key": "cafe_title_2", "name": "Заголовок банера, курсивом"},
    {"key": "cafe_text", "name": "Текст банера", "multiline": true},

    {"key": "contact_title_1", "name": "Заголовок, перший рядок"},
    {"key": "contact_title_2", "name": "Заголовок, другий рядок (курсивом)"},
    {"key": "contact_note", "name": "Текст під телефонами", "multiline": true},
    {"key": "map_link", "name": "Посилання на карту"},
    {"key": "ig_link", "name": "Посилання на Instagram"},
    {"key": "footer_text", "name": "Опис закладу в підвалі", "multiline": true},

    {"key": "note_title", "name": "Заголовок блока «Кілька слів»"},
    {"key": "note_text", "name": "Текст блока «Кілька слів»", "multiline": true},
    {"key": "cafe_footer_note", "name": "Адреса в підвалі меню"}
  ],

  "sections": [
    {
      "name": "1. Головний екран",
      "texts": ["hero_title_1", "hero_title_2", "hero_sub_strong", "hero_sub",
                "open_time", "close_time", "phone1", "phone2"],
      "photos": ["hero.jpg"]
    },
    {
      "name": "2. Про нас",
      "texts": ["about_title_1", "about_title_2", "about_text"],
      "collections": ["about_cards"]
    },
    {
      "name": "3. Номери",
      "texts": ["rooms_title", "rooms_text"],
      "collections": ["rooms", "room_perks"]
    },
    {
      "name": "4. Сауна",
      "texts": ["sauna_title_1", "sauna_text"],
      "collections": ["sauna_perks"],
      "photos": ["sauna.jpg"]
    },
    {
      "name": "5. Фото",
      "texts": ["photos_title", "photos_text"],
      "collections": ["gallery"]
    },
    {
      "name": "6. Бронювання",
      "texts": ["book_title", "book_text", "book_hint"]
    },
    {
      "name": "7. Банер кафе",
      "texts": ["cafe_title_1", "cafe_title_2", "cafe_text"]
    },
    {
      "name": "8. Контакти",
      "texts": ["contact_title_1", "contact_title_2", "contact_note",
                "map_link", "ig_link", "footer_text"],
      "collections": ["hours"]
    },
    {
      "name": "9. Меню кухні",
      "collections": ["menu_cats", "menu_items"]
    },
    {
      "name": "10. Про кухню",
      "texts": ["note_title", "note_text", "cafe_footer_note"],
      "collections": ["kitchen_facts"]
    }
  ]
}'::jsonb
where slug = 'filin';
