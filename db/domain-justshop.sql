-- Just shop переїхав на власний домен justshopp.com.ua (10.10.2026).
--
-- Адреси фото товарів зберігаються повними, тож стару адресу GitHub
-- (arikpromax.github.io/justshop) міняємо на домен. Посилання на товари в
-- Telegram-повідомленнях бот бере з адреси фото — вони теж стануть з доменом.
-- Стара адреса й далі працює (GitHub сам перекидає на домен), тож це лише
-- прибирає зайвий перехід і робить посилання гарними.
--
-- Виконати, коли https://justshopp.com.ua уже відкривається. Повторний запуск безпечний.

update public.items
   set extra = replace(extra::text, 'https://arikpromax.github.io/justshop/', 'https://justshopp.com.ua/')::jsonb,
       image_url = replace(coalesce(image_url, ''), 'https://arikpromax.github.io/justshop/', 'https://justshopp.com.ua/')
 where site_id = 106
   and (extra::text like '%arikpromax.github.io/justshop/%' or coalesce(image_url, '') like '%arikpromax.github.io/justshop/%');

select count(*) filter (where extra::text like '%justshopp.com.ua/%')              as "карток з фото на домені",
       count(*) filter (where extra::text like '%arikpromax.github.io/justshop/%') as "лишилось зі старою адресою"
  from public.items where site_id = 106;
