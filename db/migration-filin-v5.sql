-- ============================================================
--  «ФІЛІН» v5 — фото номера: кнопка «+ Додати фото»
--  Замість трьох окремих полів «Фото 2/3/4» — одне поле,
--  куди можна додавати скільки завгодно знімків, міняти порядок
--  і прибирати зайві.
--  Старі значення photo2/photo3/photo4 переносяться автоматично.
--  Запускати ОДИН раз у SQL Editor. Безпечно перезапускати.
-- ============================================================

-- 1) Переносимо вже завантажені фото 2/3/4 у новий список
update public.items
set extra = (extra - 'photo2' - 'photo3' - 'photo4')
            || jsonb_build_object('photos', (
                 select coalesce(jsonb_agg(v), '[]'::jsonb)
                 from (
                   select extra->>'photo2' as v
                   union all select extra->>'photo3'
                   union all select extra->>'photo4'
                 ) t
                 where v is not null and v <> ''
               ))
where site_id = 4
  and collection = 'rooms'
  and (extra ? 'photo2' or extra ? 'photo3' or extra ? 'photo4');

-- 2) Поля картки номера: одне поле «Фото номера» з кнопкою додавання
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
          {"key": "tags", "name": "Зручності через кому (Душ, Wi-Fi, ТВ)", "type": "text", "extra": true}
        ]'::jsonb)
        else c end
    )
    from jsonb_array_elements(config->'collections') c
  )
)
where slug = 'filin';
