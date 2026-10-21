// Запасний шлях для сайтів за Cloudflare: відкриваємо сторінки у справжньому Chrome
// (на раннерах GitHub він уже встановлений) і забираємо готовий HTML.
import fs from "fs";

const CANDIDATES = [
  process.env.CHROME_PATH,
  "/usr/bin/google-chrome",
  "/usr/bin/google-chrome-stable",
  "/usr/bin/chromium",
  "/usr/bin/chromium-browser",
].filter(Boolean);

let browserPromise = null;

async function getBrowser() {
  if (browserPromise) return browserPromise;
  browserPromise = (async () => {
    const { chromium } = await import("playwright-core");
    const executablePath = CANDIDATES.find(p => fs.existsSync(p));
    if (!executablePath) throw new Error("Chrome не знайдено");
    const browser = await chromium.launch({
      executablePath,
      headless: true,
      args: ["--headless=new", "--disable-blink-features=AutomationControlled", "--no-sandbox", "--lang=uk-UA"],
    });
    const ctx = await browser.newContext({
      locale: "uk-UA",
      timezoneId: "Europe/Kyiv",
      viewport: { width: 1366, height: 900 },
      userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36",
    });
    await ctx.addInitScript(() => { Object.defineProperty(navigator, "webdriver", { get: () => undefined }); });
    return { browser, ctx };
  })();
  return browserPromise;
}

// Відкриває сторінку, чекає, поки пройде перевірка Cloudflare і з'явиться selector, повертає HTML.
export async function browserHTML(url, selector, timeout = 45000) {
  const { ctx } = await getBrowser();
  const page = await ctx.newPage();
  try {
    const resp = await page.goto(url, { waitUntil: "domcontentloaded", timeout });
    const deadline = Date.now() + timeout;
    while (Date.now() < deadline) {
      if (selector && await page.$(selector)) break;
      const title = await page.title().catch(() => "");
      if (!selector && !/just a moment|attention required/i.test(title)) break;
      await page.waitForTimeout(1500);
    }
    const html = await page.content();
    if (selector && !(await page.$(selector))) {
      const title = await page.title().catch(() => "");
      throw new Error(`${url}: немає «${selector}» (HTTP ${resp && resp.status()}, «${title}»)`);
    }
    return html;
  } finally {
    await page.close().catch(() => {});
  }
}

// Завантажує бінарний файл (картинку) з контексту браузера — з тими ж cookie, що пройшли перевірку.
export async function browserFetchBuffer(url, referer) {
  const { ctx } = await getBrowser();
  const r = await ctx.request.get(url, { headers: referer ? { Referer: referer } : {}, timeout: 20000 });
  if (!r.ok()) throw new Error(`HTTP ${r.status()}`);
  return Buffer.from(await r.body());
}

export async function closeBrowser() {
  if (!browserPromise) return;
  try { const { browser } = await browserPromise; await browser.close(); } catch {}
  browserPromise = null;
}

export const browserStarted = () => !!browserPromise;
