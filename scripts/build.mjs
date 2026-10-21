// Збирає акції з магазинів і публікує статичні файли для GitHub Pages:
//   public/index.json          — магазини, категорії, лічильники, час оновлення
//   public/store/<id>.json     — товари магазину (відсортовані за знижкою)
//   public/img/<id>/<hash>.jpg — мініатюри 120×120 JPEG (iOS 6 не вміє WebP)
import fs from "fs";
import path from "path";
import crypto from "crypto";
import sharp from "sharp";
import { CATEGORIES } from "./categories.mjs";
import { fetchRaw, fetchJSON, pool, todayISO } from "./lib.mjs";
import * as silpo from "./sources/silpo.mjs";
import * as atb from "./sources/atb.mjs";
import * as varus from "./sources/varus.mjs";
import * as avrora from "./sources/avrora.mjs";

const SOURCES = [silpo, atb, varus, avrora];

const OUT = path.resolve("public");
const IMG_CACHE = path.resolve(".cache/img");
const PAGES_URL = (process.env.PAGES_URL || "").replace(/\/$/, "");
const PER_CATEGORY = +process.env.PER_CATEGORY || 150; // макс. товарів на категорію в одному магазині
const MIN_DISCOUNT = 5;
const THUMB = 120;

fs.rmSync(OUT, { recursive: true, force: true });
fs.mkdirSync(path.join(OUT, "store"), { recursive: true });
fs.mkdirSync(IMG_CACHE, { recursive: true });

const now = new Date();
const today = todayISO(now);
const farDate = todayISO(new Date(now.getTime() + 120 * 864e5));
const catIds = new Set(CATEGORIES.map(c => c.id));

function finalize(items) {
  const out = [];
  for (const it of items) {
    if (!it || !it.t || !(it.p > 0) || !(it.o > it.p)) continue;
    const d = Math.round((1 - it.p / it.o) * 100);
    if (d < MIN_DISCOUNT || d > 99) continue;
    let e = it.e || null;
    if (e && (e < today || e > farDate)) e = null; // «безстрокові» або прострочені дати не показуємо
    out.push({ ...it, e, t: it.t.replace(/\s+/g, " ").trim(), d, c: catIds.has(it.c) ? it.c : "other" });
  }
  // у кожній категорії лишаємо найвигідніші
  const byCat = new Map();
  for (const it of out) {
    if (!byCat.has(it.c)) byCat.set(it.c, []);
    byCat.get(it.c).push(it);
  }
  const kept = [];
  for (const list of byCat.values()) {
    list.sort((a, b) => b.d - a.d || a.p - b.p);
    kept.push(...list.slice(0, PER_CATEGORY));
  }
  kept.sort((a, b) => b.d - a.d || a.p - b.p);
  return kept;
}

const hashOf = s => crypto.createHash("sha1").update(s).digest("hex").slice(0, 16);

// Запобіжник: якщо CDN магазину не віддає картинки (блок, таймаути) — після N невдач поспіль
// перестаємо пробувати до наступного запуску, щоб збірка не висіла годинами.
const IMG_FAIL_LIMIT = 25;
const imgFails = {};
const NO_IMAGES = !!process.env.NO_IMAGES;

async function thumb(storeId, src) {
  const name = `${hashOf(src)}.jpg`;
  const cached = path.join(IMG_CACHE, storeId, name);
  if (!fs.existsSync(cached)) {
    if (NO_IMAGES || (imgFails[storeId] || 0) >= IMG_FAIL_LIMIT) return null;
    try {
      const r = await fetchRaw(src, { timeout: 10000, tries: 1, headers: { Accept: "image/jpeg,image/png,image/webp,*/*" } });
      const buf = Buffer.from(await r.arrayBuffer());
      const jpg = await sharp(buf)
        .resize(THUMB, THUMB, { fit: "contain", background: "#ffffff" })
        .flatten({ background: "#ffffff" })
        .jpeg({ quality: 72, progressive: false, mozjpeg: false })
        .toBuffer();
      fs.mkdirSync(path.dirname(cached), { recursive: true });
      fs.writeFileSync(cached, jpg);
      imgFails[storeId] = 0;
    } catch {
      imgFails[storeId] = (imgFails[storeId] || 0) + 1;
      if (imgFails[storeId] === IMG_FAIL_LIMIT) console.log(`[${storeId}] картинки не вантажаться — пропускаю до наступного запуску`);
      return null;
    }
  }
  const dst = path.join(OUT, "img", storeId, name);
  fs.mkdirSync(path.dirname(dst), { recursive: true });
  fs.copyFileSync(cached, dst);
  return `img/${storeId}/${name}`;
}

