-- ============================================================
--  ARAWEBSITE (портфоліо) у платформі адмінок
--  Згенеровано з D:/claude/portfolio/tools/gen-admin.mjs — не правте руками.
--
--  Виконати в Supabase → SQL Editor (весь файл разом).
--  Повторний запуск безпечний: оновлюється лише опис адмінки,
--  тексти лягають через on conflict do nothing, а картки
--  засіваються тільки в порожні колекції — наредаговане не затреться.
--  Після запуску внизу буде номер сайту — його вписати в
--  portfolio/lib/content.ts → SITE.
-- ============================================================

-- ---------- 1) Сайт і опис адмінки ----------
insert into public.sites (slug, name, paid_until, config) values (
  'arawebsite',
  'arawebsite — портфоліо',
  current_date + 3650,
  '{
  "collections": [
    {
      "key": "site_photos",
      "name": "Фото на сайті",
      "noAdd": true,
      "noDelete": true,
      "fields": [
        {
          "type": "image",
          "key": "image",
          "name": "Фото",
          "aspect": 1.7777777777777777,
          "hint": "Горизонтальне 16:9, щонайменше 1920 пікселів завширшки."
        }
      ]
    },
    {
      "key": "pains",
      "name": "Картки проблем",
      "fields": [
        {
          "type": "text",
          "key": "title",
          "name": "Заголовок картки",
          "hint": "Картки під темним блоком, по дві в ряд."
        },
        {
          "type": "textarea",
          "key": "text",
          "name": "Текст",
          "hint": "Сірий текст під заголовком."
        },
        {
          "type": "select",
          "key": "visual",
          "name": "Ілюстрація",
          "extra": true,
          "options": [
            {
              "value": "calls",
              "label": "Телефон: дзвінків немає"
            },
            {
              "value": "rival",
              "label": "Два сайти: ваш і конкурента"
            },
            {
              "value": "broken",
              "label": "Телефон: сайт не влазить"
            },
            {
              "value": "noprice",
              "label": "Картка без ціни"
            },
            {
              "value": "proof",
              "label": "Фото робіт і відгук"
            },
            {
              "value": "form",
              "label": "Форма заявки"
            },
            {
              "value": "screens",
              "label": "Комп''ютер, планшет і телефон"
            },
            {
              "value": "speed",
              "label": "Спідометр швидкості"
            },
            {
              "value": "map",
              "label": "Карта Google (справжня)"
            },
            {
              "value": "search",
              "label": "Пошук у Google"
            },
            {
              "value": "chat-brief",
              "label": "Листування: бриф"
            },
            {
              "value": "chat-support",
              "label": "Листування: підтримка"
            },
            {
              "value": "demo",
              "label": "Демо-версія сайту"
            },
            {
              "value": "sitemap",
              "label": "Схема сторінок (як база даних)"
            },
            {
              "value": "design",
              "label": "Редактор макета"
            },
            {
              "value": "code",
              "label": "Код"
            },
            {
              "value": "launch",
              "label": "Сайт опубліковано"
            },
            {
              "value": "layers",
              "label": "Сторінки: лендинг, візитка, каталог"
            },
            {
              "value": "niches",
              "label": "Іконки ніш"
            },
            {
              "value": "integrations",
              "label": "Хмара інтеграцій"
            },
            {
              "value": "content",
              "label": "Фото й текст"
            }
          ],
          "hint": "Намальований макет над текстом. Якщо завантажите своє фото нижче — замість макета покажеться фото."
        },
        {
          "type": "image",
          "key": "image",
          "name": "Своє фото замість ілюстрації",
          "aspect": 1.7777777777777777,
          "hint": "Необовʼязково. Щоб повернути ілюстрацію — приберіть фото."
        }
      ]
    },
    {
      "key": "features",
      "name": "Картки «Що я роблю»",
      "fields": [
        {
          "type": "text",
          "key": "title",
          "name": "Заголовок картки",
          "hint": "Картки під сірим блоком, по три в ряд."
        },
        {
          "type": "textarea",
          "key": "text",
          "name": "Текст",
          "hint": "Сірий текст під заголовком."
        },
        {
          "type": "select",
          "key": "visual",
          "name": "Ілюстрація",
          "extra": true,
          "options": [
            {
              "value": "calls",
              "label": "Телефон: дзвінків немає"
            },
            {
              "value": "rival",
              "label": "Два сайти: ваш і конкурента"
            },
            {
              "value": "broken",
              "label": "Телефон: сайт не влазить"
            },
            {
              "value": "noprice",
              "label": "Картка без ціни"
            },
            {
              "value": "proof",
              "label": "Фото робіт і відгук"
            },
            {
              "value": "form",
              "label": "Форма заявки"
            },
            {
              "value": "screens",
              "label": "Комп''ютер, планшет і телефон"
            },
            {
              "value": "speed",
              "label": "Спідометр швидкості"
            },
            {
              "value": "map",
              "label": "Карта Google (справжня)"
            },
            {
              "value": "search",
              "label": "Пошук у Google"
            },
            {
              "value": "chat-brief",
              "label": "Листування: бриф"
            },
            {
              "value": "chat-support",
              "label": "Листування: підтримка"
            },
            {
              "value": "demo",
              "label": "Демо-версія сайту"
            },
            {
              "value": "sitemap",
              "label": "Схема сторінок (як база даних)"
            },
            {
              "value": "design",
              "label": "Редактор макета"
            },
            {
              "value": "code",
              "label": "Код"
            },
            {
              "value": "launch",
              "label": "Сайт опубліковано"
            },
            {
              "value": "layers",
              "label": "Сторінки: лендинг, візитка, каталог"
            },
            {
              "value": "niches",
              "label": "Іконки ніш"
            },
            {
              "value": "integrations",
              "label": "Хмара інтеграцій"
            },
            {
              "value": "content",
              "label": "Фото й текст"
            }
          ],
          "hint": "Намальований макет над текстом. Якщо завантажите своє фото нижче — замість макета покажеться фото."
        },
        {
          "type": "image",
          "key": "image",
          "name": "Своє фото замість ілюстрації",
          "aspect": 1.7777777777777777,
          "hint": "Необовʼязково. Щоб повернути ілюстрацію — приберіть фото."
        }
      ]
    },
    {
      "key": "stats",
      "name": "Цифри",
      "fields": [
        {
          "type": "text",
          "key": "title",
          "name": "Підпис над числом",
          "hint": "Дрібно великими літерами. Напр.: Сайт під ключ"
        },
        {
          "type": "text",
          "key": "prefix",
          "name": "Перед числом",
          "extra": true,
          "hint": "Напр.: «від $» або «1–». Можна лишити порожнім."
        },
        {
          "type": "text",
          "key": "number",
          "name": "Число",
          "extra": true,
          "hint": "Лише цифри — вони «набігають» при прокрутці. Напр.: 500"
        },
        {
          "type": "text",
          "key": "from",
          "name": "З якого числа рахувати",
          "extra": true,
          "hint": "Зазвичай 0. Для «1–3 дні» — 1, щоб не мигнуло «1–0»."
        },
        {
          "type": "text",
          "key": "text",
          "name": "Підпис під числом",
          "hint": "Напр.: дні"
        }
      ]
    },
    {
      "key": "steps",
      "name": "Етапи роботи",
      "fields": [
        {
          "type": "text",
          "key": "title",
          "name": "Назва на вкладці",
          "hint": "Коротко: Бриф, Дизайн, Запуск…"
        },
        {
          "type": "text",
          "key": "heading",
          "name": "Великий заголовок",
          "extra": true,
          "hint": "Порожньо — такий самий, як на вкладці. Напр.: Демосайт — безкоштовно"
        },
        {
          "type": "textarea",
          "key": "text",
          "name": "Опис"
        },
        {
          "type": "text",
          "key": "btn",
          "name": "Кнопка до заявки",
          "extra": true,
          "hint": "Необовʼязково. Напр.: Хочу демосайт — кнопка веде до форми заявки."
        },
        {
          "type": "select",
          "key": "visual",
          "name": "Ілюстрація",
          "extra": true,
          "options": [
            {
              "value": "calls",
              "label": "Телефон: дзвінків немає"
            },
            {
              "value": "rival",
              "label": "Два сайти: ваш і конкурента"
            },
            {
              "value": "broken",
              "label": "Телефон: сайт не влазить"
            },
            {
              "value": "noprice",
              "label": "Картка без ціни"
            },
            {
              "value": "proof",
              "label": "Фото робіт і відгук"
            },
            {
              "value": "form",
              "label": "Форма заявки"
            },
            {
              "value": "screens",
              "label": "Комп''ютер, планшет і телефон"
            },
            {
              "value": "speed",
              "label": "Спідометр швидкості"
            },
            {
              "value": "map",
              "label": "Карта Google (справжня)"
            },
            {
              "value": "search",
              "label": "Пошук у Google"
            },
            {
              "value": "chat-brief",
              "label": "Листування: бриф"
            },
            {
              "value": "chat-support",
              "label": "Листування: підтримка"
            },
            {
              "value": "demo",
              "label": "Демо-версія сайту"
            },
            {
              "value": "sitemap",
              "label": "Схема сторінок (як база даних)"
            },
            {
              "value": "design",
              "label": "Редактор макета"
            },
            {
              "value": "code",
              "label": "Код"
            },
            {
              "value": "launch",
              "label": "Сайт опубліковано"
            },
            {
              "value": "layers",
              "label": "Сторінки: лендинг, візитка, каталог"
            },
            {
              "value": "niches",
              "label": "Іконки ніш"
            },
            {
              "value": "integrations",
              "label": "Хмара інтеграцій"
            },
            {
              "value": "content",
              "label": "Фото й текст"
            }
          ],
          "hint": "Намальований макет над текстом. Якщо завантажите своє фото нижче — замість макета покажеться фото."
        },
        {
          "type": "image",
          "key": "image",
          "name": "Своє фото замість ілюстрації",
          "aspect": 1.6,
          "hint": "Необовʼязково. Щоб повернути ілюстрацію — приберіть фото."
        }
      ]
    },
    {
      "key": "cases",
      "name": "Кейси",
      "fields": [
        {
          "type": "text",
          "key": "title",
          "name": "Назва проєкту",
          "hint": "Біля перемикача. Напр.: Fuji Sushi"
        },
        {
          "type": "text",
          "key": "meta",
          "name": "Ніша · місто",
          "extra": true,
          "hint": "Бірюзово великими літерами. Напр.: Доставка суші · Умань"
        },
        {
          "type": "textarea",
          "key": "text",
          "name": "Опис",
          "hint": "Що зроблено на сайті."
        },
        {
          "type": "text",
          "key": "result",
          "name": "Результат",
          "extra": true,
          "hint": "Жирним після опису. Пишіть лише правду. Напр.: Замовлення одразу в Telegram."
        },
        {
          "type": "text",
          "key": "link",
          "name": "Посилання на сайт",
          "extra": true,
          "hint": "Повна адреса з https://. Порожньо — напис «Сайт готується до запуску»."
        },
        {
          "type": "text",
          "key": "url_label",
          "name": "Адреса у віконці браузера",
          "extra": true,
          "hint": "Сірий рядок над скриншотом. Напр.: fujisushi.com.ua"
        },
        {
          "type": "image",
          "key": "image",
          "name": "Скриншот на компʼютері",
          "aspect": 1.6,
          "hint": "Перший екран сайту, горизонтальний 16:10 (напр. 1280×800)."
        },
        {
          "type": "image",
          "key": "image_mobile",
          "name": "Скриншот на телефоні",
          "extra": true,
          "aspect": 0.46208530805687204,
          "hint": "Вертикальний, як екран телефона (напр. 390×844). Показується в iPhone."
        },
        {
          "type": "checkbox",
          "key": "dev",
          "name": "Сайт ще в розробці",
          "extra": true,
          "hint": "Біля ніші зʼявиться жовта позначка «В розробці»."
        }
      ]
    },
    {
      "key": "usps",
      "name": "Картки «Чому я»",
      "fields": [
        {
          "type": "text",
          "key": "title",
          "name": "Заголовок картки",
          "hint": "Картки по три в ряд."
        },
        {
          "type": "textarea",
          "key": "text",
          "name": "Текст",
          "hint": "Сірий текст під заголовком."
        },
        {
          "type": "select",
          "key": "visual",
          "name": "Ілюстрація",
          "extra": true,
          "options": [
            {
              "value": "calls",
              "label": "Телефон: дзвінків немає"
            },
            {
              "value": "rival",
              "label": "Два сайти: ваш і конкурента"
            },
            {
              "value": "broken",
              "label": "Телефон: сайт не влазить"
            },
            {
              "value": "noprice",
              "label": "Картка без ціни"
            },
            {
              "value": "proof",
              "label": "Фото робіт і відгук"
            },
            {
              "value": "form",
              "label": "Форма заявки"
            },
            {
              "value": "screens",
              "label": "Комп''ютер, планшет і телефон"
            },
            {
              "value": "speed",
              "label": "Спідометр швидкості"
            },
            {
              "value": "map",
              "label": "Карта Google (справжня)"
            },
            {
              "value": "search",
              "label": "Пошук у Google"
            },
            {
              "value": "chat-brief",
              "label": "Листування: бриф"
            },
            {
              "value": "chat-support",
              "label": "Листування: підтримка"
            },
            {
              "value": "demo",
              "label": "Демо-версія сайту"
            },
            {
              "value": "sitemap",
              "label": "Схема сторінок (як база даних)"
            },
            {
              "value": "design",
              "label": "Редактор макета"
            },
            {
              "value": "code",
              "label": "Код"
            },
            {
              "value": "launch",
              "label": "Сайт опубліковано"
            },
            {
              "value": "layers",
              "label": "Сторінки: лендинг, візитка, каталог"
            },
            {
              "value": "niches",
              "label": "Іконки ніш"
            },
            {
              "value": "integrations",
              "label": "Хмара інтеграцій"
            },
            {
              "value": "content",
              "label": "Фото й текст"
            }
          ],
          "hint": "Намальований макет над текстом. Якщо завантажите своє фото нижче — замість макета покажеться фото."
        },
        {
          "type": "image",
          "key": "image",
          "name": "Своє фото замість ілюстрації",
          "aspect": 1.7777777777777777,
          "hint": "Необовʼязково. Щоб повернути ілюстрацію — приберіть фото."
        }
      ]
    },
    {
      "key": "factors",
      "name": "Що впливає на ціну",
      "fields": [
        {
          "type": "text",
          "key": "title",
          "name": "Назва вкладки",
          "hint": "І заголовок білої картки. Напр.: Дизайн"
        },
        {
          "type": "textarea",
          "key": "text",
          "name": "Пояснення",
          "hint": "Текст у білій картці."
        },
        {
          "type": "select",
          "key": "visual",
          "name": "Ілюстрація",
          "extra": true,
          "options": [
            {
              "value": "calls",
              "label": "Телефон: дзвінків немає"
            },
            {
              "value": "rival",
              "label": "Два сайти: ваш і конкурента"
            },
            {
              "value": "broken",
              "label": "Телефон: сайт не влазить"
            },
            {
              "value": "noprice",
              "label": "Картка без ціни"
            },
            {
              "value": "proof",
              "label": "Фото робіт і відгук"
            },
            {
              "value": "form",
              "label": "Форма заявки"
            },
            {
              "value": "screens",
              "label": "Комп''ютер, планшет і телефон"
            },
            {
              "value": "speed",
              "label": "Спідометр швидкості"
            },
            {
              "value": "map",
              "label": "Карта Google (справжня)"
            },
            {
              "value": "search",
              "label": "Пошук у Google"
            },
            {
              "value": "chat-brief",
              "label": "Листування: бриф"
            },
            {
              "value": "chat-support",
              "label": "Листування: підтримка"
            },
            {
              "value": "demo",
              "label": "Демо-версія сайту"
            },
            {
              "value": "sitemap",
              "label": "Схема сторінок (як база даних)"
            },
            {
              "value": "design",
              "label": "Редактор макета"
            },
            {
              "value": "code",
              "label": "Код"
            },
            {
              "value": "launch",
              "label": "Сайт опубліковано"
            },
            {
              "value": "layers",
              "label": "Сторінки: лендинг, візитка, каталог"
            },
            {
              "value": "niches",
              "label": "Іконки ніш"
            },
            {
              "value": "integrations",
              "label": "Хмара інтеграцій"
            },
            {
              "value": "content",
              "label": "Фото й текст"
            }
          ],
          "hint": "Намальований макет над текстом. Якщо завантажите своє фото нижче — замість макета покажеться фото."
        },
        {
          "type": "image",
          "key": "image",
          "name": "Своє фото замість ілюстрації",
          "aspect": 1.6,
          "hint": "Необовʼязково. Щоб повернути ілюстрацію — приберіть фото."
        }
      ]
    },
    {
      "key": "team",
      "name": "Команда",
      "fields": [
        {
          "type": "text",
          "key": "title",
          "name": "Імʼя",
          "hint": "Напр.: Ярослав"
        },
        {
          "type": "text",
          "key": "role",
          "name": "Роль",
          "extra": true,
          "hint": "Бірюзова плашка під імʼям. Напр.: Засновник, Дизайнер, Розробник"
        },
        {
          "type": "textarea",
          "key": "text",
          "name": "Коротко про людину",
          "hint": "Що робить у команді, 1–3 речення."
        },
        {
          "type": "image",
          "key": "image",
          "name": "Фото",
          "aspect": 1,
          "hint": "Квадратне, обличчя по центру — на сайті воно в колі."
        }
      ]
    }
  ],
  "texts": [
    {
      "key": "tg_user",
      "name": "Telegram (нікнейм)",
      "hint": "Без @. Кругла кнопка праворуч унизу, значок у шапці, підвал і панель «Про нас». Напр.: arikpromax"
    },
    {
      "key": "phone",
      "name": "Телефон",
      "hint": "У підвалі. Посилання для дзвінка сайт складе сам. Напр.: +380 95 764 34 16"
    },
    {
      "key": "email",
      "name": "Email",
      "hint": "У підвалі. Напр.: arikpro92@gmail.com"
    },
    {
      "key": "hero_kicker",
      "name": "Маленький напис над заголовком",
      "hint": "Бірюзовий рядок великими літерами. Порожньо — напису немає."
    },
    {
      "key": "hero_title",
      "name": "Головний заголовок",
      "hint": "Найбільший текст під фото. Напр.: Сайт, який приносить заявки"
    },
    {
      "key": "hero_btn",
      "name": "Кнопка праворуч",
      "hint": "Веде до блоку «Кейси». Порожньо — кнопки немає."
    },
    {
      "key": "pain_h",
      "name": "Заголовок розділу",
      "hint": "Великими літерами по центру. Напр.: Знайомо?"
    },
    {
      "key": "pain_panel_h",
      "name": "Темний блок: заголовок",
      "hint": "Великий текст у темному блоці з ілюстрацією."
    },
    {
      "key": "pain_panel_p",
      "name": "Темний блок: текст",
      "hint": "Абзац під заголовком темного блоку.",
      "multiline": true
    },
    {
      "key": "sol_h",
      "name": "Заголовок розділу",
      "hint": "Великими літерами по центру. Напр.: Що я роблю"
    },
    {
      "key": "sol_panel_h",
      "name": "Сірий блок: заголовок",
      "hint": "Великий текст праворуч від ілюстрації з ноутбуком і телефоном."
    },
    {
      "key": "sol_panel_p",
      "name": "Сірий блок: текст",
      "hint": "Абзац під заголовком.",
      "multiline": true
    },
    {
      "key": "sol_admin_h",
      "name": "Сайт + адмін-панель: заголовок",
      "hint": "Блок зі знімком адмінки після карток. Порожньо — блоку немає. Напр.: Сайт + адмін-панель"
    },
    {
      "key": "sol_admin_p",
      "name": "Сайт + адмін-панель: текст",
      "hint": "Абзац під заголовком.",
      "multiline": true
    },
    {
      "key": "demo_kicker",
      "name": "Маленький напис угорі",
      "hint": "Бірюзовий рядок над великим заголовком."
    },
    {
      "key": "demo_h",
      "name": "Великий заголовок",
      "hint": "Курсивом великими літерами. Напр.: Демосайт — безкоштовно"
    },
    {
      "key": "demo_sub",
      "name": "Текст під круглою кнопкою",
      "hint": "Кругла кнопка зі стрілкою веде до форми заявки.",
      "multiline": true
    },
    {
      "key": "proc_h",
      "name": "Заголовок розділу",
      "hint": "Великими літерами по центру. Напр.: Як я працюю"
    },
    {
      "key": "proc_lead_h",
      "name": "Підзаголовок",
      "hint": "Під заголовком розділу, над цифрами."
    },
    {
      "key": "proc_lead_p",
      "name": "Рядок під підзаголовком",
      "hint": "Порожньо — рядка немає.",
      "multiline": true
    },
    {
      "key": "cases_h",
      "name": "Заголовок розділу",
      "hint": "Великими літерами по центру. Напр.: Кейси"
    },
    {
      "key": "cases_card_h",
      "name": "Біла картка: заголовок",
      "hint": "Над перемикачами кейсів."
    },
    {
      "key": "cases_card_p",
      "name": "Біла картка: текст",
      "hint": "Між заголовком і перемикачами.",
      "multiline": true
    },
    {
      "key": "why_h",
      "name": "Заголовок розділу",
      "hint": "Великими літерами по центру. Напр.: Чому я"
    },
    {
      "key": "why_sub",
      "name": "Рядок під заголовком",
      "hint": "Сірий текст по центру. Порожньо — рядка немає."
    },
    {
      "key": "price_h",
      "name": "Заголовок розділу",
      "hint": "Великими літерами по центру. Напр.: Вартість"
    },
    {
      "key": "price_from",
      "name": "Слово перед ціною",
      "hint": "Дрібно ліворуч від ціни. Напр.: від"
    },
    {
      "key": "price_value",
      "name": "Ціна",
      "hint": "Величезні цифри. Напр.: $500. Число в розділі «Як я працюю» міняється окремо — у картках «Цифри»."
    },
    {
      "key": "price_sub",
      "name": "Текст під ціною",
      "hint": "",
      "multiline": true
    },
    {
      "key": "price_kicker",
      "name": "Біла картка: напис угорі",
      "hint": "Над назвою вкладки. Напр.: Що впливає на ціну"
    },
    {
      "key": "price_note",
      "name": "Біла картка: примітка",
      "hint": "Сірий рядок з іконкою. Напр.: Фінальна ціна — після прорахунку"
    },
    {
      "key": "price_btn",
      "name": "Біла картка: кнопка",
      "hint": "Веде до форми заявки. Порожньо — кнопки немає."
    },
    {
      "key": "price_integrations",
      "name": "Інтеграції на ілюстрації",
      "hint": "Вкладка «Інтеграції»: кожна з нового рядка. Іконку сайт добере сам за назвою (Telegram, Instagram, оплата, CRM…).",
      "multiline": true
    },
    {
      "key": "price_integr_more",
      "name": "Остання бірюзова плашка",
      "hint": "Після списку інтеграцій. Напр.: І будь-що інше. Порожньо — плашки немає."
    },
    {
      "key": "contact_kicker",
      "name": "Маленький напис угорі",
      "hint": "Бірюзовий рядок над заголовком."
    },
    {
      "key": "contact_h",
      "name": "Заголовок",
      "hint": "Великий текст ліворуч від форми."
    },
    {
      "key": "contact_lead",
      "name": "Текст під заголовком",
      "hint": "",
      "multiline": true
    },
    {
      "key": "contact_points",
      "name": "Пункти з галочками",
      "hint": "Кожен пункт з нового рядка.",
      "multiline": true
    },
    {
      "key": "form_h",
      "name": "Форма: заголовок",
      "hint": "Угорі білої форми. Напр.: Отримати розрахунок"
    },
    {
      "key": "form_sub",
      "name": "Форма: рядок під заголовком",
      "hint": ""
    },
    {
      "key": "form_business",
      "name": "Форма: варіанти «Тип бізнесу»",
      "hint": "Кожен варіант з нового рядка — це список, з якого обирає клієнт.",
      "multiline": true
    },
    {
      "key": "form_nocall",
      "name": "Форма: галочка під номером",
      "hint": "Видно, коли клієнт обрав «Телефон». Відмітка приходить у заявці поруч зі способом зв''язку. Порожньо — галочки немає."
    },
    {
      "key": "form_btn",
      "name": "Форма: кнопка",
      "hint": "Напр.: Надіслати заявку"
    },
    {
      "key": "form_ok",
      "name": "Форма: повідомлення після відправки",
      "hint": "Зелена плашка, коли заявку надіслано.",
      "multiline": true
    },
    {
      "key": "form_note",
      "name": "Форма: рядок під кнопкою",
      "hint": "Дрібно, з замочком. Напр.: Дані використовую лише для зв''язку з вами"
    },
    {
      "key": "about_h",
      "name": "Заголовок панелі",
      "hint": "Панель, що відкривається круглою кнопкою ліворуч унизу або пунктом меню. Напр.: Про нас"
    },
    {
      "key": "header_cta",
      "name": "Кнопка в шапці",
      "hint": "Праворуч угорі, веде до форми заявки. Напр.: Розрахувати сайт"
    },
    {
      "key": "nav_services",
      "name": "Меню: пункт 1",
      "hint": "Веде до розділу «Що я роблю». Напр.: Послуги"
    },
    {
      "key": "nav_cases",
      "name": "Меню: пункт 2",
      "hint": "Веде до розділу «Кейси»."
    },
    {
      "key": "nav_about",
      "name": "Меню: пункт 3",
      "hint": "Відкриває панель «Про нас»."
    },
    {
      "key": "nav_price",
      "name": "Меню: пункт 4",
      "hint": "Веде до розділу «Вартість»."
    },
    {
      "key": "subnav_year",
      "name": "Сіра смужка: рік",
      "hint": "Ліворуч під шапкою. Порожньо — року немає."
    },
    {
      "key": "subnav_name",
      "name": "Сіра смужка: назва",
      "hint": "Поруч із роком. Напр.: arawebsite · сайти для бізнесу"
    },
    {
      "key": "tab_top",
      "name": "Вкладка 1",
      "hint": "Смуга вкладок під шапкою: перший екран. Напр.: Огляд"
    },
    {
      "key": "tab_solution",
      "name": "Вкладка 2",
      "hint": "Розділ «Що я роблю». Напр.: Рішення"
    },
    {
      "key": "tab_process",
      "name": "Вкладка 3",
      "hint": "Розділ «Як я працюю»."
    },
    {
      "key": "tab_cases",
      "name": "Вкладка 4",
      "hint": "Розділ «Кейси»."
    },
    {
      "key": "tab_price",
      "name": "Вкладка 5",
      "hint": "Розділ «Вартість»."
    },
    {
      "key": "footer_copy",
      "name": "Підвал: рядок унизу",
      "hint": "Напр.: © 2026 Веб-студія «arawebsite». Сайти, які приносять заявки."
    },
    {
      "key": "seo_title",
      "name": "Заголовок у Google і на вкладці браузера",
      "hint": "До 60 символів."
    },
    {
      "key": "seo_desc",
      "name": "Опис у Google і соцмережах",
      "hint": "1–2 речення, до 160 символів. Показується під заголовком у пошуку й у прев''ю посилання.",
      "multiline": true
    }
  ],
  "sections": [
    {
      "name": "Контакти",
      "note": "Вписуєте один раз — змінюється на всьому сайті: кнопки, шапка, підвал, панель «Про нас».",
      "texts": [
        "tg_user",
        "phone",
        "email"
      ]
    },
    {
      "name": "Перший екран",
      "note": "Велике фото на всю ширину, під ним заголовок і кнопка.",
      "texts": [
        "hero_kicker",
        "hero_title",
        "hero_btn"
      ],
      "photos": [
        "hero"
      ]
    },
    {
      "name": "Знайомо?",
      "note": "Темний блок з ілюстрацією і картки під ним. Картку можна додати, прибрати чи перетягнути — сайт сам розкладе їх по дві в ряд.",
      "texts": [
        "pain_h",
        "pain_panel_h",
        "pain_panel_p"
      ],
      "collections": [
        "pains"
      ]
    },
    {
      "name": "Що я роблю",
      "note": "Сірий блок з ноутбуком і телефоном, картки по три в ряд, а під ними блок «Сайт + адмін-панель» зі знімком адмінки.",
      "texts": [
        "sol_h",
        "sol_panel_h",
        "sol_panel_p",
        "sol_admin_h",
        "sol_admin_p"
      ],
      "collections": [
        "features"
      ],
      "photos": [
        "admin"
      ]
    },
    {
      "name": "Банер «Демосайт»",
      "note": "Темна смуга на всю ширину з круглою кнопкою.",
      "texts": [
        "demo_kicker",
        "demo_h",
        "demo_sub"
      ]
    },
    {
      "name": "Як я працюю",
      "note": "Заголовок, великі цифри, що «набігають», і вкладки з етапами.",
      "texts": [
        "proc_h",
        "proc_lead_h",
        "proc_lead_p"
      ],
      "collections": [
        "stats",
        "steps"
      ]
    },
    {
      "name": "Кейси",
      "note": "Скриншот сайту в браузері й телефоні, біла картка з перемикачами. Кожен кейс — окрема картка.",
      "texts": [
        "cases_h",
        "cases_card_h",
        "cases_card_p"
      ],
      "collections": [
        "cases"
      ]
    },
    {
      "name": "Чому я",
      "note": "Заголовок, рядок під ним і картки по три в ряд.",
      "texts": [
        "why_h",
        "why_sub"
      ],
      "collections": [
        "usps"
      ]
    },
    {
      "name": "Вартість",
      "note": "Велика ціна, вкладки «що впливає на ціну» з ілюстрацією і білою карткою.",
      "texts": [
        "price_h",
        "price_from",
        "price_value",
        "price_sub",
        "price_kicker",
        "price_note",
        "price_btn",
        "price_integrations",
        "price_integr_more"
      ],
      "collections": [
        "factors"
      ]
    },
    {
      "name": "Заявка",
      "note": "Сірий блок унизу: текст ліворуч і форма праворуч. Заявки, як і раніше, приходять у вашу таблицю.",
      "texts": [
        "contact_kicker",
        "contact_h",
        "contact_lead",
        "contact_points",
        "form_h",
        "form_sub",
        "form_business",
        "form_nocall",
        "form_btn",
        "form_ok",
        "form_note"
      ]
    },
    {
      "name": "Про нас",
      "note": "Панель, що виїжджає зліва: кругла кнопка ліворуч унизу або пункт меню. Нова людина в команді — нова картка.",
      "texts": [
        "about_h"
      ],
      "collections": [
        "team"
      ]
    },
    {
      "name": "Шапка й підвал",
      "note": "Меню, кнопка в шапці, сіра смужка з вкладками і рядок у підвалі.",
      "texts": [
        "header_cta",
        "nav_services",
        "nav_cases",
        "nav_about",
        "nav_price",
        "subnav_year",
        "subnav_name",
        "tab_top",
        "tab_solution",
        "tab_process",
        "tab_cases",
        "tab_price",
        "footer_copy"
      ]
    },
    {
      "name": "Google і соцмережі",
      "note": "Як сайт виглядає в пошуку Google і коли посиланням діляться в месенджерах.",
      "texts": [
        "seo_title",
        "seo_desc"
      ]
    }
  ]
}'::jsonb
)
on conflict (slug) do update set config = excluded.config, name = excluded.name;

