// Telegram-бот замовлень.
//
// Один файл робить три речі:
//   ?setup=<site>        — прив'язати бота до цієї функції (вебхук, опис)
//   POST {order: <id>}   — надіслати нове замовлення всім під'єднаним чатам
//   POST від Telegram    — /start <код> під'єднує чат, /stop відключає
//
// Токен бота лежить у Secrets як TG_TOKEN_<номер сайту>, тож у кожного сайту
// може бути свій бот. База читається службовим ключем, який Supabase сам
// підкладає функції, — у коді й на сайті його немає.

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
const HOOK = BASE + "/functions/v1/tg-bot";

const tokenOf = (site: number) => Deno.env.get("TG_TOKEN_" + site) ?? "";

/* ---------- база ---------- */

// Старий службовий ключ — це JWT, новий (sb_secret_…) у заголовок Authorization не кладуть.
const dbHead = (extra: Record<string, string> = {}) => ({
  apikey: KEY,
  ...(KEY.startsWith("eyJ") ? { Authorization: "Bearer " + KEY } : {}),
  "Content-Type": "application/json",
  ...extra,
});

async function db(path: string, init: RequestInit = {}) {
  const r = await fetch(BASE + "/rest/v1/" + path, {
    ...init,
    headers: dbHead((init.headers as Record<string, string>) ?? {}),
  });
  const text = await r.text();
  if (!r.ok) throw new Error("db " + r.status + ": " + text.slice(0, 300));
  return text ? JSON.parse(text) : null;
}

/* ---------- Telegram ---------- */

async function tg(token: string, method: string, body: unknown) {
  const r = await fetch("https://api.telegram.org/bot" + token + "/" + method, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  return await r.json().catch(() => ({ ok: false, error_code: r.status }));
}

// Пароль, яким Telegram підписує свої запити до нас. Виводимо його з токена,
// щоб не заводити ще один секрет: хто не знає токена, той не підробить запит.
async function hookSecret(token: string) {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode("tg-hook:" + token));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("").slice(0, 48);
}

/* ---------- текст замовлення ---------- */

