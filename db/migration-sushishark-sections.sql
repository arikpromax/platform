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

-- ---------- 8) Розклад показу страви (бізнес-ланч) ----------
-- Страва зʼявляється й зникає сама: у вибрані дні тижня та години.
-- Порожні поля = показувати завжди, як і було.
update public.sites s
set config = jsonb_set(
  s.config,
  '{collections}',
  (
    select jsonb_agg(
      case
        when c->>'key' = 'menu'
             and not (c->'fields' @> '[{"key":"show_from"}]'::jsonb)
        then jsonb_set(c, '{fields}', (c->'fields') || '[
               {"type":"select","key":"day_from","name":"Показувати з дня","extra":true,
                "options":[{"value":"","label":"Щодня"},
                           {"value":"1","label":"Понеділок"},
                           {"value":"2","label":"Вівторок"},
                           {"value":"3","label":"Середа"},
                           {"value":"4","label":"Четвер"},
                           {"value":"5","label":"Пʼятниця"},
                           {"value":"6","label":"Субота"},
                           {"value":"7","label":"Неділя"}],
                "hint":"Перший день тижня, коли страва є в меню. Лишіть «Щодня», щоб вона була завжди."},
               {"type":"select","key":"day_to","name":"Показувати до дня","extra":true,
                "options":[{"value":"","label":"Щодня"},
                           {"value":"1","label":"Понеділок"},
                           {"value":"2","label":"Вівторок"},
                           {"value":"3","label":"Середа"},
                           {"value":"4","label":"Четвер"},
                           {"value":"5","label":"Пʼятниця"},
                           {"value":"6","label":"Субота"},
                           {"value":"7","label":"Неділя"}],
                "hint":"Останній день, коли страва ще в меню — включно. Наприклад з понеділка до пʼятниці: страва є пн, вт, ср, чт і пт. Щоб працювало, оберіть обидва дні."},
               {"type":"text","key":"show_from","name":"Показувати з години","extra":true,
                "hint":"Формат 12:00. До цієї години страви в меню не видно. Порожньо — видно з початку дня."},
               {"type":"text","key":"show_to","name":"Ховати після години","extra":true,
                "hint":"Формат 15:00. Після цієї години страва зникає з меню сама. Порожньо — лишається до кінця дня."}
             ]'::jsonb)
        else c
      end
      order by idx
    )
    from jsonb_array_elements(s.config->'collections') with ordinality as t(c, idx)
  )
)
where s.id = 3;

-- ---------- 9) Опція «з напоєм» для страви ----------
-- Ставите доплату — у картці страви на сайті зʼявляється галочка
-- «Z napojem +N zł», а при додаванні гість обирає напій зі списку.
-- Порожньо або 0 — галочки немає, як і було.
update public.sites s
set config = jsonb_set(
  s.config,
  '{collections}',
  (
    select jsonb_agg(
      case
        when c->>'key' = 'menu'
             and not (c->'fields' @> '[{"key":"drink_price"}]'::jsonb)
        then jsonb_set(c, '{fields}', (c->'fields') || '[
               {"type":"text","key":"drink_price","name":"Доплата за напій, zl","extra":true,
                "hint":"Саме число, наприклад 10. У страви зʼявиться галочка «З напоєм»: гість ставить її та обирає напій зі списку напоїв меню, а до ціни додається ця сума. Порожньо — галочки немає."}
             ]'::jsonb)
        else c
      end
      order by idx
    )
    from jsonb_array_elements(s.config->'collections') with ordinality as t(c, idx)
  )
)
where s.id = 3;

-- ---------- 10) Які саме напої пропонувати ----------
-- Порожньо — гість обирає з усіх напоїв меню. Або впишіть назви,
-- кожну з нового рядка, і у вікні буде лише вони.
update public.sites s
set config = jsonb_set(
  s.config,
  '{collections}',
  (
    select jsonb_agg(
      case
        when c->>'key' = 'menu'
             and not (c->'fields' @> '[{"key":"drink_list"}]'::jsonb)
        then jsonb_set(c, '{fields}', (c->'fields') || '[
               {"type":"textarea","key":"drink_list","name":"Які напої пропонувати","extra":true,
                "hint":"Кожна назва з нового рядка, точно як у розділі «Напої»: Fanta, Sprite. Порожньо — гість обирає з усіх напоїв меню. Працює лише разом із доплатою за напій вище."}
             ]'::jsonb)
        else c
      end
      order by idx
    )
    from jsonb_array_elements(s.config->'collections') with ordinality as t(c, idx)
  )
)
where s.id = 3;

-- ---------- 11) Акційна ціна і плашка «Новинка» ----------
-- sale_price: вписана нова ціна перекреслює стару на сайті й вмикає
-- жовту плашку. Порожньо — акції немає.
-- neu: зелена плашка «Новинка» над фото.
update public.sites s
set config = jsonb_set(
  s.config,
  '{collections}',
  (
    select jsonb_agg(
      case
        when c->>'key' = 'menu'
             and not (c->'fields' @> '[{"key":"sale_price"}]'::jsonb)
        then jsonb_set(c, '{fields}', (c->'fields') || '[
               {"type":"text","key":"sale_price","name":"Ціна за акцією, zl","extra":true,
                "hint":"Заповніть, щоб запустити акцію: на сайті стара ціна стане закресленою, поруч зʼявиться нова і жовта плашка «Promocja». Щоб акцію прибрати — очистіть це поле. Приклад: звичайна 45, тут 35."},
               {"type":"checkbox","key":"neu","name":"Новинка","extra":true,
                "hint":"Над фото зʼявиться зелена плашка «Nowość». На ціну не впливає."}
             ]'::jsonb)
        else c
      end
      order by idx
    )
    from jsonb_array_elements(s.config->'collections') with ordinality as t(c, idx)
  )
)
where s.id = 3;

