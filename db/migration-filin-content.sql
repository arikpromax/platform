-- ============================================================
--  КАФЕ «ФІЛІН» — крок 2: увесь вміст сайту в адмінку
--
--  Після цього файлу власник міняє з адмінки геть усе, що видно
--  на сайті: тексти першого екрана, номери, фотогалерею, меню
--  кафе, часті питання, контакти, фото.
--
--  Спершу мають бути виконані db/booking.sql і db/migration-filin.sql.
--  Повторний запуск безпечний: оновлюється лише config (він наш),
--  тексти лягають через on conflict do nothing, а картки
--  засіваються тільки в порожні колекції.
-- ============================================================

-- ---------- 1) Опис адмінки ----------
update public.sites set config = '{
  "booking": true,
  "collections": [
    {
      "key": "rooms",
      "name": "Номери",
      "fields": [
        {"type": "text", "key": "title", "name": "Назва номера",
         "hint": "Так його бачить гість. Наприклад: Стандарт"},
        {"type": "text", "key": "price", "name": "Ціна за ніч, грн",
         "hint": "Саме число, без слова «грн». Порожньо або 0 — на сайті буде «Ціну уточнимо»."},
        {"type": "images", "key": "photos", "name": "Фото номера", "extra": true,
         "hint": "Перше фото — головне: саме воно стоїть на картці на головній. Решту гість погортає на сторінці номера. Порядок міняється стрілочками, зайве прибирається хрестиком."},
        {"type": "text", "key": "units", "name": "Скільки таких номерів", "extra": true,
         "hint": "Найважливіше поле для календаря. Якщо номерів «Стандарт» у вас три — пишіть 3, і дата стане зайнятою лише коли розберуть усі три. Порожньо — вважаємо, що один."},
        {"type": "text", "key": "cap", "name": "Скільки гостей уміщує", "extra": true,
         "hint": "Число. За ним сайт не дає вибрати більше дорослих, ніж номер витримає. Наприклад: 2"},
        {"type": "text", "key": "meta", "name": "Короткий підпис", "extra": true,
         "hint": "Рядок під назвою на картці. Наприклад: До 2 гостей · двоспальне ліжко"},
        {"type": "textarea", "key": "text", "name": "Опис номера",
         "hint": "Абзац на сторінці номера, під заголовком «Про номер»."},
        {"type": "text", "key": "beds", "name": "Ліжка", "extra": true,
         "hint": "Як на сторінці номера після слова «Ліжка:». Наприклад: двоспальне ліжко"},
        {"type": "multi-collection", "key": "amenities", "name": "Що є в цьому номері", "extra": true,
         "from": "amenities",
         "hint": "Поставте галочки — саме вони зʼявляться на сторінці номера в блоці «Зручності». Список зручностей — нижче в цій же вкладці: додасте туди нову, і вона зʼявиться тут галочкою."}
      ],
      "autoKey": "key"
    },
    {
      "key": "amenities",
      "name": "Зручності (список для галочок)",
      "fields": [
        {"type": "text", "key": "title", "name": "Назва",
         "hint": "Коротко, як побачить гість. Наприклад: Холодильник"},
        {"type": "select", "key": "group", "name": "Розділ", "extra": true,
         "options": [
           {"value": "Ванна кімната", "label": "Ванна кімната"},
           {"value": "Спальня", "label": "Спальня"},
           {"value": "Інтернет", "label": "Інтернет"},
           {"value": "Медіа", "label": "Медіа"},
           {"value": "Кухня", "label": "Кухня"},
           {"value": "Інше", "label": "Інше"}
         ],
         "hint": "Під яким заголовком показати на сторінці номера. Значок розділу сайт підставить сам."},
        {"type": "checkbox", "key": "top", "name": "Показувати плиткою вгорі сторінки номера", "extra": true,
         "hint": "Для найголовнішого — як «Окрема ванна кімната» чи «Телевізор». Решта стоїть лише в списку зручностей."}
      ]
    },
    {
      "key": "gallery",
      "name": "Альбоми галереї",
      "fields": [
        {"type": "text", "key": "title", "name": "Назва альбому",
         "hint": "Підпис на картці. Наприклад: Зал кафе"},
        {"type": "images", "key": "photos", "name": "Фото альбому", "extra": true,
         "hint": "Перше фото стоїть на картці в галереї, решту гість погортає, коли її відкриє. Сайт сам порахує знімки й напише це на картці."}
      ]
    },
    {
      "key": "mcats",
      "name": "Розділи меню",
      "fields": [
        {"type": "text", "key": "title", "name": "Назва розділу",
         "hint": "Так він підписаний у меню. Наприклад: Сніданки"}
      ],
      "autoKey": "catkey"
    },
    {
      "key": "menu",
      "name": "Страви",
      "groupBy": "cat",
      "fields": [
        {"type": "text", "key": "title", "name": "Назва страви",
         "hint": "Наприклад: Сирники зі сметаною"},
        {"type": "text", "key": "price", "name": "Ціна, грн",
         "hint": "Саме число, без слова «грн». Наприклад: 140"},
        {"type": "image", "key": "image", "name": "Фото страви",
         "hint": "Немає фото — сайт намалює світлу заглушку."},
        {"type": "select-collection", "key": "cat", "name": "У якому розділі показувати", "extra": true,
         "from": "mcats",
         "hint": "Список береться з «Розділів меню» — перейменували розділ, і підпис зміниться скрізь."},
        {"type": "textarea", "key": "text", "name": "Опис (склад)",
         "hint": "Коротко, своїми словами. Наприклад: ніжні, з ванільним ароматом."},
        {"type": "checkbox", "key": "top", "name": "Показати в «Популярному» на головній", "extra": true}
      ]
    },
    {
      "key": "rules",
      "name": "Правила проживання",
      "fields": [
        {"type": "text", "key": "title", "name": "Назва правила",
         "hint": "Коротко, одним-двома словами. Наприклад: Куріння"},
        {"type": "textarea", "key": "text", "name": "Пояснення",
         "hint": "Що саме. Наприклад: У номерах не курять."},
        {"type": "select", "key": "icon", "name": "Значок", "extra": true,
         "options": [
           {"value": "card", "label": "Гроші / оплата"},
           {"value": "cancel", "label": "Скасування"},
           {"value": "smoke", "label": "Куріння"},
           {"value": "kids", "label": "Діти"},
           {"value": "clock", "label": "Час"},
           {"value": "dot", "label": "Інше"}
         ],
         "hint": "Маленька картинка зліва від назви."}
      ]
    },
    {
      "key": "faq",
      "name": "Часті питання",
      "fields": [
        {"type": "text", "key": "title", "name": "Питання",
         "hint": "Так, як його ставить гість. Наприклад: О котрій заїзд і виїзд?"},
        {"type": "textarea", "key": "text", "name": "Відповідь",
         "hint": "Коротко й по ділу — вона розкривається по кліку."}
      ]
    },
    {
      "key": "site_photos",
      "name": "Фото першого екрана",
      "noAdd": true,
      "noDelete": true,
      "fields": [
        {"type": "images", "key": "photos", "name": "Фото", "extra": true,
         "hint": "Для першого екрана можна кілька — вони змінюють одне одного кожні 6 секунд. Для решти місць береться перше фото. Горизонтальні, бажано від 2000 пікселів завширшки."}
      ]
    }
  ],
  "texts": [
    {"key": "hero_top", "name": "Перший екран: слово над назвою", "hint": "Наприклад: Кафе"},
    {"key": "hero_script", "name": "Перший екран: назва рукописним", "hint": "Наприклад: Філін"},
    {"key": "hero_place", "name": "Перший екран: де ви", "hint": "Наприклад: Кобеляки · Полтавщина"},
    {"key": "hero_lead1", "name": "Перший екран: перший рядок", "multiline": true},
    {"key": "hero_next1", "name": "Перший екран: другий заголовок", "hint": "Наприклад: Зупиніться поїсти"},
    {"key": "hero_lead2", "name": "Перший екран: другий рядок", "multiline": true},
    {"key": "hero_next2", "name": "Перший екран: третій заголовок", "hint": "Наприклад: Або лишіться на ніч"},
    {"key": "hero_lead3", "name": "Перший екран: третій рядок", "multiline": true},

    {"key": "rooms_eyebrow", "name": "Номери: дрібний рядок", "hint": "Наприклад: Номери"},
    {"key": "rooms_title", "name": "Номери: заголовок", "hint": "Наприклад: Відпочинок після дороги"},
    {"key": "rooms_more_eye", "name": "Номери: рядок у кінці списку", "hint": "Наприклад: Великою компанією?"},
    {"key": "rooms_more_h", "name": "Номери: заголовок у кінці списку"},
    {"key": "rooms_more_txt", "name": "Номери: текст у кінці списку", "multiline": true},

    {"key": "gallery_title", "name": "Галерея: заголовок"},

    {"key": "leisure_eyebrow", "name": "Відпочинок: дрібний рядок"},
    {"key": "leisure_title", "name": "Відпочинок: заголовок"},
    {"key": "leisure1_h", "name": "Картка 1: назва", "hint": "Веде на сторінку сауни"},
    {"key": "leisure1_txt", "name": "Картка 1: текст", "multiline": true},
    {"key": "leisure2_h", "name": "Картка 2: назва", "hint": "Веде на сторінку більярда"},
    {"key": "leisure2_txt", "name": "Картка 2: текст", "multiline": true},
    {"key": "leisure3_h", "name": "Картка 3: назва", "hint": "Веде на сторінку кафе"},
    {"key": "leisure3_txt", "name": "Картка 3: текст", "multiline": true},

    {"key": "kafe_eyebrow", "name": "Сторінка «Кафе»: дрібний рядок над назвою"},
    {"key": "kafe_title", "name": "Сторінка «Кафе»: назва на фото"},
    {"key": "kafe_p1", "name": "Сторінка «Кафе»: перший абзац", "multiline": true},
    {"key": "kafe_p2", "name": "Сторінка «Кафе»: другий абзац", "multiline": true},
    {"key": "menu_title", "name": "Сторінка меню: назва на фото"},
    {"key": "menu_lead", "name": "Сторінка меню: підпис під назвою", "multiline": true},

    {"key": "sauna_title", "name": "Сторінка «Сауна»: назва на фото"},
    {"key": "sauna_lead", "name": "Сторінка «Сауна»: підпис на фото", "multiline": true},
    {"key": "sauna_p1", "name": "Сауна: абзац 1", "multiline": true},
    {"key": "sauna_p2", "name": "Сауна: абзац 2", "multiline": true},
    {"key": "sauna_p3", "name": "Сауна: абзац 3", "multiline": true},
    {"key": "bilyard_title", "name": "Сторінка «Більярд»: назва на фото"},
    {"key": "bilyard_lead", "name": "Сторінка «Більярд»: підпис на фото", "multiline": true},
    {"key": "bilyard_p1", "name": "Більярд: абзац 1", "multiline": true},
    {"key": "bilyard_p2", "name": "Більярд: абзац 2", "multiline": true},

    {"key": "about_title", "name": "Сторінка «Про нас»: заголовок"},
    {"key": "about_text", "name": "Сторінка «Про нас»: текст", "multiline": true},

    {"key": "faq_eyebrow", "name": "Часті питання: дрібний рядок"},
    {"key": "faq_title", "name": "Часті питання: заголовок"},

    {"key": "route_title", "name": "Розташування: заголовок"},
    {"key": "route_text", "name": "Розташування: текст", "multiline": true},
    {"key": "route_address", "name": "Розташування: адреса"},
    {"key": "route_mark", "name": "Розташування: орієнтир"},
    {"key": "route_hours", "name": "Розташування: години кафе"},
    {"key": "drawer_meta", "name": "Меню-бургер: рядок унизу"},
    {"key": "foot_address", "name": "Підвал: адреса", "multiline": true,
     "hint": "Можна у два рядки — так і покажемо."},
    {"key": "foot_hours", "name": "Підвал: години", "multiline": true},
    {"key": "foot_copy", "name": "Підвал: нижній рядок"},

    {"key": "phone", "name": "Головний телефон",
     "hint": "Для кнопок «Зателефонувати». Наприклад: 068 155 85 95"},
    {"key": "phone2", "name": "Другий телефон", "hint": "Показується в підвалі поруч із першим."},
    {"key": "hours_open", "name": "Кафе відчиняється о",
     "hint": "Година у форматі 07:00. За нею сайт пише «зараз відкрито» або «зачинено»."},
    {"key": "hours_close", "name": "Кафе зачиняється о", "hint": "Наприклад: 23:00"},

    {"key": "check_in", "name": "Заїзд з", "hint": "Година у правилах проживання. Наприклад: 14:00"},
    {"key": "check_out", "name": "Виїзд до", "hint": "Наприклад: 11:00"},
    {"key": "sauna_price", "name": "Сауна: ціна за годину, грн",
     "hint": "Саме число. Порожньо або 0 — у вікні бронювання буде «ціну уточнимо»."},
    {"key": "prepay", "name": "Передоплата: скільки",
     "hint": "Текстом, як його побачить гість. Наприклад: за першу добу. Порожньо — сайт про передоплату взагалі не згадує."},
    {"key": "pay_recipient", "name": "Передоплата: отримувач",
     "hint": "Напр.: ФОП Прізвище Імʼя По батькові"},
    {"key": "pay_iban", "name": "Передоплата: IBAN",
     "hint": "Поки порожньо — сайт пише, що реквізити надішлете у відповідь."},
    {"key": "pay_edrpou", "name": "Передоплата: ЄДРПОУ або ІПН"},
    {"key": "pay_note", "name": "Передоплата: примітка", "multiline": true,
     "hint": "Рядок під реквізитами. Наприклад про умови скасування."}
  ],
  "sections": [
    {
      "name": "Перший екран",
      "note": "Те, що гість бачить першим: фото на весь екран і написи, які проявляються, поки він гортає.",
      "photos": ["hero"],
      "texts": ["hero_top", "hero_script", "hero_place", "hero_lead1", "hero_next1", "hero_lead2", "hero_next2", "hero_lead3"]
    },
    {
      "name": "Номери й ціни",
      "pin": true,
      "note": "Ціна за ніч, місткість і — найголовніше — скільки таких номерів у вас фізично. Саме від цього числа календар вирішує, чи показувати дату зайнятою.",
      "collections": ["rooms", "amenities"],
      "texts": ["rooms_eyebrow", "rooms_title", "rooms_more_eye", "rooms_more_h", "rooms_more_txt"]
    },
    {
      "name": "Фотогалерея",
      "note": "Альбоми на головній. Назва, обкладинка й решта фото — сайт сам порахує, скільки знімків у кожному.",
      "collections": ["gallery"],
      "texts": ["gallery_title"]
    },
    {
      "name": "Відпочинок на території",
      "note": "Три картки на головній: сауна, більярд і кафе. Кожна веде на свою сторінку.",
      "photos": ["leisure_sauna", "leisure_bilyard", "leisure_kafe"],
      "texts": ["leisure_eyebrow", "leisure_title", "leisure1_h", "leisure1_txt", "leisure2_h", "leisure2_txt", "leisure3_h", "leisure3_txt"]
    },
    {
      "name": "Кафе й меню",
      "pin": true,
      "note": "Страви, ціни й розділи меню — тут же фото й тексти сторінок «Кафе» та «Меню». Страву можна перенести в інший розділ прямо в її картці.",
      "photos": ["kafe", "menu"],
      "collections": ["mcats", "menu"],
      "texts": ["kafe_eyebrow", "kafe_title", "kafe_p1", "kafe_p2", "menu_title", "menu_lead"]
    },
    {
      "name": "Сауна й більярд",
      "note": "Фото й тексти двох окремих сторінок.",
      "photos": ["sauna", "bilyard"],
      "texts": ["sauna_title", "sauna_lead", "sauna_p1", "sauna_p2", "sauna_p3", "bilyard_title", "bilyard_lead", "bilyard_p1", "bilyard_p2"]
    },
    {
      "name": "Про нас",
      "photos": ["about"],
      "texts": ["about_title", "about_text"]
    },
    {
      "name": "Часті питання",
      "note": "Блок «Перед приїздом» на головній. Кожне питання розкривається по кліку.",
      "collections": ["faq"],
      "texts": ["faq_eyebrow", "faq_title"]
    },
    {
      "name": "Контакти й розташування",
      "note": "Адреса, орієнтир, телефони й графік. Змінюються одразу і на головній, і в підвалі кожної сторінки.",
      "texts": ["route_title", "route_text", "route_address", "route_mark", "route_hours", "phone", "phone2", "hours_open", "hours_close", "drawer_meta", "foot_address", "foot_hours", "foot_copy"]
    },
    {
      "name": "Бронювання й оплата",
      "note": "Правила проживання, години заїзду-виїзду, ціна сауни й реквізити для передоплати. Самі заявки — у вкладці «Бронювання».",
      "collections": ["rules"],
      "texts": ["check_in", "check_out", "sauna_price", "prepay", "pay_recipient", "pay_iban", "pay_edrpou", "pay_note"]
    }
  ]
}'::jsonb
where slug = 'filin';