-- ---------- фото на сайті: hero ----------
with s as (select id from public.sites where slug = 'arawebsite')
insert into public.items (site_id, collection, title, text, image_url, extra, sort_order)
select s.id, 'site_photos', 'Фото першого екрана', '', 'https://arawebsite.com/hero.webp', '{"slot":"hero"}'::jsonb, 1
from s
where not exists (select 1 from public.items i, s where i.site_id = s.id and i.collection = 'site_photos' and i.extra->>'slot' = 'hero');

-- ---------- фото на сайті: admin ----------
with s as (select id from public.sites where slug = 'arawebsite')
insert into public.items (site_id, collection, title, text, image_url, extra, sort_order)
select s.id, 'site_photos', 'Фото адмін-панелі', '', 'https://arawebsite.com/admin-panel.jpg', '{"slot":"admin"}'::jsonb, 2
from s
where not exists (select 1 from public.items i, s where i.site_id = s.id and i.collection = 'site_photos' and i.extra->>'slot' = 'admin');

-- ---------- картки: pains ----------
with s as (select id from public.sites where slug = 'arawebsite')
insert into public.items (site_id, collection, title, text, image_url, extra, sort_order)
select s.id, v.collection, v.title, v.text, v.image_url, v.extra::jsonb, v.n
from s, (values
  ('pains', 'Тиша замість дзвінків', 'Сайт працює, а заявок і дзвінків майже немає. Бюджет на нього витрачений, віддачі — нуль.', '', '{"visual":"calls"}', 1),
  ('pains', 'Конкурент виглядає надійніше', 'Поруч компанія з сучасним сайтом забирає ваших клієнтів — просто тому, що викликає більше довіри.', '', '{"visual":"rival"}', 2),
  ('pains', 'Незручно з телефону', 'Сайт застарів, довго вантажиться й «розповзається» на смартфоні. А саме звідти заходить більшість людей.', '', '{"visual":"broken"}', 3),
  ('pains', 'Незрозуміло, скільки коштує', 'Клієнт не бачить цін і прикладів робіт — і йде до того, хто все показав одразу.', '', '{"visual":"noprice"}', 4)
) as v(collection, title, text, image_url, extra, n)
where not exists (select 1 from public.items i, s where i.site_id = s.id and i.collection = 'pains');

