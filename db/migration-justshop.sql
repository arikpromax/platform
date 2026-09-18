-- ============================================================
--  JUST SHOP у платформі адмінок
--  Виконати ОДИН раз у Supabase → SQL Editor (весь файл разом).
--  Повторний запуск безпечний: конфіг оновиться, вміст не задвоїться.
-- ============================================================

-- 1) Сайт і опис його адмінки
insert into public.sites (slug, name, paid_until, config) values (
  'justshop',
  'Just shop',
  current_date + 30,
  '{"sections":[{"name":"Головний екран","note":"Перший екран сайту: рядок дрібним шрифтом угорі, банер із фото та підказки, які самі друкуються в рядку пошуку.","texts":["hero_kick1","hero_kick2"],"collections":["wishes"],"photos":["hero1","hero2","hero3","hero4"]},{"name":"Каталог і розпродаж","note":"Товари й категорії. Якщо у товару заповнити «Стару ціну», він сам зʼявиться в блоці «Розпродаж», а на картці стане червоний бейдж зі знижкою.","texts":["sale_title","catalog_title"],"collections":["cats","products"]},{"name":"Клуби","note":"Блок про партнерство з футбольними клубами на головній.","texts":["clubs_kicker","clubs_title"],"collections":["clubs"]},{"name":"Часті питання","note":"Список питань-відповідей унизу головної. Розгортаються по кліку.","texts":["faq_title"],"collections":["faq"]},{"name":"Доставка й оплата","note":"Сторінка «Доставка й оплата». Блоки показуються в тому ж порядку, що й тут.","texts":["dlv_lead","free_from","pickup","trk_lead","size_lead"],"collections":["delivery","payment","returns"]},{"name":"Контакти й підвал","note":"Сторінка «Контакти» і нижня частина всіх сторінок.","texts":["phone","hours","ig","tg","tiktok","claim","footer_text"],"collections":["contacts"]}],"collections":[{"key":"cats","name":"Категорії","autoKey":"catkey","fields":[{"key":"title","name":"Назва","type":"text","hint":"Як написано в меню категорій: «Взуття», «Куртки»"},{"key":"icon","name":"Значок","type":"select","extra":true,"options":[{"value":"sneaker","label":"Кросівок"},{"value":"jacket","label":"Куртка"},{"value":"hoodie","label":"Кофта"},{"value":"suit","label":"Костюм"},{"value":"vest","label":"Жилетка"},{"value":"pants","label":"Штани"},{"value":"tee","label":"Футболка"},{"value":"shorts","label":"Шорти"},{"value":"socks","label":"Шкарпетки"},{"value":"cap","label":"Кепка"},{"value":"beanie","label":"Шапка"},{"value":"bag","label":"Сумка"}],"hint":"Малюнок біля назви в стрічці категорій"}]},{"key":"products","name":"Товари","fields":[{"key":"title","name":"Назва","type":"text","hint":"Без бренду: «Air Max Plus TN»"},{"key":"brand","name":"Бренд","type":"text","extra":true,"hint":"напр. Nike"},{"key":"cat","name":"Категорія","type":"select-collection","from":"cats","extra":true},{"key":"price","name":"Ціна, грн","type":"text","hint":"Тільки число: 3490"},{"key":"old","name":"Стара ціна, грн","type":"text","extra":true,"hint":"Заповнити — товар піде в «Розпродаж» зі знижкою. Порожньо — знижки немає"},{"key":"stock","name":"Є в наявності","type":"checkbox","extra":true,"hint":"Знято — кнопка стає «Замовити під запит», на картці бейдж «Під запит»"},{"key":"sizes","name":"Розміри","type":"text","extra":true,"hint":"Через кому: S, M, L, XL. Якщо розмір один — покупцю не доведеться обирати"},{"key":"tag","name":"Мітка","type":"select","extra":true,"options":[{"value":"","label":"без мітки"},{"value":"hit","label":"Хіт"},{"value":"new","label":"Нове"},{"value":"last","label":"Останній розмір"}]},{"key":"text","name":"Опис","type":"textarea"},{"key":"image","name":"Фото","type":"image"}]},{"key":"wishes","name":"Підказки в пошуку","fields":[{"key":"title","name":"Текст","type":"text","hint":"Друкується сам у рядку пошуку: «Nike Tech Fleece»"}]},{"key":"clubs","name":"Клуби","fields":[{"key":"mono","name":"Літери на гербі","type":"text","extra":true,"hint":"2-4 літери: FCR"},{"key":"title","name":"Назва клубу","type":"text"},{"key":"text","name":"Підпис","type":"text","hint":"напр. Екіпірування основного складу"}]},{"key":"faq","name":"Питання","fields":[{"key":"title","name":"Питання","type":"text"},{"key":"text","name":"Відповідь","type":"textarea"}]},{"key":"delivery","name":"Доставка: блоки","fields":[{"key":"title","name":"Заголовок","type":"text"},{"key":"text","name":"Абзац","type":"textarea","hint":"Коротке пояснення під заголовком"},{"key":"list","name":"Список пунктів","type":"textarea","extra":true,"hint":"Кожен пункт з нового рядка. Порожньо — списку не буде"}]},{"key":"payment","name":"Оплата: блоки","fields":[{"key":"title","name":"Заголовок","type":"text"},{"key":"text","name":"Абзац","type":"textarea","hint":"Коротке пояснення під заголовком"},{"key":"list","name":"Список пунктів","type":"textarea","extra":true,"hint":"Кожен пункт з нового рядка. Порожньо — списку не буде"}]},{"key":"returns","name":"Обмін і повернення","fields":[{"key":"title","name":"Заголовок","type":"text"},{"key":"text","name":"Абзац","type":"textarea","hint":"Коротке пояснення під заголовком"},{"key":"list","name":"Список пунктів","type":"textarea","extra":true,"hint":"Кожен пункт з нового рядка. Порожньо — списку не буде"}]},{"key":"contacts","name":"Контакти: блоки","fields":[{"key":"title","name":"Заголовок","type":"text"},{"key":"text","name":"Абзац","type":"textarea","hint":"Коротке пояснення під заголовком"},{"key":"list","name":"Список пунктів","type":"textarea","extra":true,"hint":"Кожен пункт з нового рядка. Порожньо — списку не буде"},{"key":"link","name":"Посилання","type":"text","extra":true,"hint":"Повна адреса з https://. Порожньо — посилання не буде"},{"key":"linkText","name":"Підпис посилання","type":"text","extra":true,"hint":"напр. @just_shop____"}]},{"key":"site_photos","name":"Фото банера","noAdd":true,"noDelete":true,"fields":[{"key":"title","name":"Де стоїть","type":"text"},{"key":"slot","name":"Технічний код місця","type":"text","extra":true,"hint":"Не чіпати"},{"key":"image","name":"Фото","type":"image","hint":"Вертикальний кадр, від 1200 px заввишки"}]}],"texts":[{"key":"hero_kick1","name":"Головний екран: рядок угорі, ліворуч"},{"key":"hero_kick2","name":"Головний екран: рядок угорі, партнерство"},{"key":"sale_title","name":"Розпродаж: заголовок"},{"key":"catalog_title","name":"Каталог: заголовок"},{"key":"clubs_kicker","name":"Клуби: дрібний підпис"},{"key":"clubs_title","name":"Клуби: заголовок"},{"key":"faq_title","name":"Питання: заголовок"},{"key":"dlv_lead","name":"Доставка: абзац угорі сторінки","multiline":true},{"key":"free_from","name":"Безкоштовна доставка від суми, грн","multiline":false},{"key":"pickup","name":"Самовивіз: місто й умови","multiline":true},{"key":"trk_lead","name":"Відстеження: абзац","multiline":true},{"key":"size_lead","name":"Розмірна сітка: абзац","multiline":true},{"key":"phone","name":"Контакти: телефон"},{"key":"hours","name":"Контакти: графік"},{"key":"ig","name":"Посилання на Instagram"},{"key":"tg","name":"Посилання на Telegram"},{"key":"tiktok","name":"Посилання на TikTok"},{"key":"claim","name":"Підвал: гасло"},{"key":"footer_text","name":"Підвал: абзац під гаслом","multiline":true}]}'
)
on conflict (slug) do update set config = excluded.config, name = excluded.name;