-- ---------- 12) Прибирання у формі страви ----------
--  • стара галочка «Акція (жовта позначка)» більше не потрібна:
--    плашку вмикає заповнена «Ціна за акцією»
--  • «Новинка» стає поруч із «Нема в наявності»
--  • «Які напої пропонувати» — тепер список галочок із наявних напоїв,
--    а не поле, куди назви вписують руками
--  • поля впорядковані так, як їх читає власник
update public.sites s
set config = jsonb_set(
  s.config,
  '{collections}',
  (
    select jsonb_agg(
      case when c->>'key' = 'menu' then jsonb_set(c, '{fields}', m.arr) else c end
      order by idx
    )
    from jsonb_array_elements(s.config->'collections') with ordinality as t(c, idx)
    left join lateral (
      select jsonb_agg(f order by pos, i) as arr
      from (
        select
          case
            when f->>'key' = 'drink_list' then '{"type":"multi-collection","key":"drink_list","name":"Які напої пропонувати","extra":true,"from":"menu","whereExtra":{"key":"cat","value":"drinks"},"hint":"Позначте напої, які гість зможе обрати. Нічого не позначено — доступні всі напої меню. Працює разом із доплатою вище."}'::jsonb
            else f
          end as f,
          i,
          case f->>'key'
            when 'title' then 1   when 'price' then 2   when 'sale_price' then 3
            when 'image' then 4   when 'cat' then 5     when 'pcs' then 6
            when 'vol' then 7     when 'spicy' then 8   when 'veg' then 9
            when 'promo' then 10  when 'pl' then 11     when 'ua' then 12
            when 'en' then 13     when 'img' then 14    when 'drinks' then 15
            when 'out' then 16    when 'neu' then 17
            when 'day_from' then 18 when 'day_to' then 19
            when 'show_from' then 20 when 'show_to' then 21
            when 'drink_price' then 22 when 'drink_list' then 23
            else 100 + i
          end as pos
        from jsonb_array_elements(c->'fields') with ordinality t1(f, i)
        where f->>'key' <> 'sale'
      ) z
    ) m on c->>'key' = 'menu'
  )
)
where s.id = 3;

-- Якщо кроку 10 ще не запускали — поля drink_list могло не бути зовсім.
update public.sites s
set config = jsonb_set(
  s.config,
  '{collections}',
  (
    select jsonb_agg(
      case
        when c->>'key' = 'menu' and not (c->'fields' @> '[{"key":"drink_list"}]'::jsonb)
        then jsonb_set(c, '{fields}', (c->'fields') || '[
               {"type":"multi-collection","key":"drink_list","name":"Які напої пропонувати","extra":true,
                "from":"menu","whereExtra":{"key":"cat","value":"drinks"},
                "hint":"Позначте напої, які гість зможе обрати. Нічого не позначено — доступні всі напої меню. Працює разом із доплатою вище."}
             ]'::jsonb)
        else c
      end
      order by idx
    )
    from jsonb_array_elements(s.config->'collections') with ordinality as t(c, idx)
  )
)
where s.id = 3;

-- ---------- 13) Гратіси: напої та соуси окремо від «Промо» ----------
--  • «Промо» тепер означає лише «показувати першою» і більше не дає
--    двох напоїв автоматично — кількість задається явно тут
--  • поруч зʼявляється така сама кількість безкоштовних соусів
--  • обидва поля переїжджають униз, до решти налаштувань напоїв
update public.sites s
set config = jsonb_set(
  s.config,
  '{collections}',
  (
    select jsonb_agg(
      case when c->>'key' = 'menu' then jsonb_set(c, '{fields}', m.arr) else c end
      order by idx
    )
    from jsonb_array_elements(s.config->'collections') with ordinality as t(c, idx)
    left join lateral (
      select jsonb_agg(f order by pos, i) as arr
      from (
        select
          case when f->>'key' = 'drinks' then '{"key":"drinks","name":"Безкоштовних напоїв","type":"select","extra":true,"options":[{"value":"","label":"Немає"},{"value":"1","label":"1 напій"},{"value":"2","label":"2 напої"},{"value":"3","label":"3 напої"},{"value":"4","label":"4 напої"}],"hint":"Скільки напоїв гість отримає безкоштовно до цієї страви. При додаванні в кошик сайт попросить обрати саме стільки. «Немає» — напоїв не дається."}'::jsonb
               else f end as f,
          i,
          case f->>'key'
            when 'title' then 1   when 'price' then 2   when 'sale_price' then 3
            when 'image' then 4   when 'cat' then 5     when 'pcs' then 6
            when 'vol' then 7     when 'spicy' then 8   when 'veg' then 9
            when 'promo' then 10  when 'pl' then 11     when 'ua' then 12
            when 'en' then 13     when 'img' then 14
            when 'out' then 15    when 'neu' then 16
            when 'day_from' then 17 when 'day_to' then 18
            when 'show_from' then 19 when 'show_to' then 20
            when 'drink_price' then 21 when 'drink_list' then 22
            when 'drinks' then 23 when 'sauces' then 24
            else 100 + i
          end as pos
        from jsonb_array_elements(c->'fields') with ordinality t1(f, i)
      ) z
    ) m on c->>'key' = 'menu'
  )
)
where s.id = 3;

-- Поле «Безкоштовних соусів» — додаємо, якщо його ще немає
update public.sites s
set config = jsonb_set(
  s.config,
  '{collections}',
  (
    select jsonb_agg(
      case
        when c->>'key' = 'menu' and not (c->'fields' @> '[{"key":"sauces"}]'::jsonb)
        then jsonb_set(c, '{fields}', (c->'fields') || '[
               {"key":"sauces","name":"Безкоштовних соусів","type":"select","extra":true,
                "options":[{"value":"","label":"Немає"},
                           {"value":"1","label":"1 соус"},
                           {"value":"2","label":"2 соуси"},
                           {"value":"3","label":"3 соуси"},
                           {"value":"4","label":"4 соуси"}],
                "hint":"Скільки соусів гість отримає безкоштовно до цієї страви. Обирає їх сам при додаванні в кошик, зі списку соусів меню. «Немає» — соусів не дається."}
             ]'::jsonb)
        else c
      end
      order by idx
    )
    from jsonb_array_elements(s.config->'collections') with ordinality as t(c, idx)
  )
)
where s.id = 3;