-- ---------- картки: features ----------
with s as (select id from public.sites where slug = 'arawebsite')
insert into public.items (site_id, collection, title, text, image_url, extra, sort_order)
select s.id, v.collection, v.title, v.text, v.image_url, v.extra::jsonb, v.n
from s, (values
  ('features', 'Докази, а не обіцянки', 'Фото реальних робіт, відгуки клієнтів і чіткі гарантії — те, що знімає сумніви ще до дзвінка.', '', '{"visual":"proof"}', 1),
  ('features', 'Заявка в один клік', 'Помітна форма та дзвінок чи чат у пару дотиків. Без зайвих полів, які відлякують.', '', '{"visual":"form"}', 2),
  ('features', 'Зручно на будь-якому екрані', 'Однаково чітко й охайно на телефоні, планшеті та комп''ютері.', '', '{"visual":"screens"}', 3),
  ('features', 'Швидке завантаження', 'Сторінка відкривається за секунди — людина не встигає піти до конкурента.', '', '{"visual":"speed"}', 4),
  ('features', 'Інтеграція з Google Maps', 'Клієнт одразу бачить, де ви знаходитесь, і як до вас доїхати.', '', '{"visual":"map"}', 5),
  ('features', 'SEO під локальні запити', 'Вас знаходять саме ті, хто шукає вашу послугу поруч із вами.', '', '{"visual":"search"}', 6)
) as v(collection, title, text, image_url, extra, n)
where not exists (select 1 from public.items i, s where i.site_id = s.id and i.collection = 'features');

