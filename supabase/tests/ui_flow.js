// Drives the built PWA (localhost:8080) against LOCAL Supabase: driver, rider, admin on separate phones.
// Needs: npm i playwright-core, Chrome installed, supabase/tests/make_local_admin.sh run, app served on :8080.
const { chromium } = require('playwright-core');
const path = require('path');
const OUT = path.join(__dirname, 'shots');
const BASE = 'http://localhost:8080/';
let step = 0, fails = 0;

async function phone(browser, geo) {
  const ctx = await browser.newContext({
    viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true,
    ...(geo ? { geolocation: geo, permissions: ['geolocation'] } : {}),
  });
  const page = await ctx.newPage();
  page.on('pageerror', (e) => console.log('  [pageerror]', e.message));
  page.on('console', (m) => { if (m.type() === 'error') console.log('  [console]', m.text().slice(0, 200)); });
  return page;
}

async function open(page, hash = '') {
  await page.goto(BASE + hash);
  await page.waitForSelector('flt-semantics-placeholder, flt-semantics-host', { state: 'attached', timeout: 60000 });
  await page.waitForTimeout(1500);
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await page.waitForTimeout(800);
}

async function shot(page, name) {
  await page.waitForTimeout(700);
  await page.screenshot({ path: path.join(OUT, `${String(++step).padStart(2, '0')}-${name}.png`) });
}

async function tap(page, re, nth = 0) {
  const el = page.getByRole('button', { name: re }).nth(nth);
  await el.waitFor({ timeout: 15000 });
  await el.click();
  await page.waitForTimeout(900);
}

async function type(page, labelRe, text) {
  const el = page.getByRole('textbox', { name: labelRe }).first();
  await el.waitFor({ timeout: 15000 });
  await el.click();
  await page.keyboard.type(text, { delay: 30 });
}

const allText = () => {
  const host = document.querySelector('flt-semantics-host');
  if (!host) return '';
  const labels = [...host.querySelectorAll('[aria-label]')].map((e) => e.getAttribute('aria-label'));
  return host.innerText + ' ' + labels.join(' ');
};

async function expectText(page, re, what) {
  try {
    await page.waitForFunction(([src, fn]) => new RegExp(src).test(eval(fn)()), [re.source, allText.toString()], { timeout: 20000 });
    console.log('  PASS', what);
  } catch {
    fails++;
    console.log('  FAIL', what, '| visible:', (await page.evaluate((fn) => eval(fn)(), allText.toString())).replace(/\s+/g, ' ').slice(0, 400));
  }
}

(async () => {
  require('fs').mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch({ executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: true });

  console.log('driver phone');
  const drv = await phone(browser, { latitude: 9.5480, longitude: 44.0700 });
  await open(drv, '#/driver/login');
  await shot(drv, 'driver-login');
  await type(drv, /phone|telefoon/i, '634100012');
  await type(drv, /PIN/, '1234');
  await tap(drv, /^Gal/);
  await expectText(drv, /Salaan, Cali/, 'driver signs in with phone + PIN');
  await shot(drv, 'driver-villages');
  await tap(drv, /Jigjiga Yar/);
  await expectText(drv, /Ku biir tuuladan/, 'destination step');
  await shot(drv, 'driver-destination');
  await tap(drv, /^Masalaha/);
  await tap(drv, /Ku biir oo bilow/);
  await expectText(drv, /Jigjiga Yar → Masalaha/, 'driver is live in Jigjiga Yar → Masalaha');
  await drv.waitForTimeout(3000);
  await shot(drv, 'driver-driving');

  console.log('rider phone');
  const rider = await phone(browser, null);
  await open(rider);
  await shot(rider, 'rider-welcome');
  await tap(rider, /^Bilow/);
  await tap(rider, /26 Juun/);
  await expectText(rider, /Xagee joogtaa/, 'rider step 2: where are you');
  await tap(rider, /Jigjiga Yar/);
  await tap(rider, /Masalaha/);
  await expectText(rider, /Bas 12 · Cali/, 'rider sees driver Cali on bus 12 in the list');
  await rider.waitForTimeout(4000);
  await shot(rider, 'rider-live-map');
  await tap(rider, /^Waan sugayaa/);
  await shot(rider, 'rider-wait-sheet');
  await tap(rider, /Haa, waan sugayaa/);
  await expectText(rider, /Darawalladu way ku arkaan/, 'rider is counted as waiting');
  await shot(rider, 'rider-waiting');

  console.log('driver sees the rider');
  await expectText(drv, /Isgoyska weyn/, 'driver stop list');
  const n = await drv.evaluate(() => document.querySelector('flt-semantics-host')?.innerText || '');
  console.log(/\b1\b/.test(n) ? '  PASS driver count shows 1 waiting' : '  FAIL driver count', n.replace(/\s+/g, ' ').slice(0, 200));
  await shot(drv, 'driver-sees-waiting');

  console.log('bus detail');
  await rider.bringToFront();
  await rider.waitForTimeout(1500);
  console.log('  rider sees:', (await rider.evaluate((fn) => eval(fn)(), allText.toString())).replace(/\s+/g, ' ').slice(0, 500));
  console.log('  bus_live:', require('child_process').execSync('docker exec supabase_db_buswhere psql -U postgres -tAc "select bus_number, online, now()-updated_at from bus_live"').toString().trim());
  await rider.screenshot({ path: path.join(OUT, 'before-detail.png') });
  for (let i = 0; i < 2; i++) {
    const box = { x: 195, y: 495 }; // the bus card, under the 'you are waiting' card (see before-detail.png)
    await rider.mouse.click(box.x, box.y);
    await rider.waitForTimeout(1200);
  }
  await expectText(rider, /HR 4884/, 'bus detail shows the plate');
  await shot(rider, 'rider-bus-detail');

  console.log('admin');
  const adm = await phone(browser, null);
  await open(adm, '#/admin');
  await type(adm, /Email/, 'admin@buswhere.test');
  await type(adm, /Furaha|Password/, 'pilot-admin-pass');
  await tap(adm, /^Gal/);
  await expectText(adm, /Jigjiga Yar/, 'admin sees villages');
  await shot(adm, 'admin-places');
  await tap(adm, /Darawal/);
  await expectText(adm, /Cali · Bas 12/, 'admin sees Cali on bus 12');
  await shot(adm, 'admin-drivers');
  await tap(adm, /Toos/);
  await adm.waitForTimeout(3000);
  await shot(adm, 'admin-live');

  console.log(`\nUI flow done, ${fails} failed checks. Screenshots in ${OUT}`);
  await browser.close();
  process.exit(fails ? 1 : 0);
})().catch((e) => { console.error('CRASH', e); process.exit(2); });
