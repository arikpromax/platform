"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { getSupabase, type Booking, type Item, type Site } from "@/lib/supabase";

/* ===========================================================
   БРОНЮВАННЯ НОМЕРІВ

   Ліворуч — нова бронь і список броней, праворуч — календар,
   що завжди на екрані. Усе повʼязане між собою:

   • клік по зайнятому дню в календарі підсвічує всю бронь
     (наприклад, з 2 по 5) і саму бронь у списку;
   • клік по броні в списку показує її в календарі;
   • клік по вільних днях вибирає дати нової броні:
     перший клік — заїзд, другий — виїзд.

   Бронь із сайту лягає одразу підтвердженою. Перетинів не буває:
   база сама не пустить бронь поверх зайнятих дат.
   =========================================================== */

type Notice = { kind: "ok" | "err"; text: string } | null;
type Filter = "active" | "cancelled";

const WD = ["нд", "пн", "вт", "ср", "чт", "пт", "сб"];
const WD_HEAD = ["пн", "вт", "ср", "чт", "пт", "сб", "нд"];
const MONTHS = [
  "Січень", "Лютий", "Березень", "Квітень", "Травень", "Червень",
  "Липень", "Серпень", "Вересень", "Жовтень", "Листопад", "Грудень",
];
const MONTHS_GEN = [
  "січ", "лют", "бер", "квіт", "трав", "черв", "лип", "серп", "вер", "жовт", "лист", "груд",
];

const pad = (n: number) => String(n).padStart(2, "0");
const iso = (d: Date) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
const parse = (s: string) => {
  const p = s.split("-").map(Number);
  return new Date(p[0], p[1] - 1, p[2]);
};
const addDays = (s: string, n: number) => {
  const d = parse(s);
  d.setDate(d.getDate() + n);
  return iso(d);
};
const todayISO = () => iso(new Date());

/** 2026-10-04 → «4 жовт, сб» */
const dayUA = (s: string) => {
  if (!s) return "";
  const d = parse(s);
  return `${d.getDate()} ${MONTHS_GEN[d.getMonth()]}, ${WD[d.getDay()]}`;
};
const nightsBetween = (a: string, b: string) =>
  Math.max(0, Math.round((parse(b).getTime() - parse(a).getTime()) / 86400000));
const nightsUA = (n: number) => {
  const a = n % 10;
  const b = n % 100;
  const w = b >= 11 && b <= 14 ? "ночей" : a === 1 ? "ніч" : a >= 2 && a <= 4 ? "ночі" : "ночей";
  return `${n} ${w}`;
};
const guestsUA = (b: Booking) => {
  const a = Number(b.adults) || 0;
  const k = Number(b.children) || 0;
  return `${a} ${a % 10 === 1 && a % 100 !== 11 ? "дорослий" : "дорослих"}` + (k ? `, ${k} діт.` : "");
};
const money = (n: number) => Math.round(n).toLocaleString("uk-UA") + " грн";
const fmtWhen = (s: string) => {
  const d = new Date(s);
  return `${pad(d.getDate())}.${pad(d.getMonth() + 1)}.${d.getFullYear()} о ${pad(d.getHours())}:${pad(d.getMinutes())}`;
};

// Що сказати людині, коли база відмовила
const humanError = (msg: string) =>
  msg.includes("ROOM_BUSY")
    ? "У цьому номері на ці дати вже немає вільних місць. Оберіть у календарі інші дати або інший номер."
    : msg.includes("BAD_DATES")
      ? "Виїзд має бути пізніше за заїзд."
      : msg;

