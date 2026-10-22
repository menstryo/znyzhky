// Порівняння цін: шукаємо той самий товар в інших мережах і дописуємо кожному товару поле
//   m: [[магазин, id, ціна], ...]
// Для міських мереж (Metro, Novus, ЕКО) магазин записуємо як «metro-*» — застосунок підставить
// магазин вибраного міста й візьме ціну звідти (EAN-и в Zakaz однакові в усіх містах).
//
// Збіг = однакова фасовка (вага/об'єм) + схожа назва: зважений Жаккар за токенами,
// де рідкісні слова (бренд, сорт) важать більше за загальні («молоко», «пакет»).

const STOP = new Set(`з зі із та і й в у на до для по без від ст тм шт уп упак упаковка пакет пет скло
  ж/б жб з/б зб пл пляшка асортименті асортимент різні банка коробка дой-пак дойпак ваг вагова ваговий фасований фасована
  of the and with мл л г гр кг см ш т`.split(/\s+/));

const SIZE_RE = /(\d+(?:[.,]\d+)?)\s*(кг|kg|гр|г|g|мл|ml|л|l|шт)(?![\p{L}])/iu;
const MULTI_RE = /(\d+)\s*[xх×*]\s*(\d+(?:[.,]\d+)?)\s*(кг|гр|г|мл|л|шт)(?![\p{L}])/iu;

function sizeOf(text) {
  if (!text) return null;
  let m = MULTI_RE.exec(text);
  let mult = 1, v, u;
  if (m) { mult = +m[1]; v = parseFloat(m[2].replace(",", ".")); u = m[3].toLowerCase(); }
  else {
    m = SIZE_RE.exec(text);
    if (!m) return null;
    v = parseFloat(m[1].replace(",", ".")); u = m[2].toLowerCase();
  }
  if (!(v > 0)) return null;
  if (u === "кг" || u === "kg") return { k: "g", v: v * 1000 * mult };
  if (u === "г" || u === "гр" || u === "g") return { k: "g", v: v * mult };
  if (u === "л" || u === "l") return { k: "ml", v: v * 1000 * mult };
  if (u === "мл" || u === "ml") return { k: "ml", v: v * mult };
  return { k: "pc", v: v * mult };
}

