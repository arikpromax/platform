-- ============================================================
--  МІГРАЦІЯ: вкладка «Фото сайту» для Кінного двору «Лелеки»
--  Готові картки-місця: власник відкриває картку, заливає фото —
--  і воно з'являється рівно там, де названо (номер, банер тощо).
--  Картки НЕ видаляти — лише редагувати (заливати нове фото).
--  Запускати ОДИН раз у SQL Editor проєкту platform
-- ============================================================

-- 1) Нова вкладка в конфігу
update public.sites
set config = jsonb_set(
  config,
  '{collections}',
  (config -> 'collections') || '{
    "key": "site_photos",
    "name": "Фото сайту",
    "fields": [
      {"key": "title", "name": "Місце на сайті", "type": "text"},
      {"key": "image", "name": "Фото", "type": "image"},
      {"key": "slot", "name": "Технічний код місця (не міняти!)", "type": "text", "extra": true}
    ]
  }'::jsonb
)
where slug = 'leleki';

-- 2) Вісім фото-місць сайту
insert into public.items (site_id, collection, title, extra, sort_order) values
  (2, 'site_photos', 'Головне фото (вгорі сторінки)',            '{"slot":"hero.jpg"}',           1),
  (2, 'site_photos', 'Фото «Про нас» (Місце, де час уповільнюється)', '{"slot":"about.jpg"}',     2),
  (2, 'site_photos', 'Номер «Стандарт» (картка)',                '{"slot":"room-standard.jpg"}',  3),
  (2, 'site_photos', 'Номер «Сімейний» (картка)',                '{"slot":"room-family.jpg"}',    4),
  (2, 'site_photos', 'Номер «Покращений з каміном» (картка)',    '{"slot":"room-fireplace.jpg"}', 5),
  (2, 'site_photos', '«Котедж» (картка)',                        '{"slot":"room-cottage.jpg"}',   6),
  (2, 'site_photos', '«Котедж люкс» (картка)',                   '{"slot":"room-lux.jpg"}',       7),
  (2, 'site_photos', 'Фото коней (банер)',                       '{"slot":"horses.jpg"}',         8);
