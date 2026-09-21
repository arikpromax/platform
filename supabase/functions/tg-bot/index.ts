// Telegram-бот замовлень і накладні Нової Пошти.
//
// Один файл робить чотири речі:
//   ?setup=<site>        — прив'язати бота до цієї функції (вебхук, опис, команди)
//   ?check=<site>        — перевірити, що підключено: токен, ключ НП, відправник
//   POST {order: <id>}   — нове замовлення: створити ТТН і надіслати все в чати
//   POST від Telegram    — /start <код>, /stop і кнопки під замовленням
//
// Секрети лежать у Supabase → Edge Functions → Secrets:
//   TG_TOKEN_<сайт> — токен бота, NP_KEY_<сайт> — ключ Нової Пошти.
// Без ключа НП бот працює як і раніше, лише пише, що ТТН ще не підключені.
// Базу функція читає службовим ключем, який Supabase підкладає сам.

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
const npKeyOf = (site: number) => Deno.env.get("NP_KEY_" + site) ?? "";
const liqOf = (site: number) => ({
  pub: Deno.env.get("LIQPAY_PUBLIC_" + site) ?? "",
  priv: Deno.env.get("LIQPAY_PRIVATE_" + site) ?? "",
});

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
  const r = await fetch(BASE + "/rest/v1/" + path, {
    ...init,
    headers: dbHead((init.headers as Record<string, string>) ?? {}),
  });
  const text = await r.text();
  if (!r.ok) throw new Error("db " + r.status + ": " + text.slice(0, 300));
  return text ? JSON.parse(text) : null;
}

const patchOrder = (id: number, fields: Record<string, unknown>) =>
  db(`orders?id=eq.${id}`, { method: "PATCH", body: JSON.stringify(fields) });

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

async function tgFile(token: string, chat: number, bytes: Uint8Array, name: string, caption: string) {
  const f = new FormData();
  f.append("chat_id", String(chat));
  f.append("document", new Blob([bytes as unknown as BlobPart], { type: "application/pdf" }), name);
  f.append("caption", caption);
  const r = await fetch("https://api.telegram.org/bot" + token + "/sendDocument", { method: "POST", body: f });
  return await r.json().catch(() => ({ ok: false }));
}

// Пароль, яким Telegram підписує свої запити до нас. Виводимо його з токена,
// щоб не заводити ще один секрет: хто не знає токена, той не підробить запит.
async function hookSecret(token: string) {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode("tg-hook:" + token));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("").slice(0, 48);
}

/* ---------- Нова Пошта ---------- */

// deno-lint-ignore no-explicit-any
async function np(key: string, model: string, method: string, props: Record<string, unknown>): Promise<any[]> {
  const r = await fetch("https://api.novaposhta.ua/v2.0/json/", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ apiKey: key, modelName: model, calledMethod: method, methodProperties: props }),
  });
  const j = await r.json().catch(() => null);
  if (!j) throw new Error("Нова Пошта не відповіла");
  if (!j.success) {
    const why = [...(j.errors ?? []), ...(j.warnings ?? [])].map(String).filter(Boolean)[0];
    throw new Error(why || "Нова Пошта відмовила без пояснення");
  }
  return j.data ?? [];
}

type NpSet = {
  site_id: number;
  auto: boolean;
  sender_city: string;
  sender_branch: string;
  sender_city_ref: string;
  sender_wh_ref: string;
  sender_ref: string;
  sender_contact_ref: string;
  sender_phone: string;
  cod_mode: string;
  description: string;
};

async function npSettings(site: number): Promise<NpSet | null> {
  try {
    const [s] = await db(`np_settings?site_id=eq.${site}&select=*`);
    return s ?? null;
  } catch {
    return null; // таблиці ще немає — значить, накладні не налаштовані
  }
}

