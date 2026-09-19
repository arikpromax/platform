"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { getSupabase, type Order, type OrderStatus, type Site } from "@/lib/supabase";

/* ===========================================================
   ЗАМОВЛЕННЯ
   Список того, що прийшло з сайту. Товар списується зі складу ще
   при оформленні, тому тут важливі дві дії: скасувати (повертає
   товар на склад) і прийняти повернення (теж повертає).
   =========================================================== */

type Notice = { kind: "ok" | "err"; text: string } | null;
type Filter = "all" | OrderStatus;

const STATUS: Record<OrderStatus, string> = {
  new: "Нове",
  done: "Виконане",
  cancelled: "Скасоване",
  returned: "Повернення",
};

// Підписи полів покупця — сайт кладе їх у customer як є
const FIELD: Record<string, string> = {
  name: "Імʼя",
  phone: "Телефон",
  city: "Місто",
  branch: "Відділення",
  pay: "Оплата",
  delivery: "Доставка",
  comment: "Коментар",
};

const fmtWhen = (iso: string) => {
  const d = new Date(iso);
  const p = (n: number) => String(n).padStart(2, "0");
  return `${p(d.getDate())}.${p(d.getMonth() + 1)}.${d.getFullYear()} ${p(d.getHours())}:${p(d.getMinutes())}`;
};

const money = (n: number) => Math.round(n).toLocaleString("uk-UA") + " грн";

