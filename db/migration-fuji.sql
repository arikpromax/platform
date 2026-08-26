-- ============================================================
--  Fuji Sushi (Умань) — підключення до адмінки arawebsite
--  Згенеровано з fuji/data.js. Запускати у SQL Editor платформи.
--
--  БЕЗПЕЧНИЙ ДЛЯ ПОВТОРНОГО ЗАПУСКУ.
--  Картки засіваються лише якщо колекція порожня, тексти —
--  on conflict do nothing. Нічого з наредагованого власником
--  цей файл не стирає. Оновлюється тільки config сайту —
--  він наш, не власників.
-- ============================================================

insert into public.sites (id, slug, name, paid_until, config) values (
  5, 'fuji', 'Fuji Sushi (Умань)', current_date + 30,
  '{"collections":[{"key":"menu","name":"Страви","groupBy":"cat","rowToggle":{"flag":"ban","label":"банер","title":"Показати цю страву банером угорі головної"},"fields":[{"type":"text","key":"title","name":"Назва страви","hint":"Так її побачить покупець. Наприклад: Філадельфія з лососем"},{"type":"text","key":"price","name":"Ціна, грн","hint":"Саме число, без слова «грн». Наприклад: 279"},{"type":"text","key":"promo","name":"Ціна за акцією, грн","extra":true,"hint":"Заповніть, щоб запустити акцію: на сайті стара ціна стане закресленою, поруч зʼявиться нова і жовта плашка «АКЦІЯ». Щоб акцію прибрати — очистіть це поле. Приклад: звичайна 279, тут 199."},{"type":"image","key":"image","name":"Фото страви","hint":"Якщо фото немає — сайт намалює умовну картинку сам. Щойно завантажите фото, воно замінить малюнок."},{"type":"select-collection","key":"cat","name":"У якому розділі показувати","extra":true,"from":"cats","hint":"Перенести страву в інший розділ можна прямо тут. Список береться з «Розділів меню», тож перейменований розділ одразу міняє підпис і на кнопках вище."},{"type":"text","key":"w","name":"Вага і кількість","extra":true,"hint":"Наприклад: 8 шт · 250 г"},{"type":"textarea","key":"d","name":"Опис (склад)","extra":true,"hint":"Своїми словами, через кому. Наприклад: лосось, крем-сир, огірок"},{"type":"checkbox","key":"top","name":"Хіт — показати на головній сторінці","extra":true,"hint":"Такі страви потрапляють у блок «Топові позиції» на головній."},{"type":"checkbox","key":"neu","name":"Новинка","extra":true,"hint":"Над фото зʼявиться червона плашка «НОВИНКА»."},{"type":"checkbox","key":"hot","name":"Гостре","extra":true,"hint":"Плашка «ГОСТРЕ»."},{"type":"checkbox","key":"veg","name":"Без риби","extra":true,"hint":"Плашка «БЕЗ РИБИ» — для тих, хто рибу не їсть."},{"type":"checkbox","key":"add","name":"Пропонувати перед оформленням","extra":true,"hint":"Для соусів, паличок і напоїв. Такі позиції покупець бачить окремим списком на кроці перед оформленням замовлення."},{"type":"textarea","key":"bs","name":"Підпис на банері","extra":true,"hint":"Потрібен, лише якщо ви винесли цю страву в банер кнопкою у списку. Порожньо — сайт підставить склад."},{"type":"text","key":"bo","name":"Яким показувати в банері","extra":true,"hint":"Число: 1 — перший банер, 2 — другий і так далі. Спільна нумерація зі стравами й сетами. Порожньо — стане в кінець."}],"groupSkip":["all","set"]},{"key":"sets","name":"Сети","rowToggle":{"flag":"ban","label":"банер","title":"Показати цей сет банером угорі головної"},"fields":[{"type":"text","key":"title","name":"Назва сета","hint":"Без слова «Сет» — воно додасться саме. Наприклад: Титан"},{"type":"text","key":"price","name":"Ціна, грн","hint":"Саме число, без слова «грн». Наприклад: 999"},{"type":"text","key":"promo","name":"Ціна за акцією, грн","extra":true,"hint":"Заповніть, щоб запустити акцію: на сайті стара ціна стане закресленою, поруч зʼявиться нова і жовта плашка «АКЦІЯ». Щоб акцію прибрати — очистіть це поле. Приклад: звичайна 279, тут 199."},{"type":"image","key":"image","name":"Фото сета","hint":"Якщо фото немає — сайт намалює умовну картинку сам."},{"type":"text","key":"pcs","name":"Скільки шматочків","extra":true,"hint":"Наприклад: 48 шт. Можна лишити порожнім."},{"type":"text","key":"w","name":"Вага","extra":true,"hint":"Наприклад: 1650 г. Можна лишити порожнім."},{"type":"textarea","key":"list","name":"Що входить у сет","extra":true,"hint":"Кожна позиція з нового рядка. Саме цей список покупець бачить на картці сета."},{"type":"checkbox","key":"week","name":"Сет тижня","extra":true,"hint":"Над фото зʼявиться золота плашка «СЕТ ТИЖНЯ»."},{"type":"checkbox","key":"top","name":"Хіт — показати на головній сторінці","extra":true},{"type":"textarea","key":"bs","name":"Підпис на банері","extra":true,"hint":"Потрібен, лише якщо ви винесли цей сет у банер кнопкою у списку. Порожньо — сайт підставить склад."},{"type":"text","key":"bo","name":"Яким показувати в банері","extra":true,"hint":"Число: 1 — перший банер, 2 — другий і так далі. Спільна нумерація зі стравами й сетами. Порожньо — стане в кінець."}]},{"key":"cats","name":"Розділи меню","fields":[{"key":"title","name":"Назва розділу","type":"text","hint":"Так він підписаний на сайті. Наприклад: Запечені"},{"key":"image","name":"Кругла картинка розділу","type":"image","hint":"Показується над назвою в стрічці розділів. Не завантажите — сайт намалює свою."}],"autoKey":"catkey"},{"key":"settings","name":"Режим роботи","noAdd":true,"noDelete":true,"fields":[{"type":"text","key":"title","name":"Службова назва — не міняйте"},{"type":"text","key":"open_from","name":"Приймаємо замовлення з","extra":true,"hint":"Година у форматі 10:00. На головній зʼявиться зелена позначка «зараз відчинено», а поза цим часом — «зачинено, відкриємось о…». Замовити все одно можна."},{"type":"text","key":"open_to","name":"Приймаємо замовлення до","extra":true,"hint":"Година у форматі 22:00. Цим же обмежується вибір часу в оформленні замовлення."},{"type":"checkbox","key":"dayoff","name":"СЬОГОДНІ САНІТАРНИЙ ДЕНЬ — не приймаємо замовлення","extra":true,"hint":"Поставте галочку зранку: відвідувач побачить екран «Сьогодні санітарний день» з вашим телефоном. Меню дивитися можна, а кнопки «Додати» і оформлення не працюють. Наступного дня галочку зніміть."},{"type":"text","key":"msg","name":"Що написати великими літерами","extra":true,"hint":"Наприклад: Сьогодні санітарний день"},{"type":"text","key":"msg2","name":"Пояснення дрібнішим шрифтом","extra":true,"hint":"Наприклад: Понеділок — санітарний день. Чекаємо завтра з 10:00"}]},{"key":"promos","name":"Промокоди","fields":[{"type":"text","key":"title","name":"Код","gen":"code","hint":"Те, що покупець вписує в кошику. Великі літери й цифри, без пробілів. Не памʼятаєте, що вигадати — натисніть «Згенерувати»."},{"type":"select","key":"type","name":"Тип знижки","extra":true,"options":[{"value":"uah","label":"Гривні"},{"value":"%","label":"Відсоток"}],"hint":"Гривні — мінус фіксована сума. Відсоток — мінус частка від суми кошика."},{"type":"text","key":"off","name":"Скільки знімати","extra":true,"hint":"Саме число. Для гривень: 50 — це мінус 50 ₴. Для відсотка: 10 — це мінус 10%."},{"type":"select-collection","key":"only_menu","name":"Діє тільки на страву","extra":true,"from":"menu","hint":"Порожньо — код діє на весь кошик. Обрали страву — знижка рахується тільки з її ціни, а без неї в кошику код не приймається."},{"type":"select-collection","key":"only_set","name":"Діє тільки на сет","extra":true,"from":"sets","hint":"Те саме, але для сетів. Заповнюйте щось одне: або страву, або сет."},{"type":"text","key":"uses","name":"Скільки разів код може спрацювати","extra":true,"hint":"Порожньо — без обмежень, користуватися можуть усі. 1 — код одноразовий: хто перший оформив замовлення, той і скористався, далі він не діє. 3 — спрацює для перших трьох. Зручно для QR-наліпок і розіграшів."},{"type":"checkbox","key":"stop","name":"Тимчасово вимкнути код","extra":true,"hint":"Поставте галочку — код перестане діяти, але залишиться в списку. Так зручніше, ніж видаляти й заводити знову."}]}],"texts":[{"key":"hours","name":"Графік роботи","hint":"Показується на головній і внизу сайту. Наприклад: вт–нд з 10:00 до 22:00"},{"key":"dayoff_note","name":"Примітка про санітарний день","hint":"Наприклад: Понеділок — санітарний день"},{"key":"open_msg","name":"Напис, коли відчинено","hint":"Зелена позначка поруч із графіком на головній. {час} підставиться сам — це година закриття. Наприклад: зараз відчинено, приймаємо до {час}"},{"key":"shut_msg","name":"Напис, коли зачинено","hint":"Те саме, але поза робочими годинами. {час} — година відкриття. Наприклад: зараз зачинено, відкриємось о {час}"},{"key":"phone_view","name":"Телефон — як показувати","hint":"Наприклад: (098) 000 77 92"},{"key":"phone","name":"Телефон — для дзвінка","hint":"Той самий номер, але суцільно і з кодом країни. Наприклад: +380980007792"},{"key":"free_from","name":"Безкоштовна доставка від, грн","hint":"Саме число. Наприклад: 499"},{"key":"min_order","name":"Мінімальне замовлення на доставку, грн","hint":"Менше цієї суми кошик не дасть оформити доставку. На самовиніс мінімальна сума не діє. Наприклад: 250"},{"key":"pickup_time","name":"Самовиніс: за скільки готуємо","hint":"Наприклад: 15–45 хв"}],"sections":[{"name":"1. Режим роботи","note":"Тут закривають сайт на день і задають години прийому замовлень. Страви й ціни — у наступних вкладках.","collections":["settings"],"texts":["hours","dayoff_note","open_msg","shut_msg","phone_view","phone"]},{"name":"2. Страви","note":"Усі позиції меню, крім сетів. Щоб змінити ціну чи запустити акцію — натисніть «Редагувати» біля потрібної страви.","collections":["menu","cats"]},{"name":"3. Сети","note":"Великі набори. Ціна, склад і акції — так само, як у стравах.","collections":["sets"]},{"name":"4. Доставка та оплата","note":"Суми й умови, які покупець бачить у кошику та в розділі «Доставка та оплата». Тут же промокоди.","texts":["free_from","min_order","pickup_time"],"collections":["promos"]}]}'::jsonb
)
on conflict (id) do update set config = excluded.config, name = excluded.name;