-- ---------- 2) Тексти ----------
with s as (select id from public.sites where slug = 'filin')
insert into public.texts (site_id, key, value)
select s.id, v.key, v.value
from s, (values
  ('hero_top', 'Кафе'),
  ('hero_script', 'Філін'),
  ('hero_place', 'Кобеляки · Полтавщина'),
  ('hero_lead1', 'Домашня кухня, затишні номери та сауна.'),
  ('hero_next1', 'Зупиніться поїсти'),
  ('hero_lead2', 'Борщ, вареники, гаряче з печі — усе як удома.'),
  ('hero_next2', 'Або лишіться на ніч'),
  ('hero_lead3', 'Сауну прогріємо до вашого приїзду, а зранку на вас чекатиме сніданок.'),

  ('rooms_eyebrow', 'Номери'),
  ('rooms_title', 'Відпочинок після дороги'),
  ('rooms_more_eye', 'Великою компанією?'),
  ('rooms_more_h', 'Підберемо кілька номерів поруч'),
  ('rooms_more_txt', 'Номер уміщує до 4 гостей. Якщо вас більше — зателефонуйте, усе організуємо. А сауну прогріємо до вашого приїзду.'),

  ('gallery_title', 'Фотогалерея'),

  ('leisure_eyebrow', 'Відпочинок'),
  ('leisure_title', 'Усе поруч, на території'),
  ('leisure1_h', 'Сауна'),
  ('leisure1_txt', 'Прогрітися й відпочити після дороги. Вільний час і вартість підкажемо.'),
  ('leisure2_h', 'Більярд'),
  ('leisure2_txt', 'Партія для компанії ввечері, поки готується вечеря.'),
  ('leisure3_h', 'Кафе'),
  ('leisure3_txt', 'Домашня кухня щодня з 07:00 до 23:00 — сніданки, обіди й вечері.'),

  ('kafe_eyebrow', 'Кобеляки · щодня 07:00 — 23:00'),
  ('kafe_title', 'Кафе'),
  ('kafe_p1', 'Борщ, вареники, гаряче з печі — те, що готують удома, а не на потоці.'),
  ('kafe_p2', 'Хтось заїжджає пообідати дорогою на Дніпро, хтось сідає снідати о сьомій ранку, а хтось лишається на вечерю й ночує тут же, у номері.'),
  ('menu_title', 'Меню'),
  ('menu_lead', 'Оберіть страви заздалегідь — коли підійде офіціант, просто продиктуйте замовлення з кошика.'),

  ('sauna_title', 'Сауна'),
  ('sauna_lead', 'Прогрітися після дороги, посидіти компанією — і лишитися ночувати тут же, у номері.'),
  ('sauna_p1', 'Прогріваємо заздалегідь — щоб до вашого часу сауна вже була гаряча.'),
  ('sauna_p2', 'Якщо берете номер, замовити її можна там же, у вікні бронювання: є окремий крок «Сауна» — день, година й скільки годин топити.'),
  ('sauna_p3', 'Без номера теж можна — подзвоніть, підкажемо вільний час і ціну.'),
  ('bilyard_title', 'Більярд'),
  ('bilyard_lead', 'Партія для компанії ввечері — поки на кухні готується вечеря.'),
  ('bilyard_p1', 'Стіл працює в ті самі години, що й кафе — щодня з 07:00 до 23:00.'),
  ('bilyard_p2', 'Окремо домовлятися не треба: подзвоніть або спитайте на місці, і ми скажемо, чи вільний він зараз.'),

  ('about_title', 'Про нас'),
  ('about_text', 'Кафе з домашньою кухнею, номери й сауна — усе на одній території, на обʼїзній дорозі Кобеляк.'),

  ('faq_eyebrow', 'Корисно знати'),
  ('faq_title', 'Перед приїздом'),

  ('route_title', 'Наше розташування'),
  ('route_text', 'Кафе «Філін» — на обʼїзній дорозі Кобеляк, з боку виїзду в напрямку Дніпра.'),
  ('route_address', 'Кобеляки, Полтавська обл., обʼїзна дорога'),
  ('route_mark', 'виїзд у бік Дніпра'),
  ('route_hours', 'щодня 07:00 — 23:00'),
  ('drawer_meta', 'Кобеляки · щодня 07:00 — 23:00'),
  ('foot_address', E'Кобеляки, Полтавська обл.\nвиїзд у бік Дніпра, обʼїзна дорога'),
  ('foot_hours', E'Щодня\n07:00 — 23:00'),
  ('foot_copy', '© 2026 Кафе «Філін» · Кобеляки')
) as v(key, value)
on conflict (site_id, key) do nothing;

