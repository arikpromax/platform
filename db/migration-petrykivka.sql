-- ============================================================
--  МІГРАЦІЯ: друга точка SUSHI BOOM (Петриківка)
--  1) В адмінці з'являються окремі вкладки для двох точок
--  2) Меню Петриківки створюється копією поточного меню Царичанки
--     (далі точки редагуються незалежно)
--  Запускати ОДИН раз у SQL Editor проєкту platform
-- ============================================================

-- 1) Оновлюємо конфіг сайту: чотири колекції замість двох
update public.sites set config = '{
  "collections": [
    {
      "key": "cats",
      "name": "Категорії · Царичанка",
      "fields": [
        {"key": "title", "name": "Назва категорії", "type": "text"},
        {"key": "catkey", "name": "Код (латиницею, не міняти)", "type": "text", "extra": true}
      ]
    },
    {
      "key": "menu",
      "name": "Меню · Царичанка",
      "fields": [
        {"key": "title", "name": "Назва", "type": "text"},
        {"key": "text", "name": "Склад", "type": "textarea"},
        {"key": "price", "name": "Ціна, грн", "type": "text"},
        {"key": "image", "name": "Фото", "type": "image"},
        {"key": "cat", "name": "Категорія", "type": "select-collection", "from": "cats", "extra": true},
        {"key": "top", "name": "Хіт продажів", "type": "checkbox", "extra": true},
        {"key": "unit", "name": "Кількість (для сетів)", "type": "text", "extra": true}
      ]
    },
    {
      "key": "cats_petr",
      "name": "Категорії · Петриківка",
      "fields": [
        {"key": "title", "name": "Назва категорії", "type": "text"},
        {"key": "catkey", "name": "Код (латиницею, не міняти)", "type": "text", "extra": true}
      ]
    },
    {
      "key": "menu_petr",
      "name": "Меню · Петриківка",
      "fields": [
        {"key": "title", "name": "Назва", "type": "text"},
        {"key": "text", "name": "Склад", "type": "textarea"},
        {"key": "price", "name": "Ціна, грн", "type": "text"},
        {"key": "image", "name": "Фото", "type": "image"},
        {"key": "cat", "name": "Категорія", "type": "select-collection", "from": "cats_petr", "extra": true},
        {"key": "top", "name": "Хіт продажів", "type": "checkbox", "extra": true},
        {"key": "unit", "name": "Кількість (для сетів)", "type": "text", "extra": true}
      ]
    }
  ],
  "texts": [
    {"key": "phone", "name": "Телефон"},
    {"key": "address", "name": "Адреса"}
  ]
}'
where slug = 'sushiboom';

-- 2) Копіюємо категорії Царичанки -> Петриківка
insert into public.items (site_id, collection, title, text, price, image_url, extra, sort_order)
select site_id, 'cats_petr', title, text, price, image_url, extra, sort_order
from public.items
where site_id = 1 and collection = 'cats';

-- 3) Копіюємо меню Царичанки -> Петриківка
insert into public.items (site_id, collection, title, text, price, image_url, extra, sort_order)
select site_id, 'menu_petr', title, text, price, image_url, extra, sort_order
from public.items
where site_id = 1 and collection = 'menu';