-- Підпис «Промо» більше не обіцяє напоїв
update public.sites s
set config = jsonb_set(
  s.config,
  '{collections}',
  (
    select jsonb_agg(
      case when c->>'key' = 'menu' then jsonb_set(c, '{fields}', (
        select jsonb_agg(
          case when f->>'key' = 'promo'
               then f || '{"name":"Промо (показувати першою)","hint":"Страва стає першою в меню і отримує помаранчеву плашку. На напої та соуси це не впливає — їх кількість задається нижче."}'::jsonb
               else f end
          order by i)
        from jsonb_array_elements(c->'fields') with ordinality t1(f, i)
      )) else c end
      order by idx
    )
    from jsonb_array_elements(s.config->'collections') with ordinality as t(c, idx)
  )
)
where s.id = 3;

-- ---------- 14) Які соуси пропонувати ----------
-- Такий самий список галочок, як у напоїв, але з розділу «Соуси».
-- Нічого не позначено — гість обирає з усіх соусів меню.
-- Заразом уточнюємо підпис списку напоїв: він діє і на безкоштовні.
update public.sites s
set config = jsonb_set(
  s.config,
  '{collections}',
  (
    select jsonb_agg(
      case
        when c->>'key' = 'menu' and not (c->'fields' @> '[{"key":"sauce_list"}]'::jsonb)
        then jsonb_set(c, '{fields}', (c->'fields') || '[
               {"type":"multi-collection","key":"sauce_list","name":"Які соуси пропонувати","extra":true,
                "from":"menu","whereExtra":{"key":"cat","value":"sosy"},
                "hint":"Позначте соуси, які гість зможе обрати. Нічого не позначено — доступні всі соуси меню. Працює разом із кількістю безкоштовних соусів вище."}
             ]'::jsonb)
        else c
      end
      order by idx
    )
    from jsonb_array_elements(s.config->'collections') with ordinality as t(c, idx)
  )
)
where s.id = 3;

-- Ставимо список соусів одразу під кількістю, а список напоїв — під їхньою
update public.sites s
set config = jsonb_set(
  s.config,
  '{collections}',
  (
    select jsonb_agg(
      case when c->>'key' = 'menu' then jsonb_set(c, '{fields}', m.arr) else c end
      order by idx
    )
    from jsonb_array_elements(s.config->'collections') with ordinality as t(c, idx)
    left join lateral (
      select jsonb_agg(f order by pos, i) as arr
      from (
        select
          case when f->>'key' = 'drink_list'
               then f || '{"hint":"Позначте напої, які гість зможе обрати. Нічого не позначено — доступні всі напої меню. Діє і на платний напій, і на безкоштовні."}'::jsonb
               else f end as f,
          i,
          case f->>'key'
            when 'title' then 1   when 'price' then 2   when 'sale_price' then 3
            when 'image' then 4   when 'cat' then 5     when 'pcs' then 6
            when 'vol' then 7     when 'spicy' then 8   when 'veg' then 9
            when 'promo' then 10  when 'pl' then 11     when 'ua' then 12
            when 'en' then 13     when 'img' then 14
            when 'out' then 15    when 'neu' then 16
            when 'day_from' then 17 when 'day_to' then 18
            when 'show_from' then 19 when 'show_to' then 20
            when 'drink_price' then 21
            when 'drinks' then 22 when 'drink_list' then 23
            when 'sauces' then 24 when 'sauce_list' then 25
            else 100 + i
          end as pos
        from jsonb_array_elements(c->'fields') with ordinality t1(f, i)
      ) z
    ) m on c->>'key' = 'menu'
  )
)
where s.id = 3;

-- ---------- 15) Додатки за доплату (моцарела, авокадо…) ----------
-- Пишемо по одному в рядок: «Назва = ціна». Наприклад:
--   Mozzarella = 8
--   Awokado = 6
-- На сайті при додаванні страви в кошик гість побачить вікно з цим
-- списком і зможе позначити потрібне; доплата додається до ціни.
update public.sites s
set config = jsonb_set(
  s.config,
  '{collections}',
  (
    select jsonb_agg(
      case
        when c->>'key' = 'menu' and not (c->'fields' @> '[{"key":"addons"}]'::jsonb)
        then jsonb_set(c, '{fields}', (c->'fields') || '[
               {"type":"textarea","key":"addons","name":"Додатки за доплату","extra":true,
                "hint":"По одному в рядок, у форматі «Назва = ціна». Наприклад: Mozzarella = 8. Гість обере їх при додаванні страви в кошик, доплата піде до ціни. Порожньо — вікна не буде."}
             ]'::jsonb)
        else c
      end
      order by idx
    )
    from jsonb_array_elements(s.config->'collections') with ordinality as t(c, idx)
  )
)
where s.id = 3;

-- Ставимо поле одразу під ціною за акцією, щоб усе про гроші було поруч
update public.sites s
set config = jsonb_set(
  s.config,
  '{collections}',
  (
    select jsonb_agg(
      case when c->>'key' = 'menu' then jsonb_set(c, '{fields}', m.arr) else c end
      order by idx
    )
    from jsonb_array_elements(s.config->'collections') with ordinality as t(c, idx)
    left join lateral (
      select jsonb_agg(f order by pos, i) as arr
      from (
        select f, i,
          case f->>'key'
            when 'title' then 1   when 'price' then 2   when 'sale_price' then 3
            when 'addons' then 4
            when 'image' then 5   when 'cat' then 6     when 'pcs' then 7
            when 'vol' then 8     when 'spicy' then 9   when 'veg' then 10
            when 'promo' then 11  when 'pl' then 12     when 'ua' then 13
            when 'en' then 14     when 'img' then 15
            when 'out' then 16    when 'neu' then 17
            when 'day_from' then 18 when 'day_to' then 19
            when 'show_from' then 20 when 'show_to' then 21
            when 'drink_price' then 22
            when 'drinks' then 23 when 'drink_list' then 24
            when 'sauces' then 25 when 'sauce_list' then 26
            else 100 + i
          end as pos
        from jsonb_array_elements(c->'fields') with ordinality t1(f, i)
      ) z
    ) m on c->>'key' = 'menu'
  )
)
where s.id = 3;