-- ---------- 3) Фото першого екрана ----------
--  Кожне місце на сайті, де стоїть фото, — окремий рядок зі своїм «slot».
--  Адмінка показує ці рядки у вкладці того блока, де фото на сайті.

-- самі старі порожні слоти першого екрана (hero1/hero2) більше не потрібні
delete from public.items
where collection = 'site_photos'
  and site_id = (select id from public.sites where slug = 'filin')
  and extra->>'slot' in ('hero1', 'hero2')
  and coalesce(image_url, '') = '';

-- рядок першого екрана з минулого запуску був без slot — даємо йому
update public.items set extra = extra || '{"slot":"hero"}'::jsonb
where collection = 'site_photos'
  and site_id = (select id from public.sites where slug = 'filin')
  and coalesce(extra->>'slot', '') = '';

with s as (select id from public.sites where slug = 'filin')
insert into public.items (site_id, collection, title, extra, sort_order)
select s.id, 'site_photos', v.title, jsonb_build_object('slot', v.slot, 'photos', '[]'::jsonb), v.n
from s, (values
  ('hero',            'Фото на весь екран (можна кілька)', 1),
  ('leisure_sauna',   'Картка «Сауна» на головній', 2),
  ('leisure_bilyard', 'Картка «Більярд» на головній', 3),
  ('leisure_kafe',    'Картка «Кафе» на головній', 4),
  ('kafe',            'Сторінка «Кафе» — фото вгорі', 5),
  ('menu',            'Сторінка меню — фото вгорі', 6),
  ('sauna',           'Сторінка «Сауна» — фото', 7),
  ('bilyard',         'Сторінка «Більярд» — фото', 8),
  ('about',           'Сторінка «Про нас» — фото', 9)
) as v(slot, title, n)
where not exists (
  select 1 from public.items i
  where i.site_id = s.id and i.collection = 'site_photos' and i.extra->>'slot' = v.slot);

