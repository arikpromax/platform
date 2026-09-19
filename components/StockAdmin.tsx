"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  getSupabase,
  type MoveKind,
  type Site,
  type StockMove,
  type StockRow,
} from "@/lib/supabase";

/* ===========================================================
   СКЛАД
   Вкладка для власника: скільки чого лишилось по кожному розміру,
   ручні надходження й списання, історія всіх змін.
   Залишки не редагуються напряму — усе йде через функції бази,
   тому кожна зміна одразу лягає в історію.
   =========================================================== */

type Prod = { id: number; title: string; extra: Record<string, unknown> };
type Notice = { kind: "ok" | "err"; text: string } | null;
type Filter = "all" | "low" | "out" | "ok";

const KIND: Record<MoveKind, string> = {
  in: "Надходження",
  sale: "Продаж",
  return: "Повернення",
  writeoff: "Списання",
  fix: "Виправлення",
};

const ERR: Record<string, string> = {
  access: "Немає прав або закінчилась підписка.",
  item: "Товар не знайдено — оновіть сторінку.",
  kind: "Невідомий тип руху.",
};

const norm = (s: string) => String(s ?? "").toLowerCase().replace(/[’ʼ`´']/g, "'");

/* Порядок розмірів як на сайті. Абетка тут не годиться: вона ставить
   L перед M, а 5 перед 44. */
const WEAR = ["XS", "S", "S-M", "M", "L", "L-XL", "XL", "XXL", "XXXL"];
const szRank = (s: string): [number, number] => {
  const u = s.trim().toUpperCase();
  const w = WEAR.indexOf(u);
  if (w >= 0) return [0, w];
  const n = parseFloat(u.replace(",", "."));
  if (!Number.isNaN(n)) return [1, n];
  return [2, 0];
};
const szCmp = (a: string, b: string) => {
  const x = szRank(a);
  const y = szRank(b);
  return x[0] - y[0] || x[1] - y[1] || a.localeCompare(b, "uk", { numeric: true });
};
const fmtWhen = (iso: string) => {
  const d = new Date(iso);
  const p = (n: number) => String(n).padStart(2, "0");
  return `${p(d.getDate())}.${p(d.getMonth() + 1)} ${p(d.getHours())}:${p(d.getMinutes())}`;
};

export default function StockAdmin({ site, canEdit }: { site: Site; canEdit: boolean }) {
  const supabase = getSupabase()!;
  const colKey = site.config?.stockCollection ?? "products";

  const [prods, setProds] = useState<Prod[]>([]);
  const [rows, setRows] = useState<StockRow[]>([]);
  const [moves, setMoves] = useState<StockMove[]>([]);
  const [loading, setLoading] = useState(true); // перший показ завжди з «завантажую»
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<Notice>(null);
  const [q, setQ] = useState("");
  const [filter, setFilter] = useState<Filter>("all");
  const [openId, setOpenId] = useState<number | null>(null);
  const [shown, setShown] = useState(25);
  const [draft, setDraft] = useState<Record<string, string>>({}); // «поставити рівно» по кожному розміру
  const [newSz, setNewSz] = useState<Record<number, string>>({}); // поле «новий розмір» по товару

  /* ---------- Завантаження ----------
     Позицій складу буває більше за тисячу, а база віддає максимум
     1000 рядків за раз, тому беремо сторінками. */
  const fetchPaged = useCallback(
    async (table: string) => {
      const out: Record<string, unknown>[] = [];
      for (let from = 0; ; from += 1000) {
        const { data, error } = await supabase
          .from(table)
          .select("*")
          .eq("site_id", site.id)
          .range(from, from + 999);
        if (error) throw new Error(error.message);
        const part = data ?? [];
        out.push(...part);
        if (part.length < 1000) break;
      }
      return out;
    },
    [supabase, site.id],
  );

  const fetchMoves = useCallback(async () => {
    const { data } = await supabase
      .from("stock_moves")
      .select("*")
      .eq("site_id", site.id)
      .order("at", { ascending: false })
      .limit(80);
    return (data ?? []) as StockMove[];
  }, [supabase, site.id]);

  const fetchAll = useCallback(async () => {
    // нові товари самі отримують рядки складу під свої розміри
    if (canEdit) await supabase.rpc("stock_sync", { p_site: site.id });
    const [items, stock, moves] = await Promise.all([
      supabase
        .from("items")
        .select("id,title,extra")
        .eq("site_id", site.id)
        .eq("collection", colKey)
        .order("sort_order"),
      fetchPaged("stock"),
      fetchMoves(),
    ]);
    if (items.error) throw new Error(items.error.message);
    return {
      prods: (items.data ?? []) as Prod[],
      rows: stock as unknown as StockRow[],
      moves,
    };
  }, [supabase, site.id, colKey, canEdit, fetchPaged, fetchMoves]);

  const apply = (d: { prods: Prod[]; rows: StockRow[]; moves: StockMove[] }) => {
    setProds(d.prods);
    setRows(d.rows);
    setMoves(d.moves);
    setLoading(false);
  };
  const failed = (e: unknown) => {
    setNotice({ kind: "err", text: "Не вдалося завантажити склад: " + (e as Error).message });
    setLoading(false);
  };

  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const d = await fetchAll();
        if (alive) apply(d);
      } catch (e) {
        if (alive) failed(e);
      }
    })();
    return () => {
      alive = false; // перемкнули вкладку — стару відповідь уже не застосовуємо
    };
  }, [fetchAll]);

  const refresh = async () => {
    setLoading(true);
    try {
      apply(await fetchAll());
    } catch (e) {
      failed(e);
    }
  };

  /* ---------- Розкладка по товарах ---------- */

  const byItem = useMemo(() => {
    const m = new Map<number, StockRow[]>();
    rows.forEach((r) => {
      const list = m.get(r.item_id) ?? [];
      list.push(r);
      m.set(r.item_id, list);
    });
    m.forEach((list) => list.sort((a, b) => szCmp(a.size, b.size)));
    return m;
  }, [rows]);

  const free = (r: StockRow) => Math.max(0, r.qty - r.reserved);

  // Стан товару: немає — коли вільного нуль у всіх розмірах;
  // закінчується — коли хоч один розмір дійшов до свого порогу.
  const stateOf = useCallback(
    (id: number): Filter => {
      const list = byItem.get(id) ?? [];
      if (!list.length) return "out";
      const total = list.reduce((s, r) => s + free(r), 0);
      if (total === 0) return "out";
      if (list.some((r) => free(r) > 0 && free(r) <= r.low_at)) return "low";
      return "ok";
    },
    [byItem],
  );

  const counts = useMemo(() => {
    const c = { all: prods.length, low: 0, out: 0, ok: 0 };
    prods.forEach((p) => {
      c[stateOf(p.id) as "low" | "out" | "ok"] += 1;
    });
    return c;
  }, [prods, stateOf]);

  const list = useMemo(() => {
    const needle = norm(q.trim());
    return prods.filter((p) => {
      if (filter !== "all" && stateOf(p.id) !== filter) return false;
      if (!needle) return true;
      const sku = String(p.extra?.["sku"] ?? "");
      const brand = String(p.extra?.["brand"] ?? "");
      return norm(p.title + " " + brand + " " + sku).includes(needle);
    });
  }, [prods, q, filter, stateOf]);

  /* ---------- Дії ---------- */

  const after = async (itemId: number) => {
    const { data } = await supabase.from("stock").select("*").eq("item_id", itemId);
    const fresh = (data ?? []) as StockRow[];
    setRows((all) => all.filter((r) => r.item_id !== itemId).concat(fresh));
    setMoves(await fetchMoves());
  };

  const adjust = async (
    itemId: number,
    size: string,
    delta: number,
    kind: "in" | "writeoff" | "fix",
    note: string,
  ) => {
    if (!canEdit || !delta) return;
    setBusy(true);
    setNotice(null);
    const { data, error } = await supabase.rpc("stock_adjust", {
      p_item: itemId,
      p_size: size,
      p_color: "",
      p_delta: delta,
      p_kind: kind,
      p_note: note,
    });
    const res = (data ?? {}) as { ok?: boolean; error?: string; left?: number };
    if (error) setNotice({ kind: "err", text: "Не вдалося: " + error.message });
    else if (!res.ok)
      setNotice({
        kind: "err",
        text:
          res.error === "negative"
            ? `На складі лише ${res.left ?? 0} — більше списати не вийде.`
            : (ERR[res.error ?? ""] ?? "Не вдалося змінити залишок."),
      });
    else {
      await after(itemId);
      setNotice({ kind: "ok", text: "Залишок оновлено ✔" });
    }
    setBusy(false);
  };

  /* Розмір заводиться й прибирається разом із карткою товару: у базі за це
     відповідають функції, бо треба і рядок складу, і список розмірів,
     який читає сайт. */
  const call = async (fn: string, args: Record<string, unknown>, itemId: number, okText: string) => {
    setBusy(true);
    setNotice(null);
    const { data, error } = await supabase.rpc(fn, args);
    const res = (data ?? {}) as { ok?: boolean; error?: string; left?: number };
    if (error)
      setNotice({
        kind: "err",
        text: /function|schema cache/i.test(error.message)
          ? "Спершу виконайте migration-stock-sizes.sql у базі."
          : "Не вдалося: " + error.message,
      });
    else if (!res.ok)
      setNotice({
        kind: "err",
        text:
          res.error === "reserved"
            ? `Цей розмір зараз відкладений під чийсь кошик (${res.left ?? 0}). Спробуйте за 15 хвилин.`
            : res.error === "size"
              ? "Вкажіть розмір."
              : (ERR[res.error ?? ""] ?? "Не вдалося."),
      });
    else {
      await after(itemId);
      setNotice({ kind: "ok", text: okText });
    }
    setBusy(false);
  };

  const addSize = async (p: Prod) => {
    const size = (newSz[p.id] ?? "").trim();
    if (!canEdit || !size) return;
    await call("stock_add_size", { p_item: p.id, p_size: size }, p.id, `Розмір ${size} додано ✔`);
    setNewSz((v) => ({ ...v, [p.id]: "" }));
  };

  const dropSize = async (p: Prod, r: StockRow) => {
    if (!canEdit) return;
    const warn =
      r.qty > 0
        ? `Прибрати розмір ${r.size}? На складі ще ${r.qty} — вони підуть у списання.`
        : `Прибрати розмір ${r.size}?`;
    if (!window.confirm(warn)) return;
    await call("stock_drop_size", { p_item: p.id, p_size: r.size }, p.id, `Розмір ${r.size} прибрано ✔`);
  };

  // «Поставити рівно N»: рахуємо різницю самі, у історію йде «виправлення»
  const setExact = async (r: StockRow, value: string) => {
    const n = Math.max(0, Math.round(Number(value.replace(",", "."))));
    if (!Number.isFinite(n) || n === r.qty) return;
    await adjust(r.item_id, r.size, n - r.qty, "fix", "перерахунок");
  };

  const prodTitle = (id: number) => prods.find((p) => p.id === id)?.title ?? "товар " + id;

  /* ---------- Малювання ---------- */

  const sizeRow = (p: Prod, r: StockRow) => {
    const key = r.item_id + "|" + r.size;
    const f = free(r);
    const state = f === 0 ? "out" : f <= r.low_at ? "low" : "ok";
    return (
      <div className="szr" key={r.id}>
        <b className="szr__sz">{r.size || "—"}</b>
        <span className={"pill" + (state === "ok" ? " pill--ok" : state === "out" ? " pill--off" : " pill--warn")}>
          {state === "out" ? "немає" : state === "low" ? "закінчується" : "є в наявності"}
        </span>
        <span className="szr__q">
          {r.qty} шт
          {r.reserved > 0 && <i title="відкладено під кошики покупців"> · {r.reserved} відкладено</i>}
        </span>
        <span className="szr__act">
          <button
            className="btn btn--ghost btn--sm btn--icon"
            title="Списати одну"
            disabled={busy || !canEdit || r.qty === 0}
            onClick={() => adjust(p.id, r.size, -1, "writeoff", "вручну")}
          >
            −
          </button>
          <button
            className="btn btn--ghost btn--sm btn--icon"
            title="Надходження однієї"
            disabled={busy || !canEdit}
            onClick={() => adjust(p.id, r.size, 1, "in", "вручну")}
          >
            +
          </button>
          <input
            className="szr__n"
            inputMode="numeric"
            placeholder="рівно"
            value={draft[key] ?? ""}
            disabled={busy || !canEdit}
            onChange={(e) => setDraft((d) => ({ ...d, [key]: e.target.value }))}
            onKeyDown={(e) => {
              if (e.key !== "Enter") return;
              setExact(r, draft[key] ?? "");
              setDraft((d) => ({ ...d, [key]: "" }));
            }}
            onBlur={() => {
              if (!(draft[key] ?? "").trim()) return;
              setExact(r, draft[key] ?? "");
              setDraft((d) => ({ ...d, [key]: "" }));
            }}
          />
          <button
            className="btn btn--ghost btn--sm btn--icon"
            title="Прибрати цей розмір"
            disabled={busy || !canEdit}
            onClick={() => dropSize(p, r)}
          >
            ×
          </button>
        </span>
      </div>
    );
  };

  const prodRow = (p: Prod) => {
    const list = byItem.get(p.id) ?? [];
    const total = list.reduce((s, r) => s + r.qty, 0);
    const held = list.reduce((s, r) => s + r.reserved, 0);
    const state = stateOf(p.id);
    const open = openId === p.id;
    const sku = String(p.extra?.["sku"] ?? "");
    const brand = String(p.extra?.["brand"] ?? "");
    return (
      <div key={p.id}>
        <div className="row">
          <div className="row__txt">
            <b>{p.title}</b>
            <span>
              {[brand, sku].filter(Boolean).join(" · ") || "без артикула"}
              {" · "}
              {list.length} {list.length === 1 ? "розмір" : "розмірів"}
            </span>
          </div>
          <div className="row__actions">
            <span className={"pill" + (state === "ok" ? " pill--ok" : state === "out" ? " pill--off" : " pill--warn")}>
              {state === "out" ? "немає" : state === "low" ? "закінчується" : total + " шт"}
            </span>
            {held > 0 && <span className="note">{held} відкладено</span>}
            <button className="btn btn--ghost btn--sm" onClick={() => setOpenId(open ? null : p.id)}>
              {open ? "Згорнути" : "Залишки"}
            </button>
          </div>
        </div>
        {open && (
          <div className="szbox">
            {list.length === 0 && (
              <p className="note">
                У товару не вказані розміри — додайте їх у картці товару, і вони зʼявляться тут.
              </p>
            )}
            {list.map((r) => sizeRow(p, r))}
            <div className="szr szr--add">
              <input
                className="szr__n szr__n--wide"
                placeholder="новий розмір"
                value={newSz[p.id] ?? ""}
                disabled={busy || !canEdit}
                onChange={(e) => setNewSz((v) => ({ ...v, [p.id]: e.target.value }))}
                onKeyDown={(e) => {
                  if (e.key === "Enter") addSize(p);
                }}
              />
              <button
                className="btn btn--ghost btn--sm"
                disabled={busy || !canEdit || !(newSz[p.id] ?? "").trim()}
                onClick={() => addSize(p)}
              >
                Додати розмір
              </button>
            </div>
            <p className="note">
              «−» списує одну одиницю, «+» приймає одну. У поле «рівно» впишіть, скільки
              насправді лежить на складі, — різниця піде в історію як виправлення.
              Новий розмір одразу зʼявляється і в картці товару, а «×» прибирає його
              звідусіль.
            </p>
          </div>
        )}
      </div>
    );
  };

  return (
    <>
      <div className="card">
        <h2>Склад</h2>
        <p className="note">
          Залишки рахуються окремо по кожному розміру. Сайт списує товар сам, щойно покупець
          оформив замовлення, і повертає назад, якщо ви скасували замовлення у вкладці
          «Замовлення».
        </p>
        <p className="note">
          <b>Новий товар спершу створюють у «Каталог і розпродаж»</b> — там назва, ціна, фото
          й розміри. Щойно в картці вказані розміри, вони самі зʼявляться тут із нулем, і
          лишиться проставити кількість. Доки вона нульова, товар показується на сайті як
          «Немає» — тож не забувайте про цей другий крок.
        </p>

        <div className="search">
          <input
            placeholder="Назва, бренд або артикул"
            value={q}
            onChange={(e) => {
              setQ(e.target.value);
              setShown(25);
            }}
          />
          {q && (
            <button className="search__x" aria-label="Очистити пошук" onClick={() => setQ("")}>
              ×
            </button>
          )}
        </div>

        <div className="groups__row">
          {([
            ["all", "Усі", counts.all],
            ["low", "Закінчується", counts.low],
            ["out", "Немає", counts.out],
            ["ok", "Є в наявності", counts.ok],
          ] as [Filter, string, number][]).map(([k, label, n]) => (
            <button
              key={k}
              className={"chip" + (filter === k ? " chip--on" : "")}
              onClick={() => {
                setFilter(k);
                setShown(25);
              }}
            >
              {label} <i>{n}</i>
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
        {loading && <p className="note">Завантажую склад…</p>}
        {!loading && list.length === 0 && <p className="note">Нічого не знайшлося.</p>}

        {list.slice(0, shown).map(prodRow)}

        {list.length > shown && (
          <button className="btn btn--ghost btn--sm" onClick={() => setShown((s) => s + 25)}>
            Показати ще ({list.length - shown})
          </button>
        )}
      </div>

      <div className="card">
        <h2>Історія змін</h2>
        <p className="note">
          Останні 80 змін: продажі з сайту, повернення, ваші надходження й списання.
        </p>
        {moves.length === 0 && <p className="note">Поки порожньо.</p>}
        {moves.map((m) => (
          <div className="row" key={m.id}>
            <div className="row__txt">
              <b>
                {prodTitle(m.item_id)}
                {m.size ? " · " + m.size : ""}
              </b>
              <span>
                {fmtWhen(m.at)} · {KIND[m.kind]}
                {m.note ? " · " + m.note : ""}
                {m.order_ref ? " · замовлення " + m.order_ref : ""}
                {m.who ? " · " + m.who : ""}
              </span>
            </div>
            <div className="row__actions">
              <b className={m.delta > 0 ? "delta delta--up" : "delta delta--dn"}>
                {m.delta > 0 ? "+" : ""}
                {m.delta}
              </b>
              <span className="note">стало {m.qty_after}</span>
            </div>
          </div>
        ))}
      </div>
    </>
  );
}
