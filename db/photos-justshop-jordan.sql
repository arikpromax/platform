-- Just shop: фото рукавиць Jordan J0003593980 і рюкзака Jordan 2A9006-023 (04.10.2026).
-- Фото додав власник; приведені до 864×864 на білому тлі.
-- Виконати ПІСЛЯ того, як фото опубліковані на сайті.
update items set extra = jsonb_set(extra, '{photos}', '["https://arikpromax.github.io/justshop/img/n/J0003593980-1.webp","https://arikpromax.github.io/justshop/img/n/J0003593980-2.webp","https://arikpromax.github.io/justshop/img/n/J0003593980-3.webp"]'::jsonb)
 where id = 1231 and site_id = 106;   -- Рукавиці чоловічі сенсорні Therma-Sphere
update items set extra = jsonb_set(extra, '{photos}', '["https://arikpromax.github.io/justshop/img/n/2A9006-023-1.webp","https://arikpromax.github.io/justshop/img/n/2A9006-023-2.webp","https://arikpromax.github.io/justshop/img/n/2A9006-023-3.webp"]'::jsonb)
 where id = 1234 and site_id = 106;   -- Рюкзак унісекс Jag Faux Fur Black

select title as товар, jsonb_array_length(extra->'photos') as фото
  from items where id in (1231, 1234);
