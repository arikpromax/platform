-- Відкладене під кошики — щохвилини назад у продаж.
--
-- Коли покупець відкриває оформлення, товар відкладають на 15 хвилин, щоб
-- останню пару не купили двоє одночасно. Досі прострочене знімалося лише
-- тоді, коли наступна людина доходила до оформлення. Якщо такої не було,
-- річ годинами стояла на сайті як «немає» (21.09 — 80 хвилин, п'ять позицій).
-- Тепер базу раз на хвилину прибирає сам Supabase, для всіх сайтів одразу.
--
-- Виконати один раз у Supabase → SQL Editor. Повторний запуск нічого не ламає:
-- завдання з тим самим ім'ям просто перезапишеться.

create extension if not exists pg_cron with schema pg_catalog;

select cron.schedule(
  'stock-release-expired',
  '* * * * *',
  $$select public.stock_release_expired()$$
);

-- Перевірка: має бути один рядок, active = true
select jobname, schedule, active from cron.job where jobname = 'stock-release-expired';