const norm = s => s.toLowerCase()
  .replace(/[’'`ʼ"«»“”]/g, "")
  .replace(/ё/g, "е")
  .replace(/(\d)[.,](\d)/g, "$1.$2");

function tokensOf(title) {
  const t = norm(title)
    .replace(MULTI_RE, " ")
    .replace(new RegExp(SIZE_RE.source, "giu"), " ")
    .replace(/\d+(\.\d+)?\s*%/g, m => " " + m.replace(/\s/g, "") + " ");   // 2,5% — важливий токен
  const out = new Set();
  for (const w of t.split(/[^\p{L}\p{N}%.]+/u)) {
    const x = w.replace(/^\.+|\.+$/g, "");
    if (x.length < 2 || STOP.has(x)) continue;
    if (/^\d+$/.test(x) && x.length < 2) continue;
    out.add(x);
  }
  return out;
}

const pctOf = toks => [...toks].filter(t => /%$/.test(t)).sort().join(",");
const RARE_DF = 30;
const RARE_DF2 = 250;  // «особливе» слово з обох боків одразу — різні варіанти   // слово, що трапляється рідше, — «розпізнавальне» (бренд, смак, сорт)

const chainOf = storeId => storeId.replace(/-[a-z]+$/, "");

// stores: [{ id, city?, items }]
export function addComparisons(stores, log = () => {}) {
  const all = [];
  for (const st of stores) {
    const chain = st.city ? chainOf(st.id) : st.id;
    for (const it of st.items) {
      const size = sizeOf(it.t) || (it.u && it.u !== "кг" && it.u !== "шт" ? sizeOf(it.u) : null);
      const toks = tokensOf(it.t);
      if (toks.size < 2) continue;
      all.push({ st, chain, city: st.city || null, it, size, toks });
    }
  }
  // df і інвертований індекс
  // df рахуємо по унікальних назвах: Metro в 12 містах не повинен робити слово «частим»
  const df = new Map();
  const uniq = new Set();
  for (const a of all) {
    const u = `${a.chain}|${a.it.t}`;
    if (uniq.has(u)) continue;
    uniq.add(u);
    for (const t of a.toks) df.set(t, (df.get(t) || 0) + 1);
  }
  const N = all.length;
  const idf = t => Math.log(1 + N / (df.get(t) || 1));
  const index = new Map();
  for (let i = 0; i < all.length; i++) {
    const a = all[i];
    // індексуємо 3 найрідкісніші токени — кандидати мають збігатися хоч з одним
    a.rare = [...a.toks].sort((x, y) => df.get(x) - df.get(y)).slice(0, 3);
    a.wsum = [...a.toks].reduce((s, t) => s + idf(t), 0);
    a.pct = pctOf(a.toks);
    for (const t of a.rare) {
      if (!index.has(t)) index.set(t, []);
      index.get(t).push(i);
    }
  }

  const sameSize = (x, y) => {
    if (!x || !y) return !x && !y;
    return x.k === y.k && Math.abs(x.v - y.v) <= Math.max(x.v, y.v) * 0.02;
  };

  let matched = 0;
  for (let i = 0; i < all.length; i++) {
    const a = all[i];
    const seen = new Set();
    const best = new Map();   // ключ магазину → { score, b }
    for (const t of a.rare) {
      for (const j of index.get(t) || []) {
        if (j === i || seen.has(j)) continue;
        seen.add(j);
        const b = all[j];
        if (b.chain === a.chain) continue;
        // міський магазин порівнюємо лише з національними та з магазинами свого міста
        if (a.city && b.city && a.city !== b.city) continue;
        if (!sameSize(a.size, b.size)) continue;
        // різна жирність/міцність — різні товари
        if (a.pct && b.pct && a.pct !== b.pct) continue;
        let common = 0, nCommon = 0;
        for (const x of a.toks) if (b.toks.has(x)) { common += idf(x); nCommon++; }
        if (nCommon < 2) continue;
        // рідкісне слово лише з одного боку (інший бренд, смак) — не той самий товар
        // а якщо в обох назвах є свої «особливі» слова (яблуко-полуниця vs яблуко-персик) — теж ні
        let exA = Infinity, exB = Infinity;
        for (const x of a.toks) if (!b.toks.has(x)) exA = Math.min(exA, df.get(x));
        for (const x of b.toks) if (!a.toks.has(x)) exB = Math.min(exB, df.get(x));
        if (exA < RARE_DF || exB < RARE_DF) continue;
        if (exA < RARE_DF2 && exB < RARE_DF2) continue;
        const score = common / (a.wsum + b.wsum - common);
        const need = a.size ? 0.45 : 0.6;     // без фасовки — суворіше
        if (score < need) continue;
        // для національного товару всі міста однієї мережі зводимо в «metro-*»
        // міські мережі: «metro-*»; ключ з id, бо в різних містах може збігтися різний товар
        const key = b.city ? `${b.chain}-*|${b.it.id}` : b.st.id;
        const cur = best.get(key);
        if (!cur || score > cur.score || (score === cur.score && b.it.p < cur.b.it.p)) best.set(key, { score, b });
      }
    }
    if (!best.size) continue;
    const perChain = new Map();
    const list = [...best.entries()].sort((x, y) => y[1].score - x[1].score || x[1].b.it.p - y[1].b.it.p);
    const out = [];
    for (const [key, { b }] of list) {
      const k = key.split("|")[0];
      const n = perChain.get(k) || 0;
      if (n >= (b.city ? 3 : 1)) continue;   // для міських — до 3 варіантів id, застосунок візьме той, що є у вашому місті
      perChain.set(k, n + 1);
      out.push([k, b.it.id, b.it.p]);
    }
    a.it.m = out.sort((x, y) => x[2] - y[2]).slice(0, 10);
    matched++;
  }
  log(`порівняння: ${matched} з ${all.length} товарів мають відповідники в інших мережах`);
  return matched;
}

// для тестів
export { sizeOf, tokensOf };
