"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { getSupabase, type Booking, type Item, type Site } from "@/lib/supabase";

/* ===========================================================
   БРОНЮВАННЯ НОМЕРІВ

   Сюди падають заявки з сайту. Щойно бронь зʼявилась, дата в
   календарі на сайті стає зайнятою — але лише коли розібрали
   всі номери цього типу (скільки їх, вписано у вкладці «Номери»).

   Скасували бронь тут або кнопкою в Telegram — дата одразу
   звільняється.

   Телефонні броні власник заводить тут же кнопкою «Записати
   бронь»: інакше сайт про них не знає й може продати ту саму ніч.
   =========================================================== */

type Notice = { kind: "ok" | "err"; text: string } | null;
type Filter = "all" | "new" | "confirmed" | "cancelled";

const STATUS: Record<string, string> = {
  new: "Нова",
  confirmed: "Підтверджена",
  cancelled: "Скасована",
};

const WD = ["нд", "пн", "вт", "ср", "чт", "пт", "сб"];

const dayUA = (iso: string) => {
  const p = String(iso ?? "").split("-");
  if (p.length !== 3) return String(iso ?? "");
  const d = new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2]));
  return `${p[2]}.${p[1]}, ${WD[d.getDay()]}`;
};

const nightsOf = (b: Booking) => {
  const a = Date.parse(b.date_in);
  const z = Date.parse(b.date_out);
  return a && z ? Math.max(1, Math.round((z - a) / 86400000)) : 1;
};

const nightsUA = (n: number) => {
  const a = n % 10;
  const b = n % 100;
  const w = b >= 11 && b <= 14 ? "ночей" : a === 1 ? "ніч" : a >= 2 && a <= 4 ? "ночі" : "ночей";
  return `${n} ${w}`;
};

const guestsUA = (b: Booking) => {
  const a = Number(b.adults) || 0;
  const k = Number(b.children) || 0;
  const aw = a % 10 === 1 && a % 100 !== 11 ? "дорослий" : "дорослих";
  return a + " " + aw + (k ? `, ${k} діт.` : "");
};

const money = (n: number) => Math.round(n).toLocaleString("uk-UA") + " грн";

const fmtWhen = (iso: string) => {
  const d = new Date(iso);
  const p = (n: number) => String(n).padStart(2, "0");
  return `${p(d.getDate())}.${p(d.getMonth() + 1)}.${d.getFullYear()} ${p(d.getHours())}:${p(d.getMinutes())}`;
};

const todayISO = () => new Date().toISOString().slice(0, 10);

