// Спільні утиліти сборщика: HTTP з повторами, пул паралельних задач, HTML-хелпери.

export const UA =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36";

const BASE_HEADERS = {
  "User-Agent": UA,
  "Accept-Language": "uk-UA,uk;q=0.9,ru;q=0.8,en;q=0.7",
};

export const sleep = ms => new Promise(r => setTimeout(r, ms));

export async function fetchRaw(url, { headers = {}, timeout = 25000, tries = 3 } = {}) {
  let lastErr;
  for (let i = 0; i < tries; i++) {
    const ctl = new AbortController();
    const timer = setTimeout(() => ctl.abort(), timeout);
    try {
      const r = await fetch(url, { headers: { ...BASE_HEADERS, ...headers }, signal: ctl.signal, redirect: "follow" });
      clearTimeout(timer);
      if (r.status === 429 || r.status >= 500) throw new Error(`HTTP ${r.status}`);
      if (!r.ok) {
        const e = new Error(`HTTP ${r.status}`);
        e.fatal = true;
        throw e;
      }
      return r;
    } catch (e) {
      clearTimeout(timer);
      lastErr = e;
      if (e.fatal) break;
      await sleep(1000 * (i + 1) * (i + 1));
    }
  }
  throw new Error(`${url}: ${lastErr && lastErr.message}`);
}

export async function fetchText(url, opts = {}) {
  const r = await fetchRaw(url, { ...opts, headers: { Accept: "text/html,application/xhtml+xml,*/*;q=0.8", ...(opts.headers || {}) } });
  const t = await r.text();
  // Cloudflare-челендж повертає 200/403 зі сторінкою перевірки
  if (/cf-browser-verification|challenge-platform\/h\/[a-z]\/orchestrate|Just a moment\.\.\./i.test(t) && t.length < 60000) {
    throw new Error(`${url}: Cloudflare challenge`);
  }
  return t;
}

export async function fetchJSON(url, opts = {}) {
  const r = await fetchRaw(url, { ...opts, headers: { Accept: "application/json", ...(opts.headers || {}) } });
  return r.json();
}

// Виконує fn для кожного елемента з обмеженням паралельності.
export async function pool(items, limit, fn) {
  const out = new Array(items.length);
  let next = 0;
  async function worker() {
    while (next < items.length) {
      const i = next++;
      out[i] = await fn(items[i], i);
    }
  }
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker));
  return out;
}

const ENT = { amp: "&", lt: "<", gt: ">", quot: '"', apos: "'", nbsp: " ", laquo: "«", raquo: "»", ndash: "–", mdash: "—", rsquo: "’", lsquo: "‘", hellip: "…" };

export function decode(s) {
  return String(s || "")
    .replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(+n))
    .replace(/&#x([0-9a-f]+);/gi, (_, n) => String.fromCodePoint(parseInt(n, 16)))
    .replace(/&([a-z]+);/gi, (m, n) => (n.toLowerCase() in ENT ? ENT[n.toLowerCase()] : m));
}

export const stripTags = s => decode(String(s || "").replace(/<[^>]*>/g, " ")).replace(/\s+/g, " ").trim();

export const num = s => {
  if (s == null) return null;
  const n = parseFloat(String(s).replace(/\s|&nbsp;| /g, "").replace(",", "."));
  return isFinite(n) ? n : null;
};

export const round2 = n => Math.round(n * 100) / 100;

// Розбиває HTML на шматки, що починаються з кожного входження маркера.
export function splitBy(html, marker) {
  const parts = [];
  let i = html.indexOf(marker);
  while (i !== -1) {
    const j = html.indexOf(marker, i + marker.length);
    parts.push(html.slice(i, j === -1 ? html.length : j));
    i = j;
  }
  return parts;
}

export const pick = (s, re) => {
  const m = re.exec(s);
  return m ? m[1] : null;
};

// «до 27.10» → «2026-10-27» (рік підбираємо так, щоб дата була найближчою до сьогодні).
export function dayMonthToISO(dd, mm, now = new Date()) {
  const d = +dd, m = +mm;
  if (!d || !m) return null;
  let y = now.getUTCFullYear();
  const cand = Date.UTC(y, m - 1, d);
  const diff = cand - now.getTime();
  if (diff < -180 * 864e5) y++;
  else if (diff > 180 * 864e5) y--;
  return `${y}-${String(m).padStart(2, "0")}-${String(d).padStart(2, "0")}`;
}

export function todayISO(now = new Date()) {
  // за Києвом
  const k = new Date(now.getTime() + 3 * 3600e3);
  return k.toISOString().slice(0, 10);
}
