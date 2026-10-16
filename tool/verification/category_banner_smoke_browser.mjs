/** Real locally served Admin/Flutter builds, real isolated Django APIs, no mock HTML/API. */
import { chromium } from '/home/shohjahon/.cache/ms-playwright-go/1.57.0/package/index.mjs';
import { createServer } from 'node:http';
import { readFile, mkdir, stat, writeFile } from 'node:fs/promises';
import { resolve, extname, join } from 'node:path';
import assert from 'node:assert/strict';

const root = resolve(import.meta.dirname, '../..');
const smoke = resolve(process.env.CATEGORY_BANNER_SMOKE_ROOT || join(root, 'build/category-banner-smoke/20261016-live01'));
assert(smoke.startsWith(join(root, 'build/category-banner-smoke/')));
const seed = JSON.parse(await readFile(join(smoke, 'seed.json'), 'utf8'));
const mode = process.argv[2] || 'admin';
const attempt = process.argv[3] || '01';
const output = join(smoke, `${mode}-${attempt}`);
await mkdir(output, { recursive: true });

const mime = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.png': 'image/png', '.webp': 'image/webp', '.svg': 'image/svg+xml', '.wasm': 'application/wasm', '.woff2': 'font/woff2', '.ttf': 'font/ttf', '.bin': 'application/octet-stream' };
async function staticServer(directory, port) {
  const server = createServer(async (request, response) => {
    try {
      const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
      let file = resolve(directory, `.${pathname}`);
      if (!file.startsWith(`${directory}/`) && file !== directory) throw Error('Path rejected');
      try { if ((await stat(file)).isDirectory()) file = join(file, 'index.html'); } catch { file = join(directory, 'index.html'); }
      response.writeHead(200, { 'Content-Type': mime[extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-store' });
      response.end(await readFile(file));
    } catch { response.writeHead(404); response.end('Not found'); }
  });
  await new Promise((ready) => server.listen(port, '127.0.0.1', ready));
  return server;
}

const adminServer = await staticServer(resolve(root, '../Admin_panel2/dist'), 8878);
const webServer = await staticServer(resolve(root, 'build/web'), 8879);
const browser = await chromium.launch({ executablePath: '/usr/bin/google-chrome', headless: true, args: ['--no-sandbox', '--disable-dev-shm-usage', '--enable-unsafe-swiftshader'] });
const apiLog = [];
async function wire(context) {
  await context.route(/https:\/\/api\.beshkashtan\.uz\/api\//, async (route) => {
    const request = route.request();
    const original = new URL(request.url());
    const result = await route.fetch({ url: `http://127.0.0.1:8877${original.pathname}${original.search}` });
    apiLog.push({ method: request.method(), path: original.pathname + original.search, status: result.status() });
    await route.fulfill({ response: result, headers: { ...result.headers(), 'access-control-allow-origin': '*', 'access-control-allow-headers': '*' } });
  });
}

try {
  if (mode === 'admin') {
    const setup = await browser.newContext({ viewport: { width: 1366, height: 900 } });
    await wire(setup);
    const login = await setup.newPage();
    await login.goto('http://127.0.0.1:8878/login');
    await login.getByLabel('Telefon raqam', { exact: true }).fill('+998900000001');
    await login.getByLabel('Parol', { exact: true }).fill('LocalSmokeOnly-2026');
    await login.getByRole('button', { name: 'Kirish', exact: true }).click();
    await login.waitForURL('**/dashboard', { timeout: 30000 });
    const state = await setup.storageState();
    await setup.close();
    const context = await browser.newContext({ storageState: state, viewport: { width: 1366, height: 900 }, recordVideo: { dir: output, size: { width: 1366, height: 900 } } });
    await wire(context);
    const page = await context.newPage();
    await page.goto('http://127.0.0.1:8878/category-product-banners');
    await page.getByRole('button', { name: 'Yangi reklama' }).click();
    const form = page.locator('#category-banner-editor');
    await form.locator('select').nth(0).selectOption(seed.categories[0].id);
    await form.locator('select').nth(1).selectOption(seed.products[2].id, { timeout: 20000 });
    await form.getByRole('textbox', { name: 'Sarlavha (uz)', exact: true }).fill('Uy ta’miringiz uchun qulay tanlov');
    await form.getByRole('textbox', { name: 'Izoh (uz)', exact: true }).fill('Qurilish va ta’mirlash uchun kerakli mahsulotlar');
    await form.getByRole('textbox', { name: 'Badge (uz)', exact: true }).fill('Yangi taklif');
    await form.getByRole('textbox', { name: 'Tugma matni (uz)', exact: true }).fill('Batafsil ko‘rish');
    await page.waitForTimeout(1200);
    await page.screenshot({ path: join(output, 'admin_category_banner_preview.png') });
    const saved = page.waitForResponse((res) => res.url().includes('/category-product-banners/') && res.request().method() === 'POST');
    await page.getByRole('button', { name: 'Saqlash', exact: true }).click();
    assert.equal((await saved).status(), 201);
    await page.getByRole('button', { name: 'Uy ta’miringiz uchun qulay tanlov tahrirlash', exact: true }).click();
    await page.locator('#category-banner-editor').getByRole('textbox', { name: 'Badge (uz)', exact: true }).fill('Ustalar tanlovi');
    const edited = page.waitForResponse((res) => res.url().includes('/category-product-banners/') && res.request().method() === 'PATCH');
    await page.getByRole('button', { name: 'Saqlash', exact: true }).click();
    assert.equal((await edited).status(), 200);
    await page.getByText('Uy ta’miringiz uchun qulay tanlov', { exact: true }).waitFor();
    await page.waitForTimeout(1000);
    await page.screenshot({ path: join(output, 'admin_category_banner_saved.png') });
    const video = page.video();
    await context.close();
    console.log(JSON.stringify({ status: 'passed', mode, screenshots: output, video: await video.path() }));
  } else {
    const context = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 1, isMobile: true, hasTouch: true, recordVideo: { dir: output, size: { width: 390, height: 844 } } });
    await wire(context);
    await context.addInitScript(() => {
      localStorage.setItem('flutter.app.locale_code', JSON.stringify('uz'));
      localStorage.setItem('flutter.app.onboarding_seen', 'true');
    });
    const page = await context.newPage();
    page.on('pageerror', (error) => console.log('PAGE_ERROR', error.message.replace(/pk\.[\w.-]+/g, '[token]')));
    await page.goto(`http://127.0.0.1:8879/#/store/household/catalog/category/${seed.categories[0].id}`);
    await page.locator('flutter-view').waitFor({ timeout: 30000 });
    for (let tick = 0; tick < 200 && !apiLog.some((item) => item.path.includes(`/categories/${seed.categories[0].id}/banners/`) && item.status === 200); tick++) await page.waitForTimeout(100);
    await page.waitForTimeout(1200);
    if (mode === 'focus-canvas') {
      await page.mouse.click(130, 385);
      const before = await page.evaluate(() => ({ tag: document.activeElement?.tagName, value: document.activeElement?.value }));
      await page.keyboard.type('u');
      await page.waitForTimeout(700);
      const after = await page.evaluate(() => ({ tag: document.activeElement?.tagName, value: document.activeElement?.value }));
      await page.keyboard.type('stachilik', { delay: 60 });
      await page.waitForTimeout(700);
      console.log(JSON.stringify({ mode, before, after, inputs: await page.locator('input,textarea').evaluateAll((nodes) => nodes.map((node) => ({ tag: node.tagName, value: node.value }))) }));
      await page.screenshot({ path: join(output, 'canvas_focus_debug.png') });
      await context.close();
    } else {
    await page.locator('flt-semantics-placeholder').evaluateAll((elements) => elements.forEach((element) => element.click()));
    await page.getByRole('textbox', { name: 'Shu kategoriyadan mahsulot qidirish…' }).waitFor({ timeout: 15000 });
    for (let tick = 0; tick < 300 && !['/recommendations/for-you/', '/catalog/products/?', '/stores/household/landing/', '/cart/?'].every((path) => apiLog.some((item) => item.path.includes(path) && item.status === 200)); tick++) await page.waitForTimeout(100);
    await page.waitForTimeout(600);
    if (mode === 'focus') {
      const field = page.getByRole('textbox', { name: 'Shu kategoriyadan mahsulot qidirish…' });
      await field.click();
      const before = await page.evaluate(() => ({ tag: document.activeElement?.tagName, label: document.activeElement?.getAttribute('aria-label'), value: document.activeElement?.value }));
      await page.keyboard.type('u');
      await page.waitForTimeout(700);
      const after = await page.evaluate(() => ({ tag: document.activeElement?.tagName, label: document.activeElement?.getAttribute('aria-label'), value: document.activeElement?.value }));
      await page.keyboard.type('stachilik', { delay: 60 });
      await page.waitForTimeout(700);
      console.log(JSON.stringify({ mode, before, after, inputs: await page.locator('input,textarea').evaluateAll((nodes) => nodes.map((node) => ({ tag: node.tagName, label: node.getAttribute('aria-label'), value: node.value }))) }));
      await page.screenshot({ path: join(output, 'focus_debug.png') });
      await context.close();
    } else if (mode === 'customer') {
      const startSeconds = performance.now();
      const count = page.getByText(/^[123] \/ 3$/);
      const before = await count.innerText();
      await page.screenshot({ path: join(output, 'customer_category_banner_recommendations.png') });
      await page.waitForTimeout(5700);
      assert.notEqual(await count.innerText(), before, 'Five-second automatic slide must move to another real banner');
      await page.getByRole('button', { name: 'Avvalgi sahifa', exact: true }).click();
      await page.waitForTimeout(650);
      const search = page.getByRole('textbox', { name: 'Shu kategoriyadan mahsulot qidirish…' });
      const scopedSearch = page.waitForResponse((response) => response.url().includes('q=ustachilik') && response.url().includes(`category=${seed.categories[0].id}`));
      const fallbackSearch = page.waitForResponse((response) => response.url().includes('/products/search/') && response.url().includes('q=ustachilik') && !response.url().includes('category='));
      await search.click();
      await page.keyboard.type('ustachilik', { delay: 60 });
      await page.keyboard.press('Enter');
      assert.equal((await scopedSearch).status(), 200);
      assert.equal((await fallbackSearch).status(), 200);
      await page.waitForTimeout(700);
      await page.screenshot({ path: join(output, 'customer_category_search_fallback.png') });
      await writeFile(join(output, 'search-semantics.txt'), await page.locator('body').innerText());
      assert(apiLog.some((item) => item.path.includes('q=ustachilik') && item.path.includes(`category=${seed.categories[0].id}`)), 'Search must first request the current category');
      assert(apiLog.some((item) => item.path.includes('q=ustachilik') && !item.path.includes('category=')), 'Empty scoped result must trigger Xozmak-wide fallback');
      const destination = seed.categories[1].id;
      const destinationSearch = page.waitForResponse((response) => response.url().includes(`category=${destination}`) && response.url().includes('q=ustachilik'));
      // ProductCard's canvas text is excluded from web semantics; exercise
      // the real image/card hit target, away from favorite and cart buttons.
      await page.mouse.click(90, 315);
      await page.getByRole('heading', { name: 'Ustachilik asboblari', exact: true }).waitFor();
      assert.equal((await destinationSearch).status(), 200);
      assert(apiLog.some((item) => item.path.includes(`category=${destination}`) && item.path.includes('q=ustachilik')));
      await page.waitForTimeout(700);
      await page.screenshot({ path: join(output, 'customer_destination_category.png') });
      await page.getByRole('button', { name: 'Orqaga', exact: true }).click();
      await page.getByRole('heading', { name: 'Qurilish mollari', exact: true }).waitFor();
      await page.waitForTimeout(900);
      await page.screenshot({ path: join(output, 'customer_restored_category.png') });
      await writeFile(join(output, 'back-semantics.txt'), await page.locator('body').innerText());
      // Navigator can detach the editable semantics node on return while the
      // real controller/text remains intact; click its visible clear control.
      await page.mouse.click(354, 92);
      await page.getByText('Sizga tavsiya etamiz', { exact: true }).waitFor();
      await page.getByText(/^[123] \/ 3$/).waitFor();
      await page.mouse.move(195, 745);
      await page.waitForTimeout(1000);
      await page.screenshot({ path: join(output, 'customer_search_cleared.png') });
      const video = page.video();
      await context.close();
      console.log(JSON.stringify({ status: 'passed', mode, screenshots: output, video: await video.path(), actionDurationSeconds: (performance.now() - startSeconds) / 1000 }));
    } else {
      await page.screenshot({ path: join(output, 'customer_initial_inspection.png') });
      await writeFile(join(output, 'semantics.txt'), await page.locator('body').innerText());
      await writeFile(join(output, 'dom.html'), await page.content());
      console.log(JSON.stringify({ status: 'inspected', url: page.url(), body: (await page.locator('body').innerText()).slice(0, 8000) }));
      await context.close();
    }
    }
  }
} finally {
  await writeFile(join(output, 'api-requests.json'), JSON.stringify(apiLog, null, 2));
  await browser.close();
  adminServer.close();
  webServer.close();
}