-- ---------- картки: stats ----------
with s as (select id from public.sites where slug = 'arawebsite')
insert into public.items (site_id, collection, title, text, image_url, extra, sort_order)
select s.id, v.collection, v.title, v.text, v.image_url, v.extra::jsonb, v.n
from s, (values
  ('stats', 'Сайт під ключ', 'дні', '', '{"prefix":"1–","number":"3","from":"1"}', 1),
  ('stats', 'Демосайт до оплати', 'безкоштовно', '', '{"prefix":"$","number":"0","from":"0"}', 2),
  ('stats', 'Вартість сайту', 'фінальна — після прорахунку', '', '{"prefix":"від $","number":"500","from":"0"}', 3)
) as v(collection, title, text, image_url, extra, n)
where not exists (select 1 from public.items i, s where i.site_id = s.id and i.collection = 'stats');

-- ---------- картки: steps ----------
with s as (select id from public.sites where slug = 'arawebsite')
insert into public.items (site_id, collection, title, text, image_url, extra, sort_order)
select s.id, v.collection, v.title, v.text, v.image_url, v.extra::jsonb, v.n
from s, (values
  ('steps', 'Бриф', 'Розбираюся у вашому бізнесі, клієнтах і меті сайту.', '', '{"heading":"Бриф","visual":"chat-brief","btn":""}', 1),
  ('steps', 'Демосайт', 'Показую, як виглядатиме ваш сайт. До будь-якої оплати й без зобов''язань.', '', '{"heading":"Демосайт — безкоштовно","visual":"demo","btn":"Хочу демосайт"}', 2),
  ('steps', 'Структура', 'Складаю логіку сторінок і тексти, що ведуть до заявки.', '', '{"heading":"Структура та контент","visual":"sitemap","btn":""}', 3),
  ('steps', 'Дизайн', 'Малюю сучасний макет під вашу нішу й бренд.', '', '{"heading":"Дизайн","visual":"design","btn":""}', 4),
  ('steps', 'Розробка', 'Збираю швидкий адаптивний сайт із формами та інтеграціями.', '', '{"heading":"Розробка","visual":"code","btn":""}', 5),
  ('steps', 'Запуск', 'Публікуємо сайт, і я лишаюся на зв''язку для правок.', '', '{"heading":"Запуск і підтримка","visual":"launch","btn":""}', 6)
) as v(collection, title, text, image_url, extra, n)
where not exists (select 1 from public.items i, s where i.site_id = s.id and i.collection = 'steps');