export default function BookingsAdmin({ site, canEdit }: { site: Site; canEdit: boolean }) {
  const supabase = getSupabase()!;
  const today = todayISO();

  const [list, setList] = useState<Booking[]>([]);
  const [rooms, setRooms] = useState<Item[]>([]);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<Notice>(null);
  const [filter, setFilter] = useState<Filter>("active");
  const [sel, setSel] = useState<number | null>(null);       // підсвічена бронь
  const [calRoom, setCalRoom] = useState("");                 // який номер у календарі
  const [month, setMonth] = useState(() => ({ y: new Date().getFullYear(), m: new Date().getMonth() }));
  const [picking, setPicking] = useState(false);              // заїзд обрано, чекаємо виїзд
  const [form, setForm] = useState({
    from: "",
    to: "",
    adults: "2",
    children: "0",
    name: "",
    phone: "",
    note: "",
  });

  /* ---------- дані ---------- */

  const fetchAll = useCallback(async () => {
    const [b, r] = await Promise.all([
      supabase.from("bookings").select("*").eq("site_id", site.id).order("date_in").limit(500),
      supabase.from("items").select("*").eq("site_id", site.id).eq("collection", "rooms").order("sort_order"),
    ]);
    if (b.error) throw new Error(b.error.message);
    if (r.error) throw new Error(r.error.message);
    return { list: (b.data ?? []) as Booking[], rooms: (r.data ?? []) as Item[] };
  }, [supabase, site.id]);

  const take = (got: { list: Booking[]; rooms: Item[] }) => {
    setList(got.list);
    setRooms(got.rooms);
    setCalRoom((c) => c || String(got.rooms[0]?.extra?.key ?? ""));
  };

  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const got = await fetchAll();
        if (alive) take(got);
      } catch (e) {
        if (alive) setNotice({ kind: "err", text: "Не вдалося завантажити: " + (e as Error).message });
      }
      if (alive) setLoading(false);
    })();
    return () => {
      alive = false; // пішли з вкладки — стару відповідь не застосовуємо
    };
  }, [fetchAll]);

  const refresh = async () => {
    setLoading(true);
    try {
      take(await fetchAll());
    } catch (e) {
      setNotice({ kind: "err", text: "Не вдалося завантажити: " + (e as Error).message });
    }
    setLoading(false);
  };

  const keyOf = (r: Item) => String(r.extra?.key ?? "");
  const unitsOf = useCallback(
    (key: string) => Math.max(1, Number(rooms.find((x) => keyOf(x) === key)?.extra?.units) || 1),
    [rooms],
  );
  const nameOf = (key: string) => rooms.find((x) => keyOf(x) === key)?.title ?? key;

  /* Хто займає кожну ніч кожного номера: «номер|дата» → броні */
  const occ = useMemo(() => {
    const m = new Map<string, Booking[]>();
    list
      .filter((b) => b.status !== "cancelled")
      .forEach((b) => {
        for (let d = b.date_in; d < b.date_out; d = addDays(d, 1)) {
          const k = b.room_key + "|" + d;
          m.set(k, [...(m.get(k) ?? []), b]);
        }
      });
    return m;
  }, [list]);
  const here = (key: string, d: string) => occ.get(key + "|" + d) ?? [];
  const taken = (key: string, d: string) => here(key, d).reduce((n, b) => n + (Number(b.rooms_count) || 1), 0);

  /* Старі перетини, що лягли ще до сторожа в базі */
  const conflicts = useMemo(() => {
    const out: { key: string; room: string; refs: string[] }[] = [];
    rooms.forEach((r) => {
      const key = keyOf(r);
      const refs = new Set<string>();
      occ.forEach((bs, k) => {
        if (k.startsWith(key + "|") && bs.length > unitsOf(key)) bs.forEach((b) => refs.add(b.ref));
      });
      if (refs.size) out.push({ key, room: r.title, refs: [...refs] });
    });
    return out;
  }, [rooms, occ, unitsOf]);

  const selected = list.find((b) => b.id === sel) ?? null;

  /* ---------- календар ---------- */

  // Тиждень із понеділка: на початку — порожні клітинки до 1-го числа
  const cells = useMemo(() => {
    const first = new Date(month.y, month.m, 1);
    const lead = (first.getDay() + 6) % 7;
    const n = new Date(month.y, month.m + 1, 0).getDate();
    const out: (string | null)[] = Array(lead).fill(null);
    for (let i = 1; i <= n; i++) out.push(iso(new Date(month.y, month.m, i)));
    while (out.length % 7) out.push(null);
    return out;
  }, [month]);

  const stepMonth = (d: number) =>
    setMonth((m) => {
      const x = new Date(m.y, m.m + d, 1);
      return { y: x.getFullYear(), m: x.getMonth() };
    });
  const showMonthOf = (s: string) => {
    const d = parse(s);
    setMonth({ y: d.getFullYear(), m: d.getMonth() });
  };

  /* Показати бронь: календар переходить на її номер і місяць,
     дати підсвічуються, а сама бронь у списку виділяється. */
  const pickBooking = (b: Booking) => {
    setSel(b.id);
    setPicking(false);
    setCalRoom(b.room_key);
    showMonthOf(b.date_in);
    setFilter(b.status === "cancelled" ? "cancelled" : "active");
    setTimeout(() => document.getElementById("bk-" + b.id)?.scrollIntoView({ behavior: "smooth", block: "nearest" }), 60);
  };

  const clickDay = (d: string) => {
    const occupied = taken(calRoom, d) >= unitsOf(calRoom);
    // чекаємо виїзд — будь-який день після заїзду його ставить
    if (picking && d > form.from) {
      setForm((f) => ({ ...f, to: d }));
      setPicking(false);
      return;
    }
    // зайнятий — показуємо, чия бронь
    if (occupied) {
      pickBooking(here(calRoom, d)[0]);
      return;
    }
    if (d < today || !canEdit) return;
    // вільний — це заїзд нової броні
    setSel(null);
    setForm((f) => ({ ...f, from: d, to: addDays(d, 1) }));
    setPicking(true);
  };

  /* ---------- нова бронь ---------- */

  const check = useMemo(() => {
    if (!calRoom) return { ok: false, text: "Спершу заведіть номери у вкладці «Номери й ціни»" };
    if (!form.from) return { ok: false, text: "Оберіть у календарі дату заїзду" };
    if (!form.to || form.to <= form.from) return { ok: false, text: "Виїзд має бути пізніше за заїзд" };
    const units = unitsOf(calRoom);
    const clash = new Map<number, Booking>();
    for (let d = form.from; d < form.to; d = addDays(d, 1)) {
      if (taken(calRoom, d) + 1 > units) here(calRoom, d).forEach((b) => clash.set(b.id, b));
    }
    if (clash.size) {
      const who = [...clash.values()].map((b) => `${dayUA(b.date_in)} — ${dayUA(b.date_out)}`).join("; ");
      return { ok: false, text: `Ці дати вже зайняті (${who}). Оберіть інші.` };
    }
    return { ok: true, text: `${nameOf(calRoom)}: ${dayUA(form.from)} — ${dayUA(form.to)}, ${nightsUA(nightsBetween(form.from, form.to))} · вільно` };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [calRoom, form.from, form.to, occ, unitsOf, rooms]);

  const addBooking = async () => {
    if (!canEdit || busy || !check.ok) return;
    if (!form.name.trim() && !form.phone.trim()) {
      setNotice({ kind: "err", text: "Впишіть імʼя або телефон гостя" });
      return;
    }
    setBusy(true);
    const d = new Date();
    const ref = `F-${pad(d.getDate())}${pad(d.getMonth() + 1)}-${100 + Math.floor(Math.random() * 900)}`;
    const { data, error } = await supabase
      .from("bookings")
      .insert({
        site_id: site.id,
        ref,
        room_key: calRoom,
        room_name: nameOf(calRoom),
        rooms_count: 1,
        date_in: form.from,
        date_out: form.to,
        adults: Math.max(1, Number(form.adults) || 1),
        children: Math.max(0, Number(form.children) || 0),
        guest: { name: form.name.trim(), phone: form.phone.trim(), note: form.note.trim() },
        extras: {},
        total: 0,
        status: "confirmed",
        source: "phone",
        tg_sent_at: new Date().toISOString(), // записав власник — у Telegram не дублюємо
      })
      .select()
      .single();
    setBusy(false);
    if (error) {
      setNotice({ kind: "err", text: humanError(error.message) });
      return;
    }
    const b = data as Booking;
    setList((old) => [...old, b]);
    setForm((f) => ({ ...f, from: "", to: "", name: "", phone: "", note: "" }));
    setNotice({ kind: "ok", text: `Записано: ${b.room_name}, ${dayUA(b.date_in)} — ${dayUA(b.date_out)}. На сайті ці дати вже зайняті.` });
    pickBooking(b);
  };

  /* ---------- скасувати / повернути ---------- */

  const setStatus = async (b: Booking, status: "confirmed" | "cancelled") => {
    if (!canEdit || busy) return;
    if (
      status === "cancelled" &&
      !window.confirm(
        `Скасувати бронь?\n\n${b.room_name}: ${dayUA(b.date_in)} — ${dayUA(b.date_out)}\n` +
          `${String(b.guest?.name ?? "")} ${String(b.guest?.phone ?? "")}\n\nЦі дати одразу звільняться на сайті.`,
      )
    ) {
      return;
    }
    setBusy(true);
    const { error } = await supabase.from("bookings").update({ status, updated_at: new Date().toISOString() }).eq("id", b.id);
    setBusy(false);
    if (error) {
      setNotice({ kind: "err", text: humanError(error.message) });
      return;
    }
    setList((old) => old.map((x) => (x.id === b.id ? { ...x, status } : x)));
    setNotice({ kind: "ok", text: status === "cancelled" ? "Бронь скасовано — дати знову вільні" : "Бронь повернуто" });
  };

  /* ---------- список ---------- */

  const counts = {
    active: list.filter((b) => b.status !== "cancelled" && b.date_out >= today).length,
    cancelled: list.filter((b) => b.status === "cancelled").length,
  };

  // Активні — від найближчого заїзду; минулі не показуємо, щоб не заважали
  const shown = useMemo(
    () =>
      filter === "cancelled"
        ? list.filter((b) => b.status === "cancelled").sort((a, b) => b.date_in.localeCompare(a.date_in))
        : list.filter((b) => b.status !== "cancelled" && b.date_out >= today).sort((a, b) => a.date_in.localeCompare(b.date_in)),
    [list, filter, today],
  );

  /* ---------- вигляд ---------- */

  const calTitle = `${MONTHS[month.m]} ${month.y}`;
  const roomHasBookings = (key: string) => list.some((b) => b.room_key === key && b.status !== "cancelled" && b.date_out >= today);

  return (
    <div className="bka">
      {/* ===== ліва колонка ===== */}
      <div className="bka__main">
        {conflicts.length > 0 && (
          <div className="banner banner--warn">
            {conflicts.map((c) => (
              <div key={c.key}>
                У «{c.room}» броні перетинаються ({c.refs.join(", ")}). Скасуйте зайву — нові перетини база вже не пускає.
              </div>
            ))}
          </div>
        )}

        {canEdit && (
          <div className="card bkform">
            <h2>Нова бронь</h2>
            <ol className="bkform__steps">
              <li className={calRoom ? "is-done" : ""}>
                <b>Номер</b>
                <div className="bkform__rooms">
                  {rooms.map((r) => (
                    <button
                      key={r.id}
                      type="button"
                      className={`btn btn--sm ${calRoom === keyOf(r) ? "btn--primary" : "btn--ghost"}`}
                      onClick={() => {
                        setCalRoom(keyOf(r));
                        setSel(null);
                      }}
                    >
                      {r.title}
                    </button>
                  ))}
                </div>
              </li>
              <li className={form.from && form.to ? "is-done" : ""}>
                <b>Дати</b>
                <span className="bkform__hint">
                  {picking
                    ? "Тепер натисніть у календарі день виїзду"
                    : form.from
                      ? `${dayUA(form.from)} — ${dayUA(form.to)}`
                      : "Натисніть у календарі праворуч день заїзду, потім — день виїзду"}
                </span>
              </li>
            </ol>

            {form.from && <div className={`status status--${check.ok ? "ok" : "err"}`}>{check.text}</div>}

            <div className="grid2">
              <div className="field">
                <label htmlFor="bk-name">Імʼя гостя</label>
                <input id="bk-name" value={form.name} placeholder="напр. Олена" onChange={(e) => setForm({ ...form, name: e.target.value })} />
              </div>
              <div className="field">
                <label htmlFor="bk-phone">Телефон</label>
                <input id="bk-phone" type="tel" value={form.phone} placeholder="068 000 00 00" onChange={(e) => setForm({ ...form, phone: e.target.value })} />
              </div>
              <div className="field">
                <label htmlFor="bk-ad">Дорослих</label>
                <input id="bk-ad" type="number" min={1} value={form.adults} onChange={(e) => setForm({ ...form, adults: e.target.value })} />
              </div>
              <div className="field">
                <label htmlFor="bk-ch">Дітей</label>
                <input id="bk-ch" type="number" min={0} value={form.children} onChange={(e) => setForm({ ...form, children: e.target.value })} />
              </div>
            </div>
            <div className="field">
              <label htmlFor="bk-note">
                Примітка <span className="opt">(необовʼязково)</span>
              </label>
              <input id="bk-note" value={form.note} placeholder="напр. приїдуть пізно ввечері" onChange={(e) => setForm({ ...form, note: e.target.value })} />
            </div>
            <button className="btn btn--primary" onClick={addBooking} disabled={busy || !check.ok}>
              Забронювати
            </button>
          </div>
        )}

        <div className="card">
          <div className="bka__head">
            <h2>Броні</h2>
            <div className="row__actions">
              <button className={`btn btn--sm ${filter === "active" ? "btn--primary" : "btn--ghost"}`} onClick={() => setFilter("active")}>
                Майбутні · {counts.active}
              </button>
              <button className={`btn btn--sm ${filter === "cancelled" ? "btn--primary" : "btn--ghost"}`} onClick={() => setFilter("cancelled")}>
                Скасовані · {counts.cancelled}
              </button>
              <button className="btn btn--ghost btn--sm" onClick={refresh} disabled={loading}>
                {loading ? "…" : "Оновити"}
              </button>
            </div>
          </div>

          {notice && <div className={`status status--${notice.kind}`}>{notice.text}</div>}

          {loading ? (
            <p className="note">Завантажую…</p>
          ) : !shown.length ? (
            <p className="note">{filter === "cancelled" ? "Скасованих немає." : "Майбутніх броней немає."}</p>
          ) : (
            <div className="bklist">
              {shown.map((b) => {
                const g = b.guest ?? {};
                const s = b.extras?.sauna;
                const on = sel === b.id;
                const now = b.date_in <= today && b.date_out > today;
                return (
                  <div
                    key={b.id}
                    id={"bk-" + b.id}
                    className={"bkcard" + (on ? " is-on" : "") + (b.status === "cancelled" ? " is-off" : "")}
                    onClick={() => pickBooking(b)}
                  >
                    <div className="bkcard__dates">
                      <b>{dayUA(b.date_in)}</b>
                      <span>→</span>
                      <b>{dayUA(b.date_out)}</b>
                      <em>{nightsUA(nightsBetween(b.date_in, b.date_out))}</em>
                    </div>
                    <div className="bkcard__room">
                      {b.room_name}
                      {now && b.status !== "cancelled" && <span className="pill pill--ok">зараз живуть</span>}
                      {b.status === "cancelled" && <span className="pill pill--off">скасована</span>}
                    </div>
                    <div className="bkcard__guest">
                      <b>{String(g.name || "Без імені")}</b>
                      {g.phone && (
                        <a href={"tel:" + String(g.phone).replace(/[^\d+]/g, "")} onClick={(e) => e.stopPropagation()}>
                          {String(g.phone)}
                        </a>
                      )}
                      <span>{guestsUA(b)}</span>
                    </div>

                    {on && (
                      <div className="bkcard__more" onClick={(e) => e.stopPropagation()}>
                        {g.via && <p>Звʼязок: {String(g.via)}</p>}
                        {g.note && <p>Побажання: {String(g.note)}</p>}
                        {s?.day && (
                          <p>
                            Сауна: {dayUA(String(s.day))}, {String(s.time ?? "")}, {String(s.hours ?? 2)} год
                          </p>
                        )}
                        {Number(b.total) > 0 && <p>Попередньо: {money(Number(b.total))}</p>}
                        <p className="note">
                          {b.source === "phone" ? "Записано вручну" : "З сайту"} · {fmtWhen(b.created_at)} · № {b.ref}
                        </p>
                        {canEdit && (
                          <div className="row__actions">
                            {b.status !== "cancelled" ? (
                              <button className="btn btn--danger btn--sm" onClick={() => setStatus(b, "cancelled")} disabled={busy}>
                                Скасувати бронь
                              </button>
                            ) : (
                              <button className="btn btn--ghost btn--sm" onClick={() => setStatus(b, "confirmed")} disabled={busy}>
                                Повернути бронь
                              </button>
                            )}
                          </div>
                        )}
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>

      {/* ===== календар збоку ===== */}
      <aside className="bka__side">
        <div className="card bkcal">
          <div className="bkcal__rooms">
            {rooms.map((r) => (
              <button
                key={r.id}
                type="button"
                className={"bkcal__room" + (calRoom === keyOf(r) ? " is-on" : "")}
                onClick={() => {
                  setCalRoom(keyOf(r));
                  setSel(null);
                }}
              >
                {r.title}
                {roomHasBookings(keyOf(r)) && <i aria-hidden="true" />}
              </button>
            ))}
          </div>

          <div className="bkcal__nav">
            <button className="btn btn--ghost btn--sm btn--icon" onClick={() => stepMonth(-1)} aria-label="Попередній місяць">
              ‹
            </button>
            <b>{calTitle}</b>
            <button className="btn btn--ghost btn--sm btn--icon" onClick={() => stepMonth(1)} aria-label="Наступний місяць">
              ›
            </button>
          </div>

          <div className="bkcal__grid">
            {WD_HEAD.map((w, i) => (
              <span key={w} className={"bkcal__wd" + (i > 4 ? " is-we" : "")}>
                {w}
              </span>
            ))}
            {cells.map((d, i) => {
              if (!d) return <span key={"e" + i} />;
              const units = unitsOf(calRoom);
              const n = taken(calRoom, d);
              const bs = here(calRoom, d);
              const full = n >= units;
              const inSel = !!selected && selected.room_key === calRoom && d >= selected.date_in && d < selected.date_out;
              const inPick = !!form.from && d >= form.from && d < (form.to || addDays(form.from, 1)) && !sel;
              const startsBk = bs.some((b) => b.date_in === d);
              const endsBk = bs.some((b) => addDays(b.date_out, -1) === d);
              const cls =
                "bkcal__d" +
                (d < today ? " is-past" : "") +
                (d === today ? " is-today" : "") +
                (n > units ? " is-over" : full ? " is-full" : n > 0 ? " is-part" : "") +
                (startsBk ? " is-start" : "") +
                (endsBk ? " is-end" : "") +
                (inSel ? " is-sel" : "") +
                (inPick ? " is-pick" : "");
              const tip = bs.length
                ? bs.map((b) => `${String(b.guest?.name || "без імені")}: ${dayUA(b.date_in)} — ${dayUA(b.date_out)}`).join("\n")
                : d < today
                  ? "минуло"
                  : "вільно";
              return (
                <button key={d} type="button" className={cls} title={tip} onClick={() => clickDay(d)}>
                  {parse(d).getDate()}
                  {units > 1 && n > 0 && <small>{n}/{units}</small>}
                </button>
              );
            })}
          </div>

          <div className="bkcal__legend">
            <span><i className="is-free" /> вільно</span>
            <span><i className="is-full" /> зайнято</span>
            <span><i className="is-sel" /> обрана бронь</span>
            <span><i className="is-pick" /> нова бронь</span>
          </div>

          {selected && selected.room_key === calRoom && (
            <div className="bkcal__info">
              <b>{String(selected.guest?.name || "Без імені")}</b> · {dayUA(selected.date_in)} — {dayUA(selected.date_out)}
              <button className="btn btn--ghost btn--sm" onClick={() => setSel(null)}>
                Зняти виділення
              </button>
            </div>
          )}
        </div>
      </aside>
    </div>
  );
}