-- ---------- 16) Порядок в адмінці ----------
--  • картка страви поділена на блоки із заголовками замість 26 полів підряд
--  • «Промо» тепер «Хіт місяця» — як на сайті
--  • гострота, години й дні — вибір зі списку, а не ввід руками
--  • коротші назви, пояснення — сірим рядком під полем; скрізь «zł»
--  • технічні коди бачить лише адмін платформи, клієнт — ні
--  • тубус вмикається галочкою в самій страві (раніше список був у коді)
--  • фото тубуса й безкоштовні напої за замовчуванням — у «Режимі роботи»
--  • банер вихідного — ще й англійською
--
--  Поля, яких цей крок не знає, НЕ губляться — дописуються в кінець картки.
--  Потребує оновленої платформи (типи heading і adminOnly).

update public.sites s
set config = jsonb_set(
  s.config,
  '{collections}',
  (
    select jsonb_agg(
      case
        when c->>'key' = 'menu' then jsonb_set(c, '{fields}',
          '[
  {"type":"heading","key":"h_main","name":"Основне"},
  {"type":"text","key":"title","name":"Назва",
   "hint":"Так страву підписано в меню. Наприклад: Philadelphia"},
  {"type":"select-collection","key":"cat","name":"Розділ меню","extra":true,"from":"cats",
   "hint":"У якій вкладці меню показувати страву. Список береться з «Розділів меню» нижче."},
  {"type":"image","key":"image","name":"Фото страви",
   "hint":"Найкраще — квадратне фото на білому тлі. Не завантажите — сайт покаже вбудоване."},
  {"type":"text","key":"price","name":"Ціна, zł",
   "hint":"Саме число, без zł. Наприклад: 45"},
  {"type":"text","key":"sale_price","name":"Ціна за акцією, zł","extra":true,
   "hint":"Заповніть, щоб запустити акцію: стара ціна стане закресленою, поруч зʼявиться нова і жовта плашка «Promocja». Щоб прибрати акцію — очистіть поле."},

  {"type":"heading","key":"h_desc","name":"Опис"},
  {"type":"textarea","key":"pl","name":"Склад польською","extra":true,
   "hint":"Через кому. Наприклад: łosoś, ser, ogórek"},
  {"type":"textarea","key":"ua","name":"Склад українською","extra":true},
  {"type":"textarea","key":"en","name":"Склад англійською","extra":true},
  {"type":"text","key":"pcs","name":"Кількість шматочків","extra":true,
   "hint":"Наприклад: 8. На фото буде «8 szt»."},
  {"type":"text","key":"vol","name":"Підпис замість кількості","extra":true,
   "hint":"Для напоїв і сетів: «0,33 l» або «36 szt + burger». Якщо заповнено — показується замість кількості шматочків."},

  {"type":"heading","key":"h_flags","name":"Позначки","hint":"Плашки над фото страви."},
  {"type":"checkbox","key":"promo","name":"Хіт місяця","extra":true,
   "hint":"Страва стає першою в меню з помаранчевою плашкою «Hit miesiąca». На напої й соуси не впливає."},
  {"type":"checkbox","key":"neu","name":"Новинка","extra":true,
   "hint":"Зелена плашка «Nowość». На ціну не впливає."},
  {"type":"select","key":"spicy","name":"Гострота","extra":true,
   "options":[{"value":"","label":"Не гостре"},{"value":"1","label":"Трохи гостре"},{"value":"2","label":"Гостре"},{"value":"3","label":"Дуже гостре"}],
   "hint":"Над фото зʼявляться перчики — від одного до трьох."},
  {"type":"checkbox","key":"veg","name":"Вегетаріанська","extra":true,
   "hint":"Над фото зʼявиться листочок."},
  {"type":"checkbox","key":"out","name":"Нема в наявності","extra":true,
   "hint":"Страва лишається в меню, але замовити її не можна. Зніміть галочку, коли знову буде."},

  {"type":"heading","key":"h_extra","name":"Додатки й тубус","hint":"Усе це гість вибирає, коли кладе страву в кошик."},
  {"type":"textarea","key":"addons","name":"Додатки за доплату","extra":true,
   "hint":"По одному в рядок: «Назва = ціна». Наприклад: Mozzarella = 8. Порожньо — вікна з додатками не буде."},
  {"type":"checkbox","key":"tube","name":"Можна в тубусі","extra":true,
   "hint":"У страви зʼявиться галочка «W tubusie». Доплата за тубус — у вкладці «Доставка та ціни», фото тубуса — у «Режимі роботи»."},

  {"type":"heading","key":"h_drinks","name":"Напої до страви","hint":"Безкоштовні й платні працюють разом: спершу гість обере подарункові, потім платний."},
  {"type":"select","key":"drinks","name":"Безкоштовних напоїв","extra":true,
   "options":[{"value":"","label":"Немає"},{"value":"1","label":"1 напій"},{"value":"2","label":"2 напої"},{"value":"3","label":"3 напої"},{"value":"4","label":"4 напої"}],
   "hint":"Скільки напоїв гість отримає в подарунок. Сайт попросить обрати рівно стільки."},
  {"type":"text","key":"drink_price","name":"Платний напій: доплата, zł","extra":true,
   "hint":"Впишіть суму — у страви зʼявиться галочка «з напоєм», і гість сам обере напій за цю доплату. Порожньо — галочки немає."},
  {"type":"multi-collection","key":"drink_list","name":"Які напої можна обрати","extra":true,
   "from":"menu","whereExtra":{"key":"cat","value":"drinks"},
   "hint":"Діє і на платний напій, і на безкоштовні. Нічого не позначено: для платного — усі напої меню, для безкоштовних — ті, що задані в «Режимі роботи»."},

  {"type":"heading","key":"h_sauces","name":"Соуси до страви","hint":"Так само: безкоштовні й платні можна поєднувати."},
  {"type":"select","key":"sauces","name":"Безкоштовних соусів","extra":true,
   "options":[{"value":"","label":"Немає"},{"value":"1","label":"1 соус"},{"value":"2","label":"2 соуси"},{"value":"3","label":"3 соуси"},{"value":"4","label":"4 соуси"}],
   "hint":"Скільки соусів гість отримає в подарунок."},
  {"type":"text","key":"sauce_price","name":"Платний соус: доплата, zł","extra":true,
   "hint":"Впишіть суму — у страви зʼявиться галочка «з соусом», і гість сам обере соус за цю доплату. Порожньо — галочки немає."},
  {"type":"multi-collection","key":"sauce_list","name":"Які соуси можна обрати","extra":true,
   "from":"menu","whereExtra":{"key":"cat","value":"sosy"},
   "hint":"Діє і на платний соус, і на безкоштовні. Нічого не позначено — усі соуси меню."},

  {"type":"heading","key":"h_when","name":"Коли показувати","hint":"Усе порожнє — страва в меню завжди. Наприклад, бізнес-ланч: з понеділка до пʼятниці, з 12:00 до 15:00."},
  {"type":"select","key":"day_from","name":"З дня","extra":true,
   "options":[{"value":"","label":"Щодня"},{"value":"1","label":"Понеділок"},{"value":"2","label":"Вівторок"},{"value":"3","label":"Середа"},{"value":"4","label":"Четвер"},{"value":"5","label":"Пʼятниця"},{"value":"6","label":"Субота"},{"value":"7","label":"Неділя"}]},
  {"type":"select","key":"day_to","name":"До дня (включно)","extra":true,
   "options":[{"value":"","label":"Щодня"},{"value":"1","label":"Понеділок"},{"value":"2","label":"Вівторок"},{"value":"3","label":"Середа"},{"value":"4","label":"Четвер"},{"value":"5","label":"Пʼятниця"},{"value":"6","label":"Субота"},{"value":"7","label":"Неділя"}],
   "hint":"Щоб працювало, оберіть обидва дні."},
  {"type":"select","key":"show_from","name":"З години","extra":true,"options":[{"value":"","label":"Без обмеження"},{"value":"06:00","label":"06:00"},{"value":"06:30","label":"06:30"},{"value":"07:00","label":"07:00"},{"value":"07:30","label":"07:30"},{"value":"08:00","label":"08:00"},{"value":"08:30","label":"08:30"},{"value":"09:00","label":"09:00"},{"value":"09:30","label":"09:30"},{"value":"10:00","label":"10:00"},{"value":"10:30","label":"10:30"},{"value":"11:00","label":"11:00"},{"value":"11:30","label":"11:30"},{"value":"12:00","label":"12:00"},{"value":"12:30","label":"12:30"},{"value":"13:00","label":"13:00"},{"value":"13:30","label":"13:30"},{"value":"14:00","label":"14:00"},{"value":"14:30","label":"14:30"},{"value":"15:00","label":"15:00"},{"value":"15:30","label":"15:30"},{"value":"16:00","label":"16:00"},{"value":"16:30","label":"16:30"},{"value":"17:00","label":"17:00"},{"value":"17:30","label":"17:30"},{"value":"18:00","label":"18:00"},{"value":"18:30","label":"18:30"},{"value":"19:00","label":"19:00"},{"value":"19:30","label":"19:30"},{"value":"20:00","label":"20:00"},{"value":"20:30","label":"20:30"},{"value":"21:00","label":"21:00"},{"value":"21:30","label":"21:30"},{"value":"22:00","label":"22:00"},{"value":"22:30","label":"22:30"},{"value":"23:00","label":"23:00"},{"value":"23:30","label":"23:30"}]},
  {"type":"select","key":"show_to","name":"Ховати після","extra":true,"options":[{"value":"","label":"Без обмеження"},{"value":"06:00","label":"06:00"},{"value":"06:30","label":"06:30"},{"value":"07:00","label":"07:00"},{"value":"07:30","label":"07:30"},{"value":"08:00","label":"08:00"},{"value":"08:30","label":"08:30"},{"value":"09:00","label":"09:00"},{"value":"09:30","label":"09:30"},{"value":"10:00","label":"10:00"},{"value":"10:30","label":"10:30"},{"value":"11:00","label":"11:00"},{"value":"11:30","label":"11:30"},{"value":"12:00","label":"12:00"},{"value":"12:30","label":"12:30"},{"value":"13:00","label":"13:00"},{"value":"13:30","label":"13:30"},{"value":"14:00","label":"14:00"},{"value":"14:30","label":"14:30"},{"value":"15:00","label":"15:00"},{"value":"15:30","label":"15:30"},{"value":"16:00","label":"16:00"},{"value":"16:30","label":"16:30"},{"value":"17:00","label":"17:00"},{"value":"17:30","label":"17:30"},{"value":"18:00","label":"18:00"},{"value":"18:30","label":"18:30"},{"value":"19:00","label":"19:00"},{"value":"19:30","label":"19:30"},{"value":"20:00","label":"20:00"},{"value":"20:30","label":"20:30"},{"value":"21:00","label":"21:00"},{"value":"21:30","label":"21:30"},{"value":"22:00","label":"22:00"},{"value":"22:30","label":"22:30"},{"value":"23:00","label":"23:00"},{"value":"23:30","label":"23:30"}],
   "hint":"Після цієї години страва зникає з меню сама."},

  {"type":"heading","key":"h_tech","name":"Технічне","adminOnly":true,"hint":"Бачить лише адмін платформи."},
  {"type":"text","key":"img","name":"Код вбудованого фото","extra":true,"adminOnly":true,
   "hint":"Не міняти: за ним страва бере фото з сайту, якщо своє не завантажене."}
]'::jsonb
          || coalesce((
               select jsonb_agg(f order by i)
               from jsonb_array_elements(c->'fields') with ordinality t1(f, i)
               where not (f->>'key' = any (array[
                 'h_main','title','cat','image','price','sale_price',
                 'h_desc','pl','ua','en','pcs','vol',
                 'h_flags','promo','neu','spicy','veg','out',
                 'h_extra','addons','tube',
                 'h_drinks','drinks','drink_price','drink_list',
                 'h_sauces','sauces','sauce_price','sauce_list',
                 'h_when','day_from','day_to','show_from','show_to',
                 'h_tech','img',
                 'sale','fill','pos']))
             ), '[]'::jsonb))

        when c->>'key' = 'settings' then jsonb_set(c, '{fields}',
          '[
  {"type":"heading","key":"h_day","name":"Вихідний"},
  {"type":"checkbox","key":"dayoff","name":"Сьогодні вихідний — сайт закрито","extra":true,
   "hint":"Поставте зранку: гість побачить банер і замовити не зможе. Наступного дня галочку зніміть."},
  {"type":"text","key":"msg_pl","name":"Текст банера польською","extra":true},
  {"type":"text","key":"msg_ua","name":"Текст банера українською","extra":true},
  {"type":"text","key":"msg_en","name":"Текст банера англійською","extra":true,
   "hint":"Можна лишити порожнім."},

  {"type":"heading","key":"h_hours","name":"Години кухні",
   "hint":"Від них залежать години на сайті й те, коли гість може замовити «якнайшвидше». Поза ними замовлення приймаються з вибором години."},
  {"type":"select","key":"open_from","name":"Кухня починає о","extra":true,"options":[{"value":"06:00","label":"06:00"},{"value":"06:30","label":"06:30"},{"value":"07:00","label":"07:00"},{"value":"07:30","label":"07:30"},{"value":"08:00","label":"08:00"},{"value":"08:30","label":"08:30"},{"value":"09:00","label":"09:00"},{"value":"09:30","label":"09:30"},{"value":"10:00","label":"10:00"},{"value":"10:30","label":"10:30"},{"value":"11:00","label":"11:00"},{"value":"11:30","label":"11:30"},{"value":"12:00","label":"12:00"},{"value":"12:30","label":"12:30"},{"value":"13:00","label":"13:00"},{"value":"13:30","label":"13:30"},{"value":"14:00","label":"14:00"},{"value":"14:30","label":"14:30"},{"value":"15:00","label":"15:00"},{"value":"15:30","label":"15:30"},{"value":"16:00","label":"16:00"},{"value":"16:30","label":"16:30"},{"value":"17:00","label":"17:00"},{"value":"17:30","label":"17:30"},{"value":"18:00","label":"18:00"},{"value":"18:30","label":"18:30"},{"value":"19:00","label":"19:00"},{"value":"19:30","label":"19:30"},{"value":"20:00","label":"20:00"},{"value":"20:30","label":"20:30"},{"value":"21:00","label":"21:00"},{"value":"21:30","label":"21:30"},{"value":"22:00","label":"22:00"},{"value":"22:30","label":"22:30"},{"value":"23:00","label":"23:00"},{"value":"23:30","label":"23:30"}]},
  {"type":"select","key":"open_to","name":"Кухня закінчує о","extra":true,"options":[{"value":"06:00","label":"06:00"},{"value":"06:30","label":"06:30"},{"value":"07:00","label":"07:00"},{"value":"07:30","label":"07:30"},{"value":"08:00","label":"08:00"},{"value":"08:30","label":"08:30"},{"value":"09:00","label":"09:00"},{"value":"09:30","label":"09:30"},{"value":"10:00","label":"10:00"},{"value":"10:30","label":"10:30"},{"value":"11:00","label":"11:00"},{"value":"11:30","label":"11:30"},{"value":"12:00","label":"12:00"},{"value":"12:30","label":"12:30"},{"value":"13:00","label":"13:00"},{"value":"13:30","label":"13:30"},{"value":"14:00","label":"14:00"},{"value":"14:30","label":"14:30"},{"value":"15:00","label":"15:00"},{"value":"15:30","label":"15:30"},{"value":"16:00","label":"16:00"},{"value":"16:30","label":"16:30"},{"value":"17:00","label":"17:00"},{"value":"17:30","label":"17:30"},{"value":"18:00","label":"18:00"},{"value":"18:30","label":"18:30"},{"value":"19:00","label":"19:00"},{"value":"19:30","label":"19:30"},{"value":"20:00","label":"20:00"},{"value":"20:30","label":"20:30"},{"value":"21:00","label":"21:00"},{"value":"21:30","label":"21:30"},{"value":"22:00","label":"22:00"},{"value":"22:30","label":"22:30"},{"value":"23:00","label":"23:00"},{"value":"23:30","label":"23:30"}]},

  {"type":"heading","key":"h_tube","name":"Тубус"},
  {"type":"image","key":"tube_photo","name":"Фото тубуса","extra":true,
   "hint":"Коли гість ставить галочку «W tubusie», фото страви міняється на це. Не завантажено — показується стандартне фото тубуса."},
  {"type":"checkbox","key":"tube_swap","name":"Міняти фото страви на тубус","extra":true,
   "hint":"Зніміть, щоб фото страви не мінялось зовсім. Доплата за тубус — у вкладці «Доставка та ціни»."},

  {"type":"heading","key":"h_drinks","name":"Безкоштовні напої"},
  {"type":"multi-collection","key":"free_drinks","name":"Що дарувати за замовчуванням","extra":true,
   "from":"menu","whereExtra":{"key":"cat","value":"drinks"},
   "hint":"Якщо в страві не позначено конкретних напоїв, гість обирає безкоштовний напій із цих. Краще позначати недорогі."},

  {"type":"heading","key":"h_tech","name":"Технічне","adminOnly":true,"hint":"Бачить лише адмін платформи."},
  {"type":"text","key":"title","name":"Назва картки","adminOnly":true}
]'::jsonb
          || coalesce((
               select jsonb_agg(f order by i)
               from jsonb_array_elements(c->'fields') with ordinality t1(f, i)
               where not (f->>'key' = any (array[
                 'h_day','dayoff','msg_pl','msg_ua','msg_en',
                 'h_hours','open_from','open_to',
                 'h_tube','tube_photo','tube_swap',
                 'h_drinks','free_drinks','h_tech','title']))
             ), '[]'::jsonb))

        when c->>'key' = 'cats' then jsonb_set(c, '{fields}',
          '[
  {"type":"text","key":"title","name":"Назва розділу",
   "hint":"Так вкладка підписана на сайті. Новий розділ зʼявиться в меню одразу після збереження."},
  {"type":"text","key":"catkey","name":"Код розділу","extra":true,"adminOnly":true,
   "hint":"Службовий: за ним страви привʼязані до розділу. Для нового розділу підставляється сам. У наявних НЕ міняти — страви відваляться."}
]'::jsonb)

        else c
      end
      order by idx
    )
    from jsonb_array_elements(s.config->'collections') with ordinality as t(c, idx)
  )
)
where s.id = 3;

