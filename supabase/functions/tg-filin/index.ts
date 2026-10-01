// Telegram-бот бронювання номерів.
//
// Окрема функція для сайтів-готелів. Бот замовлень (tg-bot) її не стосується:
// там свої сайти, свій токен і свій вебхук, і цей файл його не чіпає.
//
// Що вміє:
//   ?setup=<site>          — привʼязати бота до цієї функції (вебхук, опис, команди)
//   ?check=<site>          — перевірити, що підключено: токен і скільки чатів
//   POST {booking: <id>}   — нова бронь: надіслати в усі підключені чати
//   POST від Telegram      — /start <код>, /stop і кнопки під бронню
//
// Токен бота береться з Supabase → Edge Functions → Secrets за номером сайту:
// TG_TOKEN_<сайт>. Базу функція читає службовим ключем, який Supabase підкладає сам.

const BASE = Deno.env.get("SUPABASE_URL") ?? "";
const KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  (() => {
    try {
      return JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}").default ?? "";
    } catch {
      return "";
    }
  })();
const ADMIN = "https://platform-one-bay.vercel.app";
const HOOK = BASE + "/functions/v1/tg-filin";

/* ---------- ключі ---------- */

// Спершу дивимось у закриту таблицю site_keys (її заповнює адмінка),
// потім у Secrets. Півхвилини тримаємо знайдене в памʼяті.
const keyBox = new Map<string, { at: number; v: string }>();
async function keyOf(site: number, name: string): Promise<string> {
  const id = site + ":" + name;
  const hit = keyBox.get(id);
  if (hit && Date.now() - hit.at < 30000) return hit.v;
  let v = "";
  try {
    const [row] = await db(`site_keys?site_id=eq.${site}&name=eq.${name}&select=value`);
    v = String(row?.value ?? "");
  } catch { /* таблиці ще немає — працюємо на Secrets */ }
  if (!v) v = Deno.env.get(name + "_" + site) ?? "";
  keyBox.set(id, { at: Date.now(), v });
  return v;
}
const tokenOf = (site: number) => keyOf(site, "TG_TOKEN");

/* ---------- база ---------- */

// Старий службовий ключ — це JWT, новий (sb_secret_…) у заголовок Authorization не кладуть.
const dbHead = (extra: Record<string, string> = {}) => ({
  apikey: KEY,
  ...(KEY.startsWith("eyJ") ? { Authorization: "Bearer " + KEY } : {}),
  "Content-Type": "application/json",
  ...extra,
});

// deno-lint-ignore no-explicit-any
async function db(path: string, init: RequestInit = {}): Promise<any> {
  for (let attempt = 0; ; attempt++) {
    const r = await fetch(BASE + "/rest/v1/" + path, {
      ...init,
      headers: dbHead((init.headers as Record<string, string>) ?? {}),
    });
    const text = await r.text();
    // Щойно запущена функція буває на долю секунди «попереду» годинника бази,
    // і база відповідає «JWT issued in the future» (PGRST303). Це минає саме.
    if (r.status === 401 && text.includes("PGRST303") && attempt < 3) {
      await new Promise((ok) => setTimeout(ok, 1000 * (attempt + 1)));
      continue;
    }
    if (!r.ok) throw new Error("db " + r.status + ": " + text.slice(0, 300));
    return text ? JSON.parse(text) : null;
  }
}

/* ---------- Telegram ---------- */

// deno-lint-ignore no-explicit-any
async function tg(token: string, method: string, body: unknown): Promise<any> {
  const r = await fetch("https://api.telegram.org/bot" + token + "/" + method, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  return await r.json().catch(() => ({ ok: false, error_code: r.status }));
}

// Підпис, яким Telegram позначає свої запити: інакше будь-хто міг би
// прикинутись ним і підключити свій чат.
async function hookSecret(token: string) {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode("tg-hook:" + token));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("").slice(0, 48);
}

const esc = (s: unknown) =>
  String(s ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

const placeName = async (site: number) => {
  const [row] = await db(`sites?id=eq.${site}&select=name`);
  return String(row?.name ?? "");
};

const isLinked = async (site: number, chat: number) =>
  (await db(`tg_chats?site_id=eq.${site}&chat_id=eq.${chat}&select=chat_id`)).length > 0;

/* ---------- бронь ---------- */

type Booking = {
  id: number;
  site_id: number;
  ref: string;
  room_key: string;
  room_name: string;
  rooms_count: number;
  date_in: string;
  date_out: string;
  adults: number;
  children: number;
  guest: { name?: string; phone?: string; via?: string; note?: string };
  extras: { sauna?: { day?: string; time?: string; hours?: number } };
  total: number;
  status: string;
  source: string;
  created_at: string;
};

const WD = ["нд", "пн", "вт", "ср", "чт", "пт", "сб"];

/** 2026-10-04 → «04.10.2026, нд» */
const dayUA = (iso: string) => {
  const p = String(iso ?? "").split("-");
  if (p.length !== 3) return String(iso ?? "");
  const d = new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2]));
  return p[2] + "." + p[1] + "." + p[0] + ", " + WD[d.getDay()];
};