select setval(pg_get_serial_sequence('public.sites', 'id'), (select max(id) from public.sites));

-- Розділи меню
insert into public.items (site_id, collection, title, extra, sort_order)
select v.* from (values
  (5, 'cats', 'Сети', '{"catkey":"set"}'::jsonb, 1),
  (5, 'cats', 'Філадельфія', '{"catkey":"fila"}'::jsonb, 2),
  (5, 'cats', 'Фірмові', '{"catkey":"sign"}'::jsonb, 3),
  (5, 'cats', 'Каліфорнія та макі', '{"catkey":"cali"}'::jsonb, 4),
  (5, 'cats', 'Запечені', '{"catkey":"baked"}'::jsonb, 5),
  (5, 'cats', 'Темпура', '{"catkey":"temp"}'::jsonb, 6),
  (5, 'cats', 'Суші', '{"catkey":"sushi"}'::jsonb, 7),
  (5, 'cats', 'Вок', '{"catkey":"wok"}'::jsonb, 8),
  (5, 'cats', 'Напої та додатки', '{"catkey":"add"}'::jsonb, 9)
) as v(site_id, collection, title, extra, sort_order)
where not exists (select 1 from public.items where site_id = 5 and collection = 'cats');

-- Нові розділи «Бургери» і «Шаурма». Верхній засів уже не спрацює —
-- він стоїть під умовою «якщо розділів ще немає», — тож додаємо окремо.
update public.items set sort_order = 10
where site_id = 5 and collection = 'cats' and extra->>'catkey' = 'wok';
update public.items set sort_order = 11
where site_id = 5 and collection = 'cats' and extra->>'catkey' = 'add';

