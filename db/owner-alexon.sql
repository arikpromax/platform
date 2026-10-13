-- ============================================================
--  Доступ власника Alexon Home Services до адмінки
--  ------------------------------------------------------------
--  Спершу створіть користувача в Supabase:
--    Authentication → Users → Add user → Create new user
--    Email:    homeservice@alexon.info
--    Password: (придумайте й запишіть собі)
--    Auto Confirm User: увімкнути — інакше він не зможе увійти,
--                       поки не підтвердить пошту листом
--
--  Тоді запустіть цей файл у SQL Editor. Він знайде користувача
--  за поштою і прив'яже його до сайту 109 (Alexon) як власника.
--  Якщо спитає про RLS — «Run without RLS» (таблиць тут не створюється).
--
--  БЕЗПЕЧНИЙ ДЛЯ ПОВТОРНОГО ЗАПУСКУ.
-- ============================================================

insert into public.profiles (user_id, site_id, role)
select id, (select id from public.sites where slug = 'alexon'), 'owner'
from auth.users
where lower(email) = 'homeservice@alexon.info'
on conflict (user_id) do update
  set site_id = excluded.site_id,
      role    = excluded.role;

-- Перевірка: має бути рівно один рядок з site_id = 109 і role = owner
select u.email, p.site_id, p.role, s.name as site
from public.profiles p
join auth.users u on u.id = p.user_id
left join public.sites s on s.id = p.site_id
where lower(u.email) = 'homeservice@alexon.info';