const nightsUA = (n: number) => {
  const a = n % 10, b = n % 100;
  const w = b >= 11 && b <= 14 ? "ночей" : a === 1 ? "ніч" : a >= 2 && a <= 4 ? "ночі" : "ночей";
  return n + " " + w;
};

const guestsUA = (b: Booking) => {
  const a = Number(b.adults) || 0, k = Number(b.children) || 0;
  const aw = a % 10 === 1 && a % 100 !== 11 ? "дорослий" : "дорослих";
  const kw = k % 10 === 1 && k % 100 !== 11
    ? "дитина"
    : k % 10 >= 2 && k % 10 <= 4 && (k % 100 < 12 || k % 100 > 14)
      ? "дитини"
      : "дітей";
  return a + " " + aw + (k ? ", " + k + " " + kw : "");
};

const bookingNights = (b: Booking) => {
  const a = Date.parse(b.date_in), z = Date.parse(b.date_out);
  return a && z ? Math.max(1, Math.round((z - a) / 86400000)) : 1;
};

function bookingText(b: Booking, place: string) {
  const g = b.guest ?? {};
  const s = b.extras?.sauna;
  const mark = b.status === "cancelled"
    ? "  ❌ СКАСОВАНО"
    : b.status === "confirmed"
      ? "  ✅ ПІДТВЕРДЖЕНО"
      : "";
  const L: string[] = [];
  L.push("<b>БРОНЬ № " + esc(b.ref) + "</b>" + mark);
  if (place) L.push(esc(place));
  L.push("");
  L.push("Номер: <b>" + esc(b.room_name) + "</b>" + (b.rooms_count > 1 ? " ×" + b.rooms_count : ""));
  L.push("Заїзд: " + dayUA(b.date_in));
  L.push("Виїзд: " + dayUA(b.date_out) + " · " + nightsUA(bookingNights(b)));
  L.push("Гості: " + guestsUA(b));
  if (s && s.day) {
    L.push("");
    L.push("Сауна: " + dayUA(String(s.day)) + ", " + esc(String(s.time ?? "")) + ", " + (s.hours ?? 2) + " год");
  }
  L.push("");
  L.push("Гість: " + esc(String(g.name ?? "—")) + (g.phone ? ", " + esc(String(g.phone)) : ""));
  if (g.via) L.push("Звʼязок: " + esc(String(g.via)));
  if (g.note) L.push("Побажання: " + esc(String(g.note)));
  if (Number(b.total) > 0) {
    L.push("");
    L.push("Попередньо: <b>" + Math.round(Number(b.total)) + " грн</b>");
  }
  if (b.source === "phone") {
    L.push("");
    L.push("<i>Заведено вручну в адмінці</i>");
  }
  return L.join("\n");
}

function bookingKeys(b: Booking) {
  const rows: { text: string; callback_data?: string; url?: string }[][] = [];
  if (b.status === "new") rows.push([{ text: "Підтвердити", callback_data: "bok:" + b.id }]);
  if (b.status !== "cancelled") rows.push([{ text: "Скасувати бронь", callback_data: "bno:" + b.id }]);
  rows.push([{ text: "Відкрити в адмінці", url: ADMIN }]);
  return { inline_keyboard: rows };
}

/** Нова бронь → у всі підключені чати. Повторний виклик нічого не дублює. */
async function notifyBooking(id: number) {
  // Спершу «забираємо» бронь: якщо її вже хтось надіслав, рядок не повернеться.
  const got = await db(`bookings?id=eq.${id}&tg_sent_at=is.null&select=*`, {
    method: "PATCH",
    headers: { Prefer: "return=representation" },
    body: JSON.stringify({ tg_sent_at: new Date().toISOString() }),
  });
  const b: Booking | undefined = got?.[0];
  if (!b) return { ok: true, skipped: "already sent or no such booking" };

  const release = () =>
    db(`bookings?id=eq.${id}`, { method: "PATCH", body: JSON.stringify({ tg_sent_at: null }) })
      .catch(() => {});

  const token = await tokenOf(b.site_id);
  if (!token) {
    await release();
    return { ok: false, error: "no TG_TOKEN_" + b.site_id };
  }
  const chats: number[] = (await db(`tg_chats?site_id=eq.${b.site_id}&select=chat_id`)).map(
    (c: { chat_id: number }) => c.chat_id,
  );
  if (!chats.length) {
    await release();
    return { ok: false, error: "no chats" };
  }

  const text = bookingText(b, await placeName(b.site_id));
  const sent: number[] = [];
  for (const chat of chats) {
    const r = await tg(token, "sendMessage", {
      chat_id: chat,
      parse_mode: "HTML",
      text,
      reply_markup: bookingKeys(b),
      link_preview_options: { is_disabled: true },
    });
    if (r.ok) sent.push(chat);
    // Бота заблокували або вигнали з групи — більше туди не стукаємо.
    else if (r.error_code === 403) {
      await db(`tg_chats?site_id=eq.${b.site_id}&chat_id=eq.${chat}`, { method: "DELETE" });
    }
  }
  if (!sent.length) {
    await release(); // жоден чат не отримав — хай підстраховка спробує ще раз
    return { ok: false, error: "nobody got it" };
  }
  return { ok: true, sent: sent.length };
}

