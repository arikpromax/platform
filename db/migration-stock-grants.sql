-- ============================================================
--  СКЛАД: підтягнути права на функції (необовʼязково, але акуратніше)
--
--  Supabase за замовчуванням дозволяє викликати нові функції всім,
--  зокрема анонімним відвідувачам сайту. Небезпеки немає: кожна
--  «власницька» функція сама перевіряє права й відмовляє чужому
--  («error»: «access»). Але хай навіть спробувати не можна.
--
--  Викликати склад мають право лише ті, хто зайшов в адмінку.
--  Сайту лишаються тільки три функції: відкласти кошик, зняти
--  відкладене й оформити замовлення.
-- ============================================================

revoke execute on function public.stock_adjust(bigint, text, text, int, text, text) from anon;
revoke execute on function public.stock_set_low(bigint, text, text, int) from anon;
revoke execute on function public.stock_sync(bigint) from anon;
revoke execute on function public.set_order_status(bigint, text) from anon;
revoke execute on function public.stock_add_size(bigint, text) from anon;
revoke execute on function public.stock_drop_size(bigint, text) from anon;
revoke execute on function public.stock_sizes_field(bigint) from anon;
revoke execute on function public.stock_drop_hold(uuid) from anon;
revoke execute on function public.stock_release_expired() from anon;
revoke execute on function public.stock_can_edit(bigint) from anon;
revoke execute on function public.stock_who() from anon;

-- Перевірка: у списку мають лишитись тільки три рядки для anon
select p.proname as "функція", r.rolname as "кому дозволено"
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  cross join lateral (select rolname from pg_roles where rolname in ('anon', 'authenticated')) r
 where n.nspname = 'public'
   and p.proname in ('stock_hold', 'stock_unhold', 'place_order', 'stock_adjust',
                     'stock_sync', 'set_order_status', 'stock_add_size', 'stock_drop_size')
   and has_function_privilege(r.rolname, p.oid, 'execute')
 order by 1, 2;