-- ---------- картки: cases ----------
with s as (select id from public.sites where slug = 'arawebsite')
insert into public.items (site_id, collection, title, text, image_url, extra, sort_order)
select s.id, v.collection, v.title, v.text, v.image_url, v.extra::jsonb, v.n
from s, (values
  ('cases', 'Just Shop', 'Інтернет-магазин оригінального одягу й взуття з Європи: каталог із розмірами, кошик і доставка Новою Поштою.', 'https://arawebsite.com/cases/justshop.jpg', '{"meta":"Магазин одягу · Київ","url_label":"justshopp.com.ua","link":"https://justshopp.com.ua/","result":"Понад 300 товарів і адмінка для власника.","image_mobile":"https://arawebsite.com/cases/justshop-m.jpg","dev":false}', 1),
  ('cases', 'Alexon Home Services', 'Сайт англійською для майстра з ремонту: послуги, слайдер «до / після», галерея робіт і форма зворотного дзвінка.', 'https://arawebsite.com/cases/alexon.jpg', '{"meta":"Майстер з ремонту · Едмонтон, Канада","url_label":"arikpromax.github.io/tubass","link":"https://arikpromax.github.io/tubass/","result":"Окрема сторінка на кожну послугу.","image_mobile":"https://arawebsite.com/cases/alexon-m.jpg","dev":false}', 2),
  ('cases', 'Fuji Sushi', 'Сайт доставки з меню й кошиком. Замовлення одразу приходять у Telegram.', 'https://arawebsite.com/cases/fuji.jpg', '{"meta":"Доставка суші · Умань","url_label":"fujisushi.com.ua","link":"https://fujisushi.com.ua/","result":"Замовити можна без дзвінка.","image_mobile":"https://arawebsite.com/cases/fuji-m.jpg","dev":false}', 3),
  ('cases', 'SushiЮ', 'Сайт доставки для двох закладів: меню, кошик і вибір найближчої точки з її телефоном та графіком.', 'https://arawebsite.com/cases/sushiu.jpg', '{"meta":"Доставка суші · Ковель і Турійськ","url_label":"sushijulia.com.ua","link":"https://sushijulia.com.ua/","result":"Один сайт для обох міст.","image_mobile":"https://arawebsite.com/cases/sushiu-m.jpg","dev":false}', 4),
  ('cases', 'Sushi Shark', 'Сайт польською: меню на 70 позицій, кошик і доставка. Меню й категорії власник редагує сам в адмінці.', 'https://arawebsite.com/cases/sushishark.jpg', '{"meta":"Доставка суші · Єленя-Ґура, Польща","url_label":"sushishark.pl","link":"https://sushishark.pl/","result":"Власник сам оновлює меню.","image_mobile":"https://arawebsite.com/cases/sushishark-m.jpg","dev":false}', 5),
  ('cases', 'Кафе «Філін»', 'Сайт закладу з домашньою кухнею: меню, номери, сауна й карта проїзду.', 'https://arawebsite.com/cases/filin.jpg', '{"meta":"Кафе, мотель і сауна · Кобеляки","url_label":"arikpromax.github.io/filin","link":"https://arikpromax.github.io/filin/","result":"Атмосфера закладу з першого екрана.","image_mobile":"https://arawebsite.com/cases/filin-m.jpg","dev":false}', 6)
) as v(collection, title, text, image_url, extra, n)
where not exists (select 1 from public.items i, s where i.site_id = s.id and i.collection = 'cases');

