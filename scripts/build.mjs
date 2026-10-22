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
import { browserFetchBuffer, browserStarted, closeBrowser } from "./browser.mjs";
import * as silpo from "./sources/silpo.mjs";
import * as fora from "./sources/fora.mjs";
import * as atb from "./sources/atb.mjs";
import * as varus from "./sources/varus.mjs";
import * as avrora from "./sources/avrora.mjs";
import * as zakaz from "./sources/zakaz.mjs";
import { CITIES, ZAKAZ_CHAINS, LEAFLET_CHAINS } from "./cities.mjs";
import { fetchLeaflets, fetchForta, gtsViaBrowser } from "./leaflets.mjs";
import { addComparisons } from "./compare.mjs";

const SOURCES = [silpo, atb, varus, fora, avrora];

// лог збирача публікуємо разом з даними (public/build-log.txt) — щоб бачити помилки без доступу до логів Actions
const LOG = [];
const origLog = console.log;
console.log = (...args) => { LOG.push(args.join(" ")); origLog(...args); };

const OUT = path.resolve("public");
const IMG_CACHE = path.resolve(".cache/img300");   // нова папка: старі 120-піксельні не підхоплюються
const PAGES_URL = (process.env.PAGES_URL || "").replace(/\/$/, "");
const PER_CATEGORY = +process.env.PER_CATEGORY || 150; // макс. товарів на категорію в одному магазині
const PER_CATEGORY_CITY = 80;                           // для міських магазинів (їх багато)
const LF_CACHE = path.resolve(".cache/lf");
const LF_WIDTH = 640;                                    // ширина сторінки газетки (320 pt @2x)
const MIN_DISCOUNT = 5;
const THUMB = 300;   // 2× для фото на екрані товару (≈170 pt), у сітці — з запасом

fs.rmSync(OUT, { recursive: true, force: true });
fs.mkdirSync(path.join(OUT, "store"), { recursive: true });
fs.mkdirSync(path.join(OUT, "leaflets"), { recursive: true });
fs.mkdirSync(IMG_CACHE, { recursive: true });

const now = new Date();
const today = todayISO(now);
const farDate = todayISO(new Date(now.getTime() + 120 * 864e5));
const catIds = new Set(CATEGORIES.map(c => c.id));

function finalize(items, perCat = PER_CATEGORY) {
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
    kept.push(...list.slice(0, perCat));
  }
  kept.sort((a, b) => b.d - a.d || a.p - b.p);
  return kept;
}

const hashOf = s => crypto.createHash("sha1").update(s).digest("hex").slice(0, 16);

// Запобіжник: якщо CDN магазину не віддає картинки (блок, таймаути) — після N невдач поспіль
// перестаємо пробувати до наступного запуску, щоб збірка не висіла годинами.
const IMG_FAIL_LIMIT = 25;
// деякі CDN віддають картинки лише з Referer свого сайту
const REFERER = { silpo: "https://silpo.ua/", atb: "https://www.atbmarket.com/", varus: "https://varus.ua/", avrora: "https://avrora.ua/", fora: "https://fora.ua/" };
const imgFails = {};
const imgErrLogged = {};
const NO_IMAGES = !!process.env.NO_IMAGES;

async function thumb(storeId, src) {
  return thumbIn(storeId, storeId, src);
}