// Відправник: хто (з кабінету, за ключем) і звідки (місто й номер відділення з налаштувань).
// Знайдені коди записуємо назад у налаштування, щоб не питати НП щоразу.
async function sender(key: string, s: NpSet) {
  const upd: Partial<NpSet> = {};
  if (!s.sender_ref || !s.sender_contact_ref) {
    const who = await np(key, "Counterparty", "getCounterparties", { CounterpartyProperty: "Sender", Page: "1" });
    if (!who[0]) throw new Error("у кабінеті НП немає відправника");
    const cts = await np(key, "Counterparty", "getCounterpartyContactPersons", { Ref: who[0].Ref, Page: "1" });
    if (!cts[0]) throw new Error("у кабінеті НП немає контактної особи відправника");
    upd.sender_ref = who[0].Ref;
    upd.sender_contact_ref = cts[0].Ref;
    upd.sender_phone = String(cts[0].Phones ?? "").replace(/\D/g, "");
  }
  if (!s.sender_wh_ref) {
    const no = String(s.sender_branch ?? "").replace(/\D/g, "");
    if (!s.sender_city || !no) throw new Error("не вказано, з якого відділення відправляєте");
    const cities = await np(key, "Address", "getCities", { FindByString: s.sender_city.trim(), Limit: "20" });
    const want = s.sender_city.trim().toLowerCase();
    const city = cities.find((c) => String(c.Description).toLowerCase() === want) ?? cities[0];
    if (!city) throw new Error(`не знайшов місто відправлення «${s.sender_city}»`);
    const whs = await np(key, "AddressGeneral", "getWarehouses", { CityRef: city.Ref, WarehouseId: no, Limit: "50" });
    const wh = whs.find((w) => String(w.Number) === no) ?? whs[0];
    if (!wh) throw new Error(`не знайшов відділення №${no} у місті ${city.Description}`);
    upd.sender_city_ref = city.Ref;
    upd.sender_wh_ref = wh.Ref;
  }
  if (Object.keys(upd).length) {
    await db(`np_settings?site_id=eq.${s.site_id}`, { method: "PATCH", body: JSON.stringify(upd) });
    Object.assign(s, upd);
  }
  return s;
}

// Вага й коробка. Точна вага не потрібна: у відділенні посилку все одно зважать
// і виправлять накладну. Беремо поле товару «Вага, кг», а коли воно порожнє —
// середнє для категорії разом з упаковкою.
const CAT_KG: Record<string, number> = {
  vzuttia: 1.5,
  kurtky: 1,
  kostiumy: 1,
  kofty: 0.7,
  shtany: 0.7,
  zhyletky: 0.7,
  futbolky: 0.3,
  shorty: 0.3,
  shkarpetky: 0.2,
  aksesuary: 0.2,
};

async function parcel(o: Order) {
  const ids = [...new Set((o.lines ?? []).map((l) => Number(l.item_id)).filter(Boolean))];
  const items: { id: number; extra: Record<string, unknown> }[] = ids.length
    ? await db(`items?id=in.(${ids.join(",")})&select=id,extra`)
    : [];
  const by = new Map(items.map((i) => [i.id, i.extra ?? {}]));
  let kg = 0, shoes = 0, soft = 0;
  for (const l of o.lines ?? []) {
    const q = Number(l.qty) || 1;
    const x = by.get(Number(l.item_id)) ?? {};
    const own = parseFloat(String(x.weight ?? "").replace(",", "."));
    const cat = String(x.cat ?? "");
    kg += (own > 0 ? own : CAT_KG[cat] ?? 0.5) * q;
    if (cat === "vzuttia") shoes += q;
    else soft += q;
  }
  // Взуття — коробка 36×26, по 14 см на пару; одяг — пакет 30×25, товщає з кожною річчю.
  const L = shoes ? 36 : 30, W = shoes ? 26 : 25;
  const H = Math.min(Math.max(shoes * 14 + soft * 4, 5), 60);
  return { kg: Math.max(0.1, Math.round(kg * 10) / 10), L, W, H };
}

// Стан накладної для повідомлення й кнопок
type Ttn =
  | { state: "made" | "exists" }
  | { state: "none" }                 // самовивіз — накладна не потрібна
  | { state: "manual"; why: string }  // кур'єр: адреса вписана текстом
  | { state: "nokey" }                // Нову Пошту ще не підключили
  | { state: "off" }                  // автоматичне створення вимкнене
  | { state: "error"; why: string }
  | { state: "demo"; no: string };   // тестове замовлення: номер для вигляду, у НП його немає

