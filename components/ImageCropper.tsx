"use client";

import { useEffect, useRef, useState } from "react";

/*
  Панель обрізки фото: перетягування + масштаб.
  Користувач ставить страву в квадратну рамку, а на «Готово» ми малюємо
  результат у canvas 800×800 і віддаємо готовий JPEG-файл — сайт показує
  його як є, без жодних додаткових налаштувань позиції.
*/

const OUT = 1600; // розмір готового квадратного фото, px
const VIEW = 300; // розмір рамки на екрані, px

/* Фото з iPhone. Тип файлу буває порожній, тому дивимось і на розширення. */
const isHeic = (f: File) => /hei[cf]/i.test(f.type) || /\.hei[cf]$/i.test(f.name);

/* HEIC браузер не відкриває — розбираємо його самі й віддаємо JPEG.
   libheif свіжої збірки: старіші декодери спотикались на нових знімках
   iPhone (HDR із gain map — brand «tmap»), і завантажувалась лише частина фото. */
async function heicToJpeg(file: File): Promise<Blob> {
  const libheif = (await import("libheif-js/wasm-bundle")).default;
  const images = new libheif.HeifDecoder().decode(new Uint8Array(await file.arrayBuffer()));
  if (!images.length) throw new Error("у файлі немає картинки");

  const image = images[0];
  const w = image.get_width();
  const h = image.get_height();
  const full = document.createElement("canvas");
  full.width = w;
  full.height = h;
  const ctx = full.getContext("2d");
  if (!ctx) throw new Error("немає canvas");

  const data = ctx.createImageData(w, h);
  await new Promise<void>((resolve, reject) => {
    image.display(data, (res) => (res ? resolve() : reject(new Error("libheif не впорався"))));
  });
  ctx.putImageData(data, 0, 0);

  /* Знімок з iPhone — 12 мегапікселів. Тримати таке полотно телефону важко,
     а кадрувалці більше 2400 px усе одно не треба, тож одразу зменшуємо. */
  const MAX = 2400;
  let out = full;
  if (Math.max(w, h) > MAX) {
    const k = MAX / Math.max(w, h);
    out = document.createElement("canvas");
    out.width = Math.round(w * k);
    out.height = Math.round(h * k);
    const octx = out.getContext("2d");
    if (!octx) throw new Error("немає canvas");
    octx.imageSmoothingQuality = "high";
    octx.drawImage(full, 0, 0, out.width, out.height);
    full.width = full.height = 0; // віддаємо памʼять одразу
  }

  let blob = await new Promise<Blob | null>((r) => out.toBlob(r, "image/jpeg", 0.95));
  if (!blob) {
    // на деяких телефонах toBlob віддає порожньо — пробуємо інакше
    const url = out.toDataURL("image/jpeg", 0.95);
    blob = await (await fetch(url)).blob();
  }
  if (!blob || !blob.size) throw new Error("не вийшов JPEG");
  return blob;
}

