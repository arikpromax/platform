-- Just shop: оплата карткою через monobank замість LiqPay.
--
--  1. Перемикач оплати в адмінці стає «monobank», зʼявляється ознака
--     тестового токена (з нею на сайті написано, що гроші не списуються).
--  2. Тестові ключі LiqPay прибираються зі сховища ключів.
--  3. У текстах сайту — оферті, політиці, блоках «Оплата» й «Повернення»
--     та у відповіді «Як оплачувати?» — LiqPay замінюється на monobank.
--
-- Виконати один раз у Supabase → SQL Editor. Повторний запуск безпечний.

-- ---------- 1) Налаштування оплати ----------
alter table public.np_settings
  add column if not exists pay_test boolean not null default false;

-- нові сайти теж підключають monobank, LiqPay в адмінці більше не обирають
alter table public.np_settings
  alter column pay_provider set default 'mono';

update public.np_settings
   set pay_provider = 'mono',
       pay_test      = true,     -- поки токен тестовий; у адмінці перемикається
       updated_at    = now()
 where site_id = 106;

-- ---------- 2) Ключі LiqPay більше не потрібні ----------
delete from public.site_keys
 where site_id = 106 and name like 'LIQPAY%';

-- ---------- 3) Тексти ----------
-- Спершу довгі назви з банком, потім саме слово, щоб не лишилось «monobank (ПриватБанк)»
update public.texts
   set value = replace(
                 replace(
                   replace(value, 'LiqPay (АТ КБ «ПриватБанк»)', 'monobank (АТ «Універсал Банк»)'),
                 'LiqPay (ПриватБанк)', 'monobank'),
               'LiqPay', 'monobank')
 where site_id = 106 and value like '%LiqPay%';

update public.items
   set text = 'Visa, Mastercard, Apple Pay чи Google Pay на захищеній сторінці monobank. Дані картки вводите на стороні банку — ми їх не бачимо й не зберігаємо.'
 where site_id = 106 and collection = 'payment' and title = 'Карткою на сайті';

update public.items
   set extra = jsonb_set(extra, '{list}',
                 to_jsonb(replace(extra->>'list',
                   'на ту саму картку через LiqPay', 'на ту саму картку через monobank')))
 where site_id = 106 and collection = 'returns' and extra->>'list' like '%LiqPay%';

update public.items
   set text = replace(text, 'через LiqPay', 'через monobank')
 where site_id = 106 and text like '%LiqPay%';

-- ---------- 4) Що вийшло ----------
select 'налаштування' as що,
       pay_provider || case when pay_test then ' (тестовий токен)' else ' (робочий токен)' end as стан
  from public.np_settings where site_id = 106
union all
select 'ключі LiqPay', count(*)::text from public.site_keys where site_id = 106 and name like 'LIQPAY%'
union all
select 'згадок LiqPay у текстах', count(*)::text from public.texts where site_id = 106 and value like '%LiqPay%'
union all
select 'згадок LiqPay у блоках', count(*)::text from public.items
 where site_id = 106 and (text like '%LiqPay%' or extra::text like '%LiqPay%');
