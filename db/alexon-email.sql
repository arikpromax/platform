-- Alexon: email на сайті і новий рядок під заголовком форми (заявки тепер ідуть на пошту й у таблицю).
-- Виконати в Supabase → SQL Editor. Якщо спитає про RLS — «Run without RLS» (таблиць тут не створюється).
update public.texts set value = 'homeservice@alexon.info'
where site_id = (select id from public.sites where slug = 'alexon') and key = 'email';

update public.texts set value = 'Tell us what needs doing. The request comes straight to Alexon, and we call you back.'
where site_id = (select id from public.sites where slug = 'alexon') and key = 'contact_lead';

-- config: оновлена підказка поля Email
-- (повний опис адмінки — у migration-alexon.sql; його можна просто запустити ще раз, нічого не затреться)