-- ---------- картки: usps ----------
with s as (select id from public.sites where slug = 'arawebsite')
insert into public.items (site_id, collection, title, text, image_url, extra, sort_order)
select s.id, v.collection, v.title, v.text, v.image_url, v.extra::jsonb, v.n
from s, (values
  ('usps', 'Сайт під будь-який бізнес', 'Від простого лендингу до повноцінного сайту-каталогу. Підбираю формат під вашу задачу й бюджет, а не навпаки.', '', '{"visual":"layers"}', 1),
  ('usps', 'Розумію складні ніші', 'Знаю, що для стоматології важливі лікарі, обладнання й сертифікати, а для будівництва — об''єкти, матеріали та етапи. Тому впораюся з будь-яким завданням.', '', '{"visual":"niches"}', 2),
  ('usps', 'Гарантія та особистий супровід', 'Працюєте напряму зі мною, без менеджерів-посередників. Правки за домовленістю та підтримка після запуску.', '', '{"visual":"chat-support"}', 3)
) as v(collection, title, text, image_url, extra, n)
where not exists (select 1 from public.items i, s where i.site_id = s.id and i.collection = 'usps');

-- ---------- картки: factors ----------
with s as (select id from public.sites where slug = 'arawebsite')
insert into public.items (site_id, collection, title, text, image_url, extra, sort_order)
select s.id, v.collection, v.title, v.text, v.image_url, v.extra::jsonb, v.n
from s, (values
  ('factors', 'Обсяг сторінок', 'Лендинг чи багатосторінковий каталог. Що більше сторінок і розділів, то більше роботи над структурою й версткою.', '', '{"visual":"layers"}', 1),
  ('factors', 'Контент', 'Чи є готові тексти й фото, чи готую їх я. Якщо матеріалів немає — напишу тексти й підберу зображення.', '', '{"visual":"content"}', 2),
  ('factors', 'Інтеграції', 'Підключаю будь-що: оплату, доставку, CRM, ботів і месенджери, соцмережі, аналітику, онлайн-запис. Скільки інтеграцій — стільки й роботи.', '', '{"visual":"integrations"}', 3),
  ('factors', 'Дизайн', 'Шаблонний підхід чи унікальний макет. Унікальний дизайн довше, зате сайт ні з ким не сплутати.', '', '{"visual":"design"}', 4)
) as v(collection, title, text, image_url, extra, n)
where not exists (select 1 from public.items i, s where i.site_id = s.id and i.collection = 'factors');

