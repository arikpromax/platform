-- ============================================================
--  ALEXON HOME SERVICES (Edmonton) у платформі адмінок
--  Згенеровано з D:/claude/.claude/alexon-gen/gen-cms.mjs — не правте руками.
--
--  Виконати в Supabase → SQL Editor (весь файл разом).
--  Повторний запуск безпечний: оновлюється лише опис адмінки,
--  тексти лягають через on conflict do nothing, а картки
--  засіваються тільки в порожні колекції — наредаговане не затреться.
-- ============================================================

-- ---------- 1) Сайт і опис адмінки ----------
insert into public.sites (slug, name, paid_until, config) values (
  'alexon',
  'Alexon Home Services (Edmonton)',
  current_date + 30,
  '{
  "collections": [
    {
      "key": "services",
      "name": "Послуги",
      "noAdd": true,
      "noDelete": true,
      "fields": [
        {
          "type": "text",
          "key": "title",
          "name": "Назва послуги",
          "hint": "Змінюється всюди: плитка на головній, меню, підвал, форма заявки, сторінка послуги."
        },
        {
          "type": "text",
          "key": "note",
          "name": "Підпис на плитці",
          "extra": true,
          "hint": "Короткий рядок під назвою — на плитці й у меню. Напр.: Patches, cracks, new walls"
        },
        {
          "type": "image",
          "key": "image",
          "name": "Фото на плитці",
          "aspect": 1.3333333333333333,
          "hint": "Горизонтальне. Без фото на плитці велика синя іконка."
        },
        {
          "type": "heading",
          "key": "h_page",
          "name": "Сторінка послуги",
          "hint": "Те, що видно, коли натиснути на плитку."
        },
        {
          "type": "text",
          "key": "sub",
          "name": "Підзаголовок",
          "extra": true,
          "hint": "Рядок під великою назвою. Напр.: Repair & installation in Edmonton"
        },
        {
          "type": "textarea",
          "key": "text",
          "name": "Короткий опис",
          "hint": "Абзац під заголовком, над кнопками «Call now» і «Get a price»."
        },
        {
          "type": "textarea",
          "key": "list",
          "name": "Що робимо (список)",
          "extra": true,
          "hint": "Кожен пункт з нового рядка: назва — пояснення. Напр.: Ceilings — Cracks and patches, with the texture matched."
        },
        {
          "type": "images",
          "key": "photos",
          "name": "Фото на сторінці послуги",
          "extra": true,
          "aspect": 1,
          "hint": "Блок «Photos». Квадратні, скільки завгодно. Поки фото немає — на сторінці порожні квадрати."
        },
        {
          "type": "text",
          "key": "key",
          "name": "Технічний код — не міняйте",
          "extra": true,
          "adminOnly": true,
          "hint": "За ним сайт знає, яка це сторінка."
        }
      ]
    },
    {
      "key": "jobs",
      "name": "Роботи «до / після»",
      "fields": [
        {
          "type": "text",
          "key": "title",
          "name": "Назва роботи",
          "hint": "Напр.: Fence staining"
        },
        {
          "type": "textarea",
          "key": "text",
          "name": "Опис",
          "hint": "Одне речення під назвою."
        },
        {
          "type": "textarea",
          "key": "facts",
          "name": "Деталі",
          "extra": true,
          "hint": "Кожен рядок — «назва: значення». Напр.: Finish: Dark brown stain"
        },
        {
          "type": "image",
          "key": "before",
          "name": "Фото «до»",
          "extra": true,
          "aspect": 0.75,
          "hint": "Вертикальне. Знімайте з того ж місця, що й «після» — тоді повзунок виглядає найкраще."
        },
        {
          "type": "image",
          "key": "image",
          "name": "Фото «після»",
          "aspect": 0.75,
          "hint": "Вертикальне."
        },
        {
          "type": "checkbox",
          "key": "flip",
          "name": "Віддзеркалити фото «до»",
          "extra": true,
          "hint": "Якщо «до» знято з протилежного боку — так половинки збігаються."
        }
      ]
    },
    {
      "key": "best",
      "name": "Фото робіт",
      "fields": [
        {
          "type": "text",
          "key": "title",
          "name": "Підпис",
          "hint": "Напр.: Fence staining"
        },
        {
          "type": "text",
          "key": "text",
          "name": "Рядок під підписом",
          "hint": "Напр.: Weathered wood brought back with a fresh stain."
        },
        {
          "type": "image",
          "key": "image",
          "name": "Фото",
          "aspect": 1,
          "hint": "Натиснувши на картку, клієнт бачить фото на весь екран."
        },
        {
          "type": "checkbox",
          "key": "big",
          "name": "Велика картка",
          "extra": true,
          "hint": "Великі стоять по дві в ряд, звичайні — по чотири. Найкраще: 2 великі, потім 4 звичайні."
        }
      ]
    },
    {
      "key": "reviews",
      "name": "Відгуки з Google",
      "fields": [
        {
          "type": "text",
          "key": "title",
          "name": "Імʼя клієнта",
          "hint": "Як у Google. Напр.: John S."
        },
        {
          "type": "text",
          "key": "place",
          "name": "Хто / звідки",
          "extra": true,
          "hint": "Напр.: Homeowner, Edmonton AB"
        },
        {
          "type": "textarea",
          "key": "text",
          "name": "Текст відгуку",
          "hint": "Копіюйте з Google без змін. Найкраще виглядають три відгуки."
        }
      ]
    },
    {
      "key": "why",
      "name": "Чому Alexon",
      "fields": [
        {
          "type": "text",
          "key": "title",
          "name": "Пункт",
          "hint": "Великими літерами зліва. Напр.: Clear price"
        },
        {
          "type": "textarea",
          "key": "text",
          "name": "Пояснення",
          "hint": "Один рядок справа."
        }
      ]
    },
    {
      "key": "faq",
      "name": "Питання",
      "fields": [
        {
          "type": "text",
          "key": "title",
          "name": "Питання",
          "hint": "Так, як його ставить клієнт. Напр.: Do you take small jobs?"
        },
        {
          "type": "textarea",
          "key": "text",
          "name": "Відповідь",
          "hint": "Розкривається, коли натиснути на питання. Напишіть {phone} — там стане номер з поля «Телефон»."
        }
      ]
    },
    {
      "key": "site_photos",
      "name": "Фото на сайті",
      "noAdd": true,
      "noDelete": true,
      "fields": [
        {
          "type": "image",
          "key": "image",
          "name": "Фото",
          "aspect": 1.3333333333333333,
          "hint": "Горизонтальне."
        }
      ]
    }
  ],
  "texts": [
    {
      "key": "phone",
      "name": "Телефон",
      "hint": "Один номер для всього сайту: шапка, кнопки «Call» і «Send a text», меню, форма, підвал. Напр.: 780-280-2404"
    },
    {
      "key": "area",
      "name": "Де працюєте (коротко)",
      "hint": "Під лого, у шапці, в About і над картою. Напр.: Edmonton & Area"
    },
    {
      "key": "area_note",
      "name": "Район роботи (у підвалі)",
      "hint": "Напр.: Edmonton and nearby communities"
    },
    {
      "key": "hours",
      "name": "Години роботи",
      "multiline": true,
      "hint": "У підвалі й у меню Contact. Два рядки: дні, потім години. Напр.: Monday – Friday ↵ 8 a.m. – 6 p.m."
    },
    {
      "key": "email",
      "name": "Email",
      "hint": "У підвалі. Порожньо — рядка немає."
    },
    {
      "key": "address",
      "name": "Поштова адреса",
      "multiline": true,
      "hint": "У підвалі, кожен рядок з нового. Порожньо — блоку немає."
    },
    {
      "key": "facebook",
      "name": "Facebook — посилання",
      "hint": "Повне посилання на сторінку. Порожньо — значки Facebook зникнуть."
    },
    {
      "key": "instagram",
      "name": "Instagram — посилання",
      "hint": "Порожньо — у підвалі його немає."
    },
    {
      "key": "tiktok",
      "name": "TikTok — посилання",
      "hint": "Порожньо — у підвалі його немає."
    },
    {
      "key": "google",
      "name": "Профіль у Google — посилання",
      "hint": "Alexon у Google Maps. Воно ж — «Read all reviews on Google» у блоці відгуків."
    },
    {
      "key": "svc_h",
      "name": "Великий заголовок біля телефону",
      "multiline": true,
      "hint": "Кожне слово з нового рядка. Ці ж слова — рядок у підвалі «Handyman · Renovation · Painting»."
    },
    {
      "key": "svc_lead",
      "name": "Рядок під заголовком",
      "multiline": true,
      "hint": "Напр.: Repairs, renovations and painting for homes in Edmonton and area."
    },
    {
      "key": "h_work",
      "name": "Заголовок блоку",
      "hint": "Напр.: Before & After"
    },
    {
      "key": "work_ask",
      "name": "Питання над кнопкою справа",
      "hint": "Напр.: Want the same result at your place?"
    },
    {
      "key": "h_best",
      "name": "Заголовок блоку",
      "hint": "Напр.: What we do best"
    },
    {
      "key": "h_reviews",
      "name": "Заголовок блоку",
      "hint": "Напр.: Reviews"
    },
    {
      "key": "rev_rating",
      "name": "Рейтинг у Google",
      "hint": "Число, як у Google. Напр.: 4.9. Порожньо — замість зірок значок Google."
    },
    {
      "key": "rev_count",
      "name": "Скільки відгуків у Google",
      "hint": "Напр.: 12. Посилання на профіль — у розділі «Контакти»."
    },
    {
      "key": "rev_write",
      "name": "Посилання «залишити відгук»",
      "hint": "З профілю Google: «Ask for reviews» → https://g.page/r/…/review. Кнопка «Leave a review» веде сюди."
    },
    {
      "key": "h_about",
      "name": "Заголовок блоку",
      "hint": "Напр.: About Alexon"
    },
    {
      "key": "about_p1",
      "name": "Перший абзац",
      "multiline": true
    },
    {
      "key": "about_p2",
      "name": "Другий абзац",
      "multiline": true
    },
    {
      "key": "owner",
      "name": "Власник",
      "hint": "Рядок «Owner» у таблиці. Напр.: Alexander"
    },
    {
      "key": "licence",
      "name": "Номер ліцензії",
      "hint": "Alberta prepaid contractor licence. Порожньо — рядка «Licence» немає."
    },
    {
      "key": "h_why",
      "name": "Заголовок блоку",
      "hint": "Напр.: Why Alexon"
    },
    {
      "key": "why_intro",
      "name": "Рядок під заголовком",
      "multiline": true
    },
    {
      "key": "h_faq",
      "name": "Заголовок блоку",
      "hint": "Напр.: Questions"
    },
    {
      "key": "h_contact",
      "name": "Заголовок форми",
      "multiline": true,
      "hint": "Кожен рядок з нового. Напр.: Let us ↵ call you"
    },
    {
      "key": "contact_lead",
      "name": "Рядок під заголовком форми",
      "multiline": true
    },
    {
      "key": "h_area",
      "name": "Заголовок над картою",
      "hint": "Напр.: Where we work"
    }
  ],
  "sections": [
    {
      "name": "Контакти й соцмережі",
      "texts": [
        "phone",
        "area",
        "area_note",
        "hours",
        "email",
        "address",
        "facebook",
        "instagram",
        "tiktok",
        "google"
      ],
      "note": "Вписуєте один раз — змінюється на всьому сайті одразу: шапка, кнопки, меню, форма, підвал. Порожнє поле — цього рядка на сайті просто немає."
    },
    {
      "name": "Послуги",
      "texts": [
        "svc_h",
        "svc_lead"
      ],
      "collections": [
        "services"
      ],
      "note": "Білий блок під лого: заголовок, рядок під ним і шість плиток. Кожна послуга — це й плитка, і своя сторінка: тут же її підзаголовок, опис, список робіт і фото."
    },
    {
      "name": "До і після",
      "texts": [
        "h_work",
        "work_ask"
      ],
      "collections": [
        "jobs"
      ],
      "note": "Велике фото з повзунком. Кожна робота — пара фото «до» і «після». Дві й більше — справа зʼявляються мініатюри для перемикання. Порядок у списку = порядок на сайті."
    },
    {
      "name": "Фото робіт",
      "texts": [
        "h_best"
      ],
      "collections": [
        "best"
      ],
      "note": "Картки з фото під блоком «до/після» (What we do best)."
    },
    {
      "name": "Відгуки",
      "texts": [
        "h_reviews",
        "rev_rating",
        "rev_count",
        "rev_write"
      ],
      "collections": [
        "reviews"
      ],
      "note": "Лише справжні відгуки з Google. Поки список порожній, на сайті — прохання залишити відгук і кнопка."
    },
    {
      "name": "Про Alexon",
      "texts": [
        "h_about",
        "about_p1",
        "about_p2",
        "owner",
        "licence"
      ],
      "photos": [
        "about"
      ],
      "note": "Білий блок з таблицею й фото справа."
    },
    {
      "name": "Чому Alexon",
      "texts": [
        "h_why",
        "why_intro"
      ],
      "collections": [
        "why"
      ],
      "note": "Темний блок з пунктами: великий текст зліва, пояснення справа."
    },
    {
      "name": "Питання",
      "texts": [
        "h_faq"
      ],
      "collections": [
        "faq"
      ],
      "note": "Питання, що розкриваються по кліку. Порядок у списку = порядок на сайті."
    },
    {
      "name": "Заявка й карта",
      "texts": [
        "h_contact",
        "contact_lead",
        "h_area"
      ],
      "note": "Синій блок з формою і карта під ним."
    }
  ]
}'::jsonb
)
on conflict (slug) do update set config = excluded.config, name = excluded.name;

