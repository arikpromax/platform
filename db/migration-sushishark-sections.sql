-- ============================================================
--  SUSHI SHARK: адмінка «як у Фуджі»
--   • Розділи як на сайті (sections) замість трьох голих вкладок
--   • Підказки під полями і примітка вгорі кожного розділу
--   • Нові редаговані тексти: телефон, адреса, Instagram,
--     мінімальне замовлення, час доставки, доплата за тубус
--   • Години роботи кухні (open_from / open_to) у «Режим роботи»
--
--  БЕЗПЕЧНИЙ ДЛЯ ПОВТОРНОГО ЗАПУСКУ.
--  Колекції не переписуються цілком — правки з попередніх
--  міграцій (акція, нема в наявності, безкоштовні напої) лишаються.
--  Тексти засіваються лише якщо їх ще немає.
--
--  Запускати у SQL Editor проєкту platform.
-- ============================================================

-- ---------- 1) Тексти, які власник зможе міняти ----------
update public.sites
set config = jsonb_set(config, '{texts}', '[
  {"key":"phone_view","name":"Телефон — як показувати",
   "hint":"Саме так номер побачить гість у контактах. Наприклад: +48 797 254 955"},
  {"key":"phone","name":"Телефон — для дзвінка",
   "hint":"Той самий номер, але суцільно і з кодом країни. На нього спрацює кнопка дзвінка. Наприклад: +48797254955"},
  {"key":"addr","name":"Адреса",
   "hint":"Показується в контактах і відкриває карти. Кома переносить на новий рядок. Наприклад: ul. Wolnosci 29, Jelenia Gora"},
  {"key":"instagram","name":"Instagram",
   "hint":"Можна вписати нік або повне посилання — сайт розбереться. Наприклад: @sushi_shark_jg"},
  {"key":"min_order","name":"Мінімальне замовлення на доставку, zl",
   "hint":"Саме число, без zl. Менше цієї суми кошик не дасть оформити доставку. Наприклад: 70"},
  {"key":"delivery_time","name":"Скільки триває доставка",
   "hint":"Напис на головній сторінці, під годинами роботи. Наприклад: ~60 min"},
  {"key":"tube_price","name":"Доплата за рол у тубусі, zl",
   "hint":"Саме число. Стільки додається до ціни, коли гість ставить галочку «W tubusie». Галочка є лише у вибраних ролів. Наприклад: 7"}
]'::jsonb, true)
where id = 3;

-- ---------- 2) Години кухні в «Режим роботи» ----------
-- Додаємо два поля до наявної колекції settings, не чіпаючи решти.
update public.sites s
set config = jsonb_set(
  s.config,
  '{collections}',
  (
    select jsonb_agg(
      case
        when c->>'key' = 'settings'
             and not (c->'fields' @> '[{"key":"open_from"}]'::jsonb)
        then jsonb_set(c, '{fields}', (c->'fields') || '[
               {"type":"text","key":"open_from","name":"Кухня починає працювати о","extra":true,
                "hint":"Година у форматі 12:00. З цього часу починається доставка. До неї замовлення теж приймаються, але гість мусить обрати годину — сайт сам це пояснить."},
               {"type":"text","key":"open_to","name":"Кухня закінчує о","extra":true,
                "hint":"Година у форматі 22:00. Після неї замовлення приймаються вже на наступний день. Цим же обмежується вибір години в оформленні."}
             ]'::jsonb)
        else c
      end
      order by idx
    )
    from jsonb_array_elements(s.config->'collections') with ordinality as t(c, idx)
  )
)
where s.id = 3;

-- ---------- 3) Розділи як на сайті ----------
update public.sites
set config = jsonb_set(config, '{sections}', '[
  {"name":"1. Режим роботи та контакти",
   "note":"Тут закривають сайт на вихідний і задають години, коли працює кухня. Нижче — телефон, адреса та Instagram: усе це одразу міняється на сайті.",
   "collections":["settings"],
   "texts":["phone_view","phone","addr","instagram"]},
  {"name":"2. Меню",
   "note":"Усі страви сайту. Щоб змінити ціну, склад чи фото — натисніть «Редагувати» біля потрібної позиції. Нова страва зʼявляється на сайті одразу після збереження.",
   "collections":["menu","cats"]},
  {"name":"3. Доставка та ціни",
   "note":"Суми й підписи, які гість бачить у кошику та на головній сторінці.",
   "texts":["min_order","delivery_time","tube_price"]}
]'::jsonb, true)
where id = 3;

-- ---------- 4) Початкові значення текстів ----------
-- Те, що зараз зашите в сайті. Якщо власник уже щось вписав — не чіпаємо.
insert into public.texts (site_id, key, value) values
  (3, 'phone_view',    '+48 797 254 955'),
  (3, 'phone',         '+48797254955'),
  (3, 'addr',          'ul. Wolności 29, Jelenia Góra'),
  (3, 'instagram',     '@sushi_shark_jg'),
  (3, 'min_order',     '70'),
  (3, 'delivery_time', '~60 min'),
  (3, 'tube_price',    '7')
on conflict (site_id, key) do nothing;

-- ---------- 5) Години кухні за замовчуванням ----------
-- Сайт без цих значень працює на 12:00–22:00 з коду; засіваємо, щоб
-- власник побачив у полях те саме, що вже діє.
insert into public.items (site_id, collection, title, extra, sort_order)
select 3, 'settings', 'Режим роботи', '{"open_from":"12:00","open_to":"22:00"}'::jsonb, 1
where not exists (
  select 1 from public.items where site_id = 3 and collection = 'settings'
);

update public.items
set extra = extra || '{"open_from":"12:00","open_to":"22:00"}'::jsonb
where site_id = 3 and collection = 'settings'
  and extra->>'open_from' is null;

-- ---------- 6) Плитки розділів у списку страв ----------
-- Над меню зʼявиться «Оберіть розділ:» з лічильниками, як у Фуджі.
update public.sites s
set config = jsonb_set(
  s.config,
  '{collections}',
  (
    select jsonb_agg(
      case when c->>'key' = 'menu' then c || '{"groupBy":"cat"}'::jsonb else c end
      order by idx
    )
    from jsonb_array_elements(s.config->'collections') with ordinality as t(c, idx)
  )
)
where s.id = 3;

-- ---------- 7) Розділи меню стають редагованими ----------
-- Знімаємо заборони, поставлені раніше (adminOnly / noAdd / noDelete),
-- і вмикаємо autoKey: код нового розділу підставляється автоматично.
update public.sites s
set config = jsonb_set(
  s.config,
  '{collections}',
  (
    select jsonb_agg(
      case
        when c->>'key' = 'cats'
        then (c - 'adminOnly' - 'noAdd' - 'noDelete')
             || '{"name":"Розділи меню","autoKey":"catkey"}'::jsonb
             || jsonb_build_object('fields', '[
                  {"key":"title","name":"Назва розділу","type":"text",
                   "hint":"Так вкладка підписана на сайті. Наприклад: Салати. Новий розділ зʼявиться в меню одразу після збереження."},
                  {"key":"catkey","name":"Код розділу","type":"text","extra":true,
                   "hint":"Службовий код, за яким страви привʼязані до розділу. Для нового розділу підставиться сам — не чіпайте. У наявних розділів міняти НЕ можна: страви відваляться."}
                ]'::jsonb)
        else c
      end
      order by idx
    )
    from jsonb_array_elements(s.config->'collections') with ordinality as t(c, idx)
  )
)
where s.id = 3;
