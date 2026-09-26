-- Розділ «Підключення» в адмінці: ключі й налаштування відправника.
--
-- Власник сам вписує ключі Нової Пошти, оплати й обміну з програмою обліку.
-- Ключі лягають у закриту таблицю: адмінка може їх записати, але не прочитати —
-- у полі показується лише «ключ збережено». Читає їх тільки бот службовим ключем.
--
-- Виконати один раз у Supabase → SQL Editor. Повторний запуск безпечний.

-- ---------- 1) Сховище ключів ----------
create table if not exists public.site_keys (
  site_id    bigint not null references public.sites (id) on delete cascade,
  name       text   not null,     -- NP_KEY, LIQPAY_PUBLIC, LIQPAY_PRIVATE, MONO_TOKEN, SYNC_KEY
  value      text   not null,
  updated_at timestamptz not null default now(),
  who        text not null default '',
  primary key (site_id, name)
);
-- Політик немає навмисно: ні сайт, ні адмінка не прочитають значення.
alter table public.site_keys enable row level security;

-- Записати або стерти ключ. Порожнє значення прибирає ключ.
create or replace function public.set_site_key(p_site bigint, p_name text, p_value text)
returns jsonb language plpgsql security definer set search_path = public as
$fn$
declare v_name text := upper(btrim(coalesce(p_name, '')));
begin
  if not public.stock_can_edit(p_site) then
    return jsonb_build_object('ok', false, 'error', 'access');
  end if;
  if v_name not in ('NP_KEY', 'LIQPAY_PUBLIC', 'LIQPAY_PRIVATE', 'MONO_TOKEN', 'SYNC_KEY') then
    return jsonb_build_object('ok', false, 'error', 'name');
  end if;
  if length(coalesce(p_value, '')) > 500 then
    return jsonb_build_object('ok', false, 'error', 'long');
  end if;

  if btrim(coalesce(p_value, '')) = '' then
    delete from site_keys where site_id = p_site and name = v_name;
    return jsonb_build_object('ok', true, 'cleared', true);
  end if;

  insert into site_keys (site_id, name, value, who)
  values (p_site, v_name, btrim(p_value), public.stock_who())
  on conflict (site_id, name) do update
     set value = excluded.value, updated_at = now(), who = excluded.who;
  return jsonb_build_object('ok', true);
end
$fn$;

-- Що вже вписано: лише назви й дата, без самих ключів
create or replace function public.site_keys_state(p_site bigint)
returns jsonb language plpgsql security definer set search_path = public as
$fn$
begin
  if not (public.is_admin() or p_site = public.my_site()) then
    return jsonb_build_object('ok', false, 'error', 'access');
  end if;
  return jsonb_build_object('ok', true, 'keys', coalesce((
    select jsonb_object_agg(name, jsonb_build_object('filled', true, 'at', updated_at, 'tail', right(value, 4)))
      from site_keys where site_id = p_site), '{}'::jsonb));
end
$fn$;

revoke all on function public.set_site_key(bigint, text, text) from public, anon;
revoke all on function public.site_keys_state(bigint) from public, anon;
grant execute on function public.set_site_key(bigint, text, text) to authenticated;
grant execute on function public.site_keys_state(bigint) to authenticated;

-- ---------- 2) Налаштування відправлення й оплати — видно власнику ----------
alter table public.np_settings
  add column if not exists pay_provider   text not null default 'liqpay'
    check (pay_provider in ('liqpay', 'mono', 'off')),
  add column if not exists weight_default numeric not null default 0.5,
  add column if not exists updated_at     timestamptz not null default now();

drop policy if exists np_settings_read on public.np_settings;
create policy np_settings_read on public.np_settings
  for select to authenticated
  using (public.is_admin() or site_id = public.my_site());

drop policy if exists np_settings_write on public.np_settings;
create policy np_settings_write on public.np_settings
  for update to authenticated
  using (public.stock_can_edit(site_id))
  with check (public.stock_can_edit(site_id));

-- ---------- 3) Вкладка «Підключення» й розділ «Документи» в адмінці ----------
update public.sites s
   set config = s.config
     || jsonb_build_object('connect', true)
     || jsonb_build_object('texts', coalesce(s.config->'texts', '[]'::jsonb) || '[
          {"key": "oferta_text", "name": "Публічна оферта: текст сторінки", "multiline": true},
          {"key": "policy_text", "name": "Політика конфіденційності: текст сторінки", "multiline": true}
        ]'::jsonb)
     || jsonb_build_object('sections', coalesce(s.config->'sections', '[]'::jsonb) || '[
          {"name": "Документи",
           "note": "Публічна оферта й політика конфіденційності. Рядок, що починається з ##, стає заголовком; рядок з - стає пунктом списку. Замість {{sellerName}}, {{sellerCode}}, {{sellerAddress}}, {{email}} і {{phone}} на сторінці підставляються реквізити з розділу «Контакти й підвал».",
           "collections": [],
           "texts": ["oferta_text", "policy_text"]}
        ]'::jsonb)
 where s.id = 106
   and not (coalesce(s.config->'texts', '[]'::jsonb) @> '[{"key": "oferta_text"}]'::jsonb);