-- ---------- картки: services ----------
with s as (select id from public.sites where slug = 'alexon')
insert into public.items (site_id, collection, title, text, image_url, extra, sort_order)
select s.id, v.collection, v.title, v.text, v.image_url, v.extra::jsonb, v.n
from s, (values
  ('services', 'Drywall', 'Holes, cracks and new walls — patched, taped and sanded smooth, ready for paint.', 'https://arikpromax.github.io/tubass/img/half-wall.webp', '{"key":"drywall","note":"Patches, cracks, new walls","sub":"Repair & installation in Edmonton","list":"Holes and cracks — Patched, taped and sanded so the repair disappears under paint.\nWater damage — Wet or stained drywall cut out and replaced.\nNew walls — Basements, partitions and walls after a renovation.\nCeilings — Cracks and patches, with the texture matched.\nFinishing — Taping, mudding and sanding to a smooth, paint-ready surface.","photos":[]}', 1),
  ('services', 'Painting', 'Rooms, trim, doors and fences — clean lines and a finish that lasts.', 'https://arikpromax.github.io/tubass/img/hallway.webp', '{"key":"painting","note":"Interior, exterior, fences","sub":"Interior painting & staining in Edmonton","list":"Rooms — Walls and ceilings with clean, straight cut lines.\nTrim and doors — Baseboards, casing and doors in a hard-wearing finish.\nFences and decks — Old wood cleaned up and stained. See the fence below.\nExterior — Siding, trim and garage door touch-ups.\nPrep — Furniture and floors covered, holes patched before the first coat.","photos":[]}', 2),
  ('services', 'Fences & Decks', 'Washing, staining and sealing for fences, decks and stone patios.', 'https://arikpromax.github.io/tubass/img/fence-wash.webp', '{"key":"fences-decks","note":"Washing, staining, sealing","sub":"Staining, washing & sealing in Edmonton","list":"Fence staining — Grey, weathered wood brought back with a fresh stain.\nPower washing — Dirt and old weathering washed off before the new coat.\nDeck staining — Decks cleaned and stained to stand up to sun and snow.\nStone and pool decks — Slate and pavers cleaned and sealed for a deep, wet look.\nSmall fence repairs — Loose boards and posts fixed before staining.","photos":[]}', 3),
  ('services', 'Flooring', 'Laminate and vinyl plank installed, damaged floors repaired.', '', '{"key":"flooring","note":"New floors and repairs","sub":"Installation & repair in Edmonton","list":"Laminate — Installed over proper underlay, with clean transitions.\nVinyl plank — Water-resistant floors for kitchens, bathrooms and basements.\nFloor repairs — Damaged boards replaced and squeaks fixed.\nBaseboards and transitions — The finishing pieces that make a floor look done.\nOld floor removal — Carpet and old flooring taken out before the install.","photos":[]}', 4),
  ('services', 'Repairs', 'The small jobs around the house that keep getting put off.', '', '{"key":"repairs","note":"Small jobs around the house","sub":"Handyman repairs in Edmonton","list":"Doors — Sticking, squeaking or not latching — fixed.\nMounting — TVs, shelves, mirrors, curtain rods and art.\nAssembly — Furniture, shelving and storage put together.\nCaulking — Tubs, showers, windows and baseboards resealed.\nSmall carpentry — Loose railings, cabinet doors, trim and the rest of the list.","photos":[]}', 5),
  ('services', 'Trim & Doors', 'Baseboards, casing and doors — cut tight and finished clean.', 'https://arikpromax.github.io/tubass/img/ceiling.jpg', '{"key":"trim-doors","note":"Baseboards, casing, doors","sub":"Baseboards, casing & doors in Edmonton","list":"Baseboards — New or replaced, cut tight and caulked.\nCasing — Door and window casing with clean mitres.\nInterior doors — New doors hung, adjusted and fitted with hardware.\nHardware — Handles, hinges and locks replaced.\nCrown moulding — A finished look for living rooms and bedrooms.","photos":[]}', 6)
) as v(collection, title, text, image_url, extra, n)
where not exists (select 1 from public.items i, s where i.site_id = s.id and i.collection = 'services');

