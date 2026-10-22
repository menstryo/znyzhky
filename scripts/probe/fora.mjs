import { chromium } from "playwright-core";
import fs from "fs";
const exe = ["/usr/bin/google-chrome", "/usr/bin/google-chrome-stable"].find(p => fs.existsSync(p));
const browser = await chromium.launch({ executablePath: exe, headless: true, args: ["--headless=new", "--disable-blink-features=AutomationControlled", "--no-sandbox"] });
const ctx = await browser.newContext({ locale: "uk-UA", userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36", viewport: { width: 1366, height: 900 } });
await ctx.addInitScript(() => { Object.defineProperty(navigator, "webdriver", { get: () => undefined }); });
const page = await ctx.newPage();
const reqs = [];
page.on("response", async r => {
  const u = r.url(); const t = r.request().resourceType();
  if (t === "xhr" || t === "fetch") {
    let body = ""; try { body = (await r.text()).slice(0, 1500); } catch {}
    reqs.push(`${r.status()} ${r.request().method()} ${u}\n${body}\n`);
  }
});
const urls = ["https://fora.ua/", "https://fora.ua/about/news/fora-club-deis-znizhki-do-60-lishe-dlia-svoyikh", "https://fora.ua/promotions", "https://fora.ua/category/akcii", "https://fora.ua/special-offers"];
for (const u of urls) {
  try {
    await page.goto(u, { waitUntil: "networkidle", timeout: 60000 });
  } catch (e) { reqs.push(`GOTO ERR ${u} ${e.message}`); }
  await page.waitForTimeout(4000);
  const links = await page.$$eval("a[href]", as => [...new Set(as.map(a => a.href))]).catch(() => []);
  fs.appendFileSync("links.txt", `== ${u} title=${await page.title()}\n${links.join("\n")}\n`);
  fs.writeFileSync(`page-${urls.indexOf(u)}.html`, await page.content());
}
fs.writeFileSync("xhr.txt", reqs.join("\n"));
await browser.close();