// dir — папка мініатюр: для міських магазинів спільна на мережу (Metro у різних містах — ті самі фото)
async function thumbIn(storeId, dir, src) {
  // суфікс -3: інше ім'я файлу, щоб застосунок не взяв зі свого дискового кешу старе мило
  const name = `${hashOf(src)}-3.jpg`;
  const cached = path.join(IMG_CACHE, dir, name);
  if (!fs.existsSync(cached)) {
    if (NO_IMAGES || (imgFails[storeId] || 0) >= IMG_FAIL_LIMIT) return null;
    try {
      let buf;
      try {
        const r = await fetchRaw(src, { timeout: 10000, tries: 1,
          headers: { Accept: "image/jpeg,image/png,image/webp,*/*", Referer: REFERER[storeId] || "" } });
        buf = Buffer.from(await r.arrayBuffer());
      } catch (e) {
        // якщо браузер уже запущено (магазин за Cloudflare) — пробуємо через нього
        if (!browserStarted() || !/HTTP 403/.test(e.message)) throw e;
        buf = await browserFetchBuffer(src, REFERER[storeId]);
      }
      const jpg = await sharp(buf)
        .resize(THUMB, THUMB, { fit: "contain", background: "#ffffff" })
        .flatten({ background: "#ffffff" })
        .jpeg({ quality: 78, progressive: false, mozjpeg: false })
        .toBuffer();
      fs.mkdirSync(path.dirname(cached), { recursive: true });
      fs.writeFileSync(cached, jpg);
      imgFails[storeId] = 0;
    } catch (e) {
      imgFails[storeId] = (imgFails[storeId] || 0) + 1;
      if (!imgErrLogged[storeId]) { imgErrLogged[storeId] = true; console.log(`[${storeId}] картинка: ${e.message}`); }
      if (imgFails[storeId] === IMG_FAIL_LIMIT) console.log(`[${storeId}] картинки не вантажаться — пропускаю до наступного запуску`);
      return null;
    }
  }
  const dst = path.join(OUT, "img", dir, name);
  if (!fs.existsSync(dst)) {
    fs.mkdirSync(path.dirname(dst), { recursive: true });
    fs.copyFileSync(cached, dst);
  }
  return `img/${dir}/${name}`;
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

// src: { id, name, fetchItems(log), city?, imgDir?, perCat? }
async function processStore(src) {
  const log = m => console.log(`[${src.id}] ${m}`);
  const t0 = Date.now();
  const imgDir = src.imgDir || src.id;
  let items = null, updated = now.toISOString(), stale = false;
  const meta = { id: src.id, name: src.name };
  if (src.city) meta.city = src.city;
  try {
    const raw = process.env.FIXTURES
      ? JSON.parse(fs.readFileSync(path.join(process.env.FIXTURES, `${src.id}.json`), "utf8")) // локальний прогін
      : await src.fetchItems(log);
    items = finalize(raw, src.perCat);
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
      storesMeta.push({ ...meta, count: 0, avg: 0, max: 0, ok: false, updated: null });
      return;
    }
  }

  // мініатюри
  await pool(items, 12, async it => {
    if (it.img) it.i = await thumbIn(src.id, imgDir, it.img);
    else if (it._i) {
      // для застарілих даних — копія з кешу, якщо є
      const cached = path.join(IMG_CACHE, imgDir, path.basename(it._i));
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
  if (!src.city) for (const it of clean) catCount[it.c]++;
  const avg = clean.length ? Math.round(clean.reduce((s, i) => s + i.d, 0) / clean.length) : 0;
  const max = clean.reduce((m, i) => Math.max(m, i.d), 0);
  fs.writeFileSync(path.join(OUT, "store", `${src.id}.json`),
    JSON.stringify({ id: src.id, name: src.name, updated, items: clean }));
  storesMeta.push({ ...meta, count: clean.length, avg, max, ok: !stale, updated });
  const imgs = clean.filter(i => i.i).length;
  log(`готово: ${clean.length} товарів, ${imgs} фото, ${((Date.now() - t0) / 1000).toFixed(0)} с${stale ? " (застарілі)" : ""}`);
}

// 1. загальнонаціональні мережі
for (const src of SOURCES) await processStore(src);

// 2. міські магазини Zakaz.ua (Novus, ЕКО маркет, Metro)
if (!process.env.FIXTURES && !process.env.NO_CITIES) {
  let idx = {};
  try { idx = await zakaz.storeIndex(); }
  catch (e) { console.log(`[zakaz] список магазинів недоступний: ${e.message}`); }
  for (const city of CITIES) {
    if (!city.zakaz) continue;
    for (const ch of ZAKAZ_CHAINS) {
      const storeId = idx[`${ch.chain}:${city.zakaz}`];
      if (!storeId) continue;
      await processStore({
        id: `${ch.chain}-${city.id}`, name: ch.name, city: city.id, imgDir: ch.chain, perCat: PER_CATEGORY_CITY,
        fetchItems: log => zakaz.fetchStoreItems(storeId, log),
      });
    }
  }
}

// 3. газетки по містах
async function leafletPage(src) {
  const name = `${hashOf(src)}.jpg`;
  const cached = path.join(LF_CACHE, name);
  if (!fs.existsSync(cached)) {
    if ((imgFails.lf || 0) >= IMG_FAIL_LIMIT) return null;
    try {
      let buf;
      if (/gotoshop\.ua/.test(src) && gtsViaBrowser()) buf = await browserFetchBuffer(src, "https://gotoshop.ua/");
      else buf = Buffer.from(await (await fetchRaw(src, { timeout: 20000, tries: 2, headers: { Accept: "image/*" } })).arrayBuffer());
      const jpg = await sharp(buf).resize({ width: LF_WIDTH, withoutEnlargement: true })
        .flatten({ background: "#ffffff" }).jpeg({ quality: 68, progressive: false }).toBuffer();
      fs.mkdirSync(LF_CACHE, { recursive: true });
      fs.writeFileSync(cached, jpg);
      imgFails.lf = 0;
    } catch (e) {
      imgFails.lf = (imgFails.lf || 0) + 1;
      if (imgFails.lf === 1) console.log(`[газетки] сторінка: ${e.message}`);
      return null;
    }
  }
  const meta = await sharp(cached).metadata();
  const dst = path.join(OUT, "lf", name);
  if (!fs.existsSync(dst)) { fs.mkdirSync(path.dirname(dst), { recursive: true }); fs.copyFileSync(cached, dst); }
  return { i: `lf/${name}`, w: meta.width, h: meta.height };
}

const leafletCount = {};
if (!process.env.FIXTURES && !process.env.NO_CITIES) {
  const log = m => console.log(`[газетки] ${m}`);
  let forta = null;
  try { forta = await fetchForta(log); } catch (e) { log(`Форта: ${e.message}`); }
  const FORTA_CITIES = ["lutsk", "lviv"];
  for (const city of CITIES) {
    let list = [];
    try { list = await fetchLeaflets(city, LEAFLET_CHAINS, log, today); } catch (e) { log(`${city.id}: ${e.message}`); }
    if (forta && FORTA_CITIES.includes(city.id)) list.unshift(forta);
    const out = [];
    for (const lf of list) {
      const pages = (await pool(lf.src, 6, leafletPage)).filter(Boolean);
      if (!pages.length) continue;
      out.push({ chain: lf.chain, name: lf.name, title: lf.title, from: lf.from, to: lf.to, pages });
    }
    leafletCount[city.id] = out.length;
    if (out.length) log(`${city.name}: ${out.map(l => `${l.name} (${l.pages.length} стор.)`).join(", ")}`);
    fs.writeFileSync(path.join(OUT, "leaflets", `${city.id}.json`),
      JSON.stringify({ city: city.id, updated: now.toISOString(), leaflets: out }));
  }
}

await closeBrowser();

// 4. порівняння цін між мережами: дописуємо товарам поле m
try {
  const loaded = storesMeta.filter(m => m.count > 0).map(m => {
    const file = path.join(OUT, "store", `${m.id}.json`);
    return { id: m.id, city: m.city, file, json: JSON.parse(fs.readFileSync(file, "utf8")) };
  });
  addComparisons(loaded.map(l => ({ id: l.id, city: l.city, items: l.json.items })), m => console.log(m));
  for (const l of loaded) fs.writeFileSync(l.file, JSON.stringify(l.json));
} catch (e) {
  console.log(`порівняння: ПОМИЛКА ${e.message}`);
}

fs.writeFileSync(path.join(OUT, "index.json"), JSON.stringify({
  updated: now.toISOString(),
  stores: storesMeta,
  cities: CITIES.map(c => ({ id: c.id, name: c.name, leaflets: leafletCount[c.id] || 0 })),
  cats: CATEGORIES.map(c => ({ id: c.id, name: c.name, count: catCount[c.id] })),
}));
fs.writeFileSync(path.join(OUT, ".nojekyll"), "");
fs.writeFileSync(path.join(OUT, "build-log.txt"), LOG.join("\n") + "\n");
if (fs.existsSync("site/index.html")) fs.copyFileSync("site/index.html", path.join(OUT, "index.html"));
if (fs.existsSync("Znyzhky.ipa")) fs.copyFileSync("Znyzhky.ipa", path.join(OUT, "Znyzhky.ipa"));

console.log("\nКатегорії:", Object.entries(catCount).map(([k, v]) => `${k}=${v}`).join(" "));
if (!storesMeta.some(s => s.count > 0)) process.exit(1);