-- Тексти: ті самі ключі, лише «zł» замість «zl»
update public.sites
set config = jsonb_set(config, '{texts}', '[
  {"key":"phone_view","name":"Телефон — як показувати",
   "hint":"Саме так номер побачить гість у контактах. Наприклад: +48 797 254 955"},
  {"key":"phone","name":"Телефон — для дзвінка",
   "hint":"Той самий номер, але суцільно і з кодом країни. На нього спрацює кнопка дзвінка. Наприклад: +48797254955"},
  {"key":"addr","name":"Адреса",
   "hint":"Показується в контактах і відкриває карти. Кома переносить на новий рядок. Наприклад: ul. Wolności 29, Jelenia Góra"},
  {"key":"instagram","name":"Instagram",
   "hint":"Можна вписати нік або повне посилання. Наприклад: @sushi_shark_jg"},
  {"key":"min_order","name":"Мінімальне замовлення на доставку, zł",
   "hint":"Саме число. Менше цієї суми кошик не дасть оформити доставку. Наприклад: 70"},
  {"key":"delivery_time","name":"Скільки триває доставка",
   "hint":"Напис на головній сторінці. Наприклад: ~60 min"},
  {"key":"tube_price","name":"Доплата за тубус, zł",
   "hint":"Саме число. Стільки додається до ціни, коли гість ставить галочку «W tubusie». Яким стравам доступний тубус — галочка «Можна в тубусі» в самій страві."}
]'::jsonb, true)
where id = 3;