async function ensureTtn(o: Order, force: boolean): Promise<Ttn> {
  if (o.ttn) return { state: "exists" };
  const c = o.customer ?? {};
  const dlv = c.dlv ?? "";
  if (dlv === "pickup" || (!dlv && /самовивіз/i.test(c.delivery ?? ""))) return { state: "none" };
  if (dlv === "np_courier") return { state: "manual", why: "курʼєр: адреса вписана текстом" };

  const key = npKeyOf(o.site_id);
  if (!key) return { state: "nokey" };
  const s = await npSettings(o.site_id);
  if (!s) return { state: "nokey" };
  if (!force && s.auto === false) return { state: "off" };

  try {
    if (!c.cityRef || !c.branchRef) throw new Error("у замовленні немає кодів міста й відділення НП");
    const parts = String(c.name ?? "").trim().split(/\s+/).filter(Boolean);
    if (parts.length < 2) throw new Error("потрібні прізвище та імʼя отримувача");
    const tel = phone(c.phone).replace(/\D/g, "");
    if (tel.length !== 12) throw new Error("неправильний телефон отримувача");

    await sender(key, s);

    const [who] = await np(key, "Counterparty", "save", {
      CounterpartyType: "PrivatePerson",
      CounterpartyProperty: "Recipient",
      LastName: parts[0],
      FirstName: parts[1],
      MiddleName: parts.slice(2).join(" "),
      Phone: tel,
      Email: "",
    });
    const contact = who?.ContactPerson?.data?.[0]?.Ref;
    if (!who?.Ref || !contact) throw new Error("НП не прийняла дані отримувача");

    // Від суми з налаштувань сайту («Безкоштовна доставка від…») доставку платить магазин
    const [free] = await db(`texts?site_id=eq.${o.site_id}&key=eq.free_from&select=value`);
    const freeFrom = Number(String(free?.value ?? "").replace(/\D/g, "")) || 0;
    const total = Math.round(Number(o.total) || 0);
    const box = await parcel(o);
    const today = new Date().toLocaleDateString("uk-UA", {
      timeZone: "Europe/Kyiv",
      day: "2-digit",
      month: "2-digit",
      year: "numeric",
    });

    const props: Record<string, unknown> = {
      PayerType: freeFrom && total >= freeFrom ? "Sender" : "Recipient",
      PaymentMethod: "Cash",
      DateTime: today,
      CargoType: "Parcel",
      ServiceType: "WarehouseWarehouse", // і відділення, і поштомат
      SeatsAmount: "1",
      Weight: String(box.kg),
      Description: s.description || "Одяг та взуття",
      Cost: String(Math.max(total, 1)),
      CitySender: s.sender_city_ref,
      Sender: s.sender_ref,
      SenderAddress: s.sender_wh_ref,
      ContactSender: s.sender_contact_ref,
      SendersPhone: s.sender_phone,
      CityRecipient: c.cityRef,
      Recipient: who.Ref,
      RecipientAddress: c.branchRef,
      ContactRecipient: contact,
      RecipientsPhone: tel,
    };
    // Поштомат не прийме посилку без розмірів; для відділення вистачає об'єму
    if (dlv === "np_postomat") {
      props.OptionsSeat = [{
        volumetricWidth: String(box.W),
        volumetricLength: String(box.L),
        volumetricHeight: String(box.H),
        volumetricVolume: String(Math.round((box.L * box.W * box.H) / 4000 * 100) / 100),
        weight: String(box.kg),
      }];
    } else {
      props.VolumeGeneral = String(Math.round((box.L * box.W * box.H) / 1e6 * 10000) / 10000);
    }
    // Наложений платіж: звичайний грошовий переказ або «контроль оплати» (за договором з НП)
    if (c.payId === "cod") {
      if (s.cod_mode === "control") props.AfterpaymentOnGoodsCost = String(total);
      else props.BackwardDeliveryData = [{ PayerType: "Recipient", CargoType: "Money", RedeliveryString: String(total) }];
    }

    const [doc] = await np(key, "InternetDocument", "save", props);
    if (!doc?.IntDocNumber) throw new Error("НП не повернула номер накладної");
    o.ttn = String(doc.IntDocNumber);
    o.ttn_ref = String(doc.Ref);
    o.ttn_cost = Number(doc.CostOnSite) || null;
    o.ttn_date = String(doc.EstimatedDeliveryDate ?? "");
    o.ttn_error = "";
    await patchOrder(o.id, { ttn: o.ttn, ttn_ref: o.ttn_ref, ttn_cost: o.ttn_cost, ttn_date: o.ttn_date, ttn_error: "" });
    return { state: "made" };
  } catch (e) {
    const why = e instanceof Error ? e.message : String(e);
    o.ttn_error = why;
    await patchOrder(o.id, { ttn_error: why }).catch(() => {});
    return { state: "error", why };
  }
}

