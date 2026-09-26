"use client";

import { useCallback, useEffect, useState } from "react";
import { getSupabase, type Site } from "@/lib/supabase";

/* ===========================================================
   ПІДКЛЮЧЕННЯ
   Ключі Нової Пошти, оплати й обміну з програмою обліку, а також
   звідки відправляються посилки. Ключі сюди лише вписують: назад
   вони не читаються навіть в адмінці — видно тільки «збережено»
   й останні символи, щоб упізнати, який саме ключ там лежить.
   =========================================================== */

type Notice = { kind: "ok" | "err"; text: string } | null;

type KeyState = Record<string, { filled: boolean; at: string; tail: string }>;

type Settings = {
  site_id: number;
  sender_city: string;
  sender_branch: string;
  cod_mode: string;
  description: string;
  auto: boolean;
  pay_provider: string;
  pay_test: boolean;
  weight_default: number;
};

const KEYS: { name: string; title: string; hint: string }[] = [
  {
    name: "NP_KEY",
    title: "Ключ Нової Пошти",
    hint: "Кабінет НП → Налаштування → Безпека → API-ключі. Потрібен, щоб сайт сам створював ТТН.",
  },
  {
    name: "MONO_TOKEN",
    title: "Токен monobank для оплати карткою",
    hint: "Кабінет monobank для бізнесу → Еквайринг → API-токен. Цей токен нікому не показуйте.",
  },
  {
    name: "SYNC_KEY",
    title: "Ключ обміну з програмою обліку",
    hint: "Придумайте довгий набір символів і передайте його тому, хто робить обмін з вашою програмою складу.",
  },
];

const fmt = (iso: string) => {
  const d = new Date(iso);
  const p = (n: number) => String(n).padStart(2, "0");
  return `${p(d.getDate())}.${p(d.getMonth() + 1)}.${d.getFullYear()}`;
};