-- «Усі» — перша кнопка стрічки розділів. Свого списку страв не має,
-- але власнику треба мати змогу задати їй назву й картинку.
insert into public.items (site_id, collection, title, extra, sort_order)
select 5, 'cats', 'Усі', '{"catkey":"all"}'::jsonb, 0
where not exists (
  select 1 from public.items
  where site_id = 5 and collection = 'cats' and extra->>'catkey' = 'all');

insert into public.items (site_id, collection, title, extra, sort_order)
select 5, 'cats', 'Бургери', '{"catkey":"burg"}'::jsonb, 8
where not exists (
  select 1 from public.items
  where site_id = 5 and collection = 'cats' and extra->>'catkey' = 'burg');

insert into public.items (site_id, collection, title, extra, sort_order)
select 5, 'cats', 'Шаурма', '{"catkey":"shau"}'::jsonb, 9
where not exists (
  select 1 from public.items
  where site_id = 5 and collection = 'cats' and extra->>'catkey' = 'shau');

-- Якщо міграцію вже ганяли до поділу — переносимо зі спільного розділу.
update public.items set title = 'Бургери'
where site_id = 5 and collection = 'cats' and extra->>'catkey' = 'burg'
  and title = 'Бургери та шаурма';

-- Бургери й шаурму виносимо з «Фірмових» у власні розділи,
-- щоб у фірмових лишилися тільки роли.
-- Перша літера навмисно відкинута: так збіг не залежить від того,
-- чи вміє колація бази міняти регістр кирилиці.
update public.items set extra = jsonb_set(extra, '{cat}', '"burg"')
where site_id = 5 and collection = 'menu'
  and extra->>'cat' in ('sign', 'burg')
  and title like '%ургер%';

