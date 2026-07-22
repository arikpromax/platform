"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import {
  getSupabase,
  todayISO,
  fmtDate,
  type CollectionDef,
  type Item,
  type SectionDef,
  type Site,
} from "@/lib/supabase";
import ItemForm, { type Option } from "@/components/ItemForm";

type Notice = { kind: "ok" | "err"; text: string } | null;

type Props = {
  site: Site;
  isAdmin: boolean;
  onBack?: () => void; // для власника платформи: назад до списку сайтів
  onSignOut: () => void;
};

/**
 * Редактор одного сайту.
 * Два режими:
 *  • «Розділи як на сайті» — якщо в config.sections описано блоки сайту:
 *    кожна вкладка = один розділ сайту (по порядку), всередині — його тексти,
 *    його списки та його фото. Власник бачить адмінку так само, як бачить сайт.
 *  • Класичний — вкладка на кожну колекцію + «Тексти» (для сайтів без sections).
 * Якщо підписка сайту прострочена — власник бачить усе, але редагувати не може
 * (а база ще й сама відхилить запис завдяки RLS).
 */
export default function SiteAdmin({ site, isAdmin, onBack, onSignOut }: Props) {
  const supabase = getSupabase()!;

  const allCollections = site.config?.collections ?? [];
  // Вкладки з позначкою adminOnly бачить лише власник платформи
  const collections = allCollections.filter((c) => isAdmin || !c.adminOnly);
  const textDefs = site.config?.texts ?? [];
  const sections: SectionDef[] = site.config?.sections ?? [];
  const useSections = sections.length > 0;
  const paidActive = site.paid_until >= todayISO();
  const canEdit = isAdmin || paidActive;

  const colByKey = (key: string): CollectionDef | undefined =>
    collections.find((c) => c.key === key);
  const textDefByKey = (key: string) => textDefs.find((d) => d.key === key);

  /* ---------- Стан ---------- */

  const [tab, setTab] = useState<string>(collections[0]?.key ?? "__texts"); // класичний режим
  const [secIdx, setSecIdx] = useState(0); // режим розділів
  const [items, setItems] = useState<Item[]>([]); // класичний режим: активна колекція
  const [itemsByCol, setItemsByCol] = useState<Record<string, Item[]>>({}); // режим розділів
  const [texts, setTexts] = useState<Record<string, string>>({});
  const [editing, setEditing] = useState<Item | null>(null);
  const [editingCol, setEditingCol] = useState<CollectionDef | null>(null);
  const [selOptions, setSelOptions] = useState<Record<string, Option[]>>({});
  const [busy, setBusy] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [notice, setNotice] = useState<Notice>(null);
  const formRef = useRef<HTMLDivElement>(null);

  const activeCol = colByKey(tab) ?? null; // класичний режим
  const activeSec: SectionDef | null = useSections ? (sections[secIdx] ?? null) : null;

  // Коли відкрили форму редагування — плавно прокрутити до неї
  useEffect(() => {
    if (editing && formRef.current) {
      formRef.current.scrollIntoView({ behavior: "smooth", block: "start" });
    }
  }, [editing]);

  /* ---------- Завантаження ---------- */

  const loadTexts = useCallback(async () => {
    const { data } = await supabase.from("texts").select("*").eq("site_id", site.id);
    const map: Record<string, string> = {};
    ((data ?? []) as { key: string; value: string }[]).forEach((t) => {
      map[t.key] = t.value;
    });
    setTexts(map);
  }, [supabase, site.id]);

  // Класичний режим: одна активна колекція
  const loadItems = useCallback(async () => {
    if (!activeCol) return;
    const { data, error } = await supabase
      .from("items")
      .select("*")
      .eq("site_id", site.id)
      .eq("collection", activeCol.key)
      .order("sort_order");
    if (error) setNotice({ kind: "err", text: "Не вдалося завантажити: " + error.message });
    else setItems((data ?? []) as Item[]);
  }, [supabase, site.id, activeCol]);

  // Режим розділів: всі колекції активного розділу (+ фото сайту, якщо є)
  const loadSection = useCallback(async () => {
    if (!activeSec) return;
    const keys = [...(activeSec.collections ?? [])];
    if ((activeSec.photos ?? []).length > 0 && !keys.includes("site_photos")) {
      keys.push("site_photos");
    }
    const map: Record<string, Item[]> = {};
    for (const key of keys) {
      const { data, error } = await supabase
        .from("items")
        .select("*")
        .eq("site_id", site.id)
        .eq("collection", key)
        .order("sort_order");
      if (error) {
        setNotice({ kind: "err", text: "Не вдалося завантажити: " + error.message });
        return;
      }
      map[key] = (data ?? []) as Item[];
    }
    setItemsByCol(map);
  }, [supabase, site.id, activeSec]);

  useEffect(() => {
    setEditing(null);
    setEditingCol(null);
    setNotice(null);
    if (useSections) {
      loadSection();
      loadTexts();
    } else if (tab === "__texts") {
      loadTexts();
    } else {
      loadItems();
    }
  }, [tab, secIdx, useSections, site.id, loadItems, loadSection, loadTexts]);

  const reload = useSections ? loadSection : loadItems;

  /* ---------- Дії з картками ---------- */

  const startEdit = async (col: CollectionDef, item: Item) => {
    setNotice(null);
    // підвантажуємо варіанти для полів-довідників (наприклад, список категорій)
    const opts: Record<string, Option[]> = {};
    for (const f of col.fields) {
      if (f.type === "select-collection" && f.from) {
        const { data } = await supabase
          .from("items")
          .select("*")
          .eq("site_id", site.id)
          .eq("collection", f.from)
          .order("sort_order");
        opts[f.key] = ((data ?? []) as Item[]).map((o) => ({
          value: String((o.extra ?? {})["catkey"] ?? o.id),
          label: o.title,
        }));
      }
    }
    setSelOptions(opts);
    setEditingCol(col);
    setEditing(item);
  };

  const emptyItem = (col: CollectionDef): Item => ({
    site_id: site.id,
    collection: col.key,
    title: "",
    text: "",
    price: "",
    image_url: "",
    extra: {},
    sort_order: 0,
  });

  const listFor = (colKey: string): Item[] =>
    useSections ? (itemsByCol[colKey] ?? []) : items;

  const save = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editing || !editingCol) return;
    if (!editing.title.trim()) {
      setNotice({ kind: "err", text: "Вкажіть назву." });
      return;
    }
    setBusy(true);
    const row = { ...editing };
    if (!row.id) {
      delete row.id;
      const list = listFor(editingCol.key);
      row.sort_order = list.length ? Math.max(...list.map((i) => i.sort_order)) + 1 : 1;
    }
    const { error } = await supabase.from("items").upsert(row);
    if (error) setNotice({ kind: "err", text: "Не вдалося зберегти: " + error.message });
    else {
      setNotice({ kind: "ok", text: "Збережено ✔ На сайті з'явиться протягом хвилини." });
      setEditing(null);
      setEditingCol(null);
      await reload();
    }
    setBusy(false);
  };

  const remove = async (item: Item) => {
    if (!item.id) return;
    if (!window.confirm(`Видалити «${item.title}»?`)) return;
    setBusy(true);
    const { error } = await supabase.from("items").delete().eq("id", item.id);
    if (error) setNotice({ kind: "err", text: "Не вдалося видалити: " + error.message });
    else {
      setEditing(null);
      setEditingCol(null);
      await reload();
    }
    setBusy(false);
  };

  // Поміняти місцями сусідні картки списку (list — вже відфільтрований список UI)
  const move = async (list: Item[], index: number, dir: -1 | 1) => {
    const a = list[index];
    const b = list[index + dir];
    if (!a || !b || !a.id || !b.id) return;
    setBusy(true);
    await supabase.from("items").update({ sort_order: b.sort_order }).eq("id", a.id);
    await supabase.from("items").update({ sort_order: a.sort_order }).eq("id", b.id);
    await reload();
    setBusy(false);
  };

  const uploadFile = async (file: File) => {
    setUploading(true);
    setNotice(null);
    const ext = file.name.split(".").pop()?.toLowerCase() || "jpg";
    const path = `${site.slug}/${Date.now()}.${ext}`;
    const { error } = await supabase.storage.from("site-images").upload(path, file);
    if (error) {
      setNotice({ kind: "err", text: "Не вдалося завантажити фото: " + error.message });
    } else {
      const { data } = supabase.storage.from("site-images").getPublicUrl(path);
      setEditing((prev) => (prev ? { ...prev, image_url: data.publicUrl } : prev));
    }
    setUploading(false);
  };

  /* ---------- Тексти ---------- */

  // keys — які саме ключі зберігати (розділ зберігає лише свої тексти)
  const saveTexts = async (keys?: string[]) => {
    setBusy(true);
    setNotice(null);
    const list = keys ?? textDefs.map((d) => d.key);
    const rows = list
      .filter((k) => textDefByKey(k))
      .map((k) => ({ site_id: site.id, key: k, value: texts[k] ?? "" }));
    const { error } = await supabase.from("texts").upsert(rows);
    if (error) setNotice({ kind: "err", text: "Не вдалося зберегти: " + error.message });
    else setNotice({ kind: "ok", text: "Тексти збережено ✔ На сайті з'являться протягом хвилини." });
    setBusy(false);
  };

  /* ---------- Рендер-помічники ---------- */

  const rowHint = (item: Item): string => {
    const parts: string[] = [];
    if (item.price) parts.push(item.price + " грн");
    const cat = (item.extra ?? {})["cat"];
    if (cat) parts.push(String(cat));
    if ((item.extra ?? {})["top"]) parts.push("🔥 хіт");
    return parts.join(" · ");
  };

  const renderTextField = (key: string) => {
    const d = textDefByKey(key);
    if (!d) return null;
    return (
      <div className="field" key={d.key}>
        <label htmlFor={`txt-${d.key}`}>{d.name}</label>
        {d.multiline ? (
          <textarea
            id={`txt-${d.key}`}
            rows={3}
            value={texts[d.key] ?? ""}
            onChange={(e) => setTexts((prev) => ({ ...prev, [d.key]: e.target.value }))}
            disabled={!canEdit}
          />
        ) : (
          <input
            id={`txt-${d.key}`}
            type="text"
            value={texts[d.key] ?? ""}
            onChange={(e) => setTexts((prev) => ({ ...prev, [d.key]: e.target.value }))}
            disabled={!canEdit}
          />
        )}
      </div>
    );
  };

  // Один список карток (використовується в обох режимах)
  const renderRows = (col: CollectionDef, list: Item[]) => (
    <>
      {list.length === 0 && <p className="note">Тут поки порожньо — додайте першу картку.</p>}
      {list.map((item, i) => (
        <div key={item.id} className="row">
          {item.image_url ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img className="row__img" src={item.image_url} alt="" />
          ) : (
            <div className="row__img" />
          )}
          <div className="row__txt">
            <b>{item.title}</b>
            <span>{rowHint(item)}</span>
          </div>
          <div className="row__actions">
            <button
              className="btn btn--ghost btn--sm btn--icon"
              aria-label="Вище"
              disabled={busy || !canEdit || i === 0}
              onClick={() => move(list, i, -1)}
            >
              ↑
            </button>
            <button
              className="btn btn--ghost btn--sm btn--icon"
              aria-label="Нижче"
              disabled={busy || !canEdit || i === list.length - 1}
              onClick={() => move(list, i, 1)}
            >
              ↓
            </button>
            <button
              className="btn btn--ghost btn--sm"
              disabled={busy || !canEdit}
              onClick={() => startEdit(col, { ...item, extra: { ...(item.extra ?? {}) } })}
            >
              Редагувати
            </button>
          </div>
        </div>
      ))}
      {!editing && !col.noAdd && (
        <button
          className="btn btn--primary"
          disabled={!canEdit}
          onClick={() => startEdit(col, emptyItem(col))}
        >
          + Додати
        </button>
      )}
    </>
  );

  /* ---------- Рендер ---------- */

  return (
    <div className="wrap">
      <div className="topbar">
        <div className="brand">
          <span className="brand__mark">a</span>
          {site.name}
          <span className={`pill ${paidActive ? "pill--ok" : "pill--off"}`}>
            {paidActive ? `підписка до ${fmtDate(site.paid_until)}` : "підписка прострочена"}
          </span>
        </div>
        <div className="topbar__actions">
          {onBack && (
            <button className="btn btn--ghost btn--sm" onClick={onBack}>
              ← Сайти
            </button>
          )}
          <button className="btn btn--ghost btn--sm" onClick={onSignOut}>
            Вийти
          </button>
        </div>
      </div>

      {!paidActive && (
        <div className="banner banner--warn">
          {isAdmin
            ? "Підписка цього сайту прострочена. Ви бачите й редагуєте його як власник платформи."
            : "Підписка закінчилась — редагування вимкнено. Щоб продовжити, зв'яжіться зі студією arawebsite."}
        </div>
      )}

      {/* ---------- Вкладки ---------- */}
      <div className="tabs">
        {useSections
          ? sections.map((s, i) => (
              <button
                key={s.name}
                className={`tab${secIdx === i ? " on" : ""}`}
                onClick={() => setSecIdx(i)}
              >
                {i + 1}. {s.name}
              </button>
            ))
          : (
            <>
              {collections.map((c) => (
                <button
                  key={c.key}
                  className={`tab${tab === c.key ? " on" : ""}`}
                  onClick={() => setTab(c.key)}
                >
                  {c.name}
                </button>
              ))}
              {textDefs.length > 0 && (
                <button
                  className={`tab${tab === "__texts" ? " on" : ""}`}
                  onClick={() => setTab("__texts")}
                >
                  Тексти
                </button>
              )}
            </>
          )}
      </div>

      {notice && <div className={`status status--${notice.kind}`}>{notice.text}</div>}

      {/* ---------- Режим «розділи як на сайті» ---------- */}
      {useSections && activeSec && (
        <>
          {(activeSec.texts ?? []).length > 0 && (
            <div className="card">
              <h2>Тексти цього блока</h2>
              {(activeSec.texts ?? []).map(renderTextField)}
              <button
                className="btn btn--primary btn--sm"
                disabled={busy || !canEdit}
                onClick={() => saveTexts(activeSec.texts)}
              >
                {busy ? "Зберігаю…" : "Зберегти тексти"}
              </button>
            </div>
          )}

          {(activeSec.collections ?? []).map((key) => {
            const col = colByKey(key);
            if (!col) return null;
            return (
              <div className="card" key={key}>
                <h2>{col.name}</h2>
                {renderRows(col, itemsByCol[key] ?? [])}
              </div>
            );
          })}

          {(activeSec.photos ?? []).length > 0 && (() => {
            const photosCol = colByKey("site_photos");
            if (!photosCol) return null;
            const slots = activeSec.photos ?? [];
            const list = (itemsByCol["site_photos"] ?? [])
              .filter((it) => slots.includes(String((it.extra ?? {})["slot"] ?? "")))
              .sort(
                (a, b) =>
                  slots.indexOf(String((a.extra ?? {})["slot"])) -
                  slots.indexOf(String((b.extra ?? {})["slot"]))
              );
            return (
              <div className="card">
                <h2>Фото цього блока</h2>
                {list.length === 0 && (
                  <p className="note">Фото-місця цього блока ще не створені в базі.</p>
                )}
                {list.map((item) => (
                  <div key={item.id} className="row">
                    {item.image_url ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img className="row__img" src={item.image_url} alt="" />
                    ) : (
                      <div className="row__img" />
                    )}
                    <div className="row__txt">
                      <b>{item.title}</b>
                      <span>{item.image_url ? "фото завантажено" : "фото ще нема"}</span>
                    </div>
                    <div className="row__actions">
                      <button
                        className="btn btn--ghost btn--sm"
                        disabled={busy || !canEdit}
                        onClick={() =>
                          startEdit(photosCol, { ...item, extra: { ...(item.extra ?? {}) } })
                        }
                      >
                        Редагувати
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            );
          })()}
        </>
      )}

      {/* ---------- Класичний режим ---------- */}
      {!useSections &&
        (tab === "__texts" ? (
          <div className="card">
            <h2>Тексти сайту</h2>
            {textDefs.map((d) => renderTextField(d.key))}
            <button
              className="btn btn--primary btn--sm"
              disabled={busy || !canEdit}
              onClick={() => saveTexts()}
            >
              {busy ? "Зберігаю…" : "Зберегти тексти"}
            </button>
          </div>
        ) : (
          activeCol && <div className="card">{renderRows(activeCol, items)}</div>
        ))}

      {/* ---------- Форма редагування (спільна) ---------- */}
      {editing && editingCol && (
        <div ref={formRef}>
          <ItemForm
            heading={editing.id ? `Редагування: ${editing.title}` : "Нова картка"}
            fields={editingCol.fields}
            value={editing}
            options={selOptions}
            busy={busy}
            uploading={uploading}
            onChange={(patch) => setEditing((prev) => (prev ? { ...prev, ...patch } : prev))}
            onUploadFile={uploadFile}
            onSubmit={save}
            onCancel={() => {
              setEditing(null);
              setEditingCol(null);
            }}
            onDelete={editing.id && !editingCol.noDelete ? () => remove(editing) : undefined}
          />
        </div>
      )}
    </div>
  );
}