export default function ConnectAdmin({ site, canEdit }: { site: Site; canEdit: boolean }) {
  const supabase = getSupabase()!;
  const [keys, setKeys] = useState<KeyState>({});
  const [draft, setDraft] = useState<Record<string, string>>({});
  const [set, setSet] = useState<Settings | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<Notice>(null);

  const load = useCallback(async () => {
    const [state, row] = await Promise.all([
      supabase.rpc("site_keys_state", { p_site: site.id }),
      supabase.from("np_settings").select("*").eq("site_id", site.id).maybeSingle(),
    ]);
    const res = (state.data ?? {}) as { keys?: KeyState };
    setKeys(res.keys ?? {});
    setSet((row.data ?? null) as Settings | null);
    setLoading(false);
  }, [supabase, site.id]);

  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        await load();
      } catch (e) {
        if (!alive) return;
        setNotice({ kind: "err", text: "Не вдалося завантажити: " + (e as Error).message });
        setLoading(false);
      }
    })();
    return () => {
      alive = false; // пішли з вкладки — стару відповідь не застосовуємо
    };
  }, [load]);

  const saveKey = async (name: string) => {
    if (!canEdit) return;
    setBusy(true);
    setNotice(null);
    const { data, error } = await supabase.rpc("set_site_key", {
      p_site: site.id,
      p_name: name,
      p_value: draft[name] ?? "",
    });
    const res = (data ?? {}) as { ok?: boolean; error?: string; cleared?: boolean };
    if (error || !res.ok) {
      setNotice({
        kind: "err",
        text: res.error === "access" ? "Немає прав або закінчилась підписка." : "Не вдалося зберегти ключ.",
      });
    } else {
      setDraft((d) => ({ ...d, [name]: "" }));
      setNotice({ kind: "ok", text: res.cleared ? "Ключ прибрано ✔" : "Ключ збережено ✔" });
      await load();
    }
    setBusy(false);
  };

  const saveSettings = async (patch: Partial<Settings>) => {
    if (!canEdit || !set) return;
    setBusy(true);
    setNotice(null);
    const next = { ...set, ...patch };
    setSet(next);
    const { error } = await supabase
      .from("np_settings")
      .update({ ...patch, updated_at: new Date().toISOString() })
      .eq("site_id", site.id);
    if (error) setNotice({ kind: "err", text: "Не вдалося зберегти: " + error.message });
    else setNotice({ kind: "ok", text: "Збережено ✔" });
    setBusy(false);
  };

  // Коли міняють місто або відділення, коди Нової Пошти треба знайти заново
  const saveSender = () =>
    saveSettings({
      sender_city: set?.sender_city ?? "",
      sender_branch: set?.sender_branch ?? "",
      // @ts-expect-error — службові поля бот заповнить сам
      sender_city_ref: "",
      sender_wh_ref: "",
    });

  if (loading) return <div className="card"><p className="note">Завантажую…</p></div>;

  return (
    <div className="card">
      <h2>Підключення</h2>
      <p className="note">
        Тут вписують ключі до Нової Пошти, оплати й програми складу. Ключ зберігається закрито:
        назад його не покаже навіть ця сторінка, лише останні символи, щоб ви впізнали свій.
      </p>

      {notice && <div className={`status status--${notice.kind}`}>{notice.text}</div>}

      {KEYS.map((k) => {
        const have = keys[k.name];
        return (
          <div className="field" key={k.name}>
            <label htmlFor={"key-" + k.name}>{k.title}</label>
            <div className="row__actions" style={{ gap: 8, flexWrap: "nowrap" }}>
              <input
                id={"key-" + k.name}
                type="password"
                autoComplete="off"
                placeholder={have ? `збережено …${have.tail}` : "не вписаний"}
                value={draft[k.name] ?? ""}
                disabled={!canEdit || busy}
                onChange={(e) => setDraft((d) => ({ ...d, [k.name]: e.target.value }))}
              />
              <button
                className="btn btn--primary btn--sm"
                disabled={!canEdit || busy || !(draft[k.name] ?? "").trim()}
                onClick={() => saveKey(k.name)}
              >
                Зберегти
              </button>
              {have && (
                <button
                  className="btn btn--ghost btn--sm"
                  disabled={!canEdit || busy}
                  onClick={() => {
                    if (!window.confirm(`Прибрати ${k.title}? Те, що ним працює, зупиниться.`)) return;
                    setDraft((d) => ({ ...d, [k.name]: " " }));
                    setTimeout(() => saveKey(k.name), 0);
                  }}
                >
                  Прибрати
                </button>
              )}
            </div>
            <p className="fhint">
              {k.hint}
              {have ? ` Вписано ${fmt(have.at)}.` : ""}
            </p>
          </div>
        );
      })}

      {set && (
        <>
          <h3 style={{ marginTop: 28 }}>Звідки відправляєте</h3>
          <div className="field">
            <label htmlFor="np-city">Місто</label>
            <input
              id="np-city"
              value={set.sender_city}
              disabled={!canEdit || busy}
              placeholder="Київ"
              onChange={(e) => setSet({ ...set, sender_city: e.target.value })}
              onBlur={saveSender}
            />
          </div>
          <div className="field">
            <label htmlFor="np-branch">Номер відділення</label>
            <input
              id="np-branch"
              value={set.sender_branch}
              disabled={!canEdit || busy}
              placeholder="25"
              onChange={(e) => setSet({ ...set, sender_branch: e.target.value })}
              onBlur={saveSender}
            />
            <p className="fhint">
              З цього відділення створюватимуться нові ТТН. Уже створені накладні не міняються.
            </p>
          </div>

          <h3 style={{ marginTop: 28 }}>Посилка й оплата</h3>
          <div className="field">
            <label htmlFor="np-weight">Вага посилки за замовчуванням, кг</label>
            <input
              id="np-weight"
              value={String(set.weight_default)}
              disabled={!canEdit || busy}
              onChange={(e) => setSet({ ...set, weight_default: Number(e.target.value.replace(",", ".")) || 0 })}
              onBlur={() => saveSettings({ weight_default: set.weight_default })}
            />
            <p className="fhint">
              Беремо, коли в товару не вказана своя вага. У відділенні посилку однаково зважать.
            </p>
          </div>
          <div className="field">
            <label htmlFor="np-cod">Накладений платіж</label>
            <select
              id="np-cod"
                            value={set.cod_mode}
              disabled={!canEdit || busy}
              onChange={(e) => saveSettings({ cod_mode: e.target.value })}
            >
              <option value="transfer">Грошовий переказ (без договору з НП)</option>
              <option value="control">Контроль оплати (за договором з НП)</option>
            </select>
          </div>
          <div className="field">
            <label htmlFor="pay-prov">Оплата карткою на сайті</label>
            <select
              id="pay-prov"
                            value={set.pay_provider}
              disabled={!canEdit || busy}
              onChange={(e) => saveSettings({ pay_provider: e.target.value })}
            >
              <option value="mono">monobank</option>
              <option value="off">Вимкнено</option>
            </select>
            <p className="fhint">
              Оплата зʼявиться на сайті, щойно буде вписаний токен monobank.
            </p>
          </div>
          <div className="field">
            <label htmlFor="pay-test">Тестовий токен</label>
            <select
              id="pay-test"
              value={set.pay_test ? "1" : "0"}
              disabled={!canEdit || busy}
              onChange={(e) => saveSettings({ pay_test: e.target.value === "1" })}
            >
              <option value="0">Ні, це справжня оплата</option>
              <option value="1">Так, перевірка — гроші не списуються</option>
            </select>
            <p className="fhint">
              З тестовим токеном на сайті при оплаті написано, що гроші не списуються, а в
              Telegram замовлення позначається як тестове й накладна сама не створюється.
              Отримали робочий токен — поставте «Ні».
            </p>
          </div>
          <div className="field">
            <label htmlFor="np-auto">Створювати ТТН автоматично</label>
            <select
              id="np-auto"
                            value={set.auto ? "1" : "0"}
              disabled={!canEdit || busy}
              onChange={(e) => saveSettings({ auto: e.target.value === "1" })}
            >
              <option value="1">Так, одразу після замовлення</option>
              <option value="0">Ні, кнопкою в Telegram</option>
            </select>
          </div>
        </>
      )}
    </div>
  );
}
