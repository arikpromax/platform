"use client";

import { useCallback, useEffect, useState } from "react";
import type { Session } from "@supabase/supabase-js";
import {
  addDaysISO,
  fmtDate,
  getSupabase,
  isSupabaseConfigured,
  todayISO,
  type Profile,
  type Site,
} from "@/lib/supabase";
import SiteAdmin from "@/components/SiteAdmin";

export default function AdminApp() {
  const supabase = getSupabase();

  const [checking, setChecking] = useState(true);
  const [session, setSession] = useState<Session | null>(null);
  const [profile, setProfile] = useState<Profile | "missing" | null>(null);
  const [sites, setSites] = useState<Site[]>([]);
  const [openSiteId, setOpenSiteId] = useState<number | null>(null);

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [authBusy, setAuthBusy] = useState(false);
  const [err, setErr] = useState("");

  /* ---------- Автентифікація ---------- */

  useEffect(() => {
    if (!supabase) {
      setChecking(false);
      return;
    }
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      setChecking(false);
    });
    const { data: sub } = supabase.auth.onAuthStateChange((_e, s) => setSession(s));
    return () => sub.subscription.unsubscribe();
  }, [supabase]);

  const loadAll = useCallback(async () => {
    if (!supabase || !session) return;
    const { data: prof } = await supabase
      .from("profiles")
      .select("*")
      .eq("user_id", session.user.id)
      .maybeSingle();
    if (!prof) {
      setProfile("missing");
      return;
    }
    const p = prof as Profile;
    setProfile(p);
    const { data: ss } = await supabase.from("sites").select("*").order("name");
    const list = (ss ?? []) as Site[];
    setSites(list);
    // власник одного сайту одразу потрапляє у свій сайт
    if (p.role === "owner") {
      const own = list.find((s) => s.id === p.site_id) ?? list[0];
      setOpenSiteId(own ? own.id : null);
    }
  }, [supabase, session]);

  useEffect(() => {
    if (session) loadAll();
    else {
      setProfile(null);
      setSites([]);
      setOpenSiteId(null);
    }
  }, [session, loadAll]);

  const signIn = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!supabase) return;
    setAuthBusy(true);
    setErr("");
    const { error } = await supabase.auth.signInWithPassword({ email: email.trim(), password });
    if (error)
      setErr(
        error.message.toLowerCase().includes("confirm")
          ? "Email не підтверджений. У Supabase видаліть цього користувача і створіть заново з галочкою «Auto Confirm User»."
          : "Не вдалося увійти: невірний email або пароль."
      );
    setAuthBusy(false);
    setPassword("");
  };

  const signOut = async () => {
    if (!supabase) return;
    await supabase.auth.signOut();
  };

  /* ---------- Підписки (лише admin) ---------- */

  const extend = async (site: Site) => {
    if (!supabase) return;
    const next = addDaysISO(site.paid_until, 30);
    const { error } = await supabase.from("sites").update({ paid_until: next }).eq("id", site.id);
    if (!error) loadAll();
  };

  /* ---------- Рендер ---------- */

  if (!isSupabaseConfigured || !supabase) {
    return (
      <main className="wrap">
        <div className="card login-box">
          <h1>Платформа arawebsite</h1>
          <p className="note">
            Supabase не підключено: потрібні <code>NEXT_PUBLIC_SUPABASE_URL</code> і{" "}
            <code>NEXT_PUBLIC_SUPABASE_ANON_KEY</code> у <code>.env.local</code> та в налаштуваннях
            Vercel.
          </p>
        </div>
      </main>
    );
  }

  if (checking) {
    return (
      <main className="wrap">
        <div className="card login-box">
          <p className="note">Завантаження…</p>
        </div>
      </main>
    );
  }

  if (!session) {
    return (
      <main className="wrap">
        <div className="card login-box">
          <div className="brand" style={{ marginBottom: 14 }}>
            <span className="brand__mark">a</span>Платформа arawebsite
          </div>
          <h1>Вхід в адмінку</h1>
          <p className="note" style={{ marginBottom: 16 }}>
            Керуйте контентом свого сайту.
          </p>
          {err && <div className="status status--err">{err}</div>}
          <form onSubmit={signIn}>
            <div className="field">
              <label htmlFor="email">Email</label>
              <input
                id="email"
                type="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="you@example.com"
              />
            </div>
            <div className="field">
              <label htmlFor="password">Пароль</label>
              <input
                id="password"
                type="password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
              />
            </div>
            <button type="submit" className="btn btn--primary" disabled={authBusy}>
              {authBusy ? "Входжу…" : "Увійти"}
            </button>
          </form>
        </div>
      </main>
    );
  }

  if (profile === "missing") {
    return (
      <main className="wrap">
        <div className="card login-box">
          <h1>Акаунт не підключено</h1>
          <p className="note" style={{ marginBottom: 16 }}>
            Ваш акаунт існує, але ще не прив&apos;язаний до жодного сайту платформи. Зверніться до
            студії arawebsite.
          </p>
          <button className="btn btn--ghost btn--sm" onClick={signOut}>
            Вийти
          </button>
        </div>
      </main>
    );
  }

  const openSite = sites.find((s) => s.id === openSiteId) ?? null;

  if (openSite && profile && profile !== "missing") {
    return (
      <SiteAdmin
        site={openSite}
        isAdmin={profile.role === "admin"}
        onBack={profile.role === "admin" ? () => setOpenSiteId(null) : undefined}
        onSignOut={signOut}
      />
    );
  }

  // Екран власника платформи: список усіх сайтів
  return (
    <main className="wrap">
      <div className="topbar">
        <div className="brand">
          <span className="brand__mark">a</span>Платформа arawebsite
        </div>
        <div className="topbar__actions">
          <button className="btn btn--ghost btn--sm" onClick={signOut}>
            Вийти
          </button>
        </div>
      </div>

      <h1 style={{ fontSize: "1.3rem", fontWeight: 800, marginBottom: 14 }}>Сайти клієнтів</h1>

      {sites.length === 0 && (
        <div className="card">
          <p className="note">Поки немає жодного сайту.</p>
        </div>
      )}

      {sites.map((s) => {
        const active = s.paid_until >= todayISO();
        return (
          <div key={s.id} className="card site-card">
            <div className="site-card__txt">
              <b>{s.name}</b>
              <span>{s.slug}</span>
            </div>
            <span className={`pill ${active ? "pill--ok" : "pill--off"}`}>
              {active ? `до ${fmtDate(s.paid_until)}` : "прострочена"}
            </span>
            <div className="row__actions">
              <button className="btn btn--ghost btn--sm" onClick={() => extend(s)}>
                +30 днів
              </button>
              <button className="btn btn--primary btn--sm" onClick={() => setOpenSiteId(s.id)}>
                Відкрити
              </button>
            </div>
          </div>
        );
      })}
    </main>
  );
}
