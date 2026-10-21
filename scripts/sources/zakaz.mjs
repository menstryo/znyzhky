// Мережі на платформі Zakaz.ua (Novus, ЕКО маркет, Metro…): акції прив'язані до конкретного магазину,
// тому беремо один магазин мережі в кожному місті.
import { fetchJSON, round2 } from "../lib.mjs";
import { classify } from "../categories.mjs";

const API = "https://stores-api.zakaz.ua";
const MAX_PAGES = 30; // по 100 товарів

let storesPromise = null;
export function loadStores() {
  if (!storesPromise) storesPromise = fetchJSON(`${API}/stores/`, { headers: { "Accept-Language": "uk" } });
  return storesPromise;
}

// { "<chain>:<zakazCity>": storeId }
export async function storeIndex() {
  const list = await loadStores();
  const idx = {};
  for (const s of list) {
    const k = `${s.retail_chain}:${s.city}`;
    if (!idx[k]) idx[k] = s.id;
  }
  return idx;
}

export function normalize(it) {
  const price = it.price / 100;
  const d = it.discount || {};
  const old = d.old_price ? d.old_price / 100 : null;
  if (!price || !old || old <= price || !d.status) return null;
  const img = it.img && (it.img.s200x200 || it.img.s350x350 || it.img.s150x150);
  return {
    id: String(it.ean || it.sku),
    t: String(it.title || "").trim(),
    p: round2(price),
    o: round2(old),
    u: it.unit === "kg" ? "кг" : "шт",
    c: classify(null, it.title),
    e: d.due_date || null,
    img: img || null,
    l: it.web_url || null,
  };
}

export async function fetchStoreItems(storeId, log) {
  const all = [];
  for (let page = 1; page <= MAX_PAGES; page++) {
    const j = await fetchJSON(`${API}/stores/${storeId}/products/filter_by_category/promotions/?page=${page}&per_page=100`,
      { headers: { "Accept-Language": "uk" } });
    const res = j.results || [];
    all.push(...res);
    if (res.length < 100 || all.length >= (j.count || 0)) break;
  }
  log(`магазин ${storeId}: ${all.length} промо`);
  const seen = new Set();
  return all.map(normalize).filter(x => x && !seen.has(x.id) && seen.add(x.id));
}