-- 2) Перенесення нинішнього вмісту сайту.
--    Кожна колекція заповнюється, лише якщо вона ще порожня, —
--    щоб не затерти те, що власник уже наредагував.
--    extra приводимо до jsonb явно: у списку значень літерал вважається текстом.
with s as (select id from public.sites where slug = 'justshop')
insert into public.items (site_id, collection, title, text, price, image_url, extra, sort_order)
select s.id, v.collection, v.title, v.text, v.price, v.image_url, v.extra::jsonb, v.sort_order
from s, (values
  ('cats', 'Взуття', '', '', '', '{"catkey":"vzuttia","icon":"sneaker"}', 1),
  ('cats', 'Куртки', '', '', '', '{"catkey":"kurtky","icon":"jacket"}', 2),
  ('cats', 'Кофти', '', '', '', '{"catkey":"kofty","icon":"hoodie"}', 3),
  ('cats', 'Костюми', '', '', '', '{"catkey":"kostiumy","icon":"suit"}', 4),
  ('cats', 'Жилетки', '', '', '', '{"catkey":"zhyletky","icon":"vest"}', 5),
  ('cats', 'Штани', '', '', '', '{"catkey":"shtany","icon":"pants"}', 6),
  ('cats', 'Футболки', '', '', '', '{"catkey":"futbolky","icon":"tee"}', 7),
  ('cats', 'Шорти', '', '', '', '{"catkey":"shorty","icon":"shorts"}', 8),
  ('cats', 'Шкарпетки', '', '', '', '{"catkey":"shkarpetky","icon":"socks"}', 9),
  ('cats', 'Аксесуари', '', '', '', '{"catkey":"aksesuary","icon":"cap"}', 10),
  ('products', 'Air Max Plus TN', 'Класика, яку впізнають з десяти метрів. Верх — щільний сітчастий текстиль із термошвами, підошва Tuned Air.', '3490', '', '{"brand":"Nike","cat":"vzuttia","old":"4200","stock":true,"sizes":"39, 40, 41, 42, 43, 44, 45","tag":"hit"}', 1),
  ('products', 'Samba OG', 'Найпопулярніша пара останніх сезонів. Шкіряний верх, замшевий носок, гумова підошва-гам.', '2890', '', '{"brand":"adidas","cat":"vzuttia","old":"","stock":true,"sizes":"39, 40, 41, 42, 43, 44, 45","tag":"hit"}', 2),
  ('products', '2002R Protection Pack', 'Замша та сітка, амортизація N-ERGY і ABZORB. Пара, яка витримує місто щодня.', '3790', '', '{"brand":"New Balance","cat":"vzuttia","old":"","stock":true,"sizes":"39, 40, 41, 42, 43, 44, 45","tag":"new"}', 3),
  ('products', 'Air Jordan 1 Low', 'Низький силует легендарної моделі. Натуральна шкіра, перфорація на носку.', '3990', '', '{"brand":"Jordan","cat":"vzuttia","old":"","stock":true,"sizes":"39, 40, 41, 42, 43, 44, 45","tag":""}', 4),
  ('products', 'XT-6', 'Трейлова база, яка стала міською. Quicklace, Contagrip, посадка як у кросівок для бігу.', '4290', '', '{"brand":"Salomon","cat":"vzuttia","old":"4900","stock":true,"sizes":"39, 40, 41, 42, 43, 44, 45","tag":"last"}', 5),
  ('products', 'Gel-Kayano 14', 'Срібна класика 2000-х. Гелева амортизація, багатошаровий верх.', '3590', '', '{"brand":"Asics","cat":"vzuttia","old":"","stock":true,"sizes":"39, 40, 41, 42, 43, 44, 45","tag":""}', 6),
  ('products', 'Knu Skool', 'Товстий замшевий верх і пухкий язик — форма 90-х без стилізації.', '2290', '', '{"brand":"Vans","cat":"vzuttia","old":"","stock":true,"sizes":"39, 40, 41, 42, 43, 44, 45","tag":""}', 7),
  ('products', 'Nuptse 1996', 'Пух 700, водовідштовхувальне покриття, фіксація по низу. Зима в місті закрита.', '8900', '', '{"brand":"The North Face","cat":"kurtky","old":"","stock":true,"sizes":"S, M, L, XL, XXL","tag":"hit"}', 8),
  ('products', 'Goggle Jacket Chrome-R', 'Та сама куртка з лінзами на капюшоні. Матеріал Chrome-R, лінзи Mille Miglia.', '12400', '', '{"brand":"C.P. Company","cat":"kurtky","old":"","stock":false,"sizes":"S, M, L, XL, XXL","tag":"last"}', 9),
  ('products', 'Detroit Jacket', 'Щільний канвас, підкладка-ковдра, комір із вельвету. Зношується красиво.', '6400', '', '{"brand":"Carhartt WIP","cat":"kurtky","old":"7100","stock":true,"sizes":"S, M, L, XL, XXL","tag":""}', 10),
  ('products', 'Rainforest Winter', 'Анорак із прапорцем на грудях, хутро на капюшоні, кишеня-кенгуру.', '7200', '', '{"brand":"Napapijri","cat":"kurtky","old":"","stock":true,"sizes":"S, M, L, XL, XXL","tag":"new"}', 11),
  ('products', 'Beta LT Gore-Tex', 'Мембрана Gore-Tex 3L, проклеєні шви, вага близько 400 г. Дощ і вітер більше не питання.', '14900', '', '{"brand":"Arc''teryx","cat":"kurtky","old":"","stock":false,"sizes":"S, M, L, XL, XXL","tag":""}', 12),
  ('products', 'Tech Fleece Hoodie', 'Тришаровий фліс: тепло без обʼєму. Найчастіший запит у директі — тримаємо в наявності.', '3290', '', '{"brand":"Nike","cat":"kofty","old":"3900","stock":true,"sizes":"S, M, L, XL, XXL","tag":"hit"}', 13),
  ('products', 'Garment Dyed Crewneck', 'Фарбування в готовому виробі, знімний компас на рукаві.', '9800', '', '{"brand":"Stone Island","cat":"kofty","old":"","stock":true,"sizes":"S, M, L, XL, XXL","tag":""}', 14),
  ('products', 'Polo Bear Hoodie', 'Щільний футер із вишитим ведмедем. Розмір беріть свій — сидить рівно.', '5400', '', '{"brand":"Ralph Lauren","cat":"kofty","old":"","stock":true,"sizes":"S, M, L, XL, XXL","tag":"new"}', 15),
  ('products', 'Storm Full-Zip', 'Тренувальна кофта з водовідштовхувальним покриттям і високим коміром.', '2790', '', '{"brand":"Under Armour","cat":"kofty","old":"","stock":true,"sizes":"S, M, L, XL, XXL","tag":""}', 16),
  ('products', 'Tech Fleece Set', 'Кофта + штани одним комплектом. Найчастіший подарунок із нашого каталогу.', '5900', '', '{"brand":"Nike","cat":"kostiumy","old":"6800","stock":true,"sizes":"S, M, L, XL, XXL","tag":"hit"}', 17),
  ('products', 'Adicolor Firebird Set', 'Три смуги, глянцевий трикотаж, звужені штани. Форма, яка не старіє.', '4200', '', '{"brand":"adidas","cat":"kostiumy","old":"","stock":true,"sizes":"S, M, L, XL, XXL","tag":""}', 18),
  ('products', 'Tracksuit Sport', 'Костюм із фактурного трикотажу, крокодил на грудях, манжети в рубчик.', '6900', '', '{"brand":"Lacoste","cat":"kostiumy","old":"","stock":true,"sizes":"S, M, L, XL, XXL","tag":"new"}', 19),
  ('products', 'Nuptse Vest', 'Пуховий жилет на міжсезоння: під куртку або поверх худі.', '6200', '', '{"brand":"The North Face","cat":"zhyletky","old":"","stock":true,"sizes":"S, M, L, XL, XXL","tag":""}', 20),
  ('products', 'Shell-R Vest', 'Технічна оболонка Shell-R, приховані кишені, компас на липучці.', '11200', '', '{"brand":"Stone Island","cat":"zhyletky","old":"","stock":false,"sizes":"S, M, L, XL, XXL","tag":"last"}', 21),
  ('products', 'Single Knee Pant', 'Робочий крій із посиленим коліном. Тканина розноситься під вас.', '3600', '', '{"brand":"Carhartt WIP","cat":"shtany","old":"","stock":true,"sizes":"S, M, L, XL, XXL","tag":""}', 22),
  ('products', 'Tech Fleece Joggers', 'Ті самі джогери, що й у комплекті, окремо. Манжет по щиколотці.', '3100', '', '{"brand":"Nike","cat":"shtany","old":"","stock":true,"sizes":"S, M, L, XL, XXL","tag":"hit"}', 23),
  ('products', 'Silver Ridge Convertible', 'Штани, що розстібаються в шорти. Omni-Shade, швидко сохнуть.', '2600', '', '{"brand":"Columbia","cat":"shtany","old":"3000","stock":true,"sizes":"S, M, L, XL, XXL","tag":""}', 24),
  ('products', 'Custom Slim Tee', 'Бавовна з довгим волокном, вишитий поні, рівний низ.', '1290', '', '{"brand":"Ralph Lauren","cat":"futbolky","old":"","stock":true,"sizes":"S, M, L, XL, XXL","tag":""}', 25),
  ('products', 'Flag Logo Tee', 'Щільний джерсі 180 г, класичний прапорець на грудях.', '1190', '', '{"brand":"Tommy Hilfiger","cat":"futbolky","old":"1490","stock":true,"sizes":"S, M, L, XL, XXL","tag":"new"}', 26),
  ('products', 'Sportswear Club Tee', 'База, якої завжди мало. Пряма посадка, гумований свош.', '890', '', '{"brand":"Nike","cat":"futbolky","old":"","stock":true,"sizes":"S, M, L, XL, XXL","tag":""}', 27),
  ('products', 'Dri-FIT Shorts', 'Легкі шорти для залу й вулиці, вологовідвідна тканина.', '1190', '', '{"brand":"Nike","cat":"shorty","old":"","stock":true,"sizes":"S, M, L, XL, XXL","tag":""}', 28),
  ('products', 'Traveler Swim Shorts', 'Плавальні шорти з сіткою всередині та бічними кишенями.', '1890', '', '{"brand":"Ralph Lauren","cat":"shorty","old":"","stock":true,"sizes":"S, M, L, XL, XXL","tag":""}', 29),
  ('products', 'Everyday Cushioned, 3 пари', 'Три пари в упаковці, махрова стопа, високий манжет.', '390', '', '{"brand":"Nike","cat":"shkarpetky","old":"","stock":true,"sizes":"39-42, 42-46","tag":"hit"}', 30),
  ('products', 'Classic Socks, 3 пари', 'Бавовняні шкарпетки з вишитим поні. Три кольори в наборі.', '490', '', '{"brand":"Ralph Lauren","cat":"shkarpetky","old":"","stock":true,"sizes":"39-42, 42-46","tag":""}', 31),
  ('products', 'Club Cap', 'Кепка з вигнутим козирком і металевою застібкою.', '890', '', '{"brand":"Nike","cat":"aksesuary","old":"","stock":true,"sizes":"One size","tag":""}', 32),
  ('products', 'Essentials Bag', 'Поясна сумка з канвасу, тримає телефон, ключі й павербанк.', '1690', '', '{"brand":"Carhartt WIP","cat":"aksesuary","old":"","stock":true,"sizes":"One size","tag":"new"}', 33),
  ('products', 'Dock Worker Beanie', 'Шапка в рубчик із товстим відворотом і нашивкою.', '990', '', '{"brand":"The North Face","cat":"aksesuary","old":"1200","stock":true,"sizes":"One size","tag":""}', 34),
  ('wishes', 'Nike Tech Fleece', '', '', '', '{}', 1),
  ('wishes', 'adidas Samba OG', '', '', '', '{}', 2),
  ('wishes', 'Stone Island', '', '', '', '{}', 3),
  ('wishes', 'The North Face Nuptse', '', '', '', '{}', 4),
  ('wishes', 'Arc’teryx', '', '', '', '{}', 5),
  ('wishes', 'New Balance 2002R', '', '', '', '{}', 6),
  ('wishes', 'Salomon XT-6', '', '', '', '{}', 7),
  ('clubs', 'ФК «Ростянець»', 'Екіпірування основного складу', '', '', '{"mono":"FCR"}', 1),
  ('clubs', 'ФК Rebel Київ', 'Тренувальна форма та мерч', '', '', '{"mono":"RBL"}', 2),
  ('faq', 'Це справді оригінал?', 'Так. Речі викуповуються в європейських магазинах і на офіційних майданчиках. До відправлення надсилаємо фото бірок, коробки й чека — перевіряєте до того, як платите решту.', '', '', '{}', 1),
  ('faq', 'Скільки чекати?', 'Те, що є в наявності в Києві, їде Новою Поштою наступного дня. Замовлення під запит — 3—10 днів: 1—2 дні на викуп і 3—8 на дорогу з Європи.', '', '', '{}', 2),
  ('faq', 'Як оплачувати?', 'На картку ФОП або наложеним платежем Нової Пошти. Для речей під запит — передоплата 50%, решта перед відправленням.', '', '', '{}', 3),
  ('faq', 'А якщо не підійде розмір?', 'Обмін протягом 14 днів, якщо річ не носили й бірки на місці. Доставку на обмін ділимо навпіл. На речі під індивідуальний запит обмін узгоджуємо окремо до викупу.', '', '', '{}', 4),
  ('faq', 'Ви працюєте з клубами?', 'Так, ми офіційний партнер ФК «Ростянець» і ФК Rebel Київ: екіпірування, тренувальні комплекти й мерч для команд. Умови для команд — у директі.', '', '', '{}', 5),
  ('site_photos', 'Банер, кадр 1', '', '', '', '{"slot":"hero1"}', 1),
  ('site_photos', 'Банер, кадр 2', '', '', '', '{"slot":"hero2"}', 2),
  ('site_photos', 'Банер, кадр 3', '', '', '', '{"slot":"hero3"}', 3),
  ('site_photos', 'Банер, кадр 4', '', '', '', '{"slot":"hero4"}', 4),
  ('delivery', 'Відділення', 'Найдешевший і найшвидший спосіб. Місто й номер відділення підставляються в кошику з бази Нової Пошти — помилитися в адресі неможливо.', '', '', '{"list":"1—2 дні по Україні\nТариф НП, оплачується при отриманні\nВід 3 000 грн доставку оплачуємо ми"}', 1),
  ('delivery', 'Поштомат', 'Зручно, якщо не встигаєте на відділення: посилка чекає у скриньці, код приходить у СМС.', '', '', '{"list":"Забрати можна цілодобово\nОбмеження за розміром — великі куртки й коробки не поміщаються\nЗберігання до 3 днів"}', 2),
  ('delivery', 'Курʼєр Нової Пошти', 'Привезуть на вашу адресу. Вкажіть у коментарі підʼїзд, поверх і зручний час — передамо перевізнику.', '', '', '{"list":"Тариф НП + послуга адресної доставки\nДзвінок за 30—60 хвилин до приїзду"}', 3),
  ('delivery', 'Самовивіз, Київ', 'Безкоштовно. Точну адресу й час надсилаємо після підтвердження замовлення — можна приміряти на місці.', '', '', '{"list":"0 грн\nЩодня 10:00 — 21:00\nПриміряти можна перед оплатою"}', 4),
  ('payment', 'На картку ФОП', 'Реквізити надсилаємо після того, як підтвердимо наявність і розмір. За потреби даємо чек.', '', '', '{"list":"Речі в наявності — 100% перед відправленням\nРечі під запит — 50% передоплати, решта перед відправкою з Європи"}', 1),
  ('payment', 'Наложений платіж', 'Оплата при отриманні на відділенні. Нова Пошта бере власну комісію за переказ грошей — це не наша націнка.', '', '', '{"list":"Доступно для замовлень із наявності\nДля речей під запит — після передоплати 50%"}', 2),
  ('returns', '14 днів на обмін', 'Якщо річ не носили, вигляд і бірки збережені, а пакування ціле — міняємо на інший розмір або колір.', '', '', '{"list":"Напишіть у Telegram або Instagram із номером замовлення\nДоставку на обмін ділимо навпіл\nРечі під індивідуальний запит — умови узгоджуємо до викупу"}', 1),
  ('returns', 'Якщо щось не так', 'Розпакуйте посилку на відділенні й перевірте вміст. Помилилися ми — відправлення й повернення за наш рахунок.', '', '', '{"list":"Прийшов не той розмір або модель — міняємо без питань\nЗаводський брак — повертаємо повну суму\nШкарпетки й білизна обміну не підлягають"}', 2),
  ('contacts', 'Instagram', 'Основний канал: наявність, нові надходження, відповіді на запити щодня.', '', '', '{"list":"","link":"https://www.instagram.com/just_shop____","linkText":"@just_shop____"}', 1),
  ('contacts', 'Telegram', 'Канал із дропами й цінами. Туди ж надсилайте текст замовлення з кошика.', '', '', '{"list":"","link":"https://t.me/+Slwgs7ppLQI4N2Uy","linkText":"Перейти в канал"}', 2),
  ('contacts', 'TikTok', 'Відео з наявності й розпакування — видно, як річ виглядає в русі, а не на фото.', '', '', '{"list":"","link":"https://www.tiktok.com/@just_shop____","linkText":"@just_shop____"}', 3),
  ('contacts', 'Самовивіз у Києві', 'Адресу й час надсилаємо після підтвердження замовлення. Приміряти можна на місці, до оплати.', '', '', '{"list":"Щодня 10:00 — 21:00\nДоставка по Україні — Нова Пошта"}', 4)
) as v(collection, title, text, price, image_url, extra, sort_order)
where not exists (
  select 1 from public.items i
  where i.site_id = s.id and i.collection = v.collection
);