-- ---------- 4) Часті питання ----------
with s as (select id from public.sites where slug = 'filin')
insert into public.items (site_id, collection, title, text, sort_order)
select s.id, 'faq', v.q, v.a, v.n
from s, (values
  ('О котрій заїзд і виїзд?', 'Заїзд — з 14:00, виїзд — до 12:00. Приїжджаєте раніше чи пізніше — напишіть, підлаштуємося.', 1),
  ('Чи є стоянка?', 'Так, безкоштовна стоянка біля мотелю — для легкових авто й вантажівок.', 2),
  ('Можна оплатити карткою?', 'Так, готівкою або карткою — і в кафе, і за номер.', 3),
  ('Можна з тваринами?', 'Невеликих тварин — за попередньою домовленістю. Напишіть нам перед приїздом.', 4),
  ('Як забронювати сауну чи більярд?', 'Сауну — позначте «Прогріти сауну», коли бронюєте номер, і до вашого часу вона буде гаряча. Про більярд напишіть нам або зателефонуйте.', 5)
) as v(q, a, n)
where not exists (
  select 1 from public.items i, s where i.site_id = s.id and i.collection = 'faq');

-- ---------- 5) Альбоми галереї ----------
with s as (select id from public.sites where slug = 'filin')
insert into public.items (site_id, collection, title, extra, sort_order)
select s.id, 'gallery', v.title, v.extra::jsonb, v.n
from s, (values
  ('Зал кафе', '{"icon":"cup"}', 1),
  ('Домашні страви', '{"icon":"dish"}', 2),
  ('Сауна', '{"icon":"sauna"}', 3),
  ('Більярд', '{"icon":"billiard"}', 4),
  ('Тераса', '{"icon":"sun"}', 5),
  ('Вечір у «Філіні»', '{"icon":"moon"}', 6)
) as v(title, extra, n)
where not exists (
  select 1 from public.items i, s where i.site_id = s.id and i.collection = 'gallery');

