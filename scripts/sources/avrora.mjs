import { fetchText, splitBy, pick, stripTags, num, round2, decode, sleep } from "../lib.mjs";
import { classify } from "../categories.mjs";

export const id = "avrora";
export const name = "Аврора";

const LIST = "https://avrora.ua/vsi-tovary/";
const QS = "?features_hash=92-Y&items_per_page=96"; // фільтр «Товари зі знижками»

// Чиста функція: HTML сторінки каталогу → товари.
export function parsePage(html) {
  const out = [];
  for (const chunk of splitBy(html, 'class="ty-grid-list__item ')) {
    const pid = pick(chunk, /data-product-id="(\d+)"/);
    if (!pid) continue;
    const title = stripTags(pick(chunk, /class="product-title"[^>]*>([\s\S]*?)<\/a>/));
    const href = pick(chunk, /<a href="(https:\/\/avrora\.ua\/[^"]+)" class="product-title"/) ||
                 pick(chunk, /<a href="(https:\/\/avrora\.ua\/[^"]+)"/);
    const old = num(pick(chunk, new RegExp(`id="sec_list_price_${pid}"[^>]*>([^<]+)<`)));
    const price = num(pick(chunk, new RegExp(`id="sec_discounted_price_${pid}"[^>]*>([^<]+)<`)));
    const img = pick(chunk, /data-src="(https:\/\/images\.avrora\.ua\/[^"]+)"/);
    const vid = decode(pick(chunk, /<li>Вид:\s*([^<]+)<\/li>/) || "").trim();
    if (!title || !price || !old || old <= price) continue;
    out.push({
      id: pid,
      t: title,
      p: round2(price),
      o: round2(old),
      u: "шт",
      sc: vid,
      e: null,
      img: img || null,
      l: href || null,
    });
  }
  return out;
}

export async function fetchItems(log) {
  const all = new Map();
  for (let p = 1; p <= 120; p++) {
    const url = `${LIST}${p > 1 ? `page-${p}/` : ""}${QS}`;
    let html;
    try { html = await fetchText(url); }
    catch (e) {
      log(`p${p}: ${e.message}`);
      if (p === 1) throw e;
      break;
    }
    const items = parsePage(html);
    const fresh = items.filter(i => !all.has(i.id));
    // у кожній сторінці є блок «рекомендовані» (≈12 шт) — він повторюється, тож поріг > 0
    if (fresh.length === 0 || (p > 1 && fresh.length < 3 && items.length < 30)) break;
    for (const i of fresh) all.set(i.id, i);
    await sleep(300);
  }
  log(`зі знижкою: ${all.size}`);
  return [...all.values()].map(i => {
    const { sc, ...rest } = i;
    return { ...rest, c: classify(sc, i.t, true) };
  });
}