export default function BookingsAdmin({ site, canEdit }: { site: Site; canEdit: boolean }) {
  const supabase = getSupabase()!;
  const [list, setList] = useState<Booking[]>([]);
  const [rooms, setRooms] = useState<Item[]>([]);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<Notice>(null);
  const [filter, setFilter] = useState<Filter>("all");
  const [openId, setOpenId] = useState<number | null>(null);
  const [adding, setAdding] = useState(false);

  // нова бронь із телефона
  const [form, setForm] = useState({
    room: "",
    from: todayISO(),
    to: todayISO(),
    adults: "2",
    children: "0",
    name: "",
    phone: "",
    note: "",
  });

  const fetchAll = useCallback(async () => {
    const [b, r] = await Promise.all([
      supabase
        .from("bookings")
        .select("*")
        .eq("site_id", site.id)
        .order("created_at", { ascending: false })
        .limit(300),
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

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const got = await fetchAll();
      setList(got.list);
      setRooms(got.rooms);
      setForm((f) => (f.room ? f : { ...f, room: String(got.rooms[0]?.extra?.key ?? "") }));
    } catch (e) {
      setNotice({ kind: "err", text: "Не вдалося завантажити: " + (e as Error).message });
    }
    setLoading(false);
  }, [fetchAll]);

  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const got = await fetchAll();
        if (!alive) return;
        setList(got.list);
        setRooms(got.rooms);
        setForm((f) => (f.room ? f : { ...f, room: String(got.rooms[0]?.extra?.key ?? "") }));
      } catch (e) {
        if (alive) setNotice({ kind: "err", text: "Не вдалося завантажити: " + (e as Error).message });
      }
      if (alive) setLoading(false);
    })();
    return () => {
      alive = false; // пішли з вкладки — стару відповідь не застосовуємо
    };
  }, [fetchAll]);

  const counts = useMemo(() => {
    const c: Record<string, number> = { all: list.length, new: 0, confirmed: 0, cancelled: 0 };
    list.forEach((b) => {
      if (c[b.status] !== undefined) c[b.status] += 1;
    });
    return c;
  }, [list]);

  const shown = useMemo(
    () => (filter === "all" ? list : list.filter((b) => b.status === filter)),
    [list, filter],
  );

  /* ---------- дії ---------- */

  const setStatus = async (b: Booking, status: string) => {
    if (!canEdit || busy) return;
    if (
      status === "cancelled" &&
      !window.confirm(
        `Скасувати бронь ${b.ref}?\n\n${b.room_name}, ${dayUA(b.date_in)} — ${dayUA(b.date_out)}.\n` +
          "Ці дати одразу звільняться на сайті.",
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
      setNotice({ kind: "err", text: "Не вдалося змінити: " + error.message });
      return;
    }
    setList((old) => old.map((x) => (x.id === b.id ? { ...x, status } : x)));
    setNotice({
      kind: "ok",
      text: status === "cancelled" ? `Бронь ${b.ref} скасовано — дати вільні` : `Бронь ${b.ref} підтверджено`,
    });
  };

  const addByPhone = async () => {
    if (!canEdit || busy) return;
    if (!form.room) {
      setNotice({ kind: "err", text: "Спершу заведіть номери у вкладці «Номери й ціни»" });
      return;
    }
    if (form.to <= form.from) {
      setNotice({ kind: "err", text: "Виїзд має бути пізніше за заїзд" });
      return;
    }
    if (!form.name.trim() && !form.phone.trim()) {
      setNotice({ kind: "err", text: "Впишіть хоча б імʼя або телефон гостя" });
      return;
    }
    const room = rooms.find((r) => String(r.extra?.key ?? "") === form.room);
    setBusy(true);
    const ref =
      "F-" +
      String(new Date().getDate()).padStart(2, "0") +
      String(new Date().getMonth() + 1).padStart(2, "0") +
      "-" +
      String(100 + Math.floor(Math.random() * 900));
    const { data, error } = await supabase
      .from("bookings")
      .insert({
        site_id: site.id,
        ref,
        room_key: form.room,
        room_name: room?.title ?? form.room,
        rooms_count: 1,
        date_in: form.from,
        date_out: form.to,
        adults: Number(form.adults) || 1,
        children: Number(form.children) || 0,
        guest: { name: form.name.trim(), phone: form.phone.trim(), note: form.note.trim() },
        extras: {},
        total: 0,
        status: "confirmed",
        source: "phone",
        tg_sent_at: new Date().toISOString(), // заводив власник — у Telegram не дублюємо
      })
      .select()
      .single();
    setBusy(false);
    if (error) {
      setNotice({ kind: "err", text: "Не вдалося записати: " + error.message });
      return;
    }
    setList((old) => [data as Booking, ...old]);
    setAdding(false);
    setForm((f) => ({ ...f, name: "", phone: "", note: "" }));
    setNotice({ kind: "ok", text: `Бронь ${ref} записано — дати зайнято на сайті` });
  };

  /* ---------- вигляд ---------- */

  const tab = (k: Filter, label: string) => (
    <button
      key={k}
      className={`btn btn--ghost btn--sm${filter === k ? " on" : ""}`}
      onClick={() => setFilter(k)}
    >
      {label} ({counts[k] ?? 0})
    </button>
  );

  return (
    <section className="pane">
      <div className="pane__head">
        <div>
          <h3>Бронювання</h3>
          <p className="hint">
            Заявки з сайту. Дата стає зайнятою в календарі, коли розібрали всі номери цього типу —
            скільки їх, вписано у вкладці «Номери й ціни». Скасували тут або кнопкою в Telegram —
            дата звільняється одразу.
          </p>
        </div>
        <div className="row__actions">
          <button className="btn btn--ghost btn--sm" onClick={load} disabled={loading}>
            Оновити
          </button>
          {canEdit && (
            <button className="btn btn--sm" onClick={() => setAdding((v) => !v)}>
              {adding ? "Згорнути" : "Записати бронь"}
            </button>
          )}
        </div>
      </div>

      {notice && (
        <p className={notice.kind === "ok" ? "ok" : "err"} onClick={() => setNotice(null)}>
          {notice.text}
        </p>
      )}

      {adding && canEdit && (
        <div className="szbox">
          <p className="hint">
            Для броней, про які домовились телефоном. Запишіть їх тут — інакше сайт про них
            не знає і може віддати ту саму ніч комусь іншому.
          </p>
          <div className="grid2">
            <label>
              Номер
              <select
                value={form.room}
                onChange={(e) => setForm({ ...form, room: e.target.value })}
              >
                {rooms.map((r) => (
                  <option key={r.id} value={String(r.extra?.key ?? "")}>
                    {r.title}
                  </option>
                ))}
              </select>
            </label>
            <label>
              Гостей (дорослих)
              <input
                type="number"
                min={1}
                value={form.adults}
                onChange={(e) => setForm({ ...form, adults: e.target.value })}
              />
            </label>
            <label>
              Заїзд
              <input
                type="date"
                value={form.from}
                onChange={(e) => setForm({ ...form, from: e.target.value })}
              />
            </label>
            <label>
              Виїзд
              <input
                type="date"
                value={form.to}
                onChange={(e) => setForm({ ...form, to: e.target.value })}
              />
            </label>
            <label>
              Імʼя гостя
              <input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
            </label>
            <label>
              Телефон
              <input value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} />
            </label>
          </div>
          <label>
            Примітка
            <input
              value={form.note}
              onChange={(e) => setForm({ ...form, note: e.target.value })}
              placeholder="напр. приїдуть пізно ввечері"
            />
          </label>
          <div className="row__actions">
            <button className="btn btn--sm" onClick={addByPhone} disabled={busy}>
              Записати
            </button>
          </div>
        </div>
      )}

      <div className="row__actions">
        {tab("all", "Усі")}
        {tab("new", "Нові")}
        {tab("confirmed", "Підтверджені")}
        {tab("cancelled", "Скасовані")}
      </div>

      {loading ? (
        <p className="hint">Завантажую…</p>
      ) : !shown.length ? (
        <p className="hint">Поки порожньо.</p>
      ) : (
        shown.map((b) => {
          const open = openId === b.id;
          const g = b.guest ?? {};
          const s = b.extras?.sauna;
          return (
            <div className="row" key={b.id}>
              <div className="row__main">
                <b>{b.ref}</b>{" "}
                <span>
                  {b.room_name}
                  {b.rooms_count > 1 ? ` ×${b.rooms_count}` : ""} · {dayUA(b.date_in)} —{" "}
                  {dayUA(b.date_out)} · {nightsUA(nightsOf(b))} · {guestsUA(b)}
                  {b.source === "phone" ? " · телефоном" : ""}
                </span>
              </div>
              <div className="row__actions">
                <span
                  className={
                    "pill" +
                    (b.status === "new" ? "" : b.status === "confirmed" ? " pill--ok" : " pill--off")
                  }
                >
                  {STATUS[b.status] ?? b.status}
                </span>
                <button className="btn btn--ghost btn--sm" onClick={() => setOpenId(open ? null : b.id)}>
                  {open ? "Згорнути" : "Відкрити"}
                </button>
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
                        <span>Сауна:</span> {dayUA(String(s.day))}, {String(s.time ?? "")},{" "}
                        {String(s.hours ?? 2)} год
                      </p>
                    )}
                    {Number(b.total) > 0 && (
                      <p>
                        <span>Попередньо:</span> {money(Number(b.total))}
                      </p>
                    )}
                    <p>
                      <span>Заявка:</span> {fmtWhen(b.created_at)}
                    </p>
                  </div>

                  {canEdit && (
                    <div className="row__actions">
                      {b.status === "new" && (
                        <button
                          className="btn btn--ghost btn--sm"
                          onClick={() => setStatus(b, "confirmed")}
                          disabled={busy}
                        >
                          Підтвердити
                        </button>
                      )}
                      {b.status !== "cancelled" && (
                        <button
                          className="btn btn--ghost btn--sm"
                          onClick={() => setStatus(b, "cancelled")}
                          disabled={busy}
                        >
                          Скасувати бронь
                        </button>
                      )}
                      {b.status === "cancelled" && (
                        <button
                          className="btn btn--ghost btn--sm"
                          onClick={() => setStatus(b, "confirmed")}
                          disabled={busy}
                        >
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
    </section>
  );
}
