-- ============================================================
--  Доступ власника Just shop до адмінки
--  ------------------------------------------------------------
--  Спершу створіть користувача в Supabase:
--    Authentication → Users → Add user
--    Email:    shmorgun1998@gmail.com
--    Password: той, який домовились (вводите ви, не я —
--              у файл, що лежить у git, пароль класти не можна)
--    Auto Confirm User: увімкнути — інакше він не зможе увійти,
--                       поки не підтвердить пошту листом
--
--  Тоді запустіть цей файл у SQL Editor. Він знайде користувача
--  за поштою і прив'яже його до сайту 106 (Just shop) як власника.
--
--  Власник бачить лише свій сайт: товари, склад, замовлення й тексти.
--  Чужих сайтів на платформі він не побачить — за це відповідає
--  site_id у профілі та політики доступу в базі.
--
--  БЕЗПЕЧНИЙ ДЛЯ ПОВТОРНОГО ЗАПУСКУ.
-- ============================================================

insert into public.profiles (user_id, site_id, role)
select id, 106, 'owner'
from auth.users
where lower(email) = 'shmorgun1998@gmail.com'
on conflict (user_id) do update
  set site_id = excluded.site_id,
      role    = excluded.role;

-- Перевірка: має бути рівно один рядок із site_id = 106 і role = owner.
-- Порожньо — значить користувача ще не створено в Authentication.
select u.email, p.site_id, p.role, s.name as site
from public.profiles p
join auth.users u on u.id = p.user_id
left join public.sites s on s.id = p.site_id
where lower(u.email) = 'shmorgun1998@gmail.com';