-- Вкладки: перша тепер чесно називається «Режим роботи і налаштування»
update public.sites
set config = jsonb_set(config, '{sections}', '[
  {"name":"1. Режим роботи і налаштування",
   "note":"Вихідний, години кухні, фото тубуса й безкоштовні напої — у картці нижче, кнопка «Редагувати». Під нею — контакти, які видно на сайті.",
   "collections":["settings"],
   "texts":["phone_view","phone","addr","instagram"]},
  {"name":"2. Меню",
   "note":"Усі страви сайту. Щоб змінити ціну, склад, фото чи додатки — «Редагувати» біля страви. Нова страва зʼявляється на сайті одразу після збереження.",
   "collections":["menu","cats"]},
  {"name":"3. Доставка та ціни",
   "note":"Суми й підписи, які гість бачить у кошику та на головній.",
   "texts":["min_order","delivery_time","tube_price"]}
]'::jsonb, true)
where id = 3;

-- Тубус: тим 17 ролям, що мали його раніше (список був у коді), ставимо галочку
update public.items
set extra = extra || '{"tube":true}'::jsonb
where site_id = 3 and collection = 'menu'
  and extra->>'img' in ('p7','p13','p14','p18','p19','p20','p22','p23','p24',
                        'p34','p35','p45','p61','p71','p72','p73','p74')
  and extra->>'tube' is null;