-- ---------- картки: jobs ----------
with s as (select id from public.sites where slug = 'alexon')
insert into public.items (site_id, collection, title, text, image_url, extra, sort_order)
select s.id, v.collection, v.title, v.text, v.image_url, v.extra::jsonb, v.n
from s, (values
  ('jobs', 'Fence staining', 'A weathered fence brought back with a dark brown stain.', 'https://arikpromax.github.io/tubass/img/after.webp', '{"before":"https://arikpromax.github.io/tubass/img/before.webp","facts":"Finish: Dark brown stain\nService: Painting & staining","flip":true}', 1),
  ('jobs', 'Pool deck sealing', 'Slate cleaned and sealed for a deep, wet look.', 'https://arikpromax.github.io/tubass/img/pool-deck-2.webp', '{"before":"https://arikpromax.github.io/tubass/img/pool-deck-1.webp","facts":"Surface: Slate tile\nService: Cleaning & sealing","flip":false}', 2)
) as v(collection, title, text, image_url, extra, n)
where not exists (select 1 from public.items i, s where i.site_id = s.id and i.collection = 'jobs');

-- ---------- картки: best ----------
with s as (select id from public.sites where slug = 'alexon')
insert into public.items (site_id, collection, title, text, image_url, extra, sort_order)
select s.id, v.collection, v.title, v.text, v.image_url, v.extra::jsonb, v.n
from s, (values
  ('best', 'Pool deck sealing', 'Slate cleaned and sealed for a deep, wet look.', 'https://arikpromax.github.io/tubass/img/pool-deck-2.webp', '{"big":true}', 1),
  ('best', 'Fence staining', 'Weathered wood brought back with a fresh stain.', 'https://arikpromax.github.io/tubass/img/after.webp', '{"big":true}', 2),
  ('best', 'Interior painting', 'Walls and ceilings with clean, straight lines.', 'https://arikpromax.github.io/tubass/img/hallway.webp', '{"big":false}', 3),
  ('best', 'Drywall', 'Half walls, patches and smooth finishing.', 'https://arikpromax.github.io/tubass/img/half-wall.webp', '{"big":false}', 4),
  ('best', 'Ceilings', 'Fresh paint and an even finish.', 'https://arikpromax.github.io/tubass/img/ceiling.jpg', '{"big":false}', 5),
  ('best', 'Power washing', 'Fences and decks back to clean wood.', 'https://arikpromax.github.io/tubass/img/fence-wash.webp', '{"big":false}', 6)
) as v(collection, title, text, image_url, extra, n)
where not exists (select 1 from public.items i, s where i.site_id = s.id and i.collection = 'best');

