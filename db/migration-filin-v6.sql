-- ============================================================
--  «ФІЛІН» v6 — каталог кімнат
--  Гість натискає тип номера — відкривається каталог, і вже там
--  обирає конкретну кімнату: «Одномісний №2», «Двомісний №6» тощо.
--  У картці типу з’являється поле «Номери кімнат» — просто перелік
--  через кому. Скільки чисел напишете — стільки кімнат буде в каталозі.
--  Запускати ОДИН раз у SQL Editor. Безпечно перезапускати.
-- ============================================================

-- 1) Нове поле в картці типу номера
update public.sites
set config = jsonb_set(
  config,
  '{collections}',
  (
    select jsonb_agg(
      case when c->>'key' = 'rooms'
        then jsonb_set(c, '{fields}', '[
          {"key": "title", "name": "Назва номера", "type": "text"},
          {"key": "text", "name": "Опис", "type": "textarea"},
          {"key": "price", "name": "Ціна за ніч (напр. від 750)", "type": "text"},
          {"key": "image_url", "name": "Головне фото (показується у списку номерів)", "type": "image"},
          {"key": "photos", "name": "Ще фото цього номера", "type": "images", "extra": true},
          {"key": "cap", "name": "Скільки осіб (число)", "type": "text", "extra": true},
          {"key": "capw", "name": "Слово після числа (особа / особи)", "type": "text", "extra": true},
          {"key": "nums", "name": "Номери кімнат через кому (1, 2, 3) — з них складається каталог", "type": "text", "extra": true},
          {"key": "tags", "name": "Зручності через кому (Душ, Wi-Fi, ТВ)", "type": "text", "extra": true}
        ]'::jsonb)
        else c end
    )
    from jsonb_array_elements(config->'collections') c
  )
)
where slug = 'filin';

-- 2) Макети кімнат, щоб каталог було видно вже зараз.
--    Реальні номери власник просто перепише в адмінці.
update public.items
set extra = extra || jsonb_build_object('nums',
  case extra->>'kind'
    when 'single' then '1, 2, 3, 4'
    when 'double' then '5, 6, 7'
    when 'family' then '8, 9'
    else ''
  end)
where site_id = 4
  and collection = 'rooms'
  and coalesce(extra->>'nums', '') = '';
