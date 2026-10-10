-- Just shop: картку, яку програма магазину завела до нового бота, — переробити (10.10.2026).
--
-- Dunk Low Retro (DD1391-100) прийшов з УкрСкладу без назви, з якої видно, що це
-- кросівки, тож потрапив в «Аксесуари», без статі й лише з 4 фото. Новий бот
-- (збірка 2026-10-10-2) бере розділ, стать, бренд і назву з каталогу Nike і
-- ставить 5 фото. Позначаємо картку «шукати ще раз» — бот переробить її за
-- хвилину, щойно програма магазину зайде по замовлення.
--
-- Виконати після того, як залили бота 2026-10-10-2. Повторний запуск безпечний.

update public.items
   set extra = extra || jsonb_build_object('photos', '[]'::jsonb, 'photo_lookup', 'pending', 'title_auto', true)
 where site_id = 106 and collection = 'products' and extra->>'sku' = 'DD1391-100';

select id, title, extra->>'cat' as "розділ", extra->>'photo_lookup' as "пошук фото"
  from public.items where site_id = 106 and extra->>'sku' = 'DD1391-100';
