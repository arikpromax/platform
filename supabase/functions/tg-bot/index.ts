// Telegram-бот замовлень і накладні Нової Пошти.
//
// Що вміє один файл:
//   ?setup=<site>        — прив'язати бота до цієї функції (вебхук, опис, команди)
//   ?check=<site>        — перевірити, що підключено: токен, ключ НП, відправник
//   POST {order: <id>}   — нове замовлення: створити ТТН і надіслати все в чати
//   POST {track: true}   — розклад раз на 30 хв: де посилки, статуси й повернення
//   POST від Telegram    — /start <код>, /stop і кнопки під замовленням
//   ?payon / ?pay / ?paystate / ?liqpay — оплата карткою через LiqPay
//   ?sync=stock|orders|ack&site=N — обмін із програмою обліку магазину (УкрСклад)
//
// Ключі власник вписує в адмінці, розділ «Підключення» (таблиця site_keys).
// Чого там немає — беремо з Supabase → Edge Functions → Secrets:
//   TG_TOKEN_<сайт>, NP_KEY_<сайт>, LIQPAY_*_<сайт>, MONO_TOKEN_<сайт>, SYNC_KEY_<сайт>.
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

// Ключі власник вписує в адмінці («Підключення») — вони лежать у закритій
// таблиці site_keys. Якщо там порожньо, беремо з Secrets, як було раніше.
// Півхвилини тримаємо знайдене в памʼяті, щоб не питати базу на кожен крок.
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
const npKeyOf = (site: number) => keyOf(site, "NP_KEY");
const liqOf = async (site: number) => ({
  pub: await keyOf(site, "LIQPAY_PUBLIC"),
  priv: await keyOf(site, "LIQPAY_PRIVATE"),
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
  for (let attempt = 0; ; attempt++) {
    const r = await fetch(BASE + "/rest/v1/" + path, {
      ...init,
      headers: dbHead((init.headers as Record<string, string>) ?? {}),
    });
    const text = await r.text();
    // Щойно запущена функція буває на долю секунди «попереду» годинника бази,
    // і база відповідає «JWT issued in the future» (PGRST303). Це минає саме —
    // трохи чекаємо й пробуємо ще раз, замість того щоб зривати замовлення.
    if (r.status === 401 && text.includes("PGRST303") && attempt < 3) {
      await new Promise((ok) => setTimeout(ok, 1000 * (attempt + 1)));
      continue;
    }
    if (!r.ok) throw new Error("db " + r.status + ": " + text.slice(0, 300));
    return text ? JSON.parse(text) : null;
  }
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
  pay_provider: string;   // mono | off — обирають в адмінці
  pay_test: boolean;      // тестовий токен: гроші не рухаються
  weight_default: number; // вага, коли в товару своєї немає
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

async function parcel(o: Order, fallbackKg = 0.5) {
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
    kg += (own > 0 ? own : CAT_KG[cat] ?? fallbackKg) * q;
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

  const key = await npKeyOf(o.site_id);
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
    const box = await parcel(o, Number(s.weight_default) || 0.5);
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
    // Накладений платіж: звичайний грошовий переказ або «контроль оплати» (за договором з НП)
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
  const key = await npKeyOf(o.site_id);
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
  np_track?: string;
  np_arrived_at?: string | null;
  np_stay_note_at?: string | null;
  np_refused_at?: string | null;
  np_return_ttn?: string;
  np_back_arrived_at?: string | null;
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
  if (c.payId === "cod") return `Оплата: накладений платіж — ${money(o.total)} при отриманні`;
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

  // Оплата карткою: замовлення приходить у Telegram лише тоді, коли банк
  // підтвердив гроші. Неоплачене через 10 хвилин база скасує сама.
  if (o.customer?.payId === "online" && o.pay_state !== "paid") {
    await release();
    return { ok: false, error: "not paid yet" };
  }
  // Гроші прийшли вже після автоскасування: товар повернули на склад,
  // тож накладну не робимо — власник спершу перевірить наявність.
  const late = o.status === "cancelled";
  // Тестова оплата: гроші не рухались, тож і накладну сама не робимо
  const test = !!o.pay_info?.test;

  const token = await tokenOf(o.site_id);
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
    const key = await npKeyOf(site);
    if (!key) return answer("Нова Пошта не підключена", true);
    try {
      await np(key, "InternetDocument", "delete", { DocumentRefs: o.ttn_ref });
    } catch (e) {
      return answer("НП не дала скасувати: " + (e instanceof Error ? e.message : e), true);
    }
    const old = o.ttn;
    o.ttn = ""; o.ttn_ref = ""; o.ttn_cost = null; o.ttn_date = ""; o.ttn_error = "";
    // Разом із накладною скидаємо й стеження — нова ТТН почне його з нуля
    await patchOrder(o.id, {
      ttn: "", ttn_ref: "", ttn_cost: null, ttn_date: "", ttn_error: "",
      np_track: "", np_code: null, np_status: "", np_checked_at: null, np_arrived_at: null,
      np_stay_note_at: null, np_refused_at: null, np_return_ttn: "", np_back_arrived_at: null, np_final: false,
    });
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

/* ---------- стеження за посилками ---------- */

// Коди статусів Нової Пошти, згруповані за тим, що з ними робити
const NP_WAY = [4, 41, 5, 6, 12, 101];   // прийняли й везуть
const NP_HERE = [7, 8];                   // у відділенні (8 — у поштоматі)
const NP_GOT = [9, 10, 11, 106];          // отримувач забрав
const NP_BACK = [102, 103, 105];          // відмова або скінчилось зберігання — посилка їде назад
const DAY = 86400000;

// Коротке повідомлення всім під'єднаним чатам сайту
async function tell(site: number, text: string) {
  const token = await tokenOf(site);
  if (!token) return;
  const chats: { chat_id: number }[] = await db(`tg_chats?site_id=eq.${site}&select=chat_id`);
  for (const c of chats) {
    await tg(token, "sendMessage", { chat_id: c.chat_id, text, parse_mode: "HTML", link_preview_options: { is_disabled: true } });
  }
}

const setStatus = (id: number, status: string, note = "") =>
  db("rpc/order_status_apply", {
    method: "POST",
    body: JSON.stringify({ p_order: id, p_status: status, p_who: "Нова Пошта", p_note: note }),
  });

type NpDoc = {
  Number?: string;
  StatusCode?: string | number;
  Status?: string;
  WarehouseRecipient?: string;
  LastCreatedOnTheBasisNumber?: string;
};

// Один крок для одного замовлення: що змінилось із минулої перевірки
async function trackOne(o: Order, r: NpDoc, back: boolean) {
  const code = Number(r.StatusCode);
  const now = new Date().toISOString();
  const upd: Record<string, unknown> = { np_checked_at: now, np_code: code, np_status: String(r.Status ?? "") };
  const ref = `<b>${esc(o.ref)}</b>`;
  const where = code === 8 ? "поштоматі" : "відділенні";
  const say: string[] = [];

  if (back) {
    // Стежимо за зворотною ТТН: посилка їде до вас
    if (NP_HERE.includes(code) && !o.np_back_arrived_at) {
      upd.np_back_arrived_at = now;
      say.push(`📍 Повернення ${ref} чекає у ${where}: ${esc(r.WarehouseRecipient ?? "")} · ТТН ${esc(o.np_return_ttn)}`);
    } else if (NP_GOT.includes(code)) {
      upd.np_final = true;
      if (["new", "shipped", "done"].includes(o.status ?? "")) {
        await setStatus(o.id, "returned", "посилка повернулась, ТТН " + o.np_return_ttn);
        say.push(`📦 ${ref} повернулась до вас. Товар знову на складі.`);
      } else {
        say.push(`📦 ${ref} повернулась до вас.`);
      }
    }
  } else if (code === 2) {
    // ТТН видалили вручну в кабінеті НП — замовлення лишається, накладної вже немає
    Object.assign(upd, { ttn: "", ttn_ref: "", ttn_cost: null, ttn_date: "", np_track: "", np_final: false });
    say.push(`🗑 ТТН ${esc(o.ttn)} до ${ref} видалено в кабінеті Нової Пошти.`);
  } else if (code === 104 && r.LastCreatedOnTheBasisNumber && r.LastCreatedOnTheBasisNumber !== o.np_track) {
    // Переадресація: далі посилка їде під новим номером
    upd.np_track = r.LastCreatedOnTheBasisNumber;
    say.push(`🔀 ${ref}: адресу доставки змінено, нова ТТН ${esc(r.LastCreatedOnTheBasisNumber)}.`);
  } else if (NP_WAY.includes(code)) {
    if (o.status === "new") {
      await setStatus(o.id, "shipped");
      say.push(`🚚 ${ref} відправлено · ТТН ${esc(o.ttn)}`);
    }
  } else if (NP_HERE.includes(code)) {
    if (o.status === "new") await setStatus(o.id, "shipped");
    if (!o.np_arrived_at) {
      upd.np_arrived_at = now;
      say.push(`📍 ${ref} прибула у ${where}: ${esc(r.WarehouseRecipient ?? "")}`);
    } else if (!o.np_stay_note_at && Date.now() - Date.parse(o.np_arrived_at) >= 3 * DAY) {
      upd.np_stay_note_at = now;
      say.push(`⏳ ${ref} лежить у ${where} вже 3 дні.`);
    }
  } else if (NP_GOT.includes(code)) {
    upd.np_final = true;
    if (o.status === "new" || o.status === "shipped") await setStatus(o.id, "done");
    const cod = o.customer?.payId === "cod" ? ` Накладений платіж ${money(o.total)} — Нова Пошта переведе гроші.` : "";
    say.push(`✅ ${ref} отримано.${cod}`);
  } else if (NP_BACK.includes(code)) {
    if (!o.np_refused_at) {
      upd.np_refused_at = now;
      say.push(code === 105
        ? `↩️ ${ref}: строк зберігання скінчився, посилка повертається.`
        : `↩️ ${ref}: покупець відмовився, посилка повертається.`);
    }
    // Зворотна ТТН з'являється не одразу — підхопимо на наступній перевірці
    if (r.LastCreatedOnTheBasisNumber && !o.np_return_ttn) upd.np_return_ttn = r.LastCreatedOnTheBasisNumber;
  }

  await patchOrder(o.id, upd);
  for (const text of say) await tell(o.site_id, text);
  return say.length > 0;
}

async function track() {
  // Не частіше ніж раз на 20 хвилин для кожної посилки: зайвий виклик нічого не зробить
  const fresh = new Date(Date.now() - 20 * 60000).toISOString();
  const since = new Date(Date.now() - 60 * DAY).toISOString();
  const list: Order[] = await db(
    `orders?ttn=neq.&np_final=is.false&created_at=gt.${since}` +
      `&or=(np_checked_at.is.null,np_checked_at.lt.%22${fresh}%22)&select=*&order=id&limit=500`,
  );
  const bySite = new Map<number, Order[]>();
  for (const o of list) bySite.set(o.site_id, [...(bySite.get(o.site_id) ?? []), o]);

  let checked = 0, changed = 0;
  for (const [site, orders] of bySite) {
    const key = await npKeyOf(site);
    if (!key) continue; // Нову Пошту для цього сайту ще не підключили
    const s = await npSettings(site);
    const phone = s?.sender_phone ?? "";
    // Замовлення, де посилка вже їде назад, перевіряємо за зворотною ТТН
    const jobs = orders.map((o) => ({ o, back: !!o.np_return_ttn, no: o.np_return_ttn || o.np_track || o.ttn || "" }));
    for (let i = 0; i < jobs.length; i += 100) {
      const part = jobs.slice(i, i + 100);
      let docs: NpDoc[] = [];
      try {
        docs = await np(key, "TrackingDocument", "getStatusDocuments", {
          Documents: part.map((j) => ({ DocumentNumber: j.no, Phone: phone })),
        });
      } catch (e) {
        console.error("track", site, e);
        continue;
      }
      const byNo = new Map(docs.map((d) => [String(d.Number), d]));
      for (const j of part) {
        const r = byNo.get(j.no);
        if (!r) continue;
        checked++;
        try {
          if (await trackOne(j.o, r, j.back)) changed++;
        } catch (e) {
          console.error("track order", j.o.id, e);
        }
      }
    }
  }
  return { ok: true, checked, changed };
}

/* ---------- обмін із програмою обліку магазину ---------- */

// Програма магазину — головна по товарах, кількості й цінах. Її скрипт стукає
// сюди з ключем SYNC_KEY_<сайт> у заголовку X-Sync-Key:
//   POST ?sync=stock&site=N   {items:[{sku,size,qty,price,old_price,name,brand,category,gender}], full}
//   GET  ?sync=orders&site=N  — замовлення сайту для розхідних накладних
//   POST ?sync=ack&site=N     {refs:[...]} — програма забрала ці замовлення
async function syncAllowed(site: number, req: Request) {
  const want = await keyOf(site, "SYNC_KEY");
  const got = req.headers.get("x-sync-key") ?? "";
  if (want.length < 24 || got.length !== want.length) return false;
  // порівняння без підказки за часом, де саме розійшлися ключі
  let diff = 0;
  for (let i = 0; i < want.length; i++) diff |= want.charCodeAt(i) ^ got.charCodeAt(i);
  return diff === 0;
}

const rpc = (name: string, args: Record<string, unknown>) =>
  db("rpc/" + name, { method: "POST", body: JSON.stringify(args) });

// Фото з офіційного каталогу Nike за артикулом: колір гарантовано той самий.
// Картинки лежать у squarishURL; розмір задається заміною /t_default/.
// Разом із фото беремо офіційну назву моделі й колір — для нових карток.
type NikeInfo = { urls: string[]; title: string; color: string };
async function nikeInfo(sku: string): Promise<NikeInfo> {
  const code = sku.split("__")[0].trim();
  for (const [market, lang] of [["GB", "en-GB"], ["US", "en"], ["DE", "de"]]) {
    try {
      const r = await fetch(
        "https://api.nike.com/product_feed/threads/v2/?filter=marketplace(" + market + ")" +
          "&filter=language(" + lang + ")&filter=channelId(d9a5bc42-4b9c-4976-858a-f159cf99c647)" +
          "&filter=productInfo.merchProduct.styleColor(" + encodeURIComponent(code) + ")",
      );
      const j = await r.json();
      const obj = j?.objects?.[0];
      const content = obj?.productInfo?.[0]?.productContent ?? {};
      const nodes = obj?.publishedContent?.nodes?.[0]?.nodes ?? [];
      const urls: string[] = [];
      for (const n of nodes) {
        const u = n?.properties?.squarishURL;
        if (typeof u === "string" && u.includes("/t_default/")) {
          const big = u.replace("/t_default/", "/t_PDP_1280_v1/");
          if (!urls.includes(big)) urls.push(big);
        }
        if (urls.length >= 4) break;
      }
      if (urls.length) {
        return { urls, title: String(content.title ?? ""), color: String(content.colorDescription ?? "") };
      }
    } catch { /* пробуємо інший ринок */ }
  }
  return { urls: [], title: "", color: "" };
}

// Назва в стилі сайту: «Кросівки чоловічі Air Max 90 Anthracite» — бренд на
// сайті показано окремо, тому з назви Nike його прибираємо.
const KIND: Record<string, [string, "pl" | "f" | "m"]> = {
  vzuttia: ["Кросівки", "pl"], kurtky: ["Куртка", "f"], kofty: ["Кофта", "f"],
  kostiumy: ["Костюм", "m"], zhyletky: ["Жилетка", "f"], shtany: ["Штани", "pl"],
  futbolky: ["Футболка", "f"], shorty: ["Шорти", "pl"], shkarpetky: ["Шкарпетки", "pl"],
};
const WHO: Record<string, Record<string, string>> = {
  m: { pl: "чоловічі", f: "чоловіча", m: "чоловічий" },
  w: { pl: "жіночі", f: "жіноча", m: "жіночий" },
};
function niceTitle(info: NikeInfo, extra: Record<string, unknown>) {
  const model = info.title.replace(/^Nike\s+/i, "").trim();
  if (!model) return "";
  const [noun, form] = KIND[String(extra.cat ?? "")] ?? ["", "pl"];
  const who = WHO[String(extra.gender ?? "")]?.[form] ?? "";
  const color = info.color.split("/")[0].trim();
  return [noun, who, model, color].filter(Boolean).join(" ");
}

// Новим карткам Nike і Jordan шукаємо фото — не більше 15 за раз, решту
// підхопить наступна синхронізація. Знайшли — товар зʼявляється на сайті.
async function findPhotos(site: number) {
  const todo: { id: number; extra: Record<string, unknown> }[] = await db(
    `items?site_id=eq.${site}&collection=eq.products&extra->>photo_lookup=eq.pending&select=id,extra&limit=15`,
  );
  let found = 0;
  for (const it of todo) {
    const info = await nikeInfo(String(it.extra.sku ?? ""));
    const extra: Record<string, unknown> = { ...it.extra, photo_lookup: info.urls.length ? "done" : "none" };
    const patch: Record<string, unknown> = { extra };
    if (info.urls.length && !(Array.isArray(it.extra.photos) && it.extra.photos.length)) {
      extra.photos = info.urls;
      found++;
    }
    // Назву з програми («Крос Найк АМ90 сір») міняємо на офіційну, поки її не правили в адмінці
    if (it.extra.title_auto === true) {
      const title = niceTitle(info, it.extra);
      if (title) patch.title = title;
      extra.title_auto = false;
    }
    await db(`items?id=eq.${it.id}`, { method: "PATCH", body: JSON.stringify(patch) });
  }
  return { checked: todo.length, found };
}

// Одну річ продали і в магазині, і на сайті — кажемо в Telegram одразу,
// поки посилку не відправили: покупцю пропонують інший розмір або повертають гроші.
async function warnOversold(site: number, list: { ref: string; sku?: string; size?: string }[], why: string) {
  for (const c of list) {
    const what = c.sku ? ` ${esc(c.sku)}${c.size ? ", розмір " + esc(c.size) : ""}` : "";
    await tell(
      site,
      `⚠️ <b>${esc(c.ref)}</b>${what ? ":" + what : ""} — ${why}.\n` +
        "Звʼяжіться з покупцем: запропонуйте інший розмір або поверніть гроші, " +
        "скасуйте ТТН і поставте «Скасоване» в адмінці.",
    ).catch((e) => console.error("warn", e));
  }
}

async function onSync(kind: string, site: number, req: Request) {
  if (!site || !(await syncAllowed(site, req))) return json({ ok: false, error: "key" }, 401);

  if (kind === "stock" && req.method === "POST") {
    const body = await req.json().catch(() => null);
    if (!body || !Array.isArray(body.items)) return json({ ok: false, error: "items" }, 400);
    const dry = body.dry === true;
    const res = await rpc("sync_stock", {
      p_site: site, p_items: body.items, p_full: body.full === true, p_dry: dry,
    });
    if (dry) return json(res);
    await warnOversold(site, res?.conflicts ?? [], "у магазині вже продали");
    const photos = await findPhotos(site).catch((e) => ({ error: String(e) }));
    return json({ ...res, photos });
  }

  if (kind === "orders") {
    return json({ ok: true, orders: await rpc("orders_for_shop", { p_site: site }) });
  }

  if (kind === "ack" && req.method === "POST") {
    const body = await req.json().catch(() => null);
    const refs = Array.isArray(body?.refs) ? body.refs.map(String).slice(0, 500) : [];
    const short = Array.isArray(body?.short) ? body.short.map(String).slice(0, 500) : [];
    if (!refs.length && !short.length) return json({ ok: false, error: "refs" }, 400);
    const res = await rpc("sync_ack", { p_site: site, p_refs: refs, p_short: short });
    await warnOversold(site, (res?.short ?? []).map((ref: string) => ({ ref })), "магазин не зміг провести — товару немає");
    return json(res);
  }

  return json({ ok: false, error: "nothing to do" }, 400);
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

// Чи показувати на сайті «Карткою на сайті» і чи писати покупцеві, що це
// перевірка. Тестовий режим вмикають в адмінці разом із тестовим токеном:
// інакше людина заплатила б тестовою карткою й думала, що замовлення оплачене.
async function payOn(site: number) {
  const s = await npSettings(site);
  const how = s?.pay_provider ?? "mono";
  if (how === "off") return { online: false, sandbox: false, how };
  if (how === "mono") {
    return { online: !!(await keyOf(site, "MONO_TOKEN")), sandbox: !!s?.pay_test, how };
  }
  const { pub, priv } = await liqOf(site);
  return { online: !!(pub && priv), sandbox: pub.startsWith("sandbox_"), how };
}

// MonoPay: створюємо рахунок і відправляємо покупця на сторінку monobank.
// Статус оплати потім перепитуємо в них самих — так підробити його не вийде.
async function mono(token: string, path: string, init: RequestInit = {}) {
  const r = await fetch("https://api.monobank.ua/api/merchant/" + path, {
    ...init,
    headers: { "X-Token": token, "Content-Type": "application/json", ...(init.headers ?? {}) },
  });
  const j = await r.json().catch(() => null);
  if (!r.ok) throw new Error("monobank " + r.status + ": " + JSON.stringify(j).slice(0, 200));
  return j;
}

// Готує форму оплати. Суму бере з бази, а не з браузера.
async function payStart(id: number, back: string) {
  const [o]: Order[] = await db(`orders?id=eq.${id}&select=*`);
  if (!o) return { ok: false, error: "order" };
  if (o.customer?.payId !== "online") return { ok: false, error: "not online" };
  if (o.pay_state === "paid") return { ok: false, error: "paid" };
  if (o.status !== "new") return { ok: false, error: "cancelled" };
  const how = (await payOn(o.site_id)).how;
  if (how === "off") return { ok: false, error: "no pay" };

  let result_url = "";
  try {
    const u = new URL(back);
    if (u.protocol === "https:" && back.length < 500) result_url = u.href;
  } catch { /* без повернення LiqPay просто покаже свою сторінку «Дякуємо» */ }

  const shop = await shopName(o.site_id);
  const amount = Math.round(Number(o.total) * 100) / 100;
  const tail = `${o.site_id}-${o.id}-${Date.now().toString(36)}`;

  if (how === "mono") {
    const token = await keyOf(o.site_id, "MONO_TOKEN");
    if (!token) return { ok: false, error: "no mono" };
    const inv = await mono(token, "invoice/create", {
      method: "POST",
      body: JSON.stringify({
        amount: Math.round(amount * 100),          // monobank рахує в копійках
        ccy: 980,
        merchantPaymInfo: { reference: tail, destination: `Замовлення ${o.ref} · ${shop}` },
        redirectUrl: result_url || undefined,
        webHookUrl: `${HOOK}?mono=${o.site_id}`,
        validity: 900,
      }),
    });
    if (!inv?.pageUrl) return { ok: false, error: "mono" };
    if (o.pay_state !== "wait") await patchOrder(o.id, { pay_state: "wait" });
    await patchOrder(o.id, { pay_info: { how: "mono", invoiceId: inv.invoiceId, ref: tail } });
    return { ok: true, redirect: inv.pageUrl };
  }

  const { pub, priv } = await liqOf(o.site_id);
  if (!pub || !priv) return { ok: false, error: "no liqpay" };
  const params = {
    version: 3,
    public_key: pub,
    action: "pay",
    amount,
    currency: "UAH",
    description: `Замовлення ${o.ref} · ${shop}`,
    // Кожна спроба з новим хвостом: після невдалої оплати LiqPay не прийняв би той самий номер
    order_id: tail,
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
// monobank сповіщає про оплату сюди. Тілу повідомлення не віримо:
// самі питаємо monobank, що з рахунком.
async function monoCallback(site: number, req: Request) {
  const body = await req.json().catch(() => null);
  const id = String(body?.invoiceId ?? "");
  if (!id) return { ok: false, error: "invoiceId" };
  const token = await keyOf(site, "MONO_TOKEN");
  if (!token) return { ok: false, error: "no mono" };
  const inv = await mono(token, "invoice/status?invoiceId=" + encodeURIComponent(id));
  const m = String(inv?.reference ?? "").match(/^(\d+)-(\d+)-/);
  if (!m || Number(m[1]) !== site) return { ok: false, error: "reference" };
  const [o]: Order[] = await db(`orders?id=eq.${Number(m[2])}&site_id=eq.${site}&select=*`);
  if (!o) return { ok: false, error: "order" };
  const paid = Math.round(Number(inv?.amount ?? 0)) / 100;
  const info = {
    how: "mono", status: String(inv?.status ?? ""), invoiceId: id,
    amount: paid, currency: "UAH", card: inv?.paymentInfo?.maskedPan ?? "",
    test: !!(await npSettings(site))?.pay_test, at: new Date().toISOString(),
  };
  if (inv?.status === "success") {
    if (paid + 0.01 < Number(o.total)) {
      await patchOrder(o.id, { pay_state: "failed", pay_info: { ...info, error: "сума не збігається" } });
      return { ok: false, error: "amount" };
    }
    await db(`orders?id=eq.${o.id}&pay_state=neq.paid`, {
      method: "PATCH",
      body: JSON.stringify({ pay_state: "paid", paid_at: info.at, pay_info: info }),
    });
  } else if (["failure", "expired"].includes(String(inv?.status))) {
    if (o.pay_state !== "paid") await patchOrder(o.id, { pay_state: "failed", pay_info: info });
  } else if (String(inv?.status) === "reversed") {
    await patchOrder(o.id, { pay_state: "refunded", pay_info: info });
    await tell(site, `Оплату за замовлення ${esc(o.ref)} (${money(paid)}) повернено покупцеві.`);
  }
  return { ok: true };
}

async function liqCallback(site: number, req: Request) {
  const form = new URLSearchParams(await req.text());
  const data = form.get("data") ?? "";
  const { priv } = await liqOf(site);
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
    const token = await tokenOf(site);
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
  const token = await tokenOf(site);
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
  const npKey = await npKeyOf(site);
  const out: Record<string, unknown> = { bot: !!(await tokenOf(site)), np_key: !!npKey };
  const s = await npSettings(site);
  out.np_settings = !!s;
  if (s) {
    out.auto = s.auto;
    out.from = [s.sender_city, s.sender_branch && "№" + s.sender_branch].filter(Boolean).join(", ") || null;
    out.cod = s.cod_mode;
  }
  if (s && out.np_key) {
    try {
      await sender(npKey, s);
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
    // Обмін із програмою магазину — лише з ключем SYNC_KEY_<сайт>
    const syncKind = url.searchParams.get("sync");
    if (syncKind) return await onSync(syncKind, Number(url.searchParams.get("site")), req);

    const checkSite = Number(url.searchParams.get("check"));
    if (checkSite) return json(await check(checkSite));

    // Оплата карткою: що показати на сайті, форма оплати, стан після повернення, відповідь LiqPay
    const payOnSite = Number(url.searchParams.get("payon"));
    if (payOnSite) return json(await payOn(payOnSite), 200, true);
    const payId = Number(url.searchParams.get("pay"));
    if (payId) return json(await payStart(payId, url.searchParams.get("back") ?? ""), 200, true);
    const stateId = Number(url.searchParams.get("paystate"));
    if (stateId) return json(await payState(stateId, url.searchParams.get("ref") ?? ""), 200, true);
    const liqSite = Number(url.searchParams.get("liqpay"));
    if (liqSite && req.method === "POST") return json(await liqCallback(liqSite, req));
    const monoSite = Number(url.searchParams.get("mono"));
    if (monoSite && req.method === "POST") return json(await monoCallback(monoSite, req));

    // Запит від Telegram: звіряємо підпис, інакше будь-хто міг би під'єднати свій чат
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
      const id = Number(body?.order);
      if (id) return json(await notify(id));
      if (body?.track === true) return json(await track());
    }
    return json({ ok: false, error: "nothing to do" }, 400);
  } catch (e) {
    console.error(e);
    return json({ ok: false, error: String(e) }, 500);
  }
});
