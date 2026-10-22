// Фора: API інтернет-магазину (та сама платформа, що й у Сільпо — Fozzy Group).
// Сайт fora.ua за захистом від ботів, але API каталогу відповідає на звичайні POST-запити.
import crypto from "crypto";
import { pool, round2, sleep } from "../lib.mjs";
import { classify } from "../categories.mjs";

const API = "https://api.catalog.ecom.fora.ua/api/2.0/exec/EcomCatalogGlobal";
const FILIAL = 3805;   // Київ, доставка — ціни мережі
const PAGE = 100;

export const id = "fora";
export const name = "Фора";

const UID = crypto.randomUUID();

async function call(method, data, tries = 3) {
  let last;
  for (let i = 0; i < tries; i++) {
    try {
      const r = await fetch(API, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          accept: "application/json, text/plain, */*",
          "accept-language": "uk-UA",
          referer: "https://fora.ua/",
          origin: "https://fora.ua",
          "user-uid": UID,
          "x-sessionid": "undefined",
          "user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36",
        },
        body: JSON.stringify({ method, data }),
        signal: AbortSignal.timeout(30000),
      });
      if (!r.ok) throw new Error(`HTTP ${r.status}`);
      return await r.json();
    } catch (e) { last = e; await sleep(1500 * (i + 1)); }
  }
  throw new Error(`${method}: ${last && last.message}`);
}

const page = from => call("GetSimpleCatalogItems", {
  merchantId: 2, deliveryType: 2, filialId: FILIAL, businessId: 1,
  From: from, To: from + PAGE - 1, onlyPromo: true,
  RangeFilters: {}, MultiFilters: {}, UniversalFilters: [], CategoryFilter: [], Promos: [],
});

const iso = s => {
  const m = /^(\d{2})\.(\d{2})\.(\d{4})/.exec(s || "");
  return m ? `${m[3]}-${m[2]}-${m[1]}` : null;
};

export function normalize(it) {
  const price = it.price, old = it.oldPrice;
  if (!it.name || !price || !old || old <= price) return null;
  const cats = it.categories || [];
  const catText = cats.map(c => c.name).join(" / ");
  return {
    id: String(it.id),
    t: it.name,
    p: round2(price),
    o: round2(old),
    u: it.unit || "",
    c: classify(catText, it.name),
    e: iso(it.priceStopAfter || (it.promotion && it.promotion.stopAfter)),
    img: it.mainImage || null,
    l: it.slug ? `https://fora.ua/product/${it.slug}` : null,
  };
}

export async function fetchItems(log) {
  const first = await page(1);
  const total = Math.min(first.itemsCount || 0, 20000);
  const froms = [];
  for (let f = 1 + PAGE; f <= total; f += PAGE) froms.push(f);
  const rest = await pool(froms, 3, async f => {
    try { return (await page(f)).items || []; }
    catch (e) { log(`сторінка ${f}: ${e.message}`); return []; }
  });
  const raw = [first.items || [], ...rest].flat();
  log(`промо-товарів: ${raw.length} з ${first.itemsCount}`);
  const seen = new Set();
  return raw.map(normalize).filter(x => x && !seen.has(x.id) && seen.add(x.id));
}