-- ---------- картки: why ----------
with s as (select id from public.sites where slug = 'alexon')
insert into public.items (site_id, collection, title, text, image_url, extra, sort_order)
select s.id, v.collection, v.title, v.text, v.image_url, v.extra::jsonb, v.n
from s, (values
  ('why', 'One contact', 'You deal with Alexon directly, from the first call to the final clean-up.', '', '{}', 1),
  ('why', 'Clear price', 'You know the price before work starts. No surprise extras.', '', '{}', 2),
  ('why', 'Clean work', 'Floors and furniture covered, and the mess cleaned up after.', '', '{}', 3),
  ('why', 'Quick reply', 'Call or text and get an answer the same day.', '', '{}', 4),
  ('why', 'Local', 'Based in Edmonton, working across the city and area.', '', '{}', 5)
) as v(collection, title, text, image_url, extra, n)
where not exists (select 1 from public.items i, s where i.site_id = s.id and i.collection = 'why');

-- ---------- картки: faq ----------
with s as (select id from public.sites where slug = 'alexon')
insert into public.items (site_id, collection, title, text, image_url, extra, sort_order)
select s.id, v.collection, v.title, v.text, v.image_url, v.extra::jsonb, v.n
from s, (values
  ('faq', 'Do you take small jobs?', 'Yes. One patch, a sticking door or a whole list of small fixes — send it over and we’ll plan one visit.', '', '{}', 1),
  ('faq', 'How do I get a price?', 'Call or text {phone}, or send a few photos of the job. Small jobs can often be priced from photos; for bigger ones we come and take a look.', '', '{}', 2),
  ('faq', 'What areas do you cover?', 'Edmonton and nearby communities. Not sure you’re in the area? Just ask.', '', '{}', 3),
  ('faq', 'Do you supply the materials?', 'We can pick up everything the job needs, or work with materials you’ve already bought — whatever suits you.', '', '{}', 4),
  ('faq', 'Do you clean up after the job?', 'Yes. Floors and furniture are covered while we work, and we clean up before we leave.', '', '{}', 5),
  ('faq', 'When can you start?', 'It depends on the season and the size of the job. Call or text and we’ll give you the first free date.', '', '{}', 6)
) as v(collection, title, text, image_url, extra, n)
where not exists (select 1 from public.items i, s where i.site_id = s.id and i.collection = 'faq');

