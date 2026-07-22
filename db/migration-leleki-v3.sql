-- ============================================================
--  МІГРАЦІЯ v3: Кінний двір «Лелеки» — «потужна адмінка»
--  • Тепер редагується КОЖЕН блок сайту: головний екран, «Про комплекс»,
--    заголовки та підписи всіх розділів, телефон, адреса, посилання
--    на Instagram і Google Maps, рухомий рядок.
--  • Нова вкладка «Про комплекс — список переваг».
--  • НЕ чіпає вміст, який власник міг редагувати (ціни, картки номерів,
--    послуги, басейни, масаж, правила, галерею, фото) — оновлюється лише
--    конфіг адмінки, сіється список переваг і ДОДАЮТЬСЯ нові тексти
--    (наявні значення текстів не перезаписуються).
--  Запускати ОДИН раз у SQL Editor проєкту platform. Безпечно перезапускати.
-- ============================================================

-- 1) Повний конфіг сайту (вкладки + поля + всі тексти)
update public.sites set config = '{
  "collections": [
    {
      "key": "price_rows",
      "name": "Ціни на проживання",
      "fields": [
        {"key": "title", "name": "Номер (напр. 1 або Котеджі 1-6)", "type": "text"},
        {"key": "cat", "name": "Категорія (Стандарт / Сімейний / Люкс / Готельний / Котедж / Котедж люкс)", "type": "text", "extra": true},
        {"key": "text", "name": "Опис (напр. Власний вхід, 1 поверх)", "type": "text"},
        {"key": "muted", "name": "Дрібний опис (напр. деревяне оздоблення)", "type": "text", "extra": true},
        {"key": "beds", "name": "Спальні місця", "type": "text", "extra": true},
        {"key": "places", "name": "Кількість місць", "type": "text", "extra": true},
        {"key": "price", "name": "Ціна за добу (напр. 3 600 грн)", "type": "text"}
      ]
    },
    {
      "key": "room_cards",
      "name": "Картки номерів (блок зверху)",
      "fields": [
        {"key": "title", "name": "Назва (напр. Стандарт)", "type": "text"},
        {"key": "tag", "name": "Підпис зверху (напр. Номери 2, 8, 9, 10 · до 2 осіб)", "type": "text", "extra": true},
        {"key": "text", "name": "Опис", "type": "textarea"},
        {"key": "price", "name": "Ціна (напр. від 3 000)", "type": "text"},
        {"key": "places", "name": "Місць (напр. 2 місця)", "type": "text", "extra": true},
        {"key": "book", "name": "Тип для форми бронювання (напр. Стандарт (2 особи))", "type": "text", "extra": true}
      ]
    },
    {
      "key": "about_points",
      "name": "Про комплекс — список переваг",
      "fields": [
        {"key": "title", "name": "Текст пункту (нумерація 01, 02 — автоматична)", "type": "text"}
      ]
    },
    {
      "key": "svc_live",
      "name": "Послуги для проживаючих",
      "fields": [
        {"key": "title", "name": "Назва", "type": "text"},
        {"key": "small", "name": "Деталі дрібним", "type": "text", "extra": true},
        {"key": "price", "name": "Ціна", "type": "text"},
        {"key": "unit", "name": "Примітка до ціни (напр. за годину)", "type": "text", "extra": true}
      ]
    },
    {
      "key": "svc_day",
      "name": "Послуги без поселення",
      "fields": [
        {"key": "title", "name": "Назва", "type": "text"},
        {"key": "small", "name": "Деталі дрібним", "type": "text", "extra": true},
        {"key": "price", "name": "Ціна", "type": "text"},
        {"key": "unit", "name": "Примітка до ціни (напр. за годину)", "type": "text", "extra": true}
      ]
    },
    {
      "key": "pools",
      "name": "Басейни",
      "fields": [
        {"key": "title", "name": "Категорія відвідувача (напр. Дорослі)", "type": "text"},
        {"key": "small", "name": "Деталі дрібним (напр. Пн-Чт 600 грн)", "type": "text", "extra": true},
        {"key": "price", "name": "Ціна", "type": "text"},
        {"key": "unit", "name": "Примітка до ціни", "type": "text", "extra": true}
      ]
    },
    {
      "key": "massage",
      "name": "Масаж",
      "fields": [
        {"key": "title", "name": "Назва масажу", "type": "text"},
        {"key": "small", "name": "Тривалість (напр. 30 хв)", "type": "text", "extra": true},
        {"key": "price", "name": "Ціна", "type": "text"}
      ]
    },
    {
      "key": "included",
      "name": "Включено у вартість",
      "fields": [
        {"key": "title", "name": "Назва (напр. Сніданок)", "type": "text"},
        {"key": "icon", "name": "Іконка", "type": "select", "extra": true, "options": [
          {"value": "coffee", "label": "Кава / сніданок"},
          {"value": "pool", "label": "Басейн"},
          {"value": "gazebo", "label": "Альтанка"},
          {"value": "grill", "label": "Мангал"},
          {"value": "parking", "label": "Паркінг"},
          {"value": "wifi", "label": "Wi-Fi"},
          {"value": "horse", "label": "Кінь"},
          {"value": "sauna", "label": "Баня"},
          {"value": "fish", "label": "Риболовля"},
          {"value": "billiard", "label": "Більярд"}
        ]}
      ]
    },
    {
      "key": "rules",
      "name": "Умови та правила",
      "fields": [
        {"key": "title", "name": "Заголовок", "type": "text"},
        {"key": "text", "name": "Текст", "type": "textarea"}
      ]
    },
    {
      "key": "gallery",
      "name": "Галерея",
      "fields": [
        {"key": "title", "name": "Підпис фото", "type": "text"},
        {"key": "image", "name": "Фото", "type": "image"}
      ]
    },
    {
      "key": "site_photos",
      "name": "Фото сайту",
      "noAdd": true,
      "noDelete": true,
      "fields": [
        {"key": "title", "name": "Місце на сайті", "type": "text"},
        {"key": "image", "name": "Фото", "type": "image"},
        {"key": "slot", "name": "Технічний код місця (не міняти!)", "type": "text", "extra": true}
      ]
    }
  ],
  "texts": [
    {"key": "phone", "name": "Телефон (показується всюди на сайті)"},
    {"key": "hero_eyebrow", "name": "Головний екран: рядок над заголовком"},
    {"key": "hero_title", "name": "Головний екран: заголовок"},
    {"key": "hero_accent", "name": "Головний екран: акцент заголовка (курсив, напр. «Лелеки»)"},
    {"key": "hero_sub", "name": "Головний екран: опис під заголовком", "multiline": true},
    {"key": "stat_horses", "name": "Головний екран: цифра — коней у стайні (напр. 30+)"},
    {"key": "stat_pools", "name": "Головний екран: цифра — басейнів"},
    {"key": "check_in", "name": "Час заїзду (напр. 14:00)"},
    {"key": "check_out", "name": "Час виїзду (напр. 11:00)"},
    {"key": "marquee", "name": "Рухомий рядок під головним екраном (пункти через •)", "multiline": true},
    {"key": "about_title", "name": "Про комплекс: заголовок"},
    {"key": "about_text", "name": "Про комплекс: основний текст", "multiline": true},
    {"key": "rooms_title", "name": "Розділ Номери: заголовок"},
    {"key": "prices_title", "name": "Розділ Ціни: заголовок"},
    {"key": "tourist_tax", "name": "Туристичний збір, грн/особа/доба (напр. 43,24)"},
    {"key": "pools_title", "name": "Розділ Басейни: заголовок"},
    {"key": "pools_note", "name": "Розділ Басейни: підпис праворуч від заголовка", "multiline": true},
    {"key": "massage_title", "name": "Розділ Масаж: заголовок"},
    {"key": "massage_note", "name": "Розділ Масаж: підпис праворуч від заголовка", "multiline": true},
    {"key": "gallery_title", "name": "Розділ Галерея: заголовок"},
    {"key": "services_title", "name": "Розділ Послуги: заголовок"},
    {"key": "services_note", "name": "Розділ Послуги: підпис праворуч від заголовка", "multiline": true},
    {"key": "rules_title", "name": "Розділ Умови та правила: заголовок"},
    {"key": "horse_price", "name": "Катання на конях, грн за коло (напр. 100)"},
    {"key": "booking_title", "name": "Бронювання: заголовок"},
    {"key": "booking_note", "name": "Бронювання: текст під заголовком", "multiline": true},
    {"key": "contacts_title", "name": "Контакти: заголовок"},
    {"key": "address1", "name": "Контакти: адреса, рядок 1"},
    {"key": "address2", "name": "Контакти: адреса, рядок 2"},
    {"key": "distance", "name": "Контакти: відстань (напр. 70 км від Дніпра)"},
    {"key": "insta_handle", "name": "Instagram: нік (напр. @konnyi_dvor_leleki)"},
    {"key": "insta_url", "name": "Instagram: посилання"},
    {"key": "insta_rest_handle", "name": "Instagram ресторану: нік"},
    {"key": "insta_rest_url", "name": "Instagram ресторану: посилання"},
    {"key": "insta_aqua_handle", "name": "Instagram аквазони: нік"},
    {"key": "insta_aqua_url", "name": "Instagram аквазони: посилання"},
    {"key": "maps_url", "name": "Google Maps: посилання Маршрут"}
  ]
}'::jsonb
where slug = 'leleki';