-- ---------- картки: team ----------
with s as (select id from public.sites where slug = 'arawebsite')
insert into public.items (site_id, collection, title, text, image_url, extra, sort_order)
select s.id, v.collection, v.title, v.text, v.image_url, v.extra::jsonb, v.n
from s, (values
  ('team', 'Ярослав', 'Роблю сайти від ідеї до запуску: продумую структуру, малюю дизайн, пишу код і підключаю все потрібне — оплату, доставку, ботів, аналітику. Після запуску лишаюся на звʼязку.', 'https://arawebsite.com/yaroslav.jpg', '{"role":"Засновник"}', 1)
) as v(collection, title, text, image_url, extra, n)
where not exists (select 1 from public.items i, s where i.site_id = s.id and i.collection = 'team');

-- ---------- тексти ----------
with s as (select id from public.sites where slug = 'arawebsite')
insert into public.texts (site_id, key, value)
select s.id, v.key, v.value
from s, (values
  ('tg_user', 'arikpromax'),
  ('phone', '+380 95 764 34 16'),
  ('email', 'arikpro92@gmail.com'),
  ('nav_services', 'Послуги'),
  ('nav_cases', 'Кейси'),
  ('nav_about', 'Про нас'),
  ('nav_price', 'Ціна'),
  ('header_cta', 'Розрахувати сайт'),
  ('subnav_year', '2026'),
  ('subnav_name', 'arawebsite · сайти для бізнесу'),
  ('tab_top', 'Огляд'),
  ('tab_solution', 'Рішення'),
  ('tab_process', 'Як працюю'),
  ('tab_cases', 'Кейси'),
  ('tab_price', 'Ціна'),
  ('hero_kicker', 'Веб-студія «arawebsite»'),
  ('hero_title', 'Сайт, який приносить заявки'),
  ('hero_btn', 'Дивитись кейси'),
  ('pain_h', 'Знайомо?'),
  ('pain_panel_h', 'Сайт є, а клієнтів він не приводить'),
  ('pain_panel_p', 'Якщо хоча б один із цих пунктів про вас — справа не у везінні, а в самому сайті.'),
  ('sol_h', 'Що я роблю'),
  ('sol_panel_h', 'Сайт, який працює на довіру і на заявки'),
  ('sol_panel_p', 'Кожен елемент сайту має одну мету — перетворити відвідувача на клієнта.'),
  ('sol_admin_h', 'Сайт + адмін-панель'),
  ('sol_admin_p', 'До кожного сайту — власна адмін-панель, яку засновник розробив з нуля. Тексти, ціни, фото й картки міняєте самі, без програміста: вкладки повторюють блоки вашого сайту, а під кожним полем є підказка.'),
  ('demo_kicker', 'Спершу подивіться — потім вирішуйте'),
  ('demo_h', 'Демосайт — безкоштовно'),
  ('demo_sub', 'Показую, як виглядатиме ваш сайт, до будь-якої оплати й без зобов''язань'),
  ('proc_h', 'Як я працюю'),
  ('proc_lead_h', 'Від ідеї до запуску — зрозуміло й по кроках'),
  ('proc_lead_p', 'Ви завжди знаєте, на якому етапі ми зараз і що буде далі.'),
  ('cases_h', 'Кейси'),
  ('cases_card_h', 'Кілька прикладів роботи'),
  ('cases_card_p', 'Різні ніші, одна логіка: зрозуміла структура, довіра й проста дорога до заявки.'),
  ('why_h', 'Чому я'),
  ('why_sub', 'Не просто «зробити сайт», а вирішити завдання бізнесу'),
  ('price_h', 'Вартість'),
  ('price_from', 'від'),
  ('price_value', '$500'),
  ('price_sub', 'Сайт під ваш бізнес. Точну вартість рахую під вашу задачу й озвучую до старту — жодних прихованих платежів і сюрпризів у процесі.'),
  ('price_kicker', 'Що впливає на ціну'),
  ('price_note', 'Фінальна ціна — після прорахунку'),
  ('price_btn', 'Дізнатись точну вартість'),
  ('price_integrations', 'Форма заявки
Онлайн-запис
Онлайн-оплата
Apple Pay
Google Pay
Кошик і замовлення
Нова Пошта
Укрпошта
Telegram-бот
Viber
WhatsApp
Онлайн-чат
Instagram
Facebook
TikTok
YouTube
Google Maps
Відгуки Google
Google Analytics
Meta Pixel
Google Таблиці
CRM
Google Календар
SMS-сповіщення
Email-розсилка
Калькулятор ціни
Промокоди
Кілька мов
Адмінка'),
  ('price_integr_more', 'І будь-що інше'),
  ('contact_kicker', 'Залишилось питання?'),
  ('contact_h', 'Розкажіть про бізнес — порахую вартість сайту'),
  ('contact_lead', 'Залиште заявку, і я зв''яжуся з вами, щоб уточнити деталі та назвати точну ціну. Без зобов''язань.'),
  ('contact_points', 'Відповідаю протягом дня
Порахую вартість саме під вашу нішу
Підкажу, що варто, а що — зайве'),
  ('form_h', 'Отримати розрахунок'),
  ('form_sub', 'Заповніть форму — і я напишу вам першим.'),
  ('form_business', 'Стоматологія / медицина
Будівництво / ремонт
Краса / послуги
Торгівля / магазин
Інше'),
  ('form_nocall', 'Не дзвонити — краще написати'),
  ('form_btn', 'Надіслати заявку'),
  ('form_ok', 'Дякую! Заявку отримано — я зв''яжуся з вами найближчим часом.'),
  ('form_note', 'Дані використовую лише для зв''язку з вами'),
  ('about_h', 'Про нас'),
  ('footer_copy', '© 2026 Веб-студія «arawebsite». Сайти, які приносять заявки.'),
  ('seo_title', 'arawebsite — сайти, які приносять заявки вашому бізнесу'),
  ('seo_desc', 'Розробляю сайти під будь-який бізнес — від лендингу до каталогу. Роблю так, щоб відвідувач залишив заявку, подзвонив або записався. Сайт під ваш бізнес — від $500.')
) as v(key, value)
on conflict (site_id, key) do nothing;

-- ---------- номер сайту (вписати в portfolio/lib/content.ts → SITE) ----------
select id as "SITE для content.ts", slug, name from public.sites where slug = 'arawebsite';
