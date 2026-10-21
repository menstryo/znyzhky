// «Газетки»: акційні каталоги регіональних мереж (Сім23, Форта, Салют, Фора) з GoToShop.
// Це сторінки-картинки без назв товарів, тому вони йдуть окремим розділом, а не в сітку акцій.
import { fetchText, sleep, decode } from "./lib.mjs";

const BASE = "https://gotoshop.ua";

// Каталоги мережі в місті: [{ key, title, from, to, viewer }]
async function catalogsFor(citySlug, chainSlug) {
  let html;
  try { html = await fetchText(`${BASE}/${citySlug}/shops/${chainSlug}/`); }
  catch (e) { if (/HTTP 404/.test(e.message)) return []; throw e; }
  const out = [];
  const re = new RegExp(`href="(?:https://gotoshop\\.ua)?/${citySlug}/discounts/([a-z0-9-]+)/"[^>]*>\\s*<span>([^<]+)</span>`, "g");
  const seen = new Set();
  let m;
  while ((m = re.exec(html))) {
    const slug = m[1];
    if (seen.has(slug)) continue;
    seen.add(slug);
    // дати є в самому слагу: …-2026-10-15-2026-10-28-…
    const dm = /(\d{4}-\d{2}-\d{2})-(\d{4}-\d{2}-\d{2})/.exec(slug);
    out.push({ slug, title: m[2].trim(), from: dm ? dm[1] : null, to: dm ? dm[2] : null });
  }
  return out;
}

// Сторінки каталогу: з /discounts/<slug>/catalog/ беремо посилання «Відкрити каталог» → /catalogs/<id>/
async function pagesFor(citySlug, discountSlug) {
  const html = await fetchText(`${BASE}/${citySlug}/discounts/${discountSlug}/catalog/`);
  const cm = new RegExp(`/${citySlug}/catalogs/([0-9a-z-]+)/`).exec(html);
  if (!cm) return null;
  const viewer = await fetchText(`${BASE}/${citySlug}/catalogs/${cm[1]}/`);
  // повнорозмірні сторінки: storage/img/c/<рік>/<міс>/<папка>/<файл>.png (без підпапки розміру)
  const pages = [];
  const seen = new Set();
  const re = /storage\/img\/c\/(\d{4}\/\d{2}\/\d+)\/([A-Za-z0-9]+)\.(png|jpg|jpeg|webp)/g;
  let m;
  while ((m = re.exec(viewer))) {
    const key = `${m[1]}/${m[2]}`;
    if (seen.has(key)) continue;
    seen.add(key);
    pages.push(`${BASE}/storage/img/c/${m[1]}/${m[2]}.${m[3]}`);
  }
  return pages.length ? { catalogId: cm[1].split("-")[0], pages } : null;
}

export async function fetchLeaflets(city, chains, log, today) {
  const out = [];
  for (const ch of chains) {
    let cats;
    try { cats = await catalogsFor(city.gts, ch.slug); }
    catch (e) { log(`${city.id}/${ch.id}: ${e.message}`); continue; }
    for (const c of cats) {
      if (c.to && c.to < today) continue;
      try {
        const p = await pagesFor(city.gts, c.slug);
        if (!p) continue;
        out.push({ chain: ch.id, name: ch.name, title: c.title, from: c.from, to: c.to, catalogId: p.catalogId, src: p.pages });
      } catch (e) {
        log(`${city.id}/${ch.id}/${c.slug}: ${e.message}`);
      }
      await sleep(250);
    }
  }
  return out;
}

// Форта (Луцьк) — власна «акційна газета»: галерея картинок-плиток.
export async function fetchForta(log) {
  const html = await fetchText("https://www.forta.store/akczijna-gazeta");
  const srcs = [];
  const seen = new Set();
  const re = /src=(?:%2F|\/)assets(?:%2F|\/)gallery(?:%2F|\/)(\d+)(?:%2F|\/)(\d+)\.(jpg|jpeg|png)/gi;
  let m;
  while ((m = re.exec(html))) {
    const k = `${m[1]}/${m[2]}`;
    if (seen.has(k)) continue;
    seen.add(k);
    srcs.push(`https://www.forta.store/assets/gallery/${m[1]}/${m[2]}.${m[3]}`);
  }
  const dm = /з\s*(\d{1,2})\.(\d{1,2})\s*по\s*(\d{1,2})\.(\d{1,2})\.(\d{4})/.exec(decode(html.replace(/<[^>]+>/g, " ")));
  const iso = (d, mo, y) => `${y}-${String(mo).padStart(2, "0")}-${String(d).padStart(2, "0")}`;
  const from = dm ? iso(dm[1], dm[2], dm[5]) : null, to = dm ? iso(dm[3], dm[4], dm[5]) : null;
  log(`Форта: ${srcs.length} сторінок, ${from}…${to}`);
  if (!srcs.length) return null;
  return { chain: "forta", name: "Форта", title: "Смакуй разом з FORTA", from, to, catalogId: `forta-${from || "x"}`, src: srcs };
}