-- 2) Список переваг «Про комплекс» (перезаписується лише ця колекція)
delete from public.items where site_id = 2 and collection = 'about_points';
insert into public.items (site_id, collection, title, sort_order) values
  (2, 'about_points', 'Номери та котеджі з дерев''яним оздобленням, окремими входами й терасами', 1),
  (2, 'about_points', 'Кінні прогулянки для дорослих і дітей — понад 30 коней у стайні', 2),
  (2, 'about_points', 'Два вуличні басейни, баня на дровах, чан і масаж', 3),
  (2, 'about_points', 'Альтанки, у тому числі на воді, мангальні зони та ресторан', 4);

-- 3) Тексти: сіємо нові ключі. Наявні значення НЕ перезаписуємо
--    (власник міг уже щось змінити — його правки лишаються).
insert into public.texts (site_id, key, value) values
  (2, 'phone', '096 645 91 07'),
  (2, 'hero_eyebrow', 'Приорілля · с. Рудка · 70 км від Дніпра'),
  (2, 'hero_title', 'Кінний двір'),
  (2, 'hero_accent', '«Лелеки»'),
  (2, 'hero_sub', 'Будиночки, чани, два басейни, масаж та кінні прогулянки серед мальовничих просторів Приорілля. Ідеальне місце для перезавантаження.'),
  (2, 'stat_horses', '30+'),
  (2, 'stat_pools', '2'),
  (2, 'check_in', '14:00'),
  (2, 'check_out', '11:00'),
  (2, 'marquee', 'Будиночки • Чан • Два басейни • Кінні прогулянки • Баня на дровах • Масаж • Сніданки • Альтанка на воді • Ресторан'),
  (2, 'about_title', 'Місце, де час уповільнюється'),
  (2, 'about_text', 'Кінний двір «Лелеки» — заміський комплекс відпочинку в селі Рудка на Дніпропетровщині. Дерев''яні будиночки, стайня з понад тридцятьма кіньми, два басейни, чани та українська кухня — за 70 кілометрів від міського шуму.'),
  (2, 'rooms_title', 'Номери та котеджі'),
  (2, 'prices_title', 'Ціни на проживання'),
  (2, 'tourist_tax', '43,24'),
  (2, 'pools_title', 'Два басейни просто неба'),
  (2, 'pools_note', 'Денне відвідування — з 9:00 до 20:00. Великий басейн із дитячими гірками та менший релакс-басейн із соленою водою.'),
  (2, 'massage_title', 'Час турботи про тіло'),
  (2, 'massage_note', 'Подаруйте собі розслаблення після прогулянок і басейну. Запис — у адміністратора комплексу.'),
  (2, 'gallery_title', 'Подивіться на «Лелеки»'),
  (2, 'services_title', 'Додаткові послуги'),
  (2, 'services_note', 'Частина послуг доступна і без поселення — приїжджайте на день: альтанки, мангал, коні, риболовля та баня.'),
  (2, 'rules_title', 'Умови та правила'),
  (2, 'horse_price', '100'),
  (2, 'booking_title', 'Забронюйте відпочинок'),
  (2, 'booking_note', 'Залиште заявку — адміністратор зв''яжеться з вами, підтвердить вільні дати та відповість на всі запитання. Або телефонуйте напряму.'),
  (2, 'contacts_title', 'Як нас знайти'),
  (2, 'address1', 'с. Рудка, вул. Шевченка, 143'),
  (2, 'address2', 'Дніпропетровська область'),
  (2, 'distance', '≈ 70 км від Дніпра'),
  (2, 'insta_handle', '@konnyi_dvor_leleki'),
  (2, 'insta_url', 'https://www.instagram.com/konnyi_dvor_leleki'),
  (2, 'insta_rest_handle', '@kd_leleky.rest'),
  (2, 'insta_rest_url', 'https://www.instagram.com/kd_leleky.rest'),
  (2, 'insta_aqua_handle', '@relax.aqua.zone'),
  (2, 'insta_aqua_url', 'https://www.instagram.com/relax.aqua.zone'),
  (2, 'maps_url', 'https://maps.app.goo.gl/BNHh3GnjiRk4hk6f6')
on conflict (site_id, key) do nothing;
