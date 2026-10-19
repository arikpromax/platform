-- Замовлення: кнопка «Очистити історію» в адмінці (19.10.2026).
--
-- Прибирає скасовані замовлення — і ті, що скасував власник, і неоплачені
-- карткою, які база скасувала сама. Товар за ними вже повернувся на склад,
-- тож видаляється лише запис.
--
-- Не чіпає:
--   * нові (і ті, що ще чекають оплати), відправлені, виконані й повернення — це справжні продажі;
--   * скасоване, за яке гроші прийшли вже після скасування — їх ще треба повернути покупцю;
--   * скасоване, повернення якого програма магазину (УкрСклад) ще не оформила.
--
-- Для всіх сайтів платформи. Виконати один раз у Supabase → SQL Editor. Повторний запуск безпечний.

create or replace function public.orders_clear(p_site bigint)
returns jsonb language plpgsql security definer set search_path = public as
$fn$
declare n int;
begin
  if not public.stock_can_edit(p_site) then
    return jsonb_build_object('ok', false, 'error', 'access');
  end if;
  delete from orders
   where site_id = p_site
     and status = 'cancelled'
     and pay_state <> 'paid'
     and (synced_at is null or sync_status = status);
  get diagnostics n = row_count;
  return jsonb_build_object('ok', true, 'deleted', n);
end
$fn$;

revoke all on function public.orders_clear(bigint) from public, anon;
grant execute on function public.orders_clear(bigint) to authenticated;

-- Перевірка: скільки скасованих зараз можна прибрати на кожному сайті
select site_id as "сайт", count(*) as "можна прибрати"
  from public.orders
 where status = 'cancelled' and pay_state <> 'paid' and (synced_at is null or sync_status = status)
 group by site_id order by site_id;