// PDF-наклейка 100×100. Посилання містить ключ, тому файл забирає сама функція
// і вже його надсилає в Telegram — ключ назовні не потрапляє.
async function label(key: string, ref: string): Promise<Uint8Array | null> {
  for (const path of [`printMarking100x100/orders[]/${ref}/type/pdf`, `printDocument/orders[]/${ref}/type/pdf`]) {
    try {
      const r = await fetch(`https://my.novaposhta.ua/orders/${path}/apiKey/${key}`);
      const bytes = new Uint8Array(await r.arrayBuffer());
      // справжній PDF починається з «%PDF»
      if (r.ok && bytes.length > 4 && String.fromCharCode(...bytes.slice(0, 4)) === "%PDF") return bytes;
    } catch { /* пробуємо наступний вигляд */ }
  }
  return null;
}

async function sendLabel(token: string, o: Order, chats: number[]) {
  const key = npKeyOf(o.site_id);
  if (!key || !o.ttn_ref) return;
  const pdf = await label(key, o.ttn_ref);
  if (!pdf) return;
  for (const chat of chats) {
    await tgFile(token, chat, pdf, `TTN-${o.ttn}.pdf`, `Наклейка до ${o.ref} · ТТН ${o.ttn}`);
  }
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

type Line = { item_id?: number; title?: string; size?: string; qty?: number; price?: number };
type Order = {
  id: number;
  site_id: number;
  ref: string;
  total: number;
  created_at: string;
  customer: Record<string, string>;
  lines: Line[];
  ttn?: string;
  ttn_ref?: string;
  ttn_cost?: number | null;
  ttn_date?: string;
  ttn_error?: string;
  status?: string;
  pay_state?: string; // '' — оплата не на сайті; wait, paid, failed, refunded — карткою через LiqPay
  pay_info?: { amount?: number; test?: boolean };
};

function payLine(o: Order) {
  const c = o.customer ?? {};
  if (c.payId === "online") {
    if (o.pay_state === "paid") {
      return `Оплата: карткою на сайті — <b>оплачено ${money(o.pay_info?.amount ?? o.total)}</b>` +
        (o.pay_info?.test ? " (тестова оплата)" : "");
    }
    if (o.pay_state === "refunded") return "Оплата: карткою на сайті — <b>гроші повернено</b>";
    return "Оплата: карткою на сайті — <b>ще не оплачено</b>";
  }
  if (c.payId === "cod") return `Оплата: наложений платіж — ${money(o.total)} при отриманні`;
  return `Оплата: ${esc(c.pay)}`;
}

function ttnLine(o: Order, t: Ttn) {
  if (o.ttn) {
    const date = (o.ttn_date ?? "").slice(0, 5); // «23.09.2026» → «23.09»
    return `<b>ТТН ${esc(o.ttn)}</b>` +
      (o.ttn_cost ? ` · доставка ${money(o.ttn_cost)}` : "") +
      (date ? ` · прибуде ${esc(date)}` : "");
  }
  switch (t.state) {
    case "none": return "";
    case "manual": return `ТТН — вручну: ${esc(t.why)}`;
    case "nokey": return "ТТН: Нова Пошта ще не підключена";
    case "off": return "ТТН: створіть кнопкою нижче";
    case "error": return `⚠️ ТТН не створилась: ${esc(t.why)}`;
    case "demo": return `<b>ТТН ${t.no}</b> · тестова, у Новій Пошті її немає`;
    default: return "";
  }
}

function orderText(o: Order, shop: string, t: Ttn, head = "Нове замовлення") {
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
  const ttn = ttnLine(o, t);
  return [
    `<b>${esc(head)} ${esc(o.ref || "#" + o.id)}</b>`,
    `${esc(shop)} · ${when}`,
    "",
    ...items,
    "",
    `<b>Разом: ${money(o.total)}</b>`,
    "",
    `Доставка: ${esc(c.delivery)}`,
    where ? where : "",
    payLine(o),
    ttn ? "\n" + ttn : "",
    "",
    `${esc(c.name)}`,
    phone(c.phone),
    c.comment ? `\nКоментар: ${esc(c.comment)}` : "",
  ]
    .filter((x, i, a) => !(x === "" && a[i - 1] === "")) // без подвійних порожніх рядків
    .join("\n")
    .trim();
}

// Кнопки під замовленням: що можна зробити з накладною просто з Telegram
function keys(o: Order, t: Ttn) {
  const rows: { text: string; callback_data?: string; url?: string }[][] = [];
  if (o.ttn) {
    rows.push([
      { text: "Наклейка PDF", callback_data: `lbl:${o.id}` },
      { text: "Скасувати ТТН", callback_data: `del:${o.id}` },
    ]);
  } else if (t.state === "error" || t.state === "off" || t.state === "nokey") {
    rows.push([{ text: t.state === "error" ? "Спробувати ще раз" : "Створити ТТН", callback_data: `ttn:${o.id}` }]);
  }
  rows.push([{ text: "Відкрити в адмінці", url: ADMIN }]);
  return { inline_keyboard: rows };
}

const shopName = async (site: number) => {
  const [row] = await db(`sites?id=eq.${site}&select=name`);
  return String(row?.name ?? "");
};

/* ---------- нове замовлення ---------- */

async function notify(id: number) {
  // Спершу «забираємо» замовлення: якщо його вже хтось надіслав, рядок не повернеться.
  // Так повторний виклик (тригер + підстраховка за розкладом) не дублює повідомлення.
  const got = await db(`orders?id=eq.${id}&tg_sent_at=is.null&select=*`, {
    method: "PATCH",
    headers: { Prefer: "return=representation" },
    body: JSON.stringify({ tg_sent_at: new Date().toISOString() }),
  });
  const o: Order | undefined = got?.[0];
  if (!o) return { ok: true, skipped: "already sent or no such order" };

  const release = () => patchOrder(id, { tg_sent_at: null });

  // Оплата карткою: замовлення приходить у Telegram лише тоді, коли LiqPay
  // підтвердив гроші. Неоплачене через 10 хвилин база скасує сама.
  if (o.customer?.payId === "online" && o.pay_state !== "paid") {
    await release();
    return { ok: false, error: "not paid yet" };
  }
  // Гроші прийшли вже після автоскасування: товар повернули на склад,
  // тож накладну не робимо — власник спершу перевірить наявність.
  const late = o.status === "cancelled";
  // Тестова оплата LiqPay (sandbox): гроші не рухались, тож і накладну сама не робимо
  const test = !!o.pay_info?.test;

  const token = tokenOf(o.site_id);
  if (!token) {
    await release();
    return { ok: false, error: "no TG_TOKEN_" + o.site_id };
  }
  const chats: number[] = (await db(`tg_chats?site_id=eq.${o.site_id}&select=chat_id`)).map(
    (c: { chat_id: number }) => c.chat_id,
  );
  if (!chats.length) {
    await release();
    return { ok: false, error: "no chats" };
  }

  // Накладну робимо ще до повідомлення — щоб номер ТТН прийшов у тому ж тексті
  // Тестовому замовленню — вигаданий номер, щоб було видно, як виглядатиме справжнє
  const demo = (): Ttn => ({ state: "demo", no: "2045" + String(Math.floor(Math.random() * 1e10)).padStart(10, "0") });
  const t: Ttn = late
    ? { state: "off" }
    : test
    ? demo()
    : await ensureTtn(o, false).catch((e) => ({ state: "error", why: String(e) }) as Ttn);
  const text = late
    ? orderText(o, await shopName(o.site_id), t, "⚠️ Оплата після скасування") +
      "\n\nЗамовлення скасувалося, бо оплата йшла довше 10 хвилин, і товар повернувся на склад. " +
      "Перевірте наявність, поверніть замовлення в «Нове» в адмінці й створіть ТТН кнопкою."
    : test
    ? orderText(o, await shopName(o.site_id), t, "🧪 ТЕСТОВЕ замовлення") +
      "\n\nОплата тестова — гроші не списані, номер ТТН вигаданий. Справжня накладна тут сама не створюється."
    : orderText(o, await shopName(o.site_id), t);
  const got_it: number[] = [];
  for (const chat of chats) {
    const r = await tg(token, "sendMessage", {
      chat_id: chat,
      text,
      parse_mode: "HTML",
      link_preview_options: { is_disabled: true },
      reply_markup: keys(o, t),
    });
    if (r.ok) got_it.push(chat);
    // Бота заблокували або вигнали з групи — більше туди не стукаємо.
    else if (r.error_code === 403) {
      await db(`tg_chats?site_id=eq.${o.site_id}&chat_id=eq.${chat}`, { method: "DELETE" });
    }
  }
  if (!got_it.length) {
    await release(); // жоден чат не отримав — хай підстраховка спробує ще раз
    return { ok: false, ttn: t.state };
  }
  if (o.ttn) await sendLabel(token, o, got_it).catch((e) => console.error("label", e));
  return { ok: true, sent: got_it.length, ttn: t.state };
}

/* ---------- повідомлення й кнопки від людей ---------- */

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
    message?: { message_id: number; chat: Chat };
  };
};