update public.items set extra = jsonb_set(extra, '{cat}', '"shau"')
where site_id = 5 and collection = 'menu'
  and extra->>'cat' in ('sign', 'burg')
  and title like '%аурма%';

-- Вимикач «Санітарний день»
insert into public.items (site_id, collection, title, extra, sort_order)
select v.* from (values
  (5, 'settings', 'Режим роботи', '{"dayoff":false,"msg":"Сьогодні санітарний день","msg2":"Понеділок — санітарний день, чекаємо завтра з 10:00","open_from":"10:00","open_to":"22:00"}'::jsonb, 1)
) as v(site_id, collection, title, extra, sort_order)
where not exists (select 1 from public.items where site_id = 5 and collection = 'settings');

update public.items set extra =
  '{"open_from":"10:00","open_to":"22:00"}'::jsonb || extra
where site_id = 5 and collection = 'settings';

-- Перейменування «вихідний» → «санітарний день».
-- Чіпаємо лише текст за замовчуванням: якщо власник уже вписав свій, він лишається.
update public.items set extra = jsonb_set(extra, '{msg}', '"Сьогодні санітарний день"')
where site_id = 5 and collection = 'settings' and extra->>'msg' = 'Сьогодні вихідний';

-- Меню (68 позицій)
insert into public.items (site_id, collection, title, price, extra, sort_order)
select v.* from (values
  (5, 'menu', 'Філадельфія з лососем', '279', '{"cat":"fila","w":"8 шт · 250 г","t":"roll","ing":"losos,syr,ohir","top":true}'::jsonb, 1),
  (5, 'menu', 'Філадельфія з креветкою', '289', '{"cat":"fila","w":"8 шт · 250 г","t":"roll","ing":"krev,syr,ohir"}'::jsonb, 2),
  (5, 'menu', 'Філадельфія з вугрем', '319', '{"cat":"fila","w":"8 шт · 255 г","t":"roll","ing":"vuhor,syr,ohir"}'::jsonb, 3),
  (5, 'menu', 'Філадельфія з тунцем', '299', '{"cat":"fila","w":"8 шт · 250 г","t":"roll","ing":"tunec,syr,ohir"}'::jsonb, 4),
  (5, 'menu', 'Філадельфія з сиром', '249', '{"cat":"fila","w":"8 шт · 240 г","t":"roll","ing":"syr,ohir,avo","veg":true}'::jsonb, 5),
  (5, 'menu', 'Філадельфія Блек з лососем', '309', '{"cat":"fila","w":"8 шт · 255 г","t":"roll","ing":"losos,syr,black"}'::jsonb, 6),
  (5, 'menu', 'Філадельфія Блек з тунцем', '319', '{"cat":"fila","w":"8 шт · 255 г","t":"roll","ing":"tunec,syr,black"}'::jsonb, 7),
  (5, 'menu', 'Філадельфія мега', '389', '{"cat":"fila","w":"10 шт · 340 г","t":"roll","ing":"losos,tunec,krev,syr"}'::jsonb, 8),
  (5, 'menu', 'Філадельфія мікс', '349', '{"cat":"fila","w":"8 шт · 300 г","t":"roll","ing":"losos,tunec,vuhor,syr"}'::jsonb, 9),
  (5, 'menu', 'Філадельфія Делюкс', '369', '{"cat":"fila","w":"8 шт · 310 г","t":"roll","ing":"losos,syr,tobik"}'::jsonb, 10),
  (5, 'menu', 'Філадельфія «Аляска»', '349', '{"cat":"fila","w":"325 г","t":"roll","ing":"losos,syr,avo,krev","d":"лосось зверху, крем-сир, авокадо, креветка варена","top":true,"neu":true}'::jsonb, 11),
  (5, 'menu', 'Рол «Гурман»', '349', '{"cat":"sign","w":"8 шт · 280 г","t":"roll","ing":"vuhor,syr,tobik,avo","d":"вугор, крем-сир, ікра масаго, авокадо, зверху лосось","top":true}'::jsonb, 12),
  (5, 'menu', 'Лава рол', '319', '{"cat":"sign","w":"8 шт · 270 г","t":"baked","ing":"losos,syr,perec","top":true}'::jsonb, 13),
  (5, 'menu', 'Лава рол з тунцем', '329', '{"cat":"sign","w":"8 шт · 270 г","t":"baked","ing":"tunec,syr,perec"}'::jsonb, 14),
  (5, 'menu', 'Блек чікен чіз', '279', '{"cat":"sign","w":"8 шт · 260 г","t":"roll","ing":"kurka,syr,black"}'::jsonb, 15),
  (5, 'menu', 'Кранч з крем-сиром', '269', '{"cat":"sign","w":"8 шт · 250 г","t":"tempura","ing":"syr,ohir,avo","veg":true}'::jsonb, 16),
  (5, 'menu', 'Суші бургер з креветкою', '199', '{"cat":"sign","w":"180 г","t":"nigiri","ing":"krev,syr"}'::jsonb, 17),
  (5, 'menu', 'Бургер з лососем', '209', '{"cat":"sign","w":"180 г","t":"nigiri","ing":"losos,syr"}'::jsonb, 18),
  (5, 'menu', 'Суші шаурма з лососем та тунцем', '229', '{"cat":"sign","w":"220 г","t":"nigiri","ing":"losos,tunec,syr"}'::jsonb, 19),
  (5, 'menu', 'Каліфорнія з лососем', '259', '{"cat":"cali","w":"8 шт · 240 г","t":"roll","ing":"losos,avo,ohir,tobik"}'::jsonb, 20),
  (5, 'menu', 'Каліфорнія з тунцем', '269', '{"cat":"cali","w":"8 шт · 240 г","t":"roll","ing":"tunec,avo,ohir,tobik"}'::jsonb, 21),
  (5, 'menu', 'Каліфорнія з креветкою', '279', '{"cat":"cali","w":"8 шт · 245 г","t":"roll","ing":"krev,avo,ohir,tobik"}'::jsonb, 22),
  (5, 'menu', 'Каліфорнія з крабом', '239', '{"cat":"cali","w":"8 шт · 235 г","t":"roll","ing":"krab,avo,ohir,tobik"}'::jsonb, 23),
  (5, 'menu', 'Каліфорнія з вугрем', '299', '{"cat":"cali","w":"8 шт · 245 г","t":"roll","ing":"vuhor,avo,ohir,tobik"}'::jsonb, 24),
  (5, 'menu', 'Каліфорнія з креветкою темпура', '309', '{"cat":"cali","w":"8 шт · 265 г","t":"tempura","ing":"krev,syr,ohir","d":"креветка темпура, огірок, крем-сир, соуси зверху","top":true}'::jsonb, 25),
  (5, 'menu', 'Футомакі з лососем', '269', '{"cat":"cali","w":"8 шт · 275 г","t":"roll","ing":"losos,syr,avo,omlet"}'::jsonb, 26),
  (5, 'menu', 'Футомакі з тунцем', '279', '{"cat":"cali","w":"8 шт · 275 г","t":"roll","ing":"tunec,syr,avo,omlet"}'::jsonb, 27),
  (5, 'menu', 'Футомакі з креветкою', '289', '{"cat":"cali","w":"8 шт · 280 г","t":"roll","ing":"krev,syr,avo,omlet"}'::jsonb, 28),
  (5, 'menu', 'Дабл макі з креветкою та крем-сиром', '259', '{"cat":"cali","w":"8 шт · 230 г","t":"roll","ing":"krev,syr"}'::jsonb, 29),
  (5, 'menu', 'Макі з лососем', '139', '{"cat":"cali","w":"6 шт · 130 г","t":"roll","ing":"losos"}'::jsonb, 30),
  (5, 'menu', 'Макі з тунцем', '145', '{"cat":"cali","w":"6 шт · 130 г","t":"roll","ing":"tunec"}'::jsonb, 31),
  (5, 'menu', 'Макі з креветкою', '149', '{"cat":"cali","w":"6 шт · 130 г","t":"roll","ing":"krev"}'::jsonb, 32),
  (5, 'menu', 'Макі з крем-сиром', '99', '{"cat":"cali","w":"6 шт · 120 г","t":"roll","ing":"syr","veg":true}'::jsonb, 33),
  (5, 'menu', 'Макі з огірком', '89', '{"cat":"cali","w":"6 шт · 120 г","t":"roll","ing":"ohir","veg":true}'::jsonb, 34),
  (5, 'menu', 'Макі з авокадо', '99', '{"cat":"cali","w":"6 шт · 120 г","t":"roll","ing":"avo","veg":true}'::jsonb, 35),
  (5, 'menu', 'Запечений з лососем', '239', '{"cat":"baked","w":"8 шт · 250 г","t":"baked","ing":"losos,syr,ohir"}'::jsonb, 36),
  (5, 'menu', 'Запечений з вугрем', '259', '{"cat":"baked","w":"8 шт · 250 г","t":"baked","ing":"vuhor,syr,ohir"}'::jsonb, 37),
  (5, 'menu', 'Запечений з куркою', '199', '{"cat":"baked","w":"8 шт · 250 г","t":"baked","ing":"kurka,syr,ohir"}'::jsonb, 38),
  (5, 'menu', 'Запечений з сиром', '199', '{"cat":"baked","w":"8 шт · 250 г","t":"baked","ing":"syr,ohir,avo","veg":true}'::jsonb, 39),
  (5, 'menu', 'Запечений з крабом', '219', '{"cat":"baked","w":"8 шт · 250 г","t":"baked","ing":"krab,syr,ohir","top":true}'::jsonb, 40),
  (5, 'menu', 'Запечений з креветкою', '249', '{"cat":"baked","w":"8 шт · 250 г","t":"baked","ing":"krev,syr,avo"}'::jsonb, 41),
  (5, 'menu', 'Темпура з креветкою', '259', '{"cat":"temp","w":"8 шт · 265 г","t":"tempura","ing":"krev,syr,avo","top":true}'::jsonb, 42),
  (5, 'menu', 'Темпура з лососем', '249', '{"cat":"temp","w":"8 шт · 260 г","t":"tempura","ing":"losos,syr,ohir"}'::jsonb, 43),
  (5, 'menu', 'Темпура з тунцем', '255', '{"cat":"temp","w":"8 шт · 260 г","t":"tempura","ing":"tunec,syr,ohir"}'::jsonb, 44),
  (5, 'menu', 'Темпура з вугрем', '279', '{"cat":"temp","w":"8 шт · 265 г","t":"tempura","ing":"vuhor,syr,ohir"}'::jsonb, 45),
  (5, 'menu', 'Темпура з куркою', '219', '{"cat":"temp","w":"8 шт · 260 г","t":"tempura","ing":"kurka,syr,ohir"}'::jsonb, 46),
  (5, 'menu', 'Темпура з краб-міксом', '239', '{"cat":"temp","w":"8 шт · 260 г","t":"tempura","ing":"krab,syr,ohir"}'::jsonb, 47),
  (5, 'menu', 'Темпура Гурман', '279', '{"cat":"temp","w":"8 шт · 270 г","t":"tempura","ing":"losos,vuhor,syr"}'::jsonb, 48),
  (5, 'menu', 'Креветки темпура 6 шт + спайсі', '189', '{"cat":"temp","w":"6 шт · 130 г","t":"shrimp","ing":"krev,perec","hot":true}'::jsonb, 49),
  (5, 'menu', 'Креветки темпура 10 шт + спайсі', '229', '{"cat":"temp","w":"10 шт · 200 г","t":"shrimp","ing":"krev,perec","hot":true}'::jsonb, 50),
  (5, 'menu', 'Нігірі з лососем', '95', '{"cat":"sushi","w":"2 шт · 60 г","t":"nigiri","ing":"losos"}'::jsonb, 51),
  (5, 'menu', 'Нігірі з вугрем', '115', '{"cat":"sushi","w":"2 шт · 60 г","t":"nigiri","ing":"vuhor"}'::jsonb, 52),
  (5, 'menu', 'Нігірі з тунцем', '105', '{"cat":"sushi","w":"2 шт · 58 г","t":"nigiri","ing":"tunec"}'::jsonb, 53),
  (5, 'menu', 'Гункан з тобіко', '95', '{"cat":"sushi","w":"2 шт · 60 г","t":"roll","ing":"tobik"}'::jsonb, 54),
  (5, 'menu', 'Удон з куркою', '189', '{"cat":"wok","w":"380 г","t":"bowl","ing":"kurka,ovoch"}'::jsonb, 55),
  (5, 'menu', 'Удон з креветкою', '229', '{"cat":"wok","w":"380 г","t":"bowl","ing":"krev,ovoch"}'::jsonb, 56),
  (5, 'menu', 'Фунчоза з яловичиною', '209', '{"cat":"wok","w":"380 г","t":"bowl","ing":"yalov,ovoch,perec","hot":true}'::jsonb, 57),
  (5, 'menu', 'Рис з овочами', '159', '{"cat":"wok","w":"350 г","t":"bowl","ing":"ryzh,ovoch,hryby","veg":true}'::jsonb, 58),
  (5, 'menu', 'Полуничний морс', '69', '{"cat":"add","w":"0,5 л","t":"drink","ing":"perec","top":true}'::jsonb, 59),
  (5, 'menu', 'Вода без газу', '30', '{"cat":"add","w":"0,5 л","t":"drink","ing":"ohir","add":true}'::jsonb, 60),
  (5, 'menu', 'Кола', '45', '{"cat":"add","w":"0,5 л","t":"drink","ing":"yalov","add":true}'::jsonb, 61),
  (5, 'menu', 'Набір: соєвий соус, імбир, васабі', '20', '{"cat":"add","w":"1 набір","t":"drink","ing":"vuhor","d":"один набір до кожного ролу — безкоштовно","add":true}'::jsonb, 62),
  (5, 'menu', 'Палички', '10', '{"cat":"add","w":"1 пара","t":"stick","ing":"kurka","add":true}'::jsonb, 63),
  (5, 'menu', 'Палички навчальні', '20', '{"cat":"add","w":"1 пара","t":"stick","ing":"omlet","add":true}'::jsonb, 64),
  (5, 'menu', 'Соєвий соус', '12', '{"cat":"add","w":"30 г","t":"sauce","ing":"vuhor","add":true}'::jsonb, 65),
  (5, 'menu', 'Імбир', '15', '{"cat":"add","w":"30 г","t":"sauce","ing":"krev","add":true}'::jsonb, 66),
  (5, 'menu', 'Васабі', '15', '{"cat":"add","w":"20 г","t":"sauce","ing":"chuka","add":true}'::jsonb, 67),
  (5, 'menu', 'Соус унагі', '25', '{"cat":"add","w":"40 г","t":"sauce","ing":"vuhor","add":true}'::jsonb, 68)
) as v(site_id, collection, title, price, extra, sort_order)
where not exists (select 1 from public.items where site_id = 5 and collection = 'menu');

