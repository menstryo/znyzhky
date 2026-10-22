import { chromium } from "playwright-core";
import fs from "fs";
const exe = ["/usr/bin/google-chrome", "/usr/bin/google-chrome-stable"].find(p => fs.existsSync(p));
const browser = await chromium.launch({ executablePath: exe, headless: true, args: ["--headless=new", "--disable-blink-features=AutomationControlled", "--no-sandbox"] });
const ctx = await browser.newContext({ locale: "uk-UA", userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36", viewport: { width: 1366, height: 900 } });
await ctx.addInitScript(() => { Object.defineProperty(navigator, "webdriver", { get: () => undefined }); });
const page = await ctx.newPage();
const reqs = [];
let sample = null;
page.on("request", r => {
  if (/EcomCatalogGlobal/.test(r.url())) reqs.push(`REQ ${r.url()}\nHEADERS ${JSON.stringify(r.headers())}\nBODY ${r.postData()}\n`);
});
page.on("response", async r => {
  if (/EcomCatalogGlobal/.test(r.url())) {
    const t = await r.text().catch(() => "");
    if (/oldPrice/.test(t) && !sample) { sample = { body: r.request().postData(), headers: r.request().headers() }; fs.writeFileSync("sample-resp.json", t); }
  }
});
await page.goto("https://fora.ua/all-offers", { waitUntil: "networkidle", timeout: 60000 }).catch(e => reqs.push("ERR " + e.message));
await page.waitForTimeout(4000);
fs.writeFileSync("req.txt", reqs.join("\n"));
// plain fetch (no browser) with same body
if (sample) {
  const h = { "content-type": "application/json", "user-agent": "Mozilla/5.0 Chrome/130" };
  for (const k of Object.keys(sample.headers)) if (!/^(cookie|sec-|accept-encoding|content-length)/i.test(k) && !k.startsWith(":")) h[k] = sample.headers[k];
  try {
    const r = await fetch("https://api.catalog.ecom.fora.ua/api/2.0/exec/EcomCatalogGlobal", { method: "POST", headers: h, body: sample.body });
    const t = await r.text();
    fs.writeFileSync("plain.txt", `HTTP ${r.status}\nheaders sent ${JSON.stringify(h)}\n${t.slice(0, 3000)}`);
  } catch (e) { fs.writeFileSync("plain.txt", "ERR " + e.message); }
}
await browser.close();