-- ---------- 6) Меню кафе ----------
--  УВАГА: страви й ціни тут умовні — вони були прикладом і на сайті.
--  Власник замінює їх в адмінці, вкладка «Кафе й меню».
with s as (select id from public.sites where slug = 'filin')
insert into public.items (site_id, collection, title, text, price, extra, sort_order)
select s.id, v.collection, v.title, v.text, v.price, v.extra::jsonb, v.sort_order
from s, (values
('mcats', 'Сніданки', '', '', '{"catkey":"snidanky"}', 1),
  ('mcats', 'Закуски', '', '', '{"catkey":"zakusky"}', 2),
  ('mcats', 'Салати', '', '', '{"catkey":"salaty"}', 3),
  ('mcats', 'Перші страви', '', '', '{"catkey":"pershi"}', 4),
  ('mcats', 'Основні страви', '', '', '{"catkey":"osnovni"}', 5),
  ('mcats', 'Гарніри', '', '', '{"catkey":"harniry"}', 6),
  ('mcats', 'Десерти', '', '', '{"catkey":"deserty"}', 7),
  ('mcats', 'Напої', '', '', '{"catkey":"napoi"}', 8),
  ('menu', 'Сирники зі сметаною', 'Ніжні, з ванільним ароматом.', '140', '{"cat":"snidanky","dishid":"syrnyky","top":true}', 1),
  ('menu', 'Омлет з овочами', 'Три яйця, помідори, перець, зелень.', '120', '{"cat":"snidanky","dishid":"omlet"}', 2),
  ('menu', 'Яєчня з беконом', 'Подаємо з тостом.', '130', '{"cat":"snidanky","dishid":"yaiechnia"}', 3),
  ('menu', 'Млинці з сиром', 'Зі сметаною або варенням.', '120', '{"cat":"snidanky","dishid":"mlyntsi"}', 4),
  ('menu', 'Сало з часником', 'Домашнє сало, чорний хліб, гірчиця.', '95', '{"cat":"zakusky","dishid":"salo"}', 5),
  ('menu', 'Оселедець з картоплею', 'З червоною цибулею та олією.', '110', '{"cat":"zakusky","dishid":"oseledets"}', 6),
  ('menu', 'Мариновані гриби', 'З цибулею та олією.', '90', '{"cat":"zakusky","dishid":"hryby"}', 7),
  ('menu', 'М’ясна тарілка', 'Асорті домашніх м’ясних делікатесів.', '190', '{"cat":"zakusky","dishid":"miasna"}', 8),
  ('menu', 'Олів’є', 'Класичний, з домашнім майонезом.', '110', '{"cat":"salaty","dishid":"olivie"}', 9),
  ('menu', 'Овочевий салат', 'Свіжі овочі, олія, зелень.', '95', '{"cat":"salaty","dishid":"ovochevyi"}', 10),
  ('menu', 'Цезар з куркою', 'Курка, пармезан, сухарики, соус.', '160', '{"cat":"salaty","dishid":"tsezar"}', 11),
  ('menu', 'Вінегрет', 'Буряк, квашена капуста, огірок.', '85', '{"cat":"salaty","dishid":"vinehret"}', 12),
  ('menu', 'Борщ з пампушками', 'Наваристий, зі сметаною та часником.', '95', '{"cat":"pershi","dishid":"borshch","top":true}', 13),
  ('menu', 'Курячий бульйон', 'З домашньою локшиною та зеленню.', '80', '{"cat":"pershi","dishid":"bulion"}', 14),
  ('menu', 'Розсольник', 'З перловкою та солоним огірком.', '85', '{"cat":"pershi","dishid":"rozsolnyk"}', 15),
  ('menu', 'Солянка', 'М’ясна, з лимоном і маслинами.', '120', '{"cat":"pershi","dishid":"solianka"}', 16),
  ('menu', 'Деруни зі сметаною', 'Гарячі, з хрусткою скоринкою.', '120', '{"cat":"osnovni","dishid":"deruny","top":true}', 17),
  ('menu', 'Вареники з картоплею', 'Зі смаженою цибулею та сметаною.', '110', '{"cat":"osnovni","dishid":"vareniky","top":true}', 18),
  ('menu', 'Голубці', 'У томатно-сметанному соусі.', '140', '{"cat":"osnovni","dishid":"holubtsi"}', 19),
  ('menu', 'Котлета по-київськи', 'З вершковим маслом усередині.', '190', '{"cat":"osnovni","dishid":"kotleta"}', 20),
  ('menu', 'Свинина на грилі', 'Соковита, з печеною картоплею.', '230', '{"cat":"osnovni","dishid":"svynyna"}', 21),
  ('menu', 'Печеня в горщику', 'Свинина з картоплею та грибами.', '180', '{"cat":"osnovni","dishid":"pechenia"}', 22),
  ('menu', 'Картопляне пюре', '', '50', '{"cat":"harniry","dishid":"piure"}', 23),
  ('menu', 'Гречка з маслом', '', '45', '{"cat":"harniry","dishid":"hrechka"}', 24),
  ('menu', 'Овочі гриль', '', '70', '{"cat":"harniry","dishid":"ovochi"}', 25),
  ('menu', 'Медовик', 'Домашній, з ніжним кремом.', '90', '{"cat":"deserty","dishid":"medovyk"}', 26),
  ('menu', 'Наполеон', 'Листкове тісто, заварний крем.', '90', '{"cat":"deserty","dishid":"napoleon"}', 27),
  ('menu', 'Млинці з варенням', '', '85', '{"cat":"deserty","dishid":"mlyntsi-varennia"}', 28),
  ('menu', 'Узвар', 'З сушених яблук і груш.', '40', '{"cat":"napoi","dishid":"uzvar"}', 29),
  ('menu', 'Компот', 'Ягідний, домашній.', '40', '{"cat":"napoi","dishid":"kompot"}', 30),
  ('menu', 'Домашній лимонад', '', '60', '{"cat":"napoi","dishid":"lymonad"}', 31),
  ('menu', 'Чай', 'Чорний, зелений або трав’яний.', '35', '{"cat":"napoi","dishid":"chai"}', 32),
  ('menu', 'Кава', 'Еспресо, американо або з молоком.', '50', '{"cat":"napoi","dishid":"kava"}', 33)
) as v(collection, title, text, price, extra, sort_order)
where not exists (
  select 1 from public.items i, s
  where i.site_id = s.id and i.collection in ('menu', 'mcats'));