-- Режим роботи: щоб галочки показували те, що вже діє на сайті
update public.items
set extra = extra
  || case when extra->>'tube_swap'   is null then '{"tube_swap":true}'::jsonb else '{}'::jsonb end
  || case when extra->>'free_drinks' is null then jsonb_build_object('free_drinks', 'Coca-Cola Zero' || chr(10) || 'Fanta' || chr(10) || 'Sprite') else '{}'::jsonb end
where site_id = 3 and collection = 'settings';


-- ---------- 17) Тубус і безкоштовні напої — окрема картка у вкладці «Меню» ----------
-- Раніше фото тубуса й подарункові напої сиділи в картці «Режим роботи»,
-- а доплата за тубус — у «Доставка та ціни». Тепер усе це в одній картці
-- над стравами (колекція menuset). Значення переносяться як є.
-- Можна запускати повторно.

-- а) нова картка — лише якщо її ще нема
insert into public.items (site_id, collection, title, text, price, image_url, extra, sort_order)
select 3, 'menuset', 'Тубус і безкоштовні напої', '', '',
       coalesce(st.extra->>'tube_photo', ''),
       jsonb_build_object(
         'tube_price',  coalesce((select value from public.texts where site_id = 3 and key = 'tube_price'), '7'),
         'tube_swap',   coalesce(st.extra->'tube_swap', 'true'::jsonb),
         'free_drinks', coalesce(st.extra->>'free_drinks', 'Coca-Cola Zero' || chr(10) || 'Fanta' || chr(10) || 'Sprite')),
       0