-- 3) Тексти. Уже змінені власником не чіпаємо.
with s as (select id from public.sites where slug = 'justshop')
insert into public.texts (site_id, key, value)
select s.id, v.key, v.value from s, (values
  ('hero_kick1', 'Just shop · Київ'),
  ('hero_kick2', 'Офіційний партнер ФК «Ростянець» · ФК Rebel Київ'),
  ('sale_title', 'Розпродаж'),
  ('catalog_title', 'Каталог'),
  ('clubs_kicker', 'Команди'),
  ('clubs_title', 'Екіпіруємо футбольні клуби'),
  ('faq_title', 'Часті питання'),
  ('dlv_lead', 'Відправляємо в день оплати, якщо річ у наявності. Замовлення під запит їде після викупу в Європі — це 3—10 днів разом із дорогою.'),
  ('free_from', '3000'),
  ('pickup', 'Київ, самовивіз — адресу надсилаємо після підтвердження'),
  ('trk_lead', 'Введіть номер накладної — покажемо статус прямо тут, без переходу на сайт перевізника.'),
  ('size_lead', 'Виміри самої речі в сантиметрах. Якщо ви між двома розмірами — беріть більший: майже весь streetwear шиють вільно.'),
  ('phone', '+380 00 000 00 00'),
  ('hours', 'Щодня 10:00 — 21:00'),
  ('ig', 'https://www.instagram.com/just_shop____'),
  ('tg', 'https://t.me/+Slwgs7ppLQI4N2Uy'),
  ('tiktok', 'https://www.tiktok.com/@just_shop____'),
  ('claim', 'Оригінальні речі з Європи'),
  ('footer_text', 'Привозимо з Європи те, чого немає в наявності: від пари кросівок до повного комплекту для команди.')
) as v(key, value)
on conflict (site_id, key) do nothing;

-- 4) Номер сайту — його треба вписати в data.js сайту (CFG.siteId)
select id as "site_id для data.js", slug, name from public.sites where slug = 'justshop';