const isLinked = async (site: number, chat: number) =>
  (await db(`tg_chats?site_id=eq.${site}&chat_id=eq.${chat}&select=chat_id`)).length > 0;

async function onButton(site: number, token: string, q: NonNullable<Update["callback_query"]>) {
  const answer = (text = "", alert = false) =>
    tg(token, "answerCallbackQuery", { callback_query_id: q.id, text, show_alert: alert });
  const msg = q.message;
  const m = String(q.data ?? "").match(/^(\w+!?):(\d+)$/);
  if (!msg || !m) return answer();
  const chat = msg.chat.id;
  // Кнопки діють лише в під'єднаних чатах і лише для замовлень свого сайту
  if (!(await isLinked(site, chat))) return answer("Цей чат не підключений до магазину", true);
  const [, act, idStr] = m;
  const [o]: Order[] = await db(`orders?id=eq.${Number(idStr)}&site_id=eq.${site}&select=*`);
  if (!o) return answer("Не знайшов це замовлення", true);

  const shop = await shopName(site);
  const redraw = (t: Ttn, markup = keys(o, t), head?: string) =>
    tg(token, "editMessageText", {
      chat_id: chat,
      message_id: msg.message_id,
      text: orderText(o, shop, t, head),
      parse_mode: "HTML",
      link_preview_options: { is_disabled: true },
      reply_markup: markup,
    });
  const now: Ttn = o.ttn ? { state: "exists" } : o.ttn_error ? { state: "error", why: o.ttn_error } : { state: "off" };

  if (act === "ttn") {
    if (o.ttn) {
      await redraw(now);
      return answer("ТТН уже є");
    }
    // Замок на дві хвилини: подвійне натискання не створить дві накладні
    const lock = await db(
      `orders?id=eq.${o.id}&ttn=eq.&or=(ttn_lock.is.null,ttn_lock.lt.%22${new Date(Date.now() - 120000).toISOString()}%22)&select=id`,
      { method: "PATCH", headers: { Prefer: "return=representation" }, body: JSON.stringify({ ttn_lock: new Date().toISOString() }) },
    );
    if (!lock.length) return answer("Уже створюю, зачекайте кілька секунд");
    await answer("Створюю ТТН…");
    const t = await ensureTtn(o, true);
    await patchOrder(o.id, { ttn_lock: null }).catch(() => {});
    await redraw(t);
    if (t.state === "made") await sendLabel(token, o, [chat]);
    else if (t.state === "nokey") await tg(token, "sendMessage", { chat_id: chat, text: "Нова Пошта ще не підключена — ТТН створиться, щойно з'явиться ключ." });
    return;
  }

  if (act === "lbl") {
    if (!o.ttn) return answer("ТТН ще немає", true);
    await answer("Надсилаю наклейку…");
    await sendLabel(token, o, [chat]);
    return;
  }

  // Скасування питаємо двічі: на телефоні легко зачепити кнопку випадково
  if (act === "del") {
    if (!o.ttn) return answer("ТТН уже немає");
    await tg(token, "editMessageReplyMarkup", {
      chat_id: chat,
      message_id: msg.message_id,
      reply_markup: {
        inline_keyboard: [
          [{ text: `Так, скасувати ТТН ${o.ttn}`, callback_data: `del!:${o.id}` }],
          [{ text: "Ні, лишити", callback_data: `keep:${o.id}` }],
        ],
      },
    });
    return answer();
  }

  if (act === "keep") {
    await tg(token, "editMessageReplyMarkup", { chat_id: chat, message_id: msg.message_id, reply_markup: keys(o, now) });
    return answer();
  }

  if (act === "del!") {
    if (!o.ttn) return answer("ТТН уже немає");
    const key = npKeyOf(site);
    if (!key) return answer("Нова Пошта не підключена", true);
    try {
      await np(key, "InternetDocument", "delete", { DocumentRefs: o.ttn_ref });
    } catch (e) {
      return answer("НП не дала скасувати: " + (e instanceof Error ? e.message : e), true);
    }
    const old = o.ttn;
    o.ttn = ""; o.ttn_ref = ""; o.ttn_cost = null; o.ttn_date = ""; o.ttn_error = "";
    await patchOrder(o.id, { ttn: "", ttn_ref: "", ttn_cost: null, ttn_date: "", ttn_error: "" });
    await redraw({ state: "off" });
    await tg(token, "sendMessage", { chat_id: chat, text: `ТТН ${old} скасовано (замовлення ${o.ref}).` });
    return answer("ТТН скасовано");
  }

  return answer();
}