-- Сети (18)
insert into public.items (site_id, collection, title, price, extra, sort_order)
select v.* from (values
  (5, 'sets', 'Макі', '429', '{"pcs":"","w":"660 г","list":"Макі з лососем\nМакі з тунцем\nМакі з креветкою\nМакі з огірком\nМакі з крем-сиром\nМакі з авокадо","ing":"losos,tunec,krev,ohir,syr"}'::jsonb, 1),
  (5, 'sets', 'Запечений рай', '679', '{"pcs":"","w":"1140 г","list":"Запечений з лососем\nЗапечений з вугрем\nЗапечений з куркою\nЗапечений з сиром","ing":"losos,vuhor,kurka,syr"}'::jsonb, 2),
  (5, 'sets', 'Каліфорнія', '679', '{"pcs":"","w":"970 г","list":"Каліфорнія з тунцем\nКаліфорнія з краб-міксом\nКаліфорнія з креветкою\nКаліфорнія з лососем","ing":"tunec,krab,krev,losos"}'::jsonb, 3),
  (5, 'sets', 'Фантазія', '689', '{"pcs":"","w":"885 г","list":"Філадельфія мікс\nФутомакі з лососем\nКаліфорнія з креветкою\nСуші з лососем\nСуші з тунцем","ing":"losos,krev,tunec"}'::jsonb, 4),
  (5, 'sets', 'Хот', '699', '{"pcs":"","w":"1230 г","list":"Темпура з креветкою\nЗапечений з сиром\nТемпура з лососем\nЗапечений з куркою","ing":"krev,syr,losos,kurka"}'::jsonb, 5),
  (5, 'sets', 'Мега лосось', '769', '{"pcs":"","w":"900 г","list":"Філадельфія з лососем\nФіладельфія Делюкс\nТемпура з лососем\nНігірі з лососем 2 шт","ing":"losos,syr"}'::jsonb, 6),
  (5, 'sets', 'Лілія', '769', '{"pcs":"","w":"","list":"Філадельфія з лососем\nФіладельфія з тунцем\nТемпура з креветкою\nЗапечений з сиром","ing":"losos,tunec,krev,syr","week":true}'::jsonb, 7),
  (5, 'sets', 'Філадельфія', '849', '{"pcs":"","w":"1125 г","list":"Філадельфія з тунцем\nФіладельфія мікс\nФіладельфія з креветкою\nФіладельфія з лососем","ing":"tunec,losos,krev"}'::jsonb, 8),
  (5, 'sets', 'Міксовий', '899', '{"pcs":"","w":"1400 г","list":"Запечений з куркою\nФутомакі з тунцем\nКаліфорнія з крабом\nФіладельфія мікс\nТемпура з креветкою","ing":"kurka,tunec,krab,krev"}'::jsonb, 9),
  (5, 'sets', 'Хайп', '899', '{"pcs":"","w":"","list":"Філадельфія з лососем 0,5\nФіладельфія з креветкою 0,5\nБлек Філадельфія з лососем\nТемпура з креветкою\nТемпура з краб-міксом\nКреветки темпура 6 шт + спайсі","ing":"losos,krev,krab,black","week":true}'::jsonb, 10),
  (5, 'sets', 'Титан', '999', '{"pcs":"48 шт","w":"1650 г","list":"Філадельфія з лососем 0,5\nФіладельфія з тунцем 0,5\nФіладельфія Блек з лососем\nФутомакі з креветкою\nЗапечений з сиром\nТемпура з креветкою\nТемпура Гурман","ing":"losos,tunec,krev,black","week":true,"top":true}'::jsonb, 11),
  (5, 'sets', 'Дари моря', '1149', '{"pcs":"","w":"1580 г","list":"Філадельфія з лососем\nБлек Філадельфія з тунцем\nТемпура з креветкою\nЗапечений з лососем\nЛава рол з тунцем\nДабл макі з креветкою та крем-сиром","ing":"losos,tunec,krev,syr","top":true}'::jsonb, 12),
  (5, 'sets', 'Преміум', '1199', '{"pcs":"","w":"1560 г","list":"Філадельфія з тунцем\nФіладельфія з лососем 0,5\nФіладельфія з сиром 0,5\nТемпура Гурман\nБургер з лососем\nСуші шаурма з лососем та тунцем\nКреветки темпура 6 шт","ing":"tunec,losos,syr,krev","top":true}'::jsonb, 13),
  (5, 'sets', 'Темпура мікс', '1219', '{"pcs":"","w":"1660 г","list":"Темпура з креветкою\nТемпура з вугрем\nТемпура з куркою\nТемпура Гурман\nСуші бургер з креветкою\nКреветки темпура 6 шт з соусом спайсі","ing":"krev,vuhor,kurka,losos","top":true}'::jsonb, 14),
  (5, 'sets', 'Комбо', '1249', '{"pcs":"","w":"1840 г","list":"Філадельфія мега\nФіладельфія з креветкою\nБлек чікен чіз\nТемпура з креветкою\nТемпура з тунцем\nТемпура Гурман","ing":"losos,krev,kurka,tunec","top":true}'::jsonb, 15),
  (5, 'sets', 'Імператор', '1459', '{"pcs":"","w":"2050 г","list":"Філадельфія мега\nФіладельфія блек з тунцем\nФіладельфія з вугрем\nЗапечений з лососем\nЗапечений з сиром\nТемпура з креветкою\nКранч з крем-сиром","ing":"losos,tunec,vuhor,syr"}'::jsonb, 16),
  (5, 'sets', 'Друзі', '1569', '{"pcs":"","w":"1895 г","list":"Філадельфія мікс\nФіладельфія з лососем\nМакі з крем-сиром\nФутомакі з тунцем\nЗапечений з куркою\nМакі з лососем\nЗапечений з крабом\nГурман рол\nКаліфорнія з вугрем","ing":"losos,tunec,kurka,krab,vuhor"}'::jsonb, 17),
  (5, 'sets', 'Гранд', '1599', '{"pcs":"","w":"","list":"Філадельфія з лососем\nФіладельфія з вугрем\nФіладельфія з тунцем\nКаліфорнія з вугрем\nЗапечений з сиром\nЗапечений з краб-мікс\nТемпура з креветкою\nКреветки темпура 10 шт зі спайсі соусом","ing":"losos,vuhor,tunec,krab,krev","week":true}'::jsonb, 18)
) as v(site_id, collection, title, price, extra, sort_order)
where not exists (select 1 from public.items where site_id = 5 and collection = 'sets');

