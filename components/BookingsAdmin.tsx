"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { getSupabase, type Booking, type Item, type Site } from "@/lib/supabase";

/* ===========================================================
   БРОНЮВАННЯ НОМЕРІВ

   Бронь із сайту лягає одразу підтвердженою — гість отримав номер.
   Власник тут лише дивиться, що зайнято, і скасовує, якщо треба.

   Шахматка зверху: рядок — номер, клітинка — ніч. Видно одразу,
   що вільно, а клік по вільній клітинці відкриває запис броні
   на цю дату. Перетинів не буває: база сама не пустить бронь
   поверх зайнятих дат — ні з сайту, ні звідси.
   =========================================================== */

type Notice = { kind: "ok" | "err"; text: string } | null;
type Filter = "active" | "cancelled" | "all";

const WD = ["нд", "пн", "вт", "ср", "чт", "пт", "сб"];
const MONTHS = [
  "Січень", "Лютий", "Березень", "Квітень", "Травень", "Червень",
  "Липень", "Серпень", "Вересень", "Жовтень", "Листопад", "Грудень",
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

/** 2026-10-04 → «04.10, сб» */
const dayUA = (s: string) => {
  const p = String(s ?? "").split("-");
  if (p.length !== 3) return String(s ?? "");
  return `${p[2]}.${p[1]}, ${WD[parse(s).getDay()]}`;
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
  return `${pad(d.getDate())}.${pad(d.getMonth() + 1)}.${d.getFullYear()} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
};

// Що сказати людині, коли база відмовила
const humanError = (msg: string) =>
  msg.includes("ROOM_BUSY")
    ? "У цьому номері на ці дати вже немає вільних місць. Подивіться шахматку вище й оберіть інші дати чи інший номер."
    : msg.includes("BAD_DATES")
      ? "Виїзд має бути пізніше за заїзд."
      : msg;

const emptyForm = () => ({
  room: "",
  from: todayISO(),
  to: addDays(todayISO(), 1),
  adults: "2",
  children: "0",
  name: "",
  phone: "",
  note: "",
});

export default function BookingsAdmin({ site, canEdit }: { site: Site; canEdit: boolean }) {
  const supabase = getSupabase()!;
  const [list, setList] = useState<Booking[]>([]);
  const [rooms, setRooms] = useState<Item[]>([]);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<Notice>(null);
  const [filter, setFilter] = useState<Filter>("active");
  const [openId, setOpenId] = useState<number | null>(null);
  const [adding, setAdding] = useState(false);
  const [form, setForm] = useState(emptyForm);
  const [month, setMonth] = useState(() => {
    const d = new Date();
    return { y: d.getFullYear(), m: d.getMonth() };
  });
  const formRef = useRef<HTMLDivElement>(null);

  /* ---------- дані ---------- */

  const fetchAll = useCallback(async () => {
    const [b, r] = await Promise.all([
      supabase
        .from("bookings")
        .select("*")
        .eq("site_id", site.id)
        .order("date_in", { ascending: false })
        .limit(500),
      supabase
        .from("items")
        .select("*")
        .eq("site_id", site.id)
        .eq("collection", "rooms")
        .order("sort_order"),
    ]);
    if (b.error) throw new Error(b.error.message);
    if (r.error) throw new Error(r.error.message);
    return { list: (b.data ?? []) as Booking[], rooms: (r.data ?? []) as Item[] };
  }, [supabase, site.id]);

  const take = (got: { list: Booking[]; rooms: Item[] }) => {
    setList(got.list);
    setRooms(got.rooms);
    setForm((f) => (f.room ? f : { ...f, room: String(got.rooms[0]?.extra?.key ?? "") }));
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
    (key: string) => {
      const r = rooms.find((x) => keyOf(x) === key);
      return Math.max(1, Number(r?.extra?.units) || 1);
    },
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
          const arr = m.get(k) ?? [];
          arr.push(b);
          m.set(k, arr);
        }
      });
    return m;
  }, [list]);

  const taken = (key: string, d: string) =>
    (occ.get(key + "|" + d) ?? []).reduce((n, b) => n + (Number(b.rooms_count) || 1), 0);

  /* Старі перетини, що лягли ще до сторожа в базі: показуємо, щоб прибрали */
  const conflicts = useMemo(() => {
    const out: { room: string; from: string; to: string; refs: string[] }[] = [];
    rooms.forEach((r) => {
      const key = keyOf(r);
      const units = unitsOf(key);
      const days = [...occ.keys()]
        .filter((k) => k.startsWith(key + "|"))
        .map((k) => k.split("|")[1])
        .filter((d) => (occ.get(key + "|" + d) ?? []).length > units)
        .sort();
      if (!days.length) return;
      const refs = new Set<string>();
      days.forEach((d) => (occ.get(key + "|" + d) ?? []).forEach((b) => refs.add(b.ref)));
      out.push({ room: r.title, from: days[0], to: days[days.length - 1], refs: [...refs] });
    });
    return out;
  }, [rooms, occ, unitsOf]);

  /* ---------- шахматка ---------- */

  const days = useMemo(() => {
    const n = new Date(month.y, month.m + 1, 0).getDate();
    return Array.from({ length: n }, (_, i) => iso(new Date(month.y, month.m, i + 1)));
  }, [month]);
  const today = todayISO();

  const stepMonth = (d: number) =>
    setMonth((m) => {
      const x = new Date(m.y, m.m + d, 1);
      return { y: x.getFullYear(), m: x.getMonth() };
    });

  const openAdd = (room?: string, from?: string) => {
    if (!canEdit) return;
    setForm((f) => ({
      ...emptyForm(),
      room: room ?? f.room ?? String(rooms[0]?.extra?.key ?? ""),
      from: from ?? todayISO(),
      to: addDays(from ?? todayISO(), 1),
    }));
    setAdding(true);
    setNotice(null);
    setTimeout(() => formRef.current?.scrollIntoView({ behavior: "smooth", block: "start" }), 50);
  };

  const showBooking = (b: Booking) => {
    setFilter(b.status === "cancelled" ? "cancelled" : "active");
    setOpenId(b.id);
    setTimeout(() => document.getElementById("bk-" + b.id)?.scrollIntoView({ behavior: "smooth", block: "center" }), 50);
  };

  const clickCell = (key: string, d: string) => {
    const here = occ.get(key + "|" + d) ?? [];
    if (here.length && taken(key, d) >= unitsOf(key)) {
      showBooking(here[0]);
      return;
    }
    if (d < today) return;
    openAdd(key, d);
  };

  /* ---------- нова бронь вручну ---------- */

  // Перевіряємо ще до натискання: людина одразу бачить, чи вільно.
  const check = useMemo(() => {
    if (!form.room) return { ok: false, text: "Оберіть номер" };
    if (!form.from || !form.to || form.to <= form.from) return { ok: false, text: "Виїзд має бути пізніше за заїзд" };
    const units = unitsOf(form.room);
    const clash = new Map<number, Booking>();
    for (let d = form.from; d < form.to; d = addDays(d, 1)) {
      if (taken(form.room, d) + 1 > units) (occ.get(form.room + "|" + d) ?? []).forEach((b) => clash.set(b.id, b));
    }
    if (clash.size) {
      const who = [...clash.values()]
        .map((b) => `${b.ref} (${dayUA(b.date_in)} — ${dayUA(b.date_out)})`)
        .join(", ");
      return { ok: false, text: `Ці дати вже зайняті: ${who}` };
    }
    return { ok: true, text: `${nightsUA(nightsBetween(form.from, form.to))} · номер вільний` };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [form.room, form.from, form.to, occ, unitsOf]);

  const addByPhone = async () => {
    if (!canEdit || busy || !check.ok) return;
    if (!form.name.trim() && !form.phone.trim()) {
      setNotice({ kind: "err", text: "Впишіть хоча б імʼя або телефон гостя" });
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
        room_key: form.room,
        room_name: nameOf(form.room),
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
    setList((old) => [data as Booking, ...old]);
    setAdding(false);
    setNotice({
      kind: "ok",
      text: `Бронь ${ref} записано: ${nameOf(form.room)}, ${dayUA(form.from)} — ${dayUA(form.to)}. На сайті ці дати вже зайняті.`,
    });
  };

  /* ---------- скасувати / повернути ---------- */

  const setStatus = async (b: Booking, status: "confirmed" | "cancelled") => {
    if (!canEdit || busy) return;
    if (
      status === "cancelled" &&
      !window.confirm(
        `Скасувати бронь ${b.ref}?\n\n${b.room_name}, ${dayUA(b.date_in)} — ${dayUA(b.date_out)}\n` +
          `${String(b.guest?.name ?? "")} ${String(b.guest?.phone ?? "")}\n\nЦі дати одразу звільняться на сайті.`,
      )
    ) {
      return;
    }
    setBusy(true);
    const { error } = await supabase
      .from("bookings")
      .update({ status, updated_at: new Date().toISOString() })
      .eq("id", b.id);
    setBusy(false);
    if (error) {
      setNotice({ kind: "err", text: humanError(error.message) });
      return;
    }
    setList((old) => old.map((x) => (x.id === b.id ? { ...x, status } : x)));
    setNotice({
      kind: "ok",
      text: status === "cancelled" ? `Бронь ${b.ref} скасовано — дати знову вільні` : `Бронь ${b.ref} повернуто`,
    });
  };

  /* ---------- список ---------- */

  const counts = useMemo(
    () => ({
      active: list.filter((b) => b.status !== "cancelled").length,
      cancelled: list.filter((b) => b.status === "cancelled").length,
      all: list.length,
    }),
    [list],
  );

  // Активні — від найближчого заїзду; минулі йдуть у кінець
  const shown = useMemo(() => {
    const base =
      filter === "all" ? list : filter === "cancelled" ? list.filter((b) => b.status === "cancelled") : list.filter((b) => b.status !== "cancelled");
    if (filter !== "active") return base;
    const upcoming = base.filter((b) => b.date_out >= today).sort((a, b) => a.date_in.localeCompare(b.date_in));
    const past = base.filter((b) => b.date_out < today);
    return [...upcoming, ...past];
  }, [list, filter, today]);

  /* ---------- вигляд ---------- */

  const tab = (k: Filter, label: string) => (
    <button key={k} className={`btn btn--sm ${filter === k ? "btn--primary" : "btn--ghost"}`} onClick={() => setFilter(k)}>
      {label} · {counts[k]}
    </button>
  );

  return (
    <>
      <div className="card">
        <div className="shax__head">
          <h2>Зайнятість номерів</h2>
          <div className="row__actions">
            <button className="btn btn--ghost btn--sm" onClick={refresh} disabled={loading}>
              {loading ? "Оновлюю…" : "Оновити"}
            </button>
            {canEdit && (
              <button className="btn btn--primary btn--sm" onClick={() => openAdd()}>
                + Записати бронь
              </button>
            )}
          </div>
        </div>
        <p className="note">
          Рядок — номер, клітинка — ніч. Бронь із сайту зʼявляється тут сама й одразу підтверджена.
          Клік по вільній клітинці — записати бронь на цю дату; по зайнятій — відкрити, чия вона.
        </p>

        {conflicts.length > 0 && (
          <div className="banner banner--warn" style={{ marginTop: 12 }}>
            {conflicts.map((c) => (
              <div key={c.room + c.from}>
                У «{c.room}» броні перетинаються {dayUA(c.from)} — {dayUA(c.to)}: {c.refs.join(", ")}. Скасуйте
                зайву — нові перетини база вже не пускає.
              </div>
            ))}
          </div>
        )}

        <div className="shax__nav">
          <button className="btn btn--ghost btn--sm btn--icon" onClick={() => stepMonth(-1)} aria-label="Попередній місяць">
            ‹
          </button>
          <b>
            {MONTHS[month.m]} {month.y}
          </b>
          <button className="btn btn--ghost btn--sm btn--icon" onClick={() => stepMonth(1)} aria-label="Наступний місяць">
            ›
          </button>
          <button
            className="btn btn--ghost btn--sm"
            onClick={() => {
              const d = new Date();
              setMonth({ y: d.getFullYear(), m: d.getMonth() });
            }}
          >
            Сьогодні
          </button>
        </div>

        {!rooms.length && !loading ? (
          <p className="note">Номерів ще немає — додайте їх у вкладці «Номери й ціни».</p>
        ) : (
          <div className="shax__scroll">
            <table className="shax">
              <thead>
                <tr>
                  <th />
                  {days.map((d) => {
                    const wd = parse(d).getDay();
                    return (
                      <th key={d} className={(wd === 0 || wd === 6 ? "is-we " : "") + (d === today ? "is-today" : "")}>
                        {parse(d).getDate()}
                        <small>{WD[wd]}</small>
                      </th>
                    );
                  })}
                </tr>
              </thead>
              <tbody>
                {rooms.map((r) => {
                  const key = keyOf(r);
                  const units = unitsOf(key);
                  return (
                    <tr key={r.id}>
                      <th>
                        {r.title}
                        {units > 1 && <small> · {units} шт.</small>}
                      </th>
                      {days.map((d) => {
                        const here = occ.get(key + "|" + d) ?? [];
                        const n = taken(key, d);
                        const state = n === 0 ? "free" : n > units ? "over" : n >= units ? "full" : "part";
                        const startsHere = here.some((b) => b.date_in === d);
                        const endsHere = here.some((b) => addDays(b.date_out, -1) === d);
                        const tip = here.length
                          ? here
                              .map((b) => `${b.ref} · ${String(b.guest?.name ?? "без імені")} · ${dayUA(b.date_in)} — ${dayUA(b.date_out)}`)
                              .join("\n")
                          : d < today
                            ? "минуло"
                            : canEdit
                              ? "вільно — натисніть, щоб записати бронь"
                              : "вільно";
                        return (
                          <td
                            key={d}
                            className={
                              `is-${state}` +
                              (d < today ? " is-past" : "") +
                              (startsHere ? " is-start" : "") +
                              (endsHere ? " is-end" : "") +
                              (d === today ? " is-today" : "")
                            }
                            title={tip}
                            onClick={() => clickCell(key, d)}
                          >
                            {units > 1 && n > 0 ? n : ""}
                          </td>
                        );
                      })}
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}

        <div className="shax__legend">
          <span><i className="is-free" /> вільно</span>
          <span><i className="is-part" /> частково</span>
          <span><i className="is-full" /> зайнято</span>
          <span><i className="is-over" /> перетин</span>
        </div>
      </div>

      {/* ---------- запис броні вручну ---------- */}
      {adding && canEdit && (
        <div className="card" ref={formRef}>
          <h2>Нова бронь</h2>
          <p className="note" style={{ marginBottom: 14 }}>
            Для гостей, які домовились телефоном або прийшли самі. Щойно запишете, ці дати стануть зайнятими на сайті,
            і ніхто інший їх не забронює.
          </p>

          <div className="field">
            <label htmlFor="bk-room">Номер</label>
            <select id="bk-room" value={form.room} onChange={(e) => setForm({ ...form, room: e.target.value })}>
              {rooms.map((r) => (
                <option key={r.id} value={keyOf(r)}>
                  {r.title}
                </option>
              ))}
            </select>
          </div>

          <div className="grid2">
            <div className="field">
              <label htmlFor="bk-from">Заїзд</label>
              <input
                id="bk-from"
                type="date"
                value={form.from}
                onChange={(e) => {
                  const from = e.target.value;
                  setForm((f) => ({ ...f, from, to: f.to <= from ? addDays(from, 1) : f.to }));
                }}
              />
            </div>
            <div className="field">
              <label htmlFor="bk-to">Виїзд</label>
              <input id="bk-to" type="date" value={form.to} min={addDays(form.from, 1)} onChange={(e) => setForm({ ...form, to: e.target.value })} />
            </div>
          </div>

          <div className={`status status--${check.ok ? "ok" : "err"}`}>{check.text}</div>

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

          <div className="row__actions">
            <button className="btn btn--primary" onClick={addByPhone} disabled={busy || !check.ok}>
              Записати бронь
            </button>
            <button className="btn btn--ghost" onClick={() => setAdding(false)}>
              Скасувати
            </button>
          </div>
        </div>
      )}

      {/* ---------- список ---------- */}
      <div className="card">
        <h2>Броні</h2>
        {notice && <div className={`status status--${notice.kind}`}>{notice.text}</div>}

        <div className="row__actions" style={{ marginBottom: 12 }}>
          {tab("active", "Активні")}
          {tab("cancelled", "Скасовані")}
          {tab("all", "Усі")}
        </div>

        {loading ? (
          <p className="note">Завантажую…</p>
        ) : !shown.length ? (
          <p className="note">{filter === "cancelled" ? "Скасованих немає." : "Броней поки немає."}</p>
        ) : (
          shown.map((b) => {
            const open = openId === b.id;
            const g = b.guest ?? {};
            const s = b.extras?.sauna;
            const past = b.date_out < today;
            return (
              <div key={b.id} id={"bk-" + b.id} style={past && b.status !== "cancelled" ? { opacity: 0.6 } : undefined}>
                <div className="row">
                  <div className="row__txt">
                    <b>
                      {b.room_name} · {dayUA(b.date_in)} — {dayUA(b.date_out)}
                    </b>
                    <span>
                      {b.ref} · {nightsUA(nightsBetween(b.date_in, b.date_out))} · {guestsUA(b)}
                      {g.name ? " · " + String(g.name) : ""}
                      {b.source === "phone" ? " · записано вручну" : " · з сайту"}
                    </span>
                  </div>
                  <div className="row__actions">
                    <span className={"pill " + (b.status === "cancelled" ? "pill--off" : "pill--ok")}>
                      {b.status === "cancelled" ? "Скасована" : past ? "Минула" : "Активна"}
                    </span>
                    <button className="btn btn--ghost btn--sm" onClick={() => setOpenId(open ? null : b.id)}>
                      {open ? "Згорнути" : "Деталі"}
                    </button>
                  </div>
                </div>

                {open && (
                  <div className="szbox">
                    <div className="ordc">
                      <p>
                        <span>Гість:</span> {String(g.name ?? "—")}
                      </p>
                      {g.phone && (
                        <p>
                          <span>Телефон:</span>{" "}
                          <a href={"tel:" + String(g.phone).replace(/[^\d+]/g, "")}>{String(g.phone)}</a>
                        </p>
                      )}
                      {g.via && (
                        <p>
                          <span>Звʼязок:</span> {String(g.via)}
                        </p>
                      )}
                      {g.note && (
                        <p>
                          <span>Побажання:</span> {String(g.note)}
                        </p>
                      )}
                      {s?.day && (
                        <p>
                          <span>Сауна:</span> {dayUA(String(s.day))}, {String(s.time ?? "")}, {String(s.hours ?? 2)} год
                        </p>
                      )}
                      {Number(b.total) > 0 && (
                        <p>
                          <span>Попередньо:</span> {money(Number(b.total))}
                        </p>
                      )}
                      <p>
                        <span>Отримано:</span> {fmtWhen(b.created_at)}
                      </p>
                    </div>

                    {canEdit && (
                      <div className="row__actions" style={{ marginTop: 10 }}>
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
          })
        )}
      </div>
    </>
  );
}