-- ---------- 7а) Зручності — список для галочок ----------
with s as (select id from public.sites where slug = 'filin')
insert into public.items (site_id, collection, title, extra, sort_order)
select s.id, 'amenities', v.title, v.extra::jsonb, v.n
from s, (values
  ('Окрема ванна кімната', '{"group":"Ванна кімната","top":true}', 1),
  ('Душ', '{"group":"Ванна кімната"}', 2),
  ('Туалет', '{"group":"Ванна кімната"}', 3),
  ('Рушники', '{"group":"Ванна кімната"}', 4),
  ('Постільна білизна', '{"group":"Спальня"}', 5),
  ('Безкоштовний Wi-Fi', '{"group":"Інтернет"}', 6),
  ('Телевізор', '{"group":"Медіа","top":true}', 7)
) as v(title, extra, n)
where not exists (
  select 1 from public.items i, s where i.site_id = s.id and i.collection = 'amenities');

-- Наявні номери: ліжка й ті самі зручності, що стояли на сайті.
-- Лише де ще порожньо — наредаговане власником не чіпаємо.
update public.items i
set extra = i.extra
  || jsonb_build_object('beds', v.beds)
  || jsonb_build_object('amenities', E'Окрема ванна кімната\nДуш\nТуалет\nРушники\nПостільна білизна\nБезкоштовний Wi-Fi\nТелевізор')