from (select 1) one
left join lateral (
  select extra from public.items
  where site_id = 3 and collection = 'settings'
  order by sort_order, id
  limit 1
) st on true
where not exists (select 1 from public.items where site_id = 3 and collection = 'menuset');

-- б) з картки «Режим роботи» ці значення прибираємо: тепер вони живуть у новій
update public.items
set extra = extra - 'tube_photo' - 'tube_swap' - 'free_drinks'
where site_id = 3 and collection = 'settings'
  and exists (select 1 from public.items where site_id = 3 and collection = 'menuset');

-- в) конфіг: нова колекція, «Режим роботи» без тубуса й напоїв, нові підказки в страві
update public.sites s
set config = jsonb_set(s.config, '{collections}', (
  select jsonb_agg(z.c order by z.idx)
  from (
    select
      case
        when col->>'key' = 'settings' then jsonb_set(col, '{fields}', coalesce((
            select jsonb_agg(f order by i)
            from jsonb_array_elements(col->'fields') with ordinality t1(f, i)
            where not (f->>'key' = any (array['h_tube','tube_photo','tube_swap','h_drinks','free_drinks']))
          ), '[]'::jsonb))
        when col->>'key' = 'menu' then jsonb_set(col, '{fields}', coalesce((
            select jsonb_agg(
              case f->>'key'
                when 'tube' then f || '{"hint":"У страви зʼявиться галочка «W tubusie». Доплата й фото тубуса — у картці «Тубус і безкоштовні напої» вгорі цієї вкладки."}'::jsonb
                when 'drink_list' then f || '{"hint":"Діє і на платний напій, і на безкоштовні. Нічого не позначено: для платного — усі напої меню, для безкоштовних — ті, що позначені в картці «Тубус і безкоштовні напої» вгорі цієї вкладки."}'::jsonb
                else f
              end order by i)
            from jsonb_array_elements(col->'fields') with ordinality t1(f, i)
          ), col->'fields'))
        else col
      end as c,
      idx
    from jsonb_array_elements(s.config->'collections') with ordinality t(col, idx)
    where col->>'key' <> 'menuset'
    union all
    select '{"key":"menuset","name":"Для всього меню","noAdd":true,"noDelete":true,"fields":[
  {"type":"heading","key":"h_tube","name":"Тубус",
   "hint":"Тубус — це туба-упаковка, у якій рол можна замовити за доплату. Галочку «W tubusie» гість бачить лише в тих стравах, де в картці страви стоїть «Можна в тубусі»."},
  {"type":"text","key":"tube_price","name":"Доплата за тубус, zł","extra":true,
   "hint":"Саме число. Стільки додається до ціни страви, коли гість ставить галочку «W tubusie». Наприклад: 7"},
  {"type":"image","key":"image","name":"Фото тубуса",
   "hint":"Коли гість ставить галочку, фото страви в меню міняється на це. Не завантажено — сайт покаже своє стандартне фото тубуса."},
  {"type":"checkbox","key":"tube_swap","name":"Міняти фото страви на фото тубуса","extra":true,
   "hint":"Зніміть галочку — фото страви лишиться своїм, зміниться тільки ціна."},

  {"type":"heading","key":"h_free","name":"Безкоштовні напої",
   "hint":"Стосується страв, у яких у блоці «Напої до страви» вибрано «Безкоштовних напоїв: 1» чи більше. Коли гість кладе таку страву в кошик, сайт просить обрати подарунковий напій."},
  {"type":"multi-collection","key":"free_drinks","name":"З яких напоїв гість обирає подарунок","extra":true,
   "from":"menu","whereExtra":{"key":"cat","value":"drinks"},
   "hint":"Позначте напої, які можна дати безкоштовно. Якщо в самій страві позначено свої напої — для неї діє її список, а не цей. Нічого не позначено — Coca-Cola Zero, Fanta, Sprite."},

  {"type":"heading","key":"h_tech","name":"Технічне","adminOnly":true,"hint":"Бачить лише адмін платформи."},
  {"type":"text","key":"title","name":"Назва картки","adminOnly":true}
]}'::jsonb, 1000
  ) z
))
where s.id = 3;

-- г) доплата за тубус більше не текст у «Доставка та ціни» — вона в новій картці
update public.sites
set config = jsonb_set(config, '{texts}', coalesce((
  select jsonb_agg(t order by i)
  from jsonb_array_elements(config->'texts') with ordinality x(t, i)
  where t->>'key' <> 'tube_price'
), '[]'::jsonb))
where id = 3;

-- ґ) вкладки. Номер адмінка ставить сама, тому в назвах його нема
--    (раніше виходило «1. 1. Режим роботи…»)
update public.sites
set config = jsonb_set(config, '{sections}', '[
  {"name":"Режим роботи та контакти",
   "note":"Вихідний і години кухні — у картці «Режим роботи», кнопка «Редагувати». Нижче — телефон, адреса та Instagram, які видно на сайті.",
   "collections":["settings"],
   "texts":["phone_view","phone","addr","instagram"]},
  {"name":"Меню",
   "note":"Угорі — картка «Тубус і безкоштовні напої»: вона діє на все меню одразу. Нижче — усі страви: щоб змінити ціну, склад, фото чи додатки, натисніть «Редагувати» біля страви. Нова страва зʼявляється на сайті одразу після збереження.",
   "collections":["menuset","menu","cats"]},
  {"name":"Доставка",
   "note":"Мінімальна сума замовлення й час доставки — їх гість бачить у кошику та на головній.",
   "texts":["min_order","delivery_time"]}
]'::jsonb, true)
where id = 3;
