"use client";

import { useEffect, useRef, useState } from "react";

/*
  Панель обрізки фото: перетягування + масштаб.
  Користувач ставить страву в квадратну рамку, а на «Готово» ми малюємо
  результат у canvas 800×800 і віддаємо готовий JPEG-файл — сайт показує
  його як є, без жодних додаткових налаштувань позиції.
*/

const OUT = 800; // розмір готового квадратного фото, px
const VIEW = 300; // розмір рамки на екрані, px

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
  const [scale, setScale] = useState(1); // множник до базового «cover»
  const [minScale, setMinScale] = useState(1);
  const [pos, setPos] = useState({ x: 0, y: 0 }); // зсув у px рамки
  const drag = useRef<{ x: number; y: number; px: number; py: number } | null>(null);
  const objUrl = useRef<string>("");

  // Завантажуємо фото (файл або URL готового фото)
  useEffect(() => {
    const im = new Image();
    im.crossOrigin = "anonymous"; // щоб можна було перемалювати в canvas
    im.onload = () => {
      setImg(im);
      // базовий масштаб — щоб фото покривало рамку (cover)
      const base = VIEW / Math.min(im.naturalWidth, im.naturalHeight);
      setMinScale(base);
      setScale(base);
      setPos({ x: 0, y: 0 });
    };
    if (file) {
      objUrl.current = URL.createObjectURL(file);
      im.src = objUrl.current;
    } else if (src) {
      im.src = src;
    }
    return () => {
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
    const maxX = Math.max(0, (w - VIEW) / 2);
    const maxY = Math.max(0, (h - VIEW) / 2);
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
    // те, що видно в рамці, збільшуємо до 800px
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
      0.9
    );
  };

  return (
    <div className="cropper-veil" onClick={onCancel}>
      <div className="cropper" onClick={(e) => e.stopPropagation()}>
        <h3>Кадрування фото</h3>
        <p className="note" style={{ marginBottom: 14 }}>
          Перетягуйте фото і крутіть повзунок, щоб страва гарно стала в рамку.
        </p>

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
            max={minScale * 4}
            step={minScale / 100}
            value={scale}
            onChange={(e) => changeZoom(Number(e.target.value))}
          />
          <span>+</span>
        </div>

        <div className="crop-actions">
          <button type="button" className="btn btn--primary btn--sm" onClick={finish}>
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
