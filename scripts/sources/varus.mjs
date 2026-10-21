import { fetchJSON, pool, round2, todayISO } from "../lib.mjs";
import { classify } from "../categories.mjs";

export const id = "varus";
export const name = "Varus";

const API = "https://varus.ua/api/catalog/vue_storefront_catalog_2/product_v2/_search";
const PAGE = 500;
const MAX = 10000; // вікно Elasticsearch

function url(from) {
  const q = {
    _appliedFilters: [
      { attribute: "sqpp_data_region_default.special_price_discount", value: { gte: 3 }, scope: "default" },
      { attribute: "sqpp_data_region_default.in_stock", value: { eq: true }, scope: "default" },
      { attribute: "visibility", value: { in: [2, 3, 4] }, scope: "default" },
      { attribute: "status", value: { in: [0, 1] }, scope: "default" },
    ],
    _availableFilters: [],
    _appliedSort: [{ field: "sqpp_data_region_default.special_price_discount", options: "desc" }],
    _searchText: "",
  };
  const fields = "name,sku,url_key,fv_image_timestamp,category,sqpp_data_region_default,weight,volume,packingtype";
  return `${API}?from=${from}&size=${PAGE}&request_format=search-query&response_format=compact&shop_id=3` +
    `&_source_include=${fields}&request=${encodeURIComponent(JSON.stringify(q))}`;
}

export function normalize(h, today = todayISO()) {
  const d = h.sqpp_data_region_default || {};
  const old = d.price, price = d.special_price;
  if (!price || !old || old <= price) return null;
  if (d.special_price_to_date && d.special_price_to_date < today) return null;
  if (d.special_price_from_date && d.special_price_from_date > today) return null;
  const cats = (h.category || []).filter(c => c.is_product_category);
  const l2 = cats.find(c => c.level === 2), l3 = cats.find(c => c.level === 3);
  const storeCat = [l2 && l2.name, l3 && l3.name].filter(Boolean).join(" > ");
  let end = d.special_price_to_date || null;
  if (end && end > "2040") end = null; // «безстрокові» акції
  return {
    id: String(h.sku),
    t: String(h.name || "").trim(),
    p: round2(price),
    o: round2(old),
    u: h.packingtype === 1 ? "кг" : "шт",
    c: classify(storeCat, h.name),
    e: end,
    img: h.sku ? `https://varus.ua/img/product/300/300/${h.sku}${h.fv_image_timestamp ? "?t=" + h.fv_image_timestamp : ""}` : null,
    l: h.url_key ? `https://varus.ua/${h.url_key}` : null,
  };
}

export async function fetchItems(log) {
  const first = await fetchJSON(url(0));
  const total = Math.min((first.total && first.total.value) || first.total || 0, MAX);
  const froms = [];
  for (let f = PAGE; f < total; f += PAGE) froms.push(f);
  const pages = await pool(froms, 3, async f => {
    try { return (await fetchJSON(url(f))).hits || []; }
    catch (e) { log(`from=${f}: ${e.message}`); return []; }
  });
  const raw = [first.hits || [], ...pages].flat();
  log(`промо-товарів: ${raw.length}`);
  const today = todayISO();
  const seen = new Set();
  return raw.map(h => normalize(h, today)).filter(x => x && !seen.has(x.id) && seen.add(x.id));
}