const esc = (s: unknown) =>
  String(s ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

const money = (n: unknown) =>
  String(Math.round(Number(n) || 0)).replace(/\B(?=(\d{3})+(?!\d))/g, " ") + " грн";

// +380XXXXXXXXX — такий номер Telegram сам робить натискним
function phone(raw: unknown) {
  const d = String(raw ?? "").replace(/\D/g, "");
  if (d.length === 12 && d.startsWith("380")) return "+" + d;
  if (d.length === 10 && d.startsWith("0")) return "+38" + d;
  return String(raw ?? "");
}

type Line = { title?: string; size?: string; qty?: number; price?: number };
type Order = {
  id: number;
  site_id: number;
  ref: string;
  total: number;
  created_at: string;
  customer: Record<string, string>;
  lines: Line[];
};

function orderText(o: Order, shop: string) {
  const c = o.customer ?? {};
  const when = new Date(o.created_at).toLocaleString("uk-UA", {
    timeZone: "Europe/Kyiv",
    day: "2-digit",
    month: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  });
  const items = (o.lines ?? []).map((l, i) => {
    const qty = Number(l.qty) || 1;
    return (
      `${i + 1}. ${esc(l.title)}` +
      (l.size ? ` · <b>${esc(l.size)}</b>` : "") +
      (qty > 1 ? ` · ${qty} шт` : "") +
      ` — ${money((Number(l.price) || 0) * qty)}`
    );
  });
  const where = [c.city, c.branch].filter(Boolean).map(esc).join(", ");
  return [
    `<b>Нове замовлення ${esc(o.ref || "#" + o.id)}</b>`,
    `${esc(shop)} · ${when}`,
    "",
    ...items,
    "",
    `<b>Разом: ${money(o.total)}</b>`,
    "",
    `Доставка: ${esc(c.delivery)}`,
    where ? where : "",
    `Оплата: ${esc(c.pay)}`,
    "",
    `${esc(c.name)}`,
    phone(c.phone),
    c.comment ? `\nКоментар: ${esc(c.comment)}` : "",
  ]
    .filter((x, i, a) => !(x === "" && a[i - 1] === "")) // без подвійних порожніх рядків
    .join("\n")
    .trim();
}

/* ---------- нове замовлення ---------- */

async function notify(id: number) {
  // Спершу «забираємо» замовлення: якщо його вже хтось надіслав, рядок не повернеться.
  // Так повторний виклик (тригер + підстраховка за розкладом) не дублює повідомлення.
  const got = await db(`orders?id=eq.${id}&tg_sent_at=is.null&select=id,site_id,ref,total,created_at,customer,lines`, {
    method: "PATCH",
    headers: { Prefer: "return=representation" },
    body: JSON.stringify({ tg_sent_at: new Date().toISOString() }),
  });
  const o: Order | undefined = got?.[0];
  if (!o) return { ok: true, skipped: "already sent or no such order" };

  const release = () =>
    db(`orders?id=eq.${id}`, { method: "PATCH", body: JSON.stringify({ tg_sent_at: null }) });

  const token = tokenOf(o.site_id);
  if (!token) {
    await release();
    return { ok: false, error: "no TG_TOKEN_" + o.site_id };
  }
  const [site] = await db(`sites?id=eq.${o.site_id}&select=name`);
  const chats: { chat_id: number }[] = await db(`tg_chats?site_id=eq.${o.site_id}&select=chat_id`);
  if (!chats.length) {
    await release();
    return { ok: false, error: "no chats" };
  }

  const text = orderText(o, site?.name ?? "");
  let sent = 0;
  for (const ch of chats) {
    const r = await tg(token, "sendMessage", {
      chat_id: ch.chat_id,
      text,
      parse_mode: "HTML",
      link_preview_options: { is_disabled: true },
      reply_markup: { inline_keyboard: [[{ text: "Відкрити в адмінці", url: ADMIN }]] },
    });
    if (r.ok) sent++;
    // Бота заблокували або вигнали з групи — більше туди не стукаємо.
    else if (r.error_code === 403) {
      await db(`tg_chats?site_id=eq.${o.site_id}&chat_id=eq.${ch.chat_id}`, { method: "DELETE" });
    }
  }
  if (!sent) await release(); // жоден чат не отримав — хай підстраховка спробує ще раз
  return { ok: sent > 0, sent };
}

/* ---------- повідомлення від людей ---------- */

type Update = {
  message?: {
    chat: { id: number; type: string; title?: string };
    from?: { first_name?: string; last_name?: string; username?: string };
    text?: string;
  };
};

async function onUpdate(site: number, token: string, u: Update) {
  const m = u.message;
  if (!m?.text) return;
  const chat = m.chat.id;
  const [shopRow] = await db(`sites?id=eq.${site}&select=name`);
  const shop = shopRow?.name ?? "магазину";
  const say = (text: string) => tg(token, "sendMessage", { chat_id: chat, text, parse_mode: "HTML" });

  // /start, /start КОД, /start@назва_бота КОД — останнє приходить із груп
  const cmd = m.text.trim().match(/^\/(\w+)(?:@\w+)?(?:\s+(\S+))?/);
  if (!cmd) return;
  const [, name, arg] = cmd;

  const linked = (await db(`tg_chats?site_id=eq.${site}&chat_id=eq.${chat}&select=chat_id`)).length > 0;

  if (name === "start") {
    if (arg) {
      const now = new Date().toISOString();
      const inv = await db(
        `tg_invites?code=eq.${encodeURIComponent(arg)}&site_id=eq.${site}&until=gt.${now}&select=code`,
      );
      if (inv.length) {
        const f = m.from ?? {};
        const who =
          m.chat.type === "private"
            ? [f.first_name, f.last_name].filter(Boolean).join(" ") + (f.username ? " @" + f.username : "")
            : "група «" + (m.chat.title ?? "") + "»";
        await db("tg_chats?on_conflict=chat_id,site_id", {
          method: "POST",
          headers: { Prefer: "resolution=merge-duplicates" },
          body: JSON.stringify({ chat_id: chat, site_id: site, who: who.trim() }),
        });
        await say(
          `Готово. Нові замовлення з сайту <b>${esc(shop)}</b> надходитимуть сюди.\n\nВідписатися — /stop`,
        );
        return;
      }
    }
    if (linked) {
      await say(`Цей чат уже отримує замовлення <b>${esc(shop)}</b>.\n\nВідписатися — /stop`);
      return;
    }
    await say(
      `Сюди приходять замовлення магазину <b>${esc(shop)}</b> для його власників.\n\n` +
        `Щоб підключитися, попросіть посилання в адміністратора сайту.`,
    );
    return;
  }

  if (name === "stop") {
    if (linked) {
      await db(`tg_chats?site_id=eq.${site}&chat_id=eq.${chat}`, { method: "DELETE" });
      await say("Більше не надсилатиму сюди замовлення. Повернутися можна за посиланням від адміністратора.");
    } else {
      await say("Цей чат і так не отримує замовлень.");
    }
  }
}

/* ---------- налаштування бота ---------- */

async function setup(site: number) {
  const token = tokenOf(site);
  if (!token) return { ok: false, error: "no TG_TOKEN_" + site };
  const [shopRow] = await db(`sites?id=eq.${site}&select=name`);
  const shop = shopRow?.name ?? "";
  const me = await tg(token, "getMe", {});
  const hook = await tg(token, "setWebhook", {
    url: HOOK + "?site=" + site,
    secret_token: await hookSecret(token),
    allowed_updates: ["message"],
  });
  await tg(token, "setMyDescription", {
    description: `Сюди приходять нові замовлення з сайту ${shop}. Підключення — за посиланням від адміністратора.`,
  });
  await tg(token, "setMyShortDescription", { short_description: `Замовлення з сайту ${shop}` });
  await tg(token, "setMyCommands", {
    commands: [
      { command: "start", description: "Перевірити підключення" },
      { command: "stop", description: "Більше не надсилати замовлення" },
    ],
  });
  // Токен назовні не віддаємо — лише ім'я бота й чи прийняв Telegram адресу.
  return { ok: !!hook.ok, bot: me.result?.username ?? null, webhook: hook.description ?? hook.ok };
}

/* ---------- вхід ---------- */

const json = (x: unknown, status = 200) =>
  new Response(JSON.stringify(x), { status, headers: { "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  const url = new URL(req.url);
  try {
    const setupSite = Number(url.searchParams.get("setup"));
    if (setupSite) return json(await setup(setupSite));

    // Запит від Telegram: звіряємо підпис, інакше будь-хто міг би під'єднати свій чат
    const tgSecret = req.headers.get("x-telegram-bot-api-secret-token");
    if (tgSecret) {
      const site = Number(url.searchParams.get("site"));
      const token = tokenOf(site);
      if (!token || tgSecret !== (await hookSecret(token))) return json({ ok: false }, 401);
      const update = await req.json().catch(() => ({}));
      // Telegram чекає відповіді недовго й повторює запит, тому помилки лише пишемо в журнал
      await onUpdate(site, token, update).catch((e) => console.error("update", e));
      return json({ ok: true });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const id = Number(body?.order);
      if (id) return json(await notify(id));
    }
    return json({ ok: false, error: "nothing to do" }, 400);
  } catch (e) {
    console.error(e);
    return json({ ok: false, error: String(e) }, 500);
  }
});
