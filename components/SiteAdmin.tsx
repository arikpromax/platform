"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import {
  getSupabase,
  todayISO,
  fmtDate,
  type Item,
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
 * Редактор одного сайту: вкладки й форми будуються з site.config.
 * Якщо підписка сайту прострочена — власник бачить усе, але редагувати не може
 * (а база ще й сама відхилить запис завдяки RLS).
 */
export default function SiteAdmin({ site, isAdmin, onBack, onSignOut }: Props) {
  const supabase = getSupabase()!;

  const allCollections = site.config?.collections ?? [];
  // Вкладки з позначкою adminOnly бачить лише власник платформи
  const collections = allCollections.filter((c) => isAdmin || !c.adminOnly);
  const textDefs = site.config?.texts ?? [];
  const paidActive = site.paid_until >= todayISO();
  const canEdit = isAdmin || paidActive;

  const [tab, setTab] = useState<string>(collections[0]?.key ?? "__texts");
  const [items, setItems] = useState<Item[]>([]);
  const [texts, setTexts] = useState<Record<string, string>>({});
  const [editing, setEditing] = useState<Item | null>(null);
  const [selOptions, setSelOptions] = useState<Record<string, Option[]>>({});
  const [busy, setBusy] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [notice, setNotice] = useState<Notice>(null);
  const formRef = useRef<HTMLDivElement>(null);

  const activeCol = collections.find((c) => c.key === tab) ?? null;

  // Коли відкрили форму редагування — плавно прокрутити до неї
  useEffect(() => {
    if (editing && formRef.current) {
      formRef.current.scrollIntoView({ behavior: "smooth", block: "start" });
    }
  }, [editing]);

  /* ---------- Завантаження ---------- */

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

  useEffect(() => {
    setEditing(null);
    setNotice(null);
    if (tab === "__texts") {
      (async () => {
        const { data } = await supabase.from("texts").select("*").eq("site_id", site.id);
        const map: Record<string, string> = {};
        ((data ?? []) as { key: string; value: string }[]).forEach((t) => {
          map[t.key] = t.value;
        });
        setTexts(map);
      })();
    } else {
      loadItems();
    }
  }, [tab, site.id, supabase, loadItems]);

  /* ---------- Дії з картками ---------- */

  const startEdit = async (item: Item) => {
    setNotice(null);
    // підвантажуємо варіанти для полів-довідників (наприклад, список категорій)
    const opts: Record<string, Option[]> = {};
    for (const f of activeCol?.fields ?? []) {
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
    setEditing(item);
  };

  const emptyItem = (): Item => ({
    site_id: site.id,
    collection: activeCol?.key ?? "",
    title: "",
    text: "",
    price: "",
    image_url: "",
    extra: {},
    sort_order: 0,
  });

  const save = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editing) return;
    if (!editing.title.trim()) {
      setNotice({ kind: "err", text: "Вкажіть назву." });
      return;
    }
    setBusy(true);
    const row = { ...editing };
    if (!row.id) {
      delete row.id;
      row.sort_order = items.length ? Math.max(...items.map((i) => i.sort_order)) + 1 : 1;
    }
    const { error } = await supabase.from("items").upsert(row);
    if (error) setNotice({ kind: "err", text: "Не вдалося зберегти: " + error.message });
    else {
      setNotice({ kind: "ok", text: "Збережено ✔ На сайті з'явиться протягом хвилини." });
      setEditing(null);
      await loadItems();
    }
    setBusy(false);
  };

  const remove = async (item: Item) => {
    if (!item.id) return;
    if (!window.confirm(`Видалити «${item.title}»?`)) return;
    setBusy(true);
    const { error } = await supabase.from("items").delete().eq("id", item.id);
    if (error) setNotice({ kind: "err", text: "Не вдалося видалити: " + error.message });
    else await loadItems();
    setBusy(false);
  };

  const move = async (index: number, dir: -1 | 1) => {
    const a = items[index];
    const b = items[index + dir];
    if (!a || !b || !a.id || !b.id) return;
    setBusy(true);
    await supabase.from("items").update({ sort_order: b.sort_order }).eq("id", a.id);
    await supabase.from("items").update({ sort_order: a.sort_order }).eq("id", b.id);
    await loadItems();
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

  const saveTexts = async () => {
    setBusy(true);
    setNotice(null);
    const rows = textDefs.map((d) => ({
      site_id: site.id,
      key: d.key,
      value: texts[d.key] ?? "",
    }));
    const { error } = await supabase.from("texts").upsert(rows);
    if (error) setNotice({ kind: "err", text: "Не вдалося зберегти: " + error.message });
    else setNotice({ kind: "ok", text: "Тексти збережено ✔" });
    setBusy(false);
  };

  /* ---------- Рендер ---------- */

  const rowHint = (item: Item): string => {
    const parts: string[] = [];
    if (item.price) parts.push(item.price + " грн");
    const cat = (item.extra ?? {})["cat"];
    if (cat) parts.push(String(cat));
    if ((item.extra ?? {})["top"]) parts.push("🔥 хіт");
    return parts.join(" · ");
  };

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

      <div className="tabs">
        {collections.map((c) => (
          <button key={c.key} className={`tab${tab === c.key ? " on" : ""}`} onClick={() => setTab(c.key)}>
            {c.name}
          </button>
        ))}
        {textDefs.length > 0 && (
          <button className={`tab${tab === "__texts" ? " on" : ""}`} onClick={() => setTab("__texts")}>
            Тексти
          </button>
        )}
      </div>

      {notice && <div className={`status status--${notice.kind}`}>{notice.text}</div>}

      {tab === "__texts" ? (
        <div className="card">
          <h2>Тексти сайту</h2>
          {textDefs.map((d) => (
            <div className="field" key={d.key}>
              <label htmlFor={`txt-${d.key}`}>{d.name}</label>
              <input
                id={`txt-${d.key}`}
                type="text"
                value={texts[d.key] ?? ""}
                onChange={(e) => setTexts((prev) => ({ ...prev, [d.key]: e.target.value }))}
                disabled={!canEdit}
              />
            </div>
          ))}
          <button className="btn btn--primary btn--sm" disabled={busy || !canEdit} onClick={saveTexts}>
            {busy ? "Зберігаю…" : "Зберегти тексти"}
          </button>
        </div>
      ) : (
        <>
          <div className="card">
            {items.length === 0 && <p className="note">Тут поки порожньо — додайте першу картку.</p>}
            {items.map((item, i) => (
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
                    onClick={() => move(i, -1)}
                  >
                    ↑
                  </button>
                  <button
                    className="btn btn--ghost btn--sm btn--icon"
                    aria-label="Нижче"
                    disabled={busy || !canEdit || i === items.length - 1}
                    onClick={() => move(i, 1)}
                  >
                    ↓
                  </button>
                  <button
                    className="btn btn--ghost btn--sm"
                    disabled={busy || !canEdit}
                    onClick={() => startEdit({ ...item, extra: { ...(item.extra ?? {}) } })}
                  >
                    Редагувати
                  </button>
                </div>
              </div>
            ))}
          </div>

          {!editing && !activeCol?.noAdd && (
            <button className="btn btn--primary" disabled={!canEdit} onClick={() => startEdit(emptyItem())}>
              + Додати
            </button>
          )}

          {editing && activeCol && (
            <div ref={formRef}>
              <ItemForm
                heading={editing.id ? `Редагування: ${editing.title}` : "Нова картка"}
                fields={activeCol.fields}
                value={editing}
                options={selOptions}
                busy={busy}
                uploading={uploading}
                onChange={(patch) => setEditing((prev) => (prev ? { ...prev, ...patch } : prev))}
                onUploadFile={uploadFile}
                onSubmit={save}
                onCancel={() => setEditing(null)}
                onDelete={editing.id && !activeCol?.noDelete ? () => remove(editing) : undefined}
              />
            </div>
          )}
        </>
      )}
    </div>
  );
}
