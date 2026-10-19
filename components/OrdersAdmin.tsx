"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { getSupabase, type Order, type OrderStatus, type Site } from "@/lib/supabase";

/* ===========================================================
   ЗАМОВЛЕННЯ
   Список того, що прийшло з сайту. Товар списується зі складу ще
   при оформленні, тому тут важливі дві дії: скасувати (повертає
   товар на склад) і прийняти повернення (теж повертає).
   Коли підключено Нову Пошту, «Відправлено», «Виконане» й «Повернення»
   бот ставить сам за трекінгом — кнопки лишаються на випадок ручних правок.
   =========================================================== */

type Notice = { kind: "ok" | "err"; text: string } | null;
type Filter = "all" | OrderStatus | "unpaid";

const STATUS: Record<OrderStatus, string> = {
  new: "Нове",
  shipped: "Відправлено",
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

// Службові поля для бота й накладної — власнику вони нічого не кажуть
const HIDDEN = new Set(["dlv", "payId", "cityRef", "branchRef", "pay"]);

// Оплата словами: спосіб і, для картки, чи дійшли гроші
const payText = (o: Order) => {
  const c = o.customer ?? {};
  if (c["payId"] === "online") {
    const test = o.pay_info?.test ? " (тестова оплата)" : "";
    if (o.pay_state === "paid") return `Карткою на сайті — оплачено ${money(Number(o.pay_info?.amount ?? o.total))}${test}`;
    if (o.pay_state === "refunded") return "Карткою на сайті — гроші повернено";
    if (o.pay_state === "failed") return "Карткою на сайті — оплата не пройшла";
    return "Карткою на сайті — ще не оплачено";
  }
  if (c["payId"] === "cod") return `Накладений платіж — ${money(Number(o.total))} при отриманні`;
  return String(c["pay"] ?? "");
};

/* Оплата карткою, яку покупець не завершив: перейшов на сторінку банку
   й повернувся чи закрив її. Це ще не замовлення — у Telegram і в склад
   воно не йде, а за 10 хвилин база сама скасує його й поверне товар у
   продаж. Тому з «Новими» й «Скасованими» не змішуємо — окремо. */
const unpaid = (o: Order) =>
  (o.customer ?? {})["payId"] === "online" && (o.pay_state === "wait" || o.pay_state === "failed");

/* Що забере «Очистити історію» — те саме, що видаляє база (orders_clear):
   лише скасовані. Без оплаченого вже після скасування (гроші ще треба
   повернути) і без того, чиє повернення УкрСклад ще не оформив. */
const clearable = (o: Order) =>
  o.status === "cancelled" && o.pay_state !== "paid" && (!o.synced_at || o.sync_status === o.status);

// До котрої години чекаємо оплату (база скасовує через 10 хвилин після оформлення)
const payUntil = (o: Order) => {
  const d = new Date(new Date(o.created_at).getTime() + 10 * 60 * 1000);
  const p = (n: number) => String(n).padStart(2, "0");
  return `${p(d.getHours())}:${p(d.getMinutes())}`;
};

const track = (no: string) => "https://novaposhta.ua/tracking/?cargo_number=" + encodeURIComponent(no);

const fmtWhen = (iso: string) => {
  const d = new Date(iso);
  const p = (n: number) => String(n).padStart(2, "0");
  return `${p(d.getDate())}.${p(d.getMonth() + 1)}.${d.getFullYear()} ${p(d.getHours())}:${p(d.getMinutes())}`;
};

const money = (n: number) => Math.round(n).toLocaleString("uk-UA") + " грн";

type SyncMark = { text: string; cls: string; title: string };

/* Склад веде програма обліку (УкрСклад): біля замовлення видно, чи воно вже
   там. Замовлення до запуску обміну (stockSyncSince) там розібрали вручну —
   їх не позначаємо. */
function syncMark(site: Site, o: Order): SyncMark | null {
  const prog = site.config?.stockSync ?? "";
  const since = site.config?.stockSyncSince ?? "";
  if (!prog || (since && new Date(o.created_at) < new Date(since))) return null;
  if (o.oversold_at) {
    return {
      text: prog + ": не вистачило товару",
      cls: " pill--off",
      title: "Ту саму річ уже продали в магазині. Звʼяжіться з покупцем: інший розмір або повернення грошей.",
    };
  }
  const back = o.status === "cancelled" || o.status === "returned";
  if (!o.synced_at) {
    // не оплачене чи скасоване ще до передачі — у склад воно й не йде
    if (back || o.pay_state === "wait" || o.pay_state === "failed") return null;
    return {
      text: prog + ": чекає",
      cls: " pill--warn",
      title: "Програма в магазині забере замовлення за кілька хвилин, щойно ввімкнений компʼютер з " + prog + ".",
    };
  }
  if (back && o.sync_status !== o.status) {
    return { text: prog + ": повернення чекає", cls: " pill--warn", title: "Програма в магазині оформить повернення за кілька хвилин." };
  }
  return {
    text: prog + " ✓",
    cls: " pill--ok",
    title: (back ? "Повернення в " : "Видаткова в ") + prog + " оформлена " + fmtWhen(o.synced_at),
  };
}

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
    const c: Record<string, number> = { all: 0, new: 0, shipped: 0, done: 0, cancelled: 0, returned: 0, unpaid: 0 };
    orders.forEach((o) => {
      if (unpaid(o)) {
        c.unpaid += 1;
        return;
      }
      c.all += 1;
      c[o.status] += 1;
    });
    return c;
  }, [orders]);

  const list = useMemo(
    () =>
      filter === "unpaid"
        ? orders.filter(unpaid)
        : orders.filter((o) => !unpaid(o) && (filter === "all" || o.status === filter)),
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

  const toClear = orders.filter(clearable).length;

  const clearHistory = async () => {
    if (!canEdit || !toClear) return;
    if (
      !window.confirm(
        `Видалити ${toClear} скасованих замовлень назавжди? ` +
          "Нові, відправлені, виконані й повернення лишаться. Повернути видалене не вийде.",
      )
    )
      return;
    setBusy(true);
    setNotice(null);
    const { data, error } = await supabase.rpc("orders_clear", { p_site: site.id });
    const res = (data ?? {}) as { ok?: boolean; error?: string; deleted?: number };
    if (error)
      setNotice({
        kind: "err",
        text: /orders_clear/.test(error.message)
          ? "Спершу виконайте db/orders-clear.sql у Supabase → SQL Editor."
          : "Не вдалося: " + error.message,
      });
    else if (!res.ok)
      setNotice({
        kind: "err",
        text: res.error === "access" ? "Немає прав або закінчилась підписка." : "Не вдалося очистити.",
      });
    else {
      setNotice({ kind: "ok", text: `Готово ✔ Прибрано замовлень: ${res.deleted ?? 0}.` });
      if (filter === "cancelled" || filter === "unpaid") setFilter("all");
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
    const mark = syncMark(site, o);
    const wait = unpaid(o);
    const pill = wait
      ? o.status === "new"
        ? { text: "Чекає оплати", cls: " pill--warn" }
        : { text: "Не оплатили", cls: " pill--off" }
      : {
          text: STATUS[o.status],
          cls:
            o.status === "new"
              ? ""
              : o.status === "shipped"
                ? " pill--warn"
                : o.status === "done"
                  ? " pill--ok"
                  : " pill--off",
        };
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
              {o.ttn ? " · ТТН " + o.ttn : ""}
            </span>
          </div>
          <div className="row__actions">
            <span className={"pill" + pill.cls}>{pill.text}</span>
            {mark && (
              <span className={"pill" + mark.cls} title={mark.title}>
                {mark.text}
              </span>
            )}
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
              {mark && (
                <p>
                  <span>{site.config?.stockSync}:</span> {mark.title}
                </p>
              )}
              {Object.entries(c)
                .filter(([k, v]) => !HIDDEN.has(k) && v !== null && v !== "" && typeof v !== "object")
                .map(([k, v]) => (
                  <p key={k}>
                    <span>{FIELD[k] ?? k}:</span> {String(v)}
                  </p>
                ))}
              {payText(o) && (
                <p>
                  <span>Оплата:</span> {payText(o)}
                </p>
              )}
              {o.ttn ? (
                <p>
                  <span>ТТН:</span>{" "}
                  <a href={track(o.ttn)} target="_blank" rel="noopener noreferrer">
                    {o.ttn}
                  </a>
                  {o.ttn_cost ? " · доставка " + money(Number(o.ttn_cost)) : ""}
                  {o.np_status ? " · " + o.np_status : ""}
                </p>
              ) : o.ttn_error ? (
                <p>
                  <span>ТТН:</span> не створилась — {o.ttn_error}
                </p>
              ) : null}
              {o.np_return_ttn && (
                <p>
                  <span>Повернення:</span>{" "}
                  <a href={track(o.np_return_ttn)} target="_blank" rel="noopener noreferrer">
                    ТТН {o.np_return_ttn}
                  </a>
                </p>
              )}
            </div>

            {wait ? (
              <>
                <p className="note">
                  {o.status === "new"
                    ? `Покупець перейшов до оплати карткою, але ще не оплатив. Робити нічого не треба: оплатить — замовлення стане «Новим» і прийде в Telegram; ні — о ${payUntil(o)} скасується само, а товар повернеться в продаж.`
                    : "Покупець так і не оплатив — замовлення скасувалося само, товар повернувся в продаж. Робити нічого не треба."}
                </p>
                {o.status === "new" && (
                  <div className="row__actions">
                    <button
                      className="btn btn--danger btn--sm"
                      disabled={busy || !canEdit}
                      onClick={() => setStatus(o, "cancelled")}
                    >
                      Скасувати зараз
                    </button>
                  </div>
                )}
              </>
            ) : (
              <>
                <div className="row__actions">
                  {o.status === "new" && (
                    <button
                      className="btn btn--ghost btn--sm"
                      disabled={busy || !canEdit}
                      onClick={() => setStatus(o, "shipped")}
                    >
                      Відправлено
                    </button>
                  )}
                  {(o.status === "new" || o.status === "shipped") && (
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
                  {(o.status === "shipped" || o.status === "done") && (
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
                  знімає. Гроші за оплату карткою скасування не повертає — це робиться в кабінеті
                  банку, через який приймаєте оплату.
                </p>
              </>
            )}
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
        потрібно саме тут — тоді він повернеться в продаж. Оплата карткою, яку покупець не
        завершив, лежить окремо в «Не оплачені»: таке скасовується саме, чіпати не треба.
        «Очистити історію» прибирає скасовані й неоплачені — продажі лишаються.
      </p>

      <div className="groups__row">
        {([
          ["all", "Усі"],
          ["new", "Нові"],
          ["shipped", "Відправлені"],
          ["done", "Виконані"],
          ["cancelled", "Скасовані"],
          ["returned", "Повернення"],
          ...(counts.unpaid || filter === "unpaid" ? [["unpaid", "Не оплачені"]] : []),
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
        {canEdit && toClear > 0 && (
          <button
            className="btn btn--ghost btn--sm"
            disabled={loading || busy}
            onClick={clearHistory}
            title="Видаляє скасовані й неоплачені замовлення. Справжні продажі лишаються."
          >
            Очистити історію
          </button>
        )}
      </div>

      {notice && <div className={`status status--${notice.kind}`}>{notice.text}</div>}
      {loading && <p className="note">Завантажую…</p>}
      {!loading && list.length === 0 && <p className="note">Поки замовлень немає.</p>}
      {list.map(orderRow)}
    </div>
  );
}
