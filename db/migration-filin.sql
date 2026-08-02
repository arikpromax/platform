-- ============================================================
--  «ФІЛІН» (Кобеляки) — мотель, сауна і кухня. Сайт №4.
--  Реєструє сайт у платформі та наповнює адмінку поточним вмістом.
--  Розділи адмінки повторюють блоки сайту зверху вниз.
--  Запускати ОДИН раз у SQL Editor проєкту platform. Безпечно перезапускати:
--  тексти й списки, які власник уже редагував, не перезаписуються.
-- ============================================================

insert into public.sites (id, slug, name, paid_until, config) values (
  4,
  'filin',
  '«Філін» — мотель, сауна, кухня',
  current_date + 30,
  '{
    "collections": [
      {
        "key": "about_cards",
        "name": "Про нас — три картки",
        "fields": [
          {"key": "title", "name": "Заголовок (напр. Мотель)", "type": "text"},
          {"key": "text", "name": "Опис", "type": "textarea"},
          {"key": "icon", "name": "Іконка", "type": "select", "extra": true,
           "options": [
             {"value": "bed", "label": "Ліжко"},
             {"value": "steam", "label": "Пара (сауна)"},
             {"value": "car", "label": "Авто"},
             {"value": "wifi", "label": "Wi-Fi"},
             {"value": "shower", "label": "Душ"},
             {"value": "key", "label": "Ключ"},
             {"value": "fork", "label": "Кухня"}
           ]},
          {"key": "link", "name": "Посилання «Детальніше» (напр. #rooms, лишіть пустим — не показувати)", "type": "text", "extra": true}
        ]
      },
      {
        "key": "rooms",
        "name": "Номери",
        "fields": [
          {"key": "title", "name": "Назва (напр. Двомісний)", "type": "text"},
          {"key": "text", "name": "Опис", "type": "textarea"},
          {"key": "price", "name": "Ціна (напр. від 750 ₴)", "type": "text"},
          {"key": "image_url", "name": "Фото номера", "type": "image"},
          {"key": "cap", "name": "Скільки осіб (напр. 2)", "type": "text", "extra": true},
          {"key": "capw", "name": "Слово після числа (особа / особи)", "type": "text", "extra": true},
          {"key": "per", "name": "Підпис під ціною (напр. за ніч)", "type": "text", "extra": true},
          {"key": "tags", "name": "Зручності через кому (Душ, Wi-Fi, ТВ)", "type": "text", "extra": true},
          {"key": "kind", "name": "Ключ для форми бронювання (латиницею: single / double / family)", "type": "text", "extra": true}
        ]
      },
      {
        "key": "room_perks",
        "name": "Номери — смуга переваг",
        "fields": [
          {"key": "title", "name": "Текст (напр. Безкоштовний Wi-Fi)", "type": "text"},
          {"key": "icon", "name": "Іконка", "type": "select", "extra": true,
           "options": [
             {"value": "wifi", "label": "Wi-Fi"},
             {"value": "shower", "label": "Душ"},
             {"value": "car", "label": "Парковка"},
             {"value": "key", "label": "Ключ (заселення)"},
             {"value": "fork", "label": "Кухня"},
             {"value": "bed", "label": "Ліжко"},
             {"value": "steam", "label": "Сауна"}
           ]}
        ]
      },
      {
        "key": "sauna_perks",
        "name": "Сауна — позначки",
        "fields": [
          {"key": "title", "name": "Текст (напр. Кімната відпочинку)", "type": "text"}
        ]
      },
      {
        "key": "gallery",
        "name": "Фото — стрічка «Як у нас»",
        "fields": [
          {"key": "title", "name": "Підпис під фото", "type": "text"},
          {"key": "image_url", "name": "Фото", "type": "image"}
        ]
      },
      {
        "key": "hours",
        "name": "Контакти — графік",
        "fields": [
          {"key": "title", "name": "Назва рядка (напр. Рецепція)", "type": "text"},
          {"key": "text", "name": "Значення (напр. 07:00 – 23:00)", "type": "text"}
        ]
      },
      {
        "key": "menu_cats",
        "name": "Кухня — розділи меню",
        "fields": [
          {"key": "title", "name": "Назва розділу (напр. Перші страви)", "type": "text"},
          {"key": "key", "name": "Ключ латиницею (напр. soup) — має бути унікальним", "type": "text", "extra": true},
          {"key": "note", "name": "Підпис праворуч (напр. 07:00 – 11:00)", "type": "text", "extra": true}
        ]
      },
      {
        "key": "menu_items",
        "name": "Кухня — страви",
        "fields": [
          {"key": "title", "name": "Назва страви", "type": "text"},
          {"key": "text", "name": "Короткий опис", "type": "textarea"},
          {"key": "price", "name": "Ціна, лише число (напр. 110)", "type": "text"},
          {"key": "image_url", "name": "Фото страви", "type": "image"},
          {"key": "cat", "name": "Розділ меню", "type": "select-collection", "from": "menu_cats", "extra": true},
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
        "name": "Кухня — чотири факти",
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
      {"key": "brand_sub", "name": "Рейка збоку: підпис (МОТЕЛЬ · САУНА — КОБЕЛЯКИ, ПОЛТАВЩИНА)"},
      {"key": "hero_title_1", "name": "Головний екран: заголовок, рядок 1"},
      {"key": "hero_title_2", "name": "Головний екран: заголовок, рядок 2 (курсивом)"},
      {"key": "hero_sub_strong", "name": "Головний екран: початок підзаголовка (жирним)"},
      {"key": "hero_sub", "name": "Головний екран: підзаголовок", "multiline": true},
      {"key": "open_time", "name": "Години роботи: відкриття (напр. 07:00) — керує статусом «Відчинено»"},
      {"key": "close_time", "name": "Години роботи: закриття (напр. 23:00) — керує зворотним відліком"},
      {"key": "phone1", "name": "Телефон 1"},
      {"key": "phone2", "name": "Телефон 2"},
      {"key": "btn_book", "name": "Головний екран: напис на кнопці бронювання"},
      {"key": "hero_foot_1", "name": "Головний екран: рядок унизу, ліворуч"},
      {"key": "hero_foot_cafe", "name": "Головний екран: рядок унизу, посилання на кухню"},
      {"key": "hero_foot_rooms", "name": "Головний екран: рядок унизу, праворуч"},

      {"key": "about_title_1", "name": "Про нас: заголовок, рядок 1"},
      {"key": "about_title_2", "name": "Про нас: заголовок, рядок 2 (курсивом)"},
      {"key": "about_text", "name": "Про нас: текст", "multiline": true},

      {"key": "rooms_title", "name": "Номери: заголовок"},
      {"key": "rooms_text", "name": "Номери: текст під заголовком", "multiline": true},
      {"key": "room_btn", "name": "Номери: напис на кнопці в рядку номера"},

      {"key": "sauna_title_1", "name": "Сауна: заголовок, рядок 1"},
      {"key": "sauna_title_2", "name": "Сауна: заголовок, рядок 2 (курсивом)"},
      {"key": "sauna_text", "name": "Сауна: текст", "multiline": true},
      {"key": "sauna_btn", "name": "Сауна: напис на кнопці"},

      {"key": "photos_title", "name": "Фото: заголовок"},
      {"key": "photos_text", "name": "Фото: текст під заголовком"},

      {"key": "book_title", "name": "Бронювання: заголовок"},
      {"key": "book_text", "name": "Бронювання: текст під заголовком", "multiline": true},
      {"key": "book_hint", "name": "Бронювання: примітка під формою", "multiline": true},

      {"key": "cafe_title_1", "name": "Банер кафе: заголовок, початок"},
      {"key": "cafe_title_2", "name": "Банер кафе: заголовок, курсивом"},
      {"key": "cafe_text", "name": "Банер кафе: текст", "multiline": true},
      {"key": "cafe_btn", "name": "Банер кафе: напис на кнопці"},

      {"key": "contact_title_1", "name": "Контакти: заголовок, рядок 1"},
      {"key": "contact_title_2", "name": "Контакти: заголовок, рядок 2 (курсивом)"},
      {"key": "contact_note", "name": "Контакти: текст під телефонами", "multiline": true},
      {"key": "map_link", "name": "Контакти: посилання на карту (Google Maps)"},
      {"key": "ig_link", "name": "Посилання на Instagram"},
      {"key": "ig_label", "name": "Підпис Instagram (напр. @cafe__filin__)"},
      {"key": "footer_text", "name": "Підвал: опис закладу", "multiline": true},
      {"key": "footer_copy", "name": "Підвал: рядок копірайту"},

      {"key": "cafe_brand", "name": "Кухня: назва в шапці (КУХНЯ ФІЛІН)"},
      {"key": "cafe_brand_sub", "name": "Кухня: підпис у шапці"},
      {"key": "menu_title", "name": "Кухня: заголовок сторінки (Меню)"},
      {"key": "menu_title_em", "name": "Кухня: підзаголовок курсивом"},
      {"key": "seek_placeholder", "name": "Кухня: підказка в полі пошуку"},
      {"key": "note_title", "name": "Кухня: заголовок блока «Кілька слів»"},
      {"key": "note_text", "name": "Кухня: текст блока «Кілька слів»", "multiline": true},
      {"key": "cafe_footer_note", "name": "Кухня: рядок у підвалі"}
    ],

    "sections": [
      {
        "name": "1. Головний екран",
        "texts": ["brand_sub", "hero_title_1", "hero_title_2", "hero_sub_strong", "hero_sub",
                  "open_time", "close_time", "phone1", "phone2", "btn_book",
                  "hero_foot_1", "hero_foot_cafe", "hero_foot_rooms"],
        "photos": ["hero.jpg"]
      },
      {
        "name": "2. Про нас",
        "texts": ["about_title_1", "about_title_2", "about_text"],
        "collections": ["about_cards"]
      },
      {
        "name": "3. Номери",
        "texts": ["rooms_title", "rooms_text", "room_btn"],
        "collections": ["rooms", "room_perks"]
      },
      {
        "name": "4. Сауна",
        "texts": ["sauna_title_1", "sauna_title_2", "sauna_text", "sauna_btn"],
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
        "texts": ["cafe_title_1", "cafe_title_2", "cafe_text", "cafe_btn"]
      },
      {
        "name": "8. Контакти й підвал",
        "texts": ["contact_title_1", "contact_title_2", "contact_note",
                  "map_link", "ig_link", "ig_label", "footer_text", "footer_copy"],
        "collections": ["hours"]
      },
      {
        "name": "9. Кухня — шапка",
        "texts": ["cafe_brand", "cafe_brand_sub", "menu_title", "menu_title_em", "seek_placeholder"]
      },
      {
        "name": "10. Кухня — меню",
        "collections": ["menu_cats", "menu_items"]
      },
      {
        "name": "11. Кухня — про кухню",
        "texts": ["note_title", "note_text", "cafe_footer_note"],
        "collections": ["kitchen_facts"]
      }
    ]
  }'::jsonb
) on conflict (id) do update set config = excluded.config, name = excluded.name;


-- ---------- Початковий вміст (лише якщо колекція ще порожня) ----------

-- Про нас: три картки
insert into public.items (site_id, collection, title, text, extra, sort_order)
select 4, 'about_cards', v.title, v.text, v.extra::jsonb, v.ord
from (values
  ('Мотель', 'Чисті номери на 1–3 особи з душем. Заселення в будь-який час до 23:00 — навіть якщо ви приїхали останнім рейсом.', '{"icon":"bed","link":"#rooms"}', 1),
  ('Сауна', 'Прогріта парна й кімната відпочинку. Замовляйте за годинами.', '{"icon":"steam","link":"#sauna"}', 2),
  ('Парковка', 'Місце для авто просто біля входу — машина завжди на очах.', '{"icon":"car","link":""}', 3)
) as v(title, text, extra, ord)
where not exists (select 1 from public.items where site_id = 4 and collection = 'about_cards');

-- Номери
insert into public.items (site_id, collection, title, text, price, extra, sort_order)
select 4, 'rooms', v.title, v.text, v.price, v.extra::jsonb, v.ord
from (values
  ('Одномісний', 'Компактна кімната для однієї особи — переночувати й рушити далі.', 'від 600 ₴',
   '{"cap":"1","capw":"особа","per":"за ніч","tags":"Душ, Wi-Fi, Рушники","kind":"single"}', 1),
  ('Двомісний', 'Двоспальне ліжко або два окремих — скажіть, як зручніше, коли бронюєте.', 'від 750 ₴',
   '{"cap":"2","capw":"особи","per":"за ніч","tags":"Душ, Wi-Fi, ТВ","kind":"double"}', 2),
  ('Сімейний', 'Просторіший номер із додатковим ліжком — місце для речей і для дитини.', 'від 950 ₴',
   '{"cap":"3","capw":"особи","per":"за ніч","tags":"Душ, Wi-Fi, Додаткове ліжко","kind":"family"}', 3)
) as v(title, text, price, extra, ord)
where not exists (select 1 from public.items where site_id = 4 and collection = 'rooms');

-- Смуга переваг під номерами
insert into public.items (site_id, collection, title, extra, sort_order)
select 4, 'room_perks', v.title, v.extra::jsonb, v.ord
from (values
  ('Безкоштовний Wi-Fi', '{"icon":"wifi"}', 1),
  ('Душ у номері', '{"icon":"shower"}', 2),
  ('Парковка біля входу', '{"icon":"car"}', 3),
  ('Заселення до 23:00', '{"icon":"key"}', 4)
) as v(title, extra, ord)
where not exists (select 1 from public.items where site_id = 4 and collection = 'room_perks');

-- Позначки сауни
insert into public.items (site_id, collection, title, sort_order)
select 4, 'sauna_perks', v.title, v.ord
from (values
  ('Парна', 1), ('Душ', 2), ('Кімната відпочинку', 3), ('Оренда за годинами', 4)
) as v(title, ord)
where not exists (select 1 from public.items where site_id = 4 and collection = 'sauna_perks');

-- Стрічка фото
insert into public.items (site_id, collection, title, sort_order)
select 4, 'gallery', v.title, v.ord
from (values
  ('Наш дім увечері', 1), ('Номер', 2), ('Парна', 3),
  ('Кімната відпочинку', 4), ('Душ', 5), ('Парковка', 6)
) as v(title, ord)
where not exists (select 1 from public.items where site_id = 4 and collection = 'gallery');

-- Графік у контактах
insert into public.items (site_id, collection, title, text, sort_order)
select 4, 'hours', v.title, v.text, v.ord
from (values
  ('Рецепція', '07:00 – 23:00', 1),
  ('Заселення', 'до 23:00', 2),
  ('Сауна', 'за домовленістю', 3),
  ('Вихідні', 'без вихідних', 4),
  ('Де ми', 'м. Кобеляки, Полтавська обл.', 5)
) as v(title, text, ord)
where not exists (select 1 from public.items where site_id = 4 and collection = 'hours');

-- Розділи меню кухні
insert into public.items (site_id, collection, title, extra, sort_order)
select 4, 'menu_cats', v.title, v.extra::jsonb, v.ord
from (values
  ('Сніданки', '{"key":"breakfast","note":"07:00 – 11:00"}', 1),
  ('Перші страви', '{"key":"soup","note":"зі сметаною та хлібом"}', 2),
  ('Гарячі страви', '{"key":"main","note":""}', 3),
  ('Гриль', '{"key":"grill","note":"на вугіллі, 20 хвилин"}', 4),
  ('Гарніри', '{"key":"side","note":""}', 5),
  ('Салати та закуски', '{"key":"salad","note":""}', 6),
  ('Випічка', '{"key":"bake","note":"печемо зранку"}', 7),
  ('Напої', '{"key":"drink","note":""}', 8)
) as v(title, extra, ord)
where not exists (select 1 from public.items where site_id = 4 and collection = 'menu_cats');

-- Чотири факти про кухню
insert into public.items (site_id, collection, title, text, sort_order)
select 4, 'kitchen_facts', v.title, v.text, v.ord
from (values
  ('07:00', 'Відчиняємось', 1),
  ('23:00', 'Зачиняємось', 2),
  ('Щодня', 'Без вихідних', 3),
  ('20–30 хв', 'Зібрати з собою', 4)
) as v(title, text, ord)
where not exists (select 1 from public.items where site_id = 4 and collection = 'kitchen_facts');

-- Фіксовані слоти фото сайту
insert into public.items (site_id, collection, title, extra, sort_order)
select 4, 'site_photos', v.title, v.extra::jsonb, v.ord
from (values
  ('Головне фото (фон першого екрана)', '{"slot":"hero.jpg"}', 1),
  ('Фото сауни', '{"slot":"sauna.jpg"}', 2)
) as v(title, extra, ord)
where not exists (select 1 from public.items where site_id = 4 and collection = 'site_photos');


-- ---------- Тексти (наявні НЕ перезаписуємо) ----------
insert into public.texts (site_id, key, value) values
  (4, 'brand_sub', 'МОТЕЛЬ · САУНА — КОБЕЛЯКИ, ПОЛТАВЩИНА'),
  (4, 'hero_title_1', 'Зупиніться'),
  (4, 'hero_title_2', 'на теплу ніч'),
  (4, 'hero_sub_strong', 'Мотель і сауна «Філін»'),
  (4, 'hero_sub', '— Кобеляки, Полтавщина. Зупиніться на ніч, прогрійтеся в сауні й вирушайте далі відпочилими.'),
  (4, 'open_time', '07:00'),
  (4, 'close_time', '23:00'),
  (4, 'phone1', '068 155 85 95'),
  (4, 'phone2', '066 278 38 88'),
  (4, 'btn_book', 'Забронювати'),
  (4, 'hero_foot_1', 'Номери · Сауна · Парковка'),
  (4, 'hero_foot_cafe', 'Меню кухні «Філін»'),
  (4, 'hero_foot_rooms', 'Дивитись номери'),

  (4, 'about_title_1', 'Відпочити'),
  (4, 'about_title_2', 'і поїхати далі'),
  (4, 'about_text', 'Мотель, сауна й місце для авто — усе в одному дворі в Кобеляках. Без довгих формальностей на рецепції: ключ у руки — і відпочивайте.'),

  (4, 'rooms_title', 'Номери'),
  (4, 'rooms_text', 'Три типи — від короткої зупинки до родинної поїздки. Оберіть свій і надішліть заявку: підтвердимо дзвінком.'),
  (4, 'room_btn', 'Забронювати'),

  (4, 'sauna_title_1', 'Сауна'),
  (4, 'sauna_title_2', ''),
  (4, 'sauna_text', 'Прогріта парна, прохолодний душ і кімната відпочинку, де можна довго сидіти й розмовляти. Беріть компанію або приходьте вдвох — прогріємо до вашого приходу, просто скажіть час.'),
  (4, 'sauna_btn', 'Забронювати сауну'),

  (4, 'photos_title', 'Як у нас'),
  (4, 'photos_text', 'Номери, сауна й сам будинок — без прикрас.'),

  (4, 'book_title', 'Бронювання'),
  (4, 'book_text', 'Відмітьте, що вам потрібно — номер, сауну або одразу і те, і те. Заявка складеться сама, а ви надішлете її однією кнопкою. Ми підтвердимо й запишемо вас.'),
  (4, 'book_hint', 'Заявка збирається сама, поки ви заповнюєте. Онлайн-календаря ми не тримаємо й передоплати не беремо: отримаємо заявку та підтвердимо дзвінком.'),

  (4, 'cafe_title_1', 'А поїсти —'),
  (4, 'cafe_title_2', 'у кухні «Філін»'),
  (4, 'cafe_text', 'Кафе з домашньою кухнею працює в тій самій будівлі. Повне меню з цінами — на окремому сайті кухні: сніданки з 07:00, перші страви, гриль і власна випічка.'),
  (4, 'cafe_btn', 'Меню кухні'),

  (4, 'contact_title_1', 'Зателефонуйте —'),
  (4, 'contact_title_2', 'і місце ваше'),
  (4, 'contact_note', 'Номери й сауна — за будь-яким із номерів. Якщо приїжджаєте пізно, попередьте: чекатимемо.'),
  (4, 'map_link', 'https://www.google.com/maps/search/%D0%A4%D1%96%D0%BB%D1%96%D0%BD+%D0%9A%D0%BE%D0%B1%D0%B5%D0%BB%D1%8F%D0%BA%D0%B8'),
  (4, 'ig_link', 'https://www.instagram.com/cafe__filin__'),
  (4, 'ig_label', '@cafe__filin__'),
  (4, 'footer_text', 'Придорожній комплекс у Кобеляках із домашньою кухнею, номерами для нічлігу та сауною. Щодня з 07:00 до 23:00.'),
  (4, 'footer_copy', '«Філін» — мотель і сауна, Кобеляки'),

  (4, 'cafe_brand', 'КУХНЯ ФІЛІН'),
  (4, 'cafe_brand_sub', 'Кобеляки · домашня кухня'),
  (4, 'menu_title', 'Меню'),
  (4, 'menu_title_em', 'домашня кухня'),
  (4, 'seek_placeholder', 'Знайти страву — борщ, вареники, кава…'),
  (4, 'note_title', 'Кілька слів про кухню'),
  (4, 'note_text', 'Готуємо щодня невеликими партіями, тому деякі страви до вечора можуть закінчитися — якщо їдете спеціально, наберіть і ми відкладемо. Замовлення з собою збираємо за 20–30 хвилин, банкетне меню обговорюємо окремо.'),
  (4, 'cafe_footer_note', 'м. Кобеляки, Полтавська обл.')
on conflict (site_id, key) do nothing;


-- ---------- Страви кухні (лише якщо ще нічого не додано) ----------
insert into public.items (site_id, collection, title, text, price, extra, sort_order)
select 4, 'menu_items', v.title, v.text, v.price, v.extra::jsonb, v.ord
from (values
  ('Яєчня з салом та зеленню','три яйця, домашнє сало','85','{"cat":"breakfast","weight":"220 г","tag":"хіт"}',1),
  ('Омлет із сиром','пишний, на молоці','90','{"cat":"breakfast","weight":"200 г","tag":""}',2),
  ('Сирники зі сметаною','подаємо гарячими, 4 шт.','95','{"cat":"breakfast","weight":"250 г","tag":""}',3),
  ('Млинці з начинкою','сир, м''ясо або вишня','90','{"cat":"breakfast","weight":"230 г","tag":""}',4),
  ('Молочна каша','вівсяна або рисова','65','{"cat":"breakfast","weight":"300 г","tag":""}',5),
  ('Бутерброд із салом','на домашньому хлібі, з гірчицею','55','{"cat":"breakfast","weight":"120 г","tag":""}',6),

  ('Борщ український','з пампушкою та сметаною','110','{"cat":"soup","weight":"350 г","tag":"хіт"}',7),
  ('Курячий бульйон','з домашньою локшиною','95','{"cat":"soup","weight":"350 г","tag":""}',8),
  ('Солянка м''ясна','з маслинами та лимоном','135','{"cat":"soup","weight":"350 г","tag":""}',9),
  ('Грибна юшка','сезонно','105','{"cat":"soup","weight":"350 г","tag":""}',10),
  ('Розсольник','на м''ясному бульйоні','100','{"cat":"soup","weight":"350 г","tag":""}',11),

  ('Вареники з картоплею','зі шкварками або сметаною','115','{"cat":"main","weight":"300 г","tag":"хіт"}',12),
  ('Вареники з сиром','солодкі, зі сметаною','115','{"cat":"main","weight":"300 г","tag":""}',13),
  ('Домашні котлети з пюре','дві котлети, вершкове пюре','150','{"cat":"main","weight":"330 г","tag":""}',14),
  ('Печеня по-домашньому','у горщику, з овочами','175','{"cat":"main","weight":"350 г","tag":""}',15),
  ('Голубці','у томатному соусі','140','{"cat":"main","weight":"300 г","tag":""}',16),
  ('Деруни зі сметаною','смажені до хрусту','120','{"cat":"main","weight":"280 г","tag":""}',17),
  ('Курка по-київськи','з маслом і зеленню','190','{"cat":"main","weight":"250 г","tag":""}',18),
  ('Риба смажена','з лимоном','175','{"cat":"main","weight":"250 г","tag":""}',19),

  ('Шашлик зі свинини','з цибулею та лавашем','250','{"cat":"grill","weight":"250 г","tag":"хіт"}',20),
  ('Шашлик із курки','у маринаді','210','{"cat":"grill","weight":"250 г","tag":""}',21),
  ('Свиняча шия','на вугіллі','295','{"cat":"grill","weight":"300 г","tag":""}',22),
  ('Ковбаска домашня','з гірчицею','190','{"cat":"grill","weight":"200 г","tag":"гостро"}',23),
  ('Овочі на грилі','сезонні','130','{"cat":"grill","weight":"250 г","tag":"пост"}',24),

  ('Картопля смажена з грибами','','95','{"cat":"side","weight":"250 г","tag":""}',25),
  ('Пюре картопляне','вершкове','65','{"cat":"side","weight":"200 г","tag":""}',26),
  ('Каша гречана з підливою','','70','{"cat":"side","weight":"250 г","tag":""}',27),
  ('Картопля по-селянськи','з салом і цибулею','90','{"cat":"side","weight":"250 г","tag":""}',28),

  ('Салат овочевий','помідор, огірок, зелень, олія','85','{"cat":"salad","weight":"220 г","tag":"пост"}',29),
  ('Салат «Цезар» з куркою','','145','{"cat":"salad","weight":"250 г","tag":""}',30),
  ('Квашені закуски','капуста, огірки, помідори','90','{"cat":"salad","weight":"250 г","tag":""}',31),
  ('Сало з домашнім хлібом','із часником і гірчицею','95','{"cat":"salad","weight":"150 г","tag":""}',32),
  ('Сирна тарілка','до вина або пива','165','{"cat":"salad","weight":"200 г","tag":""}',33),

  ('Пиріжок печений','картопля, капуста або яблуко','30','{"cat":"bake","weight":"100 г","tag":"хіт"}',34),
  ('Пампушки з часником','до борщу, 4 шт.','35','{"cat":"bake","weight":"120 г","tag":""}',35),
  ('Булочка з маком','','40','{"cat":"bake","weight":"120 г","tag":""}',36),
  ('Пиріг домашній','сезонна начинка, кусок','60','{"cat":"bake","weight":"150 г","tag":""}',37),

  ('Кава по-турецьки','зварена на піску','45','{"cat":"drink","weight":"100 мл","tag":"хіт"}',38),
  ('Американо','','45','{"cat":"drink","weight":"250 мл","tag":""}',39),
  ('Лате','','55','{"cat":"drink","weight":"300 мл","tag":""}',40),
  ('Чай у чайнику','чорний, зелений або трав''яний','70','{"cat":"drink","weight":"500 мл","tag":""}',41),
  ('Компот домашній','із сушених фруктів','35','{"cat":"drink","weight":"250 мл","tag":""}',42),
  ('Узвар','сезонно','40','{"cat":"drink","weight":"250 мл","tag":""}',43),
  ('Морс','вишня або смородина','45','{"cat":"drink","weight":"250 мл","tag":""}',44),
  ('Мінеральна вода','','30','{"cat":"drink","weight":"500 мл","tag":""}',45)
) as v(title, text, price, extra, ord)
where not exists (select 1 from public.items where site_id = 4 and collection = 'menu_items');