-- Позначаємо позиції, які показуються банером (4)
update public.items set extra = extra || '{"ban":true,"bs":"Лосось зверху, крем-сир,\nавокадо та варена креветка"}'::jsonb
where site_id = 5 and collection = 'menu' and title = 'Філадельфія «Аляска»'
  and not (extra ? 'ban');
update public.items set extra = extra || '{"ban":true,"bs":"Шість видів макі, 660 г.\nНайлегший спосіб почати"}'::jsonb
where site_id = 5 and collection = 'sets' and title = 'Макі'
  and not (extra ? 'ban');
update public.items set extra = extra || '{"ban":true,"bs":"48 шматочків, 1650 г.\nСім видів ролів в одній коробці"}'::jsonb
where site_id = 5 and collection = 'sets' and title = 'Титан'
  and not (extra ? 'ban');
update public.items set extra = extra || '{"ban":true,"bs":"Вісім позицій: класика, вугор,\nгарячі роли та хрумкі креветки"}'::jsonb
where site_id = 5 and collection = 'sets' and title = 'Гранд'
  and not (extra ? 'ban');

-- Тексти (не перезаписуємо, якщо власник уже правив)
insert into public.texts (site_id, key, value) values
  (5, 'phone_view', '(098) 000 77 92'),
  (5, 'phone', '+380980007792'),
  (5, 'hours', 'вт–нд з 10:00 до 22:00'),
  (5, 'dayoff_note', 'Понеділок — санітарний день'),
  (5, 'open_msg', 'зараз відчинено, приймаємо до {час}'),
  (5, 'shut_msg', 'зараз зачинено, відкриємось о {час}'),
  (5, 'free_from', '499'),
  (5, 'min_order', '250'),
  (5, 'pickup_time', '15–45 хв')
on conflict (site_id, key) do nothing;

-- Доплата за кілометр більше не діє: рядок про неї прибрано з умов
-- доставки на сайті, а поля — з адмінки. Прибираємо й самі значення,
-- щоб вони не лежали в базі без діла.
delete from public.texts where site_id = 5 and key in ('far_km', 'far_fee');

-- Час готовності змінився. Правимо тільки тим, у кого лишилося старе
-- значення за замовчуванням: власний текст не чіпаємо.
update public.texts set value = '15–45 хв'
where site_id = 5 and key = 'pickup_time' and value = '30–40 хв';