from (values
  ('odnomisnyi', 'односпальне ліжко'),
  ('standart', 'двоспальне ліжко'),
  ('tvin', 'два окремі ліжка'),
  ('lyuks', 'двоспальне ліжко й диван'),
  ('simeinyi', 'кілька спальних місць')
) as v(key, beds)
where i.collection = 'rooms'
  and i.extra->>'key' = v.key
  and i.site_id = (select id from public.sites where slug = 'filin')
  and coalesce(i.extra->>'amenities', '') = '';

-- ---------- 7б) Правила проживання ----------
--  Години заїзду й виїзду лишаються окремими полями (вони ж ідуть
--  у вікно бронювання), тут — решта правил.
with s as (select id from public.sites where slug = 'filin')
insert into public.items (site_id, collection, title, text, extra, sort_order)
select s.id, 'rules', v.title, v.txt, v.extra::jsonb, v.n
from s, (values
  ('Оплата', 'Передоплата за номер за реквізитами, решта — на місці.', '{"icon":"card"}', 1),
  ('Скасування', 'Скасувати бронь без втрат можна не пізніше ніж за 5 днів до заїзду. Пізніше передоплата не повертається.', '{"icon":"cancel"}', 2),
  ('Куріння', 'У номерах не курять.', '{"icon":"smoke"}', 3),
  ('Діти', 'Дітей приймаємо, без вікових обмежень.', '{"icon":"kids"}', 4)
) as v(title, txt, extra, n)
where not exists (
  select 1 from public.items i, s where i.site_id = s.id and i.collection = 'rules');

-- Описи номерів і страв, вписані в адмінці раніше, лягали в extra.text,
-- а сайт читає колонку text. Переносимо, щоб нічого не загубилось.
update public.items
set text = extra->>'text', extra = extra - 'text'
where site_id = (select id from public.sites where slug = 'filin')
  and collection in ('rooms', 'menu')
  and coalesce(extra->>'text', '') <> '';

-- ---------- 7) Сторінки номерів, які вже є у сайті ----------
update public.items i set extra = i.extra || jsonb_build_object('page', v.page)
from (values
  ('odnomisnyi', 'odnomisnyi.html'),
  ('standart', 'standart.html'),
  ('tvin', 'tvin.html'),
  ('lyuks', 'lyuks.html'),
  ('simeinyi', 'simeinyi.html')
) as v(key, page)
where i.collection = 'rooms'
  and i.extra->>'key' = v.key
  and i.site_id = (select id from public.sites where slug = 'filin')
  and coalesce(i.extra->>'page', '') = '';

select 'Готово. Тепер з адмінки редагується весь сайт.' as "крок 2";