-- ---------- картки: site_photos ----------
with s as (select id from public.sites where slug = 'alexon')
insert into public.items (site_id, collection, title, text, image_url, extra, sort_order)
select s.id, v.collection, v.title, v.text, v.image_url, v.extra::jsonb, v.n
from s, (values
  ('site_photos', 'Фото в блоці «About Alexon»', '', 'https://arikpromax.github.io/tubass/img/pool-deck-1.webp', '{"slot":"about"}', 1)
) as v(collection, title, text, image_url, extra, n)
where not exists (select 1 from public.items i, s where i.site_id = s.id and i.collection = 'site_photos');

-- ---------- тексти ----------
with s as (select id from public.sites where slug = 'alexon')
insert into public.texts (site_id, key, value)
select s.id, v.key, v.value
from s, (values
  ('phone', '780-280-2404'),
  ('area', 'Edmonton & Area'),
  ('area_note', 'Edmonton and nearby communities'),
  ('hours', 'Monday – Friday
8 a.m. – 6 p.m.'),
  ('email', ''),
  ('address', ''),
  ('facebook', 'https://www.facebook.com/share/1EPT72c4Zw/'),
  ('instagram', ''),
  ('tiktok', ''),
  ('google', ''),
  ('svc_h', 'Handyman
Renovation
Painting'),
  ('svc_lead', 'Repairs, renovations and painting for homes in Edmonton and area.'),
  ('h_work', 'Before & After'),
  ('work_ask', 'Want the same result at your place?'),
  ('h_best', 'What we do best'),
  ('h_reviews', 'Reviews'),
  ('rev_rating', ''),
  ('rev_count', ''),
  ('rev_write', ''),
  ('h_about', 'About Alexon'),
  ('about_p1', 'A home services company in Edmonton. Handyman jobs, renovations and painting — from a single repair to a whole room.'),
  ('about_p2', 'Send a photo of the job by text — it’s the quickest way to get a price.'),
  ('owner', 'Alexander'),
  ('licence', ''),
  ('h_why', 'Why Alexon'),
  ('why_intro', 'A local handyman service for Edmonton homes. One call covers repairs, renovation and painting.'),
  ('h_faq', 'Questions'),
  ('h_contact', 'Let us
call you'),
  ('contact_lead', 'Tell us what needs doing. It comes to Alexon as a text message, and we call you back.'),
  ('h_area', 'Where we work')
) as v(key, value)
on conflict (site_id, key) do nothing;

-- ---------- номер сайту (вписати в alexon/platform.js → SITE) ----------
select id as "SITE для platform.js", slug, name from public.sites where slug = 'alexon';