export default function ImageCropper({
  file,
  src,
  onDone,
  onCancel,
}: {
  file?: File; // нове фото з компʼютера
  src?: string; // або редагуємо вже завантажене (URL)
  onDone: (blob: Blob) => void;
  onCancel: () => void;
}) {
  const [img, setImg] = useState<HTMLImageElement | null>(null);
  const [err, setErr] = useState(""); // чому фото не стало в рамку
  const [wait, setWait] = useState(""); // що зараз робимо з файлом
  const [scale, setScale] = useState(1); // множник до базового «cover»
  const [minScale, setMinScale] = useState(1);
  const [maxScale, setMaxScale] = useState(4);
  const [pos, setPos] = useState({ x: 0, y: 0 }); // зсув у px рамки
  const drag = useRef<{ x: number; y: number; px: number; py: number } | null>(null);
  const objUrl = useRef<string>("");

  // Завантажуємо фото (файл або URL готового фото)
  useEffect(() => {
    const im = new Image();
    im.crossOrigin = "anonymous"; // щоб можна було перемалювати в canvas
    // Підпис файлу — щоб було видно, що саме не відкрилось
    const about = file
      ? " (" + file.name + ", " + Math.round(file.size / 1024) + " КБ)"
      : "";
    im.onerror = () => {
      setErr(
        "Браузер не зміг відкрити цей файл" + about + ". Найчастіше так буває з фото з iPhone " +
          "(формат HEIC): надішліть його собі через Viber чи Telegram — вони віддають звичайний " +
          "JPG — і завантажте вже його."
      );
    };
    im.onload = () => {
      // SVG та деякі файли вантажаться, але не мають розміру — кадрувати нічого
      if (!im.naturalWidth || !im.naturalHeight) {
        setErr("Це не звичайне фото" + about + " — у файлі немає розміру. Потрібен JPG або PNG.");
        return;
      }
      setErr("");
      setImg(im);
      const cover = VIEW / Math.min(im.naturalWidth, im.naturalHeight); // фото заповнює рамку
      const contain = VIEW / Math.max(im.naturalWidth, im.naturalHeight); // усе фото видно
      setMinScale(contain * 0.4); // можна сильно віддаляти — фото стає маленьким із полями
      setMaxScale(cover * 4);
      setScale(cover * 1.15); // старт: трохи наближено, щоб одразу можна тягнути
      setPos({ x: 0, y: 0 });
    };
    let dead = false;
    (async () => {
      if (file) {
        let blob: Blob = file;
        // Фото з iPhone (HEIC) браузер не відкриває — перетворюємо тут же, у браузері
        if (isHeic(file)) {
          setWait("Перетворюю фото з iPhone… кілька секунд");
          try {
            blob = await heicToJpeg(file);
          } catch (e) {
            if (!dead) {
              setWait("");
              const why = e instanceof Error && e.message ? " Причина: " + e.message + "." : "";
              setErr(
                "Не вдалося перетворити це фото з iPhone" + about + "." + why +
                  " Спробуйте ще раз — на телефоні допомагає закрити зайві вкладки. Або збережіть фото як JPG."
              );
            }
            return;
          }
          if (dead) return;
          setWait("");
        }
        objUrl.current = URL.createObjectURL(blob);
        im.src = objUrl.current;
      } else if (src) {
        im.src = src;
      }
    })();
    return () => {
      dead = true;
      if (objUrl.current) URL.revokeObjectURL(objUrl.current);
    };
  }, [file, src]);

  const displaySrc = file ? objUrl.current : src || "";

  // Розміри фото на екрані при поточному масштабі
  const shown = img ? { w: img.naturalWidth * scale, h: img.naturalHeight * scale } : { w: 0, h: 0 };

  // Тримаємо фото так, щоб рамка завжди була закрита (без білих полів).
  // s — масштаб, для якого рахуємо межі (за замовчуванням поточний).
  const clampAt = (p: { x: number; y: number }, s: number) => {
    if (!img) return p;
    const w = img.naturalWidth * s;
    const h = img.naturalHeight * s;
    // abs: якщо фото БІЛЬШЕ рамки — не даємо зʼявитись білим полям (cover);
    // якщо МЕНШЕ рамки — тримаємо фото всередині рамки (вільне розміщення з полями).
    const maxX = Math.abs(w - VIEW) / 2;
    const maxY = Math.abs(h - VIEW) / 2;
    return {
      x: Math.max(-maxX, Math.min(maxX, p.x)),
      y: Math.max(-maxY, Math.min(maxY, p.y)),
    };
  };

  const onPointerDown = (e: React.PointerEvent) => {
    e.preventDefault();
    try {
      (e.target as HTMLElement).setPointerCapture(e.pointerId);
    } catch {}
    drag.current = { x: e.clientX, y: e.clientY, px: pos.x, py: pos.y };
  };
  const onPointerMove = (e: React.PointerEvent) => {
    if (!drag.current) return;
    e.preventDefault();
    const nx = drag.current.px + (e.clientX - drag.current.x);
    const ny = drag.current.py + (e.clientY - drag.current.y);
    setPos(clampAt({ x: nx, y: ny }, scale));
  };
  const onPointerUp = () => {
    drag.current = null;
  };

  const changeZoom = (v: number) => {
    setScale(v);
    setPos((p) => clampAt(p, v)); // межі рахуємо вже для НОВОГО масштабу
  };

  const finish = () => {
    if (!img) return;
    const canvas = document.createElement("canvas");
    canvas.width = OUT;
    canvas.height = OUT;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    ctx.fillStyle = "#fff";
    ctx.fillRect(0, 0, OUT, OUT);
    ctx.imageSmoothingQuality = "high"; // менше «милка» при зменшенні
    // те, що видно в рамці, збільшуємо до розміру готового фото
    const k = OUT / VIEW;
    const drawW = shown.w * k;
    const drawH = shown.h * k;
    const dx = (OUT - drawW) / 2 + pos.x * k;
    const dy = (OUT - drawH) / 2 + pos.y * k;
    ctx.drawImage(img, dx, dy, drawW, drawH);
    canvas.toBlob(
      (blob) => {
        if (blob) onDone(blob);
      },
      "image/jpeg",
      0.92
    );
  };

  return (
    <div className="cropper-veil" onClick={onCancel}>
      <div className="cropper" onClick={(e) => e.stopPropagation()}>
        <h3>Кадрування фото</h3>
        <p className="note" style={{ marginBottom: 14 }}>
          🖐 Тягніть фото, щоб посунути · повзунок ↔ наближає. Щоб рухати більше — наблизьте сильніше.
        </p>

        {wait && <p className="crop-wait">{wait}</p>}
        {err && <p className="crop-err">{err}</p>}

        <div
          className="crop-view"
          style={{ width: VIEW, height: VIEW }}
          onPointerDown={onPointerDown}
          onPointerMove={onPointerMove}
          onPointerUp={onPointerUp}
        >
          {img && (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={displaySrc}
              alt=""
              draggable={false}
              style={{
                width: shown.w,
                height: shown.h,
                transform: `translate(-50%, -50%) translate(${pos.x}px, ${pos.y}px)`,
              }}
            />
          )}
        </div>

        <div className="crop-zoom">
          <span>−</span>
          <input
            type="range"
            min={minScale}
            max={maxScale}
            step={(maxScale - minScale) / 200}
            value={scale}
            onChange={(e) => changeZoom(Number(e.target.value))}
          />
          <span>+</span>
        </div>

        <div className="crop-actions">
          <button type="button" className="btn btn--primary btn--sm" onClick={finish} disabled={!img}>
            Готово
          </button>
          <button type="button" className="btn btn--ghost btn--sm" onClick={onCancel}>
            Скасувати
          </button>
        </div>
      </div>
    </div>
  );
}
