import { fetchText, splitBy, pick, stripTags, num, round2, dayMonthToISO, decode, sleep } from "../lib.mjs";
import { classify } from "../categories.mjs";
import { browserHTML } from "../browser.mjs";

export const id = "atb";
export const name = "АТБ";

const BASE = "https://www.atbmarket.com";
// «Економія», «Суперціна», «Вигода з АТБільше»
const PROMOS = ["economy", "sale_tovari", "znyzhky"];

// Чиста функція: HTML сторінки акцій → товари (працює і в Node, і в браузері).
export function parsePage(html, now = new Date()) {
  const out = [];
  for (const chunk of splitBy(html, '<article class="').slice(0)) {
    if (!/catalog-item/.test(chunk.slice(0, 200))) continue;
    const pid = pick(chunk, /data-productid="(\d+)"/);
    const storeCat = decode(pick(chunk, /data-category="([^"]*)"/) || "");
    const href = pick(chunk, /<div class="catalog-item__title[^"]*">\s*<a href="([^"]+)"/);
    const title = stripTags(pick(chunk, /<div class="catalog-item__title[^"]*">([\s\S]*?)<\/div>/));
    // перший блок цін (видимий); другий — прихований «за шт» для вагових
    const priceBlock = pick(chunk, /(<div class="catalog-item__product-price[^"]*"[\s\S]*?<\/div>)/) || "";
    const price = num(pick(priceBlock, /<data value="([\d.]+)" class="product-price__top"/));
    const old = num(pick(priceBlock, /<data value="([\d.]+)" class="product-price__bottom"/));
    const unit = stripTags(pick(priceBlock, /<span class="product-price__unit">([^<]*)<\/span>/) || "").replace(/^\//, "");
    const img = pick(chunk, /<img src="(https:\/\/[^"]+\.(?:jpg|jpeg|png))"/i);
    const dm = /custom-product-label__date">\s*до\s*(\d{1,2})\.(\d{1,2})/.exec(chunk);
    if (!pid || !title || !price || !old || old <= price) continue;
    out.push({
      id: pid,
      t: title,
      p: round2(price),
      o: round2(old),
      u: unit || "шт",
      sc: storeCat,
      e: dm ? dayMonthToISO(dm[1], dm[2], now) : null,
      img: img || null,
      l: href ? BASE + href : null,
    });
  }
  return out;
}

export async function fetchItems(log) {
  const all = new Map();
  let fails = 0;
  // Cloudflare часто віддає 403 серверам GitHub — тоді переходимо на справжній Chrome
  let viaBrowser = false;
  const load = async url => {
    if (!viaBrowser) {
      try {
        return await fetchText(url, { headers: { Referer: BASE + "/" }, tries: 2 });
      } catch (e) {
        if (!/HTTP 403|HTTP 503|Cloudflare/.test(e.message)) throw e;
        log(`${e.message} — перемикаюсь на браузер`);
        viaBrowser = true;
      }
    }
    return browserHTML(url, "article.catalog-item");
  };
  for (const promo of PROMOS) {
    let added = 0;
    for (let p = 1; p <= 80; p++) {
      let html;
      try {
        html = await load(`${BASE}/promo/${promo}${p > 1 ? "?page=" + p : ""}`);
      } catch (e) {
        log(`${promo} p${p}: ${e.message}`);
        fails++;
        break;
      }
      const items = parsePage(html);
      const fresh = items.filter(i => !all.has(i.id));
      // за останньою сторінкою сайт повертає ту саму — зупиняємось, коли нових немає
      if (!fresh.length) break;
      for (const i of fresh) all.set(i.id, i);
      added += fresh.length;
      await sleep(viaBrowser ? 800 : 400);
    }
    log(`${promo}: +${added}${viaBrowser ? " (через браузер)" : ""}`);
  }
  if (!all.size && fails) throw new Error("усі запити до АТБ не вдалися");
  return [...all.values()].map(i => {
    const { sc, ...rest } = i;
    return { ...rest, c: classify(sc, i.t) };
  });
}
