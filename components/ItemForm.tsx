"use client";

import { useState } from "react";
import type { FieldDef, Item } from "@/lib/supabase";
import ImageCropper from "@/components/ImageCropper";

export type Option = { value: string; label: string };

type Props = {
  heading: string;
  fields: FieldDef[];
  value: Item;
  options: Record<string, Option[]>; // варіанти для полів-довідників (select-collection)
  busy: boolean;
  uploading: boolean;
  onChange: (patch: Partial<Item>) => void;
  onUploadFile: (file: File) => void;
  onSubmit: (e: React.FormEvent) => void;
  onCancel: () => void;
  onDelete?: () => void; // тільки для наявних карток
};

/**
 * Форма-конструктор: малює поля картки за описом із конфіга сайту.
 * Типи полів: text, textarea, checkbox, image, select-collection.
 */
export default function ItemForm({
  heading,
  fields,
  value,
  options,
  busy,
  uploading,
  onChange,
  onUploadFile,
  onSubmit,
  onCancel,
  onDelete,
}: Props) {
  const get = (f: FieldDef): string => {
    if (f.type === "image") return value.image_url;
    if (f.extra) {
      const v = value.extra[f.key];
      return v == null ? "" : String(v);
    }
    if (f.key === "title") return value.title;
    if (f.key === "text") return value.text;
    if (f.key === "price") return value.price;
    return "";
  };

  const getBool = (f: FieldDef): boolean => Boolean(f.extra ? value.extra[f.key] : false);

  // Файл, який зараз кадруємо (нове фото), або URL наявного для перекадрування
  const [cropFile, setCropFile] = useState<File | null>(null);
  const [editSrc, setEditSrc] = useState<string | null>(null);

  const set = (f: FieldDef, v: string | boolean) => {
    if (f.type === "image") {
      onChange({ image_url: String(v) });
      return;
    }
    if (f.extra) {
      onChange({ extra: { ...value.extra, [f.key]: v } });
      return;
    }
    if (f.key === "title") onChange({ title: String(v) });
    else if (f.key === "text") onChange({ text: String(v) });
    else if (f.key === "price") onChange({ price: String(v) });
  };

  return (
    <div className="card">
      <h2>{heading}</h2>
      <form onSubmit={onSubmit}>
        {fields.map((f) => {
          const id = `fld-${f.key}`;

          if (f.type === "checkbox")
            return (
              <div className="field" key={f.key}>
                <label className="check-row" htmlFor={id}>
                  <input
                    id={id}
                    type="checkbox"
                    checked={getBool(f)}
                    onChange={(e) => set(f, e.target.checked)}
                  />
                  {f.name}
                </label>
              </div>
            );

          if (f.type === "textarea")
            return (
              <div className="field" key={f.key}>
                <label htmlFor={id}>{f.name}</label>
                <textarea id={id} rows={2} value={get(f)} onChange={(e) => set(f, e.target.value)} />
              </div>
            );

          if (f.type === "select")
            return (
              <div className="field" key={f.key}>
                <label htmlFor={id}>{f.name}</label>
                <select id={id} value={get(f)} onChange={(e) => set(f, e.target.value)}>
                  {(f.options ?? []).map((o) => (
                    <option key={o.value} value={o.value}>
                      {o.label}
                    </option>
                  ))}
                </select>
              </div>
            );

          if (f.type === "select-collection")
            return (
              <div className="field" key={f.key}>
                <label htmlFor={id}>{f.name}</label>
                <select id={id} value={get(f)} onChange={(e) => set(f, e.target.value)}>
                  <option value="">— оберіть —</option>
                  {(options[f.key] ?? []).map((o) => (
                    <option key={o.value} value={o.value}>
                      {o.label}
                    </option>
                  ))}
                </select>
              </div>
            );

          if (f.type === "image") {
            const url = get(f);
            return (
              <div className="field" key={f.key}>
                <label htmlFor={id}>
                  {f.name} <span className="opt">(необов&apos;язково)</span>
                </label>
                {url && url.startsWith("http") ? (
                  <div className="photo-row">
                    {/* Клік по фото — відкрити кадрування наявного фото */}
                    <button
                      type="button"
                      className="photo-thumb"
                      title="Натисніть, щоб відкадрувати"
                      onClick={() => setEditSrc(url)}
                    >
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      <img src={url} alt="" />
                      <span className="photo-thumb__hint">✎ Кадрувати</span>
                    </button>
                    <label className="btn btn--ghost btn--sm" style={{ cursor: "pointer" }}>
                      Замінити фото
                      <input
                        type="file"
                        accept="image/*"
                        hidden
                        disabled={uploading}
                        onChange={(e) => {
                          const file = e.target.files?.[0];
                          if (file) setCropFile(file);
                          e.target.value = "";
                        }}
                      />
                    </label>
                    <button
                      type="button"
                      className="btn btn--ghost btn--sm"
                      onClick={() => set(f, "")}
                    >
                      Прибрати фото
                    </button>
                  </div>
                ) : (
                  <input
                    id={id}
                    type="file"
                    accept="image/*"
                    disabled={uploading}
                    onChange={(e) => {
                      const file = e.target.files?.[0];
                      if (file) setCropFile(file);
                      e.target.value = "";
                    }}
                  />
                )}
                {uploading && <p className="note">Завантажую фото…</p>}

                {(cropFile || editSrc) && (
                  <ImageCropper
                    file={cropFile ?? undefined}
                    src={editSrc ?? undefined}
                    onCancel={() => {
                      setCropFile(null);
                      setEditSrc(null);
                    }}
                    onDone={(blob) => {
                      setCropFile(null);
                      setEditSrc(null);
                      onUploadFile(new File([blob], "photo.jpg", { type: "image/jpeg" }));
                    }}
                  />
                )}
              </div>
            );
          }

          // звичайне текстове поле
          return (
            <div className="field" key={f.key}>
              <label htmlFor={id}>{f.name}</label>
              <input id={id} type="text" value={get(f)} onChange={(e) => set(f, e.target.value)} />
            </div>
          );
        })}

        <div style={{ display: "flex", gap: 8, marginTop: 4 }}>
          <button type="submit" className="btn btn--primary btn--sm" disabled={busy || uploading}>
            {busy ? "Зберігаю…" : "Зберегти"}
          </button>
          <button type="button" className="btn btn--ghost btn--sm" disabled={busy} onClick={onCancel}>
            Скасувати
          </button>
        </div>

        {onDelete && (
          // Видалення — окремо внизу, подалі від «Зберегти», щоб не натиснути випадково
          <div className="form-danger">
            <button type="button" className="btn btn--danger btn--sm" disabled={busy} onClick={onDelete}>
              Видалити цю картку
            </button>
          </div>
        )}
      </form>
    </div>
  );
}