/* ---------- кнопки й команди ---------- */

type Chat = { id: number; type: string; title?: string };
type Update = {
  message?: {
    chat: Chat;
    from?: { first_name?: string; last_name?: string; username?: string };
    text?: string;
  };
  callback_query?: {
    id: string;
    data?: string;
    message?: { chat: Chat; message_id: number };
  };
};

async function onButton(site: number, token: string, q: NonNullable<Update["callback_query"]>) {
  const answer = (text = "", alert = false) =>
    tg(token, "answerCallbackQuery", { callback_query_id: q.id, text, show_alert: alert });
  const msg = q.message;
  const m = String(q.data ?? "").match(/^(\w+!?):(\d+)$/);
  if (!msg || !m) return answer();
  const chat = msg.chat.id;
  // Кнопки діють лише в підключених чатах і лише для броней свого сайту
  if (!(await isLinked(site, chat))) return answer("Цей чат не підключений", true);

  const [, act, idStr] = m;
  const id = Number(idStr);
  const [b]: Booking[] = await db(`bookings?id=eq.${id}&site_id=eq.${site}&select=*`);
  if (!b) return answer("Не знайшов цю бронь", true);

  const place = await placeName(site);
  const redraw = (row: Booking) =>
    tg(token, "editMessageText", {
      chat_id: chat,
      message_id: msg.message_id,
      text: bookingText(row, place),
      parse_mode: "HTML",
      link_preview_options: { is_disabled: true },
      reply_markup: bookingKeys(row),
    });

  if (act === "bok") {
    if (b.status !== "new") return answer("Уже не нова бронь");
    const [row] = await db(`bookings?id=eq.${id}`, {
      method: "PATCH",
      headers: { Prefer: "return=representation" },
      body: JSON.stringify({ status: "confirmed", updated_at: new Date().toISOString() }),
    });
    await redraw(row ?? { ...b, status: "confirmed" });
    return answer("Підтверджено");
  }

  // Скасування питаємо двічі: на телефоні легко зачепити кнопку випадково
  if (act === "bno") {
    if (b.status === "cancelled") return answer("Бронь уже скасовано");
    await tg(token, "editMessageReplyMarkup", {
      chat_id: chat,
      message_id: msg.message_id,
      reply_markup: {
        inline_keyboard: [
          [{ text: "Так, скасувати бронь " + b.ref, callback_data: "bno!:" + b.id }],
          [{ text: "Ні, лишити", callback_data: "bkeep:" + b.id }],
        ],
      },
    });
    return answer();
  }

  if (act === "bno!") {
    const [row] = await db(`bookings?id=eq.${id}`, {
      method: "PATCH",
      headers: { Prefer: "return=representation" },
      body: JSON.stringify({ status: "cancelled", updated_at: new Date().toISOString() }),
    });
    // Дата звільняється одразу: календар на сайті питає базу щоразу,
    // коли гість відкриває вікно бронювання.
    await redraw(row ?? { ...b, status: "cancelled" });
    return answer("Скасовано — дати знову вільні");
  }

  if (act === "bkeep") {
    await redraw(b);
    return answer();
  }
  return answer();
}