async function onUpdate(site: number, token: string, u: Update) {
  if (u.callback_query) return onButton(site, token, u.callback_query);
  const m = u.message;
  if (!m?.text) return;
  const chat = m.chat.id;
  const shop = (await shopName(site)) || "магазину";
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

/* ---------- оплата карткою через LiqPay ---------- */

// Ключі LiqPay: LIQPAY_PUBLIC_<сайт> і LIQPAY_PRIVATE_<сайт>. Приватним ключем
// підписуємо платіж і перевіряємо відповідь — він ніколи не покидає функцію.
const b64 = (s: string) => btoa(String.fromCharCode(...new TextEncoder().encode(s)));
const unb64 = (s: string) => new TextDecoder().decode(Uint8Array.from(atob(s), (ch) => ch.charCodeAt(0)));

async function liqSign(priv: string, data: string) {
  const buf = await crypto.subtle.digest("SHA-1", new TextEncoder().encode(priv + data + priv));
  return btoa(String.fromCharCode(...new Uint8Array(buf)));
}

// Чи показувати на сайті «Карткою на сайті». Тестові ключі (sandbox_…) сайт
// показує лише тому, хто сам увімкнув перевірку, — інакше справжній покупець
// «оплатив» би тестовою карткою.
function payOn(site: number) {
  const { pub, priv } = liqOf(site);
  return { online: !!(pub && priv), sandbox: pub.startsWith("sandbox_") };
}

// Готує форму оплати. Суму бере з бази, а не з браузера.
async function payStart(id: number, back: string) {
  const [o]: Order[] = await db(`orders?id=eq.${id}&select=*`);
  if (!o) return { ok: false, error: "order" };
  if (o.customer?.payId !== "online") return { ok: false, error: "not online" };
  if (o.pay_state === "paid") return { ok: false, error: "paid" };
  if (o.status !== "new") return { ok: false, error: "cancelled" };
  const { pub, priv } = liqOf(o.site_id);
  if (!pub || !priv) return { ok: false, error: "no liqpay" };

  let result_url = "";
  try {
    const u = new URL(back);
    if (u.protocol === "https:" && back.length < 500) result_url = u.href;
  } catch { /* без повернення LiqPay просто покаже свою сторінку «Дякуємо» */ }

  const params = {
    version: 3,
    public_key: pub,
    action: "pay",
    amount: Math.round(Number(o.total) * 100) / 100,
    currency: "UAH",
    description: `Замовлення ${o.ref} · ${await shopName(o.site_id)}`,
    // Кожна спроба з новим хвостом: після невдалої оплати LiqPay не прийняв би той самий номер
    order_id: `${o.site_id}-${o.id}-${Date.now().toString(36)}`,
    language: "uk",
    server_url: `${HOOK}?liqpay=${o.site_id}`,
    ...(result_url ? { result_url } : {}),
  };
  const data = b64(JSON.stringify(params));
  if (o.pay_state !== "wait") await patchOrder(o.id, { pay_state: "wait" });
  return { ok: true, url: "https://www.liqpay.ua/api/3/checkout", data, signature: await liqSign(priv, data) };
}

// Для сторінки, на яку покупець повертається з LiqPay. Потрібні і номер, і код
// замовлення — так чужі замовлення не перебрати.
async function payState(id: number, ref: string) {
  const [o] = await db(`orders?id=eq.${id}&ref=eq.${encodeURIComponent(ref)}&select=pay_state,status`);
  return o ? { ok: true, state: o.pay_state, status: o.status } : { ok: false };
}

// LiqPay повідомляє про оплату сюди. Віримо лише підпису приватним ключем.
async function liqCallback(site: number, req: Request) {
  const form = new URLSearchParams(await req.text());
  const data = form.get("data") ?? "";
  const { priv } = liqOf(site);
  if (!priv || !data || form.get("signature") !== (await liqSign(priv, data))) return { ok: false, error: "sign" };
  const p = JSON.parse(unb64(data));
  const m = String(p.order_id ?? "").match(/^(\d+)-(\d+)-/);
  if (!m || Number(m[1]) !== site) return { ok: false, error: "order_id" };
  const [o]: Order[] = await db(`orders?id=eq.${Number(m[2])}&site_id=eq.${site}&select=*`);
  if (!o) return { ok: false, error: "order" };

  const status = String(p.status ?? "");
  const info = {
    status,
    payment_id: p.payment_id ?? null,
    amount: Number(p.amount) || 0,
    currency: p.currency ?? "",
    card: p.sender_card_mask2 ?? "",
    test: status === "sandbox",
    at: new Date().toISOString(),
  };

  // success — оплачено; sandbox — те саме в тестовому режимі;
  // wait_accept — гроші списані, але магазин ще не пройшов перевірку LiqPay
  if (["success", "sandbox", "wait_accept"].includes(status)) {
    if (info.amount + 0.01 < Number(o.total) || info.currency !== "UAH") {
      await patchOrder(o.id, { pay_state: "failed", pay_info: { ...info, error: "сума не збігається" } });
      return { ok: false, error: "amount" };
    }
    // Лише перший раз: зміна на «оплачено» сама штовхає бота через тригер у базі
    await db(`orders?id=eq.${o.id}&pay_state=neq.paid`, {
      method: "PATCH",
      body: JSON.stringify({ pay_state: "paid", paid_at: info.at, pay_info: info }),
    });
  } else if (["failure", "error"].includes(status)) {
    if (o.pay_state !== "paid") await patchOrder(o.id, { pay_state: "failed", pay_info: info });
  } else if (status === "reversed") {
    await patchOrder(o.id, { pay_state: "refunded", pay_info: info });
    const token = tokenOf(site);
    const chats = await db(`tg_chats?site_id=eq.${site}&select=chat_id`);
    for (const c of chats) {
      await tg(token, "sendMessage", {
        chat_id: c.chat_id,
        text: `Оплату за замовлення ${o.ref} (${money(info.amount)}) повернено покупцеві.`,
      });
    }
  }
  return { ok: true };
}

/* ---------- налаштування й перевірка ---------- */

async function setup(site: number) {
  const token = tokenOf(site);
  if (!token) return { ok: false, error: "no TG_TOKEN_" + site };
  const shop = await shopName(site);
  const me = await tg(token, "getMe", {});
  const hook = await tg(token, "setWebhook", {
    url: HOOK + "?site=" + site,
    secret_token: await hookSecret(token),
    allowed_updates: ["message", "callback_query"],
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

// Що вже підключено. Жодних ключів і даних покупців — лише «так/ні» й адреса відправлення.
async function check(site: number) {
  const out: Record<string, unknown> = { bot: !!tokenOf(site), np_key: !!npKeyOf(site) };
  const s = await npSettings(site);
  out.np_settings = !!s;
  if (s) {
    out.auto = s.auto;
    out.from = [s.sender_city, s.sender_branch && "№" + s.sender_branch].filter(Boolean).join(", ") || null;
    out.cod = s.cod_mode;
  }
  if (s && out.np_key) {
    try {
      await sender(npKeyOf(site), s);
      out.sender = "ok";
    } catch (e) {
      out.sender = e instanceof Error ? e.message : String(e);
    }
  }
  return out;
}

/* ---------- вхід ---------- */

// Запити з браузера (оплата на сайті) приходять з іншої адреси — їм потрібен дозвіл CORS
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

    // Оплата карткою: що показати на сайті, форма оплати, стан після повернення, відповідь LiqPay
    const payOnSite = Number(url.searchParams.get("payon"));
    if (payOnSite) return json(payOn(payOnSite), 200, true);
    const payId = Number(url.searchParams.get("pay"));
    if (payId) return json(await payStart(payId, url.searchParams.get("back") ?? ""), 200, true);
    const stateId = Number(url.searchParams.get("paystate"));
    if (stateId) return json(await payState(stateId, url.searchParams.get("ref") ?? ""), 200, true);
    const liqSite = Number(url.searchParams.get("liqpay"));
    if (liqSite && req.method === "POST") return json(await liqCallback(liqSite, req));

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
