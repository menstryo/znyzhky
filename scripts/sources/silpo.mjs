import { fetchJSON, pool, round2 } from "../lib.mjs";
import { silpoRootCategory, classify } from "../categories.mjs";

const BRANCH = "00000000-0000-0000-0000-000000000000";
const API = "https://sf-ecom-api.silpo.ua";
const PAGE = 100;

export const id = "silpo";
export const name = "Сільпо";

function productsUrl(offset) {
  return `${API}/v1/uk/branches/${BRANCH}/products?limit=${PAGE}&offset=${offset}` +
    `&deliveryType=DeliveryHome&includeChildCategories=true&sortBy=productsList&sortDirection=desc` +
    `&inStock=true&mustHavePromotion=true`;
}

// slug → { root, path }
async function loadTree() {
  const j = await fetchJSON(`${API}/v1/branches/${BRANCH}/categories/tree?deliveryType=DeliveryHome&depth=6`);
  const map = new Map();
  const walk = (nodes, root, path) => {
    for (const n of nodes || []) {
      const r = root || n.slug;
      const p = path ? `${path}>${n.slug}` : n.slug;
      const cur = map.get(n.slug);
      // слаг може бути в кількох гілках (спецпропозиції, власні марки) — перевага «справжній» гілці
      const curKnown = cur && silpoRootCategory(cur.root, cur.path);
      if (!cur || (!curKnown && silpoRootCategory(r, p))) map.set(n.slug, { root: r, path: p });
      walk(n.children, r, p);
    }
  };
  walk(j.items, null, "");
  return map;
}

export function normalize(it, tree) {
  const price = it.displayPrice ?? it.price;
  const old = it.displayOldPrice ?? it.oldPrice;
  if (!price || !old || old <= price) return null;
  const node = tree && tree.get(it.sectionSlug);
  let cat = node ? silpoRootCategory(node.root, node.path) : null;
  if (!cat) cat = classify(null, it.title);
  return {
    id: String(it.externalProductId || it.id),
    t: it.title,
    p: round2(price),
    o: round2(old),
    u: it.displayRatio || it.ratio || "",
    c: cat,
    e: null,
    img: it.icon ? `https://images.silpo.ua/v2/products/300x300/webp/${it.icon}` : null,
    l: it.slug ? `https://silpo.ua/product/${it.slug}` : null,
  };
}

export async function fetchItems(log) {
  let tree = null;
  try {
    tree = await loadTree();
    log(`дерево категорій: ${tree.size}`);
  } catch (e) {
    log(`дерево категорій недоступне (${e.message}), класифікую за назвами`);
  }
  const first = await fetchJSON(productsUrl(0));
  const total = Math.min(first.total || 0, 20000);
  const offsets = [];
  for (let o = PAGE; o < total; o += PAGE) offsets.push(o);
  const pages = await pool(offsets, 4, async o => {
    try { return (await fetchJSON(productsUrl(o))).items || []; }
    catch (e) { log(`сторінка ${o}: ${e.message}`); return []; }
  });
  const raw = [first.items || [], ...pages].flat();
  log(`промо-товарів: ${raw.length} з ${first.total}`);
  return raw.map(it => normalize(it, tree)).filter(Boolean);
}