async function onText(site: number, token: string, m: NonNullable<Update["message"]>) {
  if (!m.text) return;
  const chat = m.chat.id;
  const place = (await placeName(site)) || "закладу";
  const say = (text: string) => tg(token, "sendMessage", { chat_id: chat, text, parse_mode: "HTML" });

  // /start, /start КОД, /start@назва_бота КОД — останнє приходить із груп
  const cmd = m.text.trim().match(/^\/(\w+)(?:@\w+)?(?:\s+(\S+))?/);
  if (!cmd) return;
  const [, name, arg] = cmd;
  const linked = await isLinked(site, chat);

  if (name === "start") {
    if (arg) {
      const now = new Date().toISOString();
      const inv = await db(
        `tg_invites?code=eq.${encodeURIComponent(arg)}&site_id=eq.${site}&until=gt.${now}&select=code`,
      );
      if (inv.length) {
        const f = m.from ?? {};
        const who = m.chat.type === "private"
          ? [f.first_name, f.last_name].filter(Boolean).join(" ") + (f.username ? " @" + f.username : "")
          : "група «" + (m.chat.title ?? "") + "»";
        await db("tg_chats?on_conflict=chat_id,site_id", {
          method: "POST",
          headers: { Prefer: "resolution=merge-duplicates" },
          body: JSON.stringify({ chat_id: chat, site_id: site, who: who.trim() }),
        });
        await say(
          `Готово. Нові броні з сайту <b>${esc(place)}</b> надходитимуть сюди.\n\nВідписатися — /stop`,
        );
        return;
      }
      await say("Код не підійшов — він діє тиждень. Попросіть новий в адміністратора сайту.");
      return;
    }
    await say(
      linked
        ? `Цей чат уже отримує броні <b>${esc(place)}</b>.\n\nВідписатися — /stop`
        : `Сюди приходять броні номерів <b>${esc(place)}</b>.\n\n` +
          `Щоб підключитися, попросіть посилання в адміністратора сайту.`,
    );
    return;
  }

  if (name === "stop") {
    if (!linked) return void (await say("Цей чат і так нічого не отримує."));
    await db(`tg_chats?site_id=eq.${site}&chat_id=eq.${chat}`, { method: "DELETE" });
    await say("Готово, більше не надсилаю. Повернутись — /start із кодом запрошення.");
    return;
  }
}

async function onUpdate(site: number, token: string, u: Update) {
  if (u.callback_query) return onButton(site, token, u.callback_query);
  if (u.message) return onText(site, token, u.message);
}

/* ---------- налаштування ---------- */

async function setup(site: number) {
  const token = await tokenOf(site);
  if (!token) return { ok: false, error: "no TG_TOKEN_" + site };
  const place = await placeName(site);
  const me = await tg(token, "getMe", {});
  const hook = await tg(token, "setWebhook", {
    url: HOOK + "?site=" + site,
    secret_token: await hookSecret(token),
    allowed_updates: ["message", "callback_query"],
  });
  await tg(token, "setMyDescription", {
    description: `Сюди приходять нові броні номерів ${place}. Підключення — за посиланням від адміністратора.`,
  });
  await tg(token, "setMyShortDescription", { short_description: `Броні ${place}` });
  await tg(token, "setMyCommands", {
    commands: [
      { command: "start", description: "Перевірити підключення" },
      { command: "stop", description: "Більше не надсилати броні" },
    ],
  });
  // Токен назовні не віддаємо — лише ім'я бота й чи прийняв Telegram адресу.
  return { ok: !!hook.ok, bot: me.result?.username ?? null, webhook: hook.description ?? hook.ok };
}

// Що вже підключено. Жодних ключів і даних гостей — лише «так/ні» й числа.
async function check(site: number) {
  const token = await tokenOf(site);
  const chats = token ? await db(`tg_chats?site_id=eq.${site}&select=chat_id,who`) : [];
  const waiting = token
    ? await db(`bookings?site_id=eq.${site}&tg_sent_at=is.null&select=id`)
    : [];
  return {
    site,
    place: await placeName(site).catch(() => ""),
    token: !!token,
    chats: chats.length,
    who: chats.map((c: { who: string }) => c.who),
    waiting: waiting.length,
    hook: HOOK + "?site=" + site,
  };
}

/* ---------- вхід ---------- */

const CORS = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Methods": "GET, POST, OPTIONS" };
const json = (x: unknown, status = 200, cors = false) =>
  new Response(JSON.stringify(x), {
    status,
    headers: { "Content-Type": "application/json", ...(cors ? CORS : {}) },
  });

Deno.serve(async (req) => {
  const url = new URL(req.url);
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
  try {
    const setupSite = Number(url.searchParams.get("setup"));
    if (setupSite) return json(await setup(setupSite));

    const checkSite = Number(url.searchParams.get("check"));
    if (checkSite) return json(await check(checkSite));

    // Запит від Telegram: звіряємо підпис, інакше будь-хто міг би підключити свій чат
    const tgSecret = req.headers.get("x-telegram-bot-api-secret-token");
    if (tgSecret) {
      const site = Number(url.searchParams.get("site"));
      const token = await tokenOf(site);
      if (!token || tgSecret !== (await hookSecret(token))) return json({ ok: false }, 401);
      const update = await req.json().catch(() => ({}));
      // Telegram чекає відповіді недовго й повторює запит, тому помилки лише пишемо в журнал
      await onUpdate(site, token, update).catch((e) => console.error("update", e));
      return json({ ok: true });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const id = Number(body?.booking);
      if (id) return json(await notifyBooking(id));
    }
    return json({ ok: false, error: "nothing to do" }, 400);
  } catch (e) {
    console.error(e);
    return json({ ok: false, error: String(e) }, 500);
  }
});