export default function OrdersAdmin({ site, canEdit }: { site: Site; canEdit: boolean }) {
  const supabase = getSupabase()!;
  const [orders, setOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<Notice>(null);
  const [filter, setFilter] = useState<Filter>("all");
  const [openId, setOpenId] = useState<number | null>(null);

  const fetchOrders = useCallback(async () => {
    const { data, error } = await supabase
      .from("orders")
      .select("*")
      .eq("site_id", site.id)
      .order("created_at", { ascending: false })
      .limit(300);
    if (error) throw new Error(error.message);
    return (data ?? []) as Order[];
  }, [supabase, site.id]);

  const apply = (list: Order[]) => {
    setOrders(list);
    setLoading(false);
  };
  const failed = (e: unknown) => {
    setNotice({ kind: "err", text: "Не вдалося завантажити: " + (e as Error).message });
    setLoading(false);
  };

  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const list = await fetchOrders();
        if (alive) apply(list);
      } catch (e) {
        if (alive) failed(e);
      }
    })();
    return () => {
      alive = false; // пішли з вкладки — стару відповідь не застосовуємо
    };
  }, [fetchOrders]);

  const refresh = async () => {
    setLoading(true);
    try {
      apply(await fetchOrders());
    } catch (e) {
      failed(e);
    }
  };

  const counts = useMemo(() => {
    const c: Record<string, number> = { all: orders.length, new: 0, done: 0, cancelled: 0, returned: 0 };
    orders.forEach((o) => {
      c[o.status] += 1;
    });
    return c;
  }, [orders]);

  const list = useMemo(
    () => (filter === "all" ? orders : orders.filter((o) => o.status === filter)),
    [orders, filter],
  );

  const setStatus = async (o: Order, status: OrderStatus) => {
    if (!canEdit) return;
    const back = status === "cancelled" || status === "returned";
    if (
      back &&
      !window.confirm(
        status === "cancelled"
          ? `Скасувати замовлення ${o.ref}? Товар повернеться на склад.`
          : `Прийняти повернення по замовленню ${o.ref}? Товар повернеться на склад.`,
      )
    )
      return;
    setBusy(true);
    setNotice(null);
    const { data, error } = await supabase.rpc("set_order_status", {
      p_order: o.id,
      p_status: status,
    });
    const res = (data ?? {}) as { ok?: boolean; error?: string };
    if (error) setNotice({ kind: "err", text: "Не вдалося: " + error.message });
    else if (!res.ok)
      setNotice({
        kind: "err",
        text: res.error === "access" ? "Немає прав або закінчилась підписка." : "Не вдалося змінити статус.",
      });
    else {
      setNotice({
        kind: "ok",
        text: back ? "Готово ✔ Товар повернувся на склад." : "Статус змінено ✔",
      });
      try {
        apply(await fetchOrders());
      } catch (e) {
        failed(e);
      }
    }
    setBusy(false);
  };

  const orderRow = (o: Order) => {
    const open = openId === o.id;
    const c = o.customer ?? {};
    const who = [String(c["name"] ?? ""), String(c["phone"] ?? "")].filter(Boolean).join(" · ");
    return (
      <div key={o.id}>
        <div className="row">
          <div className="row__txt">
            <b>
              № {o.ref} · {money(Number(o.total))}
            </b>
            <span>
              {fmtWhen(o.created_at)}
              {who ? " · " + who : ""} · {o.lines.length}{" "}
              {o.lines.length === 1 ? "позиція" : "позицій"}
            </span>
          </div>
          <div className="row__actions">
            <span
              className={
                "pill" +
                (o.status === "new" ? "" : o.status === "done" ? " pill--ok" : " pill--off")
              }
            >
              {STATUS[o.status]}
            </span>
            <button className="btn btn--ghost btn--sm" onClick={() => setOpenId(open ? null : o.id)}>
              {open ? "Згорнути" : "Відкрити"}
            </button>
          </div>
        </div>

        {open && (
          <div className="szbox">
            {o.lines.map((l, i) => (
              <div className="szr" key={i}>
                <b className="szr__sz">{l.size || "—"}</b>
                <span className="szr__q">
                  {l.title ?? "товар " + l.item_id} · {l.qty} шт
                  {l.price ? " · " + money(Number(l.price) * l.qty) : ""}
                </span>
              </div>
            ))}

            <div className="ordc">
              {Object.entries(c)
                .filter(([, v]) => v !== null && v !== "" && typeof v !== "object")
                .map(([k, v]) => (
                  <p key={k}>
                    <span>{FIELD[k] ?? k}:</span> {String(v)}
                  </p>
                ))}
            </div>

            <div className="row__actions">
              {o.status !== "done" && o.status !== "returned" && (
                <button
                  className="btn btn--primary btn--sm"
                  disabled={busy || !canEdit}
                  onClick={() => setStatus(o, "done")}
                >
                  Виконане
                </button>
              )}
              {o.status === "new" && (
                <button
                  className="btn btn--danger btn--sm"
                  disabled={busy || !canEdit}
                  onClick={() => setStatus(o, "cancelled")}
                >
                  Скасувати
                </button>
              )}
              {o.status === "done" && (
                <button
                  className="btn btn--danger btn--sm"
                  disabled={busy || !canEdit}
                  onClick={() => setStatus(o, "returned")}
                >
                  Повернення
                </button>
              )}
              {(o.status === "cancelled" || o.status === "returned") && (
                <button
                  className="btn btn--ghost btn--sm"
                  disabled={busy || !canEdit}
                  onClick={() => setStatus(o, "new")}
                >
                  Поновити
                </button>
              )}
            </div>
            <p className="note">
              Скасування й повернення самі кладуть товар назад на склад, поновлення — знову
              знімає.
            </p>
          </div>
        )}
      </div>
    );
  };

  return (
    <div className="card">
      <h2>Замовлення</h2>
      <p className="note">
        Замовлення з сайту. Товар списується зі складу вже при оформленні, тому скасовувати
        потрібно саме тут — тоді він повернеться в продаж.
      </p>

      <div className="groups__row">
        {([
          ["all", "Усі"],
          ["new", "Нові"],
          ["done", "Виконані"],
          ["cancelled", "Скасовані"],
          ["returned", "Повернення"],
        ] as [Filter, string][]).map(([k, label]) => (
          <button
            key={k}
            className={"chip" + (filter === k ? " chip--on" : "")}
            onClick={() => setFilter(k)}
          >
            {label} <i>{counts[k]}</i>
          </button>
        ))}
        <button
          className="btn btn--ghost btn--sm"
          disabled={loading || busy}
          onClick={refresh}
        >
          Оновити
        </button>
      </div>

      {notice && <div className={`status status--${notice.kind}`}>{notice.text}</div>}
      {loading && <p className="note">Завантажую…</p>}
      {!loading && list.length === 0 && <p className="note">Поки замовлень немає.</p>}
      {list.map(orderRow)}
    </div>
  );
}
