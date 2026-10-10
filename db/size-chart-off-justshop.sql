-- Just shop: розмірну сітку прибрано зі сторінки «Доставка й оплата» (10.10.2026).
--
-- Таблиця розмірів лишається на сторінці кожного товару (кнопка «Таблиця
-- розмірів»). Абзац над сіткою на доставці більше ніде не показується, тож
-- поле «Розмірна сітка: абзац» прибираємо з адмінки, щоб воно не плутало.
-- Сам текст у базі лишається — якщо сітку повернемо, він не загубиться.
--
-- Виконати один раз у Supabase → SQL Editor. Повторний запуск безпечний.

update public.sites
   set config = jsonb_set(
         jsonb_set(config, '{sections}', (
           select coalesce(jsonb_agg(
                    case when jsonb_typeof(s->'texts') = 'array'
                         then s || jsonb_build_object('texts', (
                                select coalesce(jsonb_agg(t order by o2), '[]'::jsonb)
                                  from jsonb_array_elements(s->'texts') with ordinality as x(t, o2)
                                 where t #>> '{}' <> 'size_lead'))
                         else s end
                    order by o), '[]'::jsonb)
             from jsonb_array_elements(config->'sections') with ordinality as y(s, o))),
         '{texts}', (
           select coalesce(jsonb_agg(t order by o), '[]'::jsonb)
             from jsonb_array_elements(config->'texts') with ordinality as z(t, o)
            where t->>'key' <> 'size_lead'))
 where id = 106
   and jsonb_typeof(config->'sections') = 'array'
   and jsonb_typeof(config->'texts') = 'array';

select (select count(*) from jsonb_array_elements(config->'texts') t where t->>'key' = 'size_lead') as "поле в адмінці (має бути 0)",
       (select s->'texts' from jsonb_array_elements(config->'sections') s where s->>'name' = 'Доставка й оплата') as "тексти вкладки «Доставка й оплата»"
  from public.sites where id = 106;
