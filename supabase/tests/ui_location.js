// Location + "No bus available" check, against LOCAL Supabase with the app served on :8081
// (python -m http.server 8081 --directory buswhere_app/build/web_local).
// A driver 40 km away must not be offered; a rider near Dugsiga is placed in Jigjiga Yar at that stop;
// when the driver comes close, the bus appears.
const { chromium } = require('playwright-core');
const path = require('path');
const OUT = process.argv[2] || 'shots';
const BASE = 'http://localhost:8081/';
let fails = 0;

const allText = (p) => p.evaluate(() => {
  const h = document.querySelector('flt-semantics-host');
  return h ? (h.innerText + ' ' + [...h.querySelectorAll('[aria-label]')].map((e) => e.getAttribute('aria-label')).join(' ')).replace(/\s+/g, ' ') : '';
});
async function expectText(p, re, what, ms = 25000) {
  const end = Date.now() + ms;
  while (Date.now() < end) { if (re.test(await allText(p))) { console.log('  PASS', what); return; } await p.waitForTimeout(700); }
  fails++; console.log('  FAIL', what, '|', (await allText(p)).slice(0, 300));
}
async function open(p, hash = '') {
  await p.goto(BASE + hash);
  await p.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 60000 });
  await p.waitForTimeout(2000);
  await p.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await p.waitForTimeout(1000);
}
const tap = async (p, re) => { await p.getByRole('button', { name: re }).first().click(); await p.waitForTimeout(1200); };
const type = async (p, re, t) => { const e = p.getByRole('textbox', { name: re }).first(); await e.click(); await p.keyboard.type(t, { delay: 25 }); };
const shot = (p, n) => p.screenshot({ path: path.join(OUT, n + '.png') });

(async () => {
  require('fs').mkdirSync(OUT, { recursive: true });
  const b = await chromium.launch({ executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: true });
  const phone = (geo) => b.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true, geolocation: geo, permissions: ['geolocation'] });

  console.log('driver 40 km away');
  const dctx = await phone({ latitude: 9.9000, longitude: 44.0700 });
  const drv = await dctx.newPage();
  await open(drv, '#/driver/login');
  await type(drv, /phone|telefoon/i, '634100012');
  await type(drv, /PIN/, '1234');
  await tap(drv, /^Gal/);
  await expectText(drv, /Salaan, Cali/, 'driver signed in');
  await tap(drv, /Jigjiga Yar/);
  await tap(drv, /^Masalaha/);
  await tap(drv, /Ku biir oo bilow/);
  await expectText(drv, /Jigjiga Yar → Masalaha/, 'driver live (far away)');
  await drv.waitForTimeout(4000);

  console.log('rider near Dugsiga uses GPS');
  const rctx = await phone({ latitude: 9.5586, longitude: 44.0909 });
  const r = await rctx.newPage();
  await open(r);
  await tap(r, /^Bilow/);
  await tap(r, /^Ka bood/);
  await tap(r, /26 Juun/);
  await expectText(r, /Isticmaal goobtayda/, '"Use my location" offered');
  await shot(r, 'loc-1-use-my-location');
  await tap(r, /Isticmaal goobtayda/);
  await expectText(r, /Xagee u socotaa/, 'GPS picked the village and moved on');
  await tap(r, /Masalaha/);
  await expectText(r, /Bas lama heli karo hadda/, '"No bus available" when the only bus is 40 km away');
  await expectText(r, /wuu ka fog yahay/, 'says the bus is too far, with distance');
  await shot(r, 'loc-2-no-bus-available');
  await tap(r, /Halkee baan joogaa/);
  await r.waitForTimeout(2500);
  await shot(r, 'loc-3-gps-dot');
  await expectText(r, /Dugsiga/, 'rider stop is Dugsiga (nearest to GPS)');

  console.log('driver comes close');
  await dctx.setGeolocation({ latitude: 9.5560, longitude: 44.0870 });
  await drv.waitForTimeout(14000); // next GPS ping
  await expectText(r, /Bas 12 · Cali/, 'bus appears once it is near', 30000);
  await shot(r, 'loc-4-bus-near');

  console.log(`\n${fails} failed checks`);
  await b.close();
  process.exit(fails ? 1 : 0);
})().catch((e) => { console.error('CRASH', e.message.split('\n')[0]); process.exit(2); });