async function previous(storeId) {
  if (!PAGES_URL) return null;
  try {
    const j = await fetchJSON(`${PAGES_URL}/store/${storeId}.json`, { tries: 2 });
    return Array.isArray(j.items) ? j : null;
  } catch {
    return null;
  }
}

const storesMeta = [];
const catCount = Object.fromEntries(CATEGORIES.map(c => [c.id, 0]));

for (const src of SOURCES) {
  const log = m => console.log(`[${src.id}] ${m}`);
  const t0 = Date.now();
  let items = null, updated = now.toISOString(), stale = false;
  try {
    const raw = process.env.FIXTURES
      ? JSON.parse(fs.readFileSync(path.join(process.env.FIXTURES, `${src.id}.json`), "utf8")) // локальний прогін
      : await src.fetchItems(log);
    items = finalize(raw);
    if (!items.length) throw new Error("0 товарів");
  } catch (e) {
    log(`ПОМИЛКА: ${e.message}`);
    const prev = await previous(src.id);
    if (prev) {
      log(`беру попередні дані від ${prev.updated} (${prev.items.length} шт)`);
      items = prev.items.map(({ i, ...rest }) => ({ ...rest, img: null, _i: i }));
      updated = prev.updated;
      stale = true;
    } else {
      storesMeta.push({ id: src.id, name: src.name, count: 0, avg: 0, max: 0, ok: false, updated: null });
      continue;
    }
  }

  // мініатюри
  await pool(items, 12, async it => {
    if (it.img) it.i = await thumb(src.id, it.img);
    else if (it._i) {
      // для застарілих даних — копія з кешу, якщо є
      const cached = path.join(IMG_CACHE, src.id, path.basename(it._i));
      if (fs.existsSync(cached)) {
        const dst = path.join(OUT, it._i);
        fs.mkdirSync(path.dirname(dst), { recursive: true });
        fs.copyFileSync(cached, dst);
        it.i = it._i;
      }
    }
  });

  const clean = items.map(it => {
    const o = { id: it.id, t: it.t, p: it.p, o: it.o, d: it.d, u: it.u || "", c: it.c };
    if (it.e) o.e = it.e;
    if (it.i) o.i = it.i;
    if (it.l) o.l = it.l;
    return o;
  });
  for (const it of clean) catCount[it.c]++;
  const avg = clean.length ? Math.round(clean.reduce((s, i) => s + i.d, 0) / clean.length) : 0;
  const max = clean.reduce((m, i) => Math.max(m, i.d), 0);
  fs.writeFileSync(path.join(OUT, "store", `${src.id}.json`),
    JSON.stringify({ id: src.id, name: src.name, updated, items: clean }));
  storesMeta.push({ id: src.id, name: src.name, count: clean.length, avg, max, ok: !stale, updated });
  const imgs = clean.filter(i => i.i).length;
  log(`готово: ${clean.length} товарів, ${imgs} фото, ${((Date.now() - t0) / 1000).toFixed(0)} с${stale ? " (застарілі)" : ""}`);
}

fs.writeFileSync(path.join(OUT, "index.json"), JSON.stringify({
  updated: now.toISOString(),
  stores: storesMeta,
  cats: CATEGORIES.map(c => ({ id: c.id, name: c.name, count: catCount[c.id] })),
}));
fs.writeFileSync(path.join(OUT, ".nojekyll"), "");
if (fs.existsSync("site/index.html")) fs.copyFileSync("site/index.html", path.join(OUT, "index.html"));
if (fs.existsSync("Znyzhky.ipa")) fs.copyFileSync("Znyzhky.ipa", path.join(OUT, "Znyzhky.ipa"));

console.log("\nКатегорії:", Object.entries(catCount).map(([k, v]) => `${k}=${v}`).join(" "));
if (!storesMeta.some(s => s.count > 0)) process.exit(1);
