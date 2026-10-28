// Location-first start, against LOCAL Supabase with the app served on :8081.
// Rider: welcome → intro → pop-up "turn on location" → map shows them in Jigjiga Yar at Dugsiga
// → "where are you going?" → buses near them. Also: the page never flashes narrow while starting,
// and a rider who blocks location gets a clear way forward.
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
  while (Date.now() < end) { if (re.test(await allText(p))) { console.log('  PASS', what); return; } await p.waitForTimeout(600); }
  fails++; console.log('  FAIL', what, '|', (await allText(p)).slice(0, 300));
}
const check = (ok, what, extra = '') => { if (!ok) fails++; console.log(ok ? '  PASS' : '  FAIL', what, ok ? '' : extra); };
const tap = async (p, re) => { await p.getByRole('button', { name: re }).first().click(); await p.waitForTimeout(1200); };
const type = async (p, re, t) => { const e = p.getByRole('textbox', { name: re }).first(); await e.click(); await p.keyboard.type(t, { delay: 25 }); };
const shot = (p, n) => p.screenshot({ path: path.join(OUT, n + '.png') });

async function open(p, hash = '') {
  // Sample the layout width every 100 ms while the app starts: it must never be narrower than the screen.
  const widths = [];
  const sampler = setInterval(() => p.evaluate(() => {
    const v = document.querySelector('flutter-view');
    return v ? [Math.round(v.getBoundingClientRect().width), innerWidth] : null;
  }).then((w) => w && widths.push(w)).catch(() => {}), 100);
  await p.goto(BASE + hash);
  await p.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 60000 });
  await p.waitForTimeout(2000);
  clearInterval(sampler);
  await p.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await p.waitForTimeout(1000);
  return widths;
}

(async () => {
  require('fs').mkdirSync(OUT, { recursive: true });
  const b = await chromium.launch({ executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: true });
  const phone = (geo) => b.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true, ...(geo ? { geolocation: geo, permissions: ['geolocation'] } : {}) });

  console.log('driver near Jigjiga Yar');
  const drv = await (await phone({ latitude: 9.5560, longitude: 44.0870 })).newPage();
  await open(drv, '#/driver/login');
  await type(drv, /phone|telefoon/i, '634100012');
  await type(drv, /PIN/, '1234');
  await tap(drv, /^Gal/);
  await tap(drv, /Jigjiga Yar/);
  await tap(drv, /^Masalaha/);
  await tap(drv, /Ku biir oo bilow/);
  await expectText(drv, /Jigjiga Yar → Masalaha/, 'driver live near Jigjiga Yar');

  console.log('rider starts with location');
  const r = await (await phone({ latitude: 9.5586, longitude: 44.0909 })).newPage();
  const widths = await open(r);
  const narrow = widths.filter(([w, iw]) => w < iw - 2);
  const meta = await r.evaluate(() => document.querySelector('meta[name="viewport"]')?.content);
  check(widths.length > 0 && narrow.length === 0, `never narrow while starting (${widths.length} samples)`, JSON.stringify(narrow.slice(0, 3)));
  check(/user-scalable=no/.test(meta || ''), 'our viewport tag is kept', meta);
  await tap(r, /^Bilow/);
  await tap(r, /^Ka bood/);
  await expectText(r, /Shid goobtaada/, 'pop-up asks to turn on location');
  await shot(r, 'gps-1-popup');
  await tap(r, /^Shid goobta/);
  await expectText(r, /Halkan ayaad joogtaa/, 'map shows "you are here"');
  await expectText(r, /Jigjiga Yar/, 'village found from GPS');
  await expectText(r, /Dugsiga/, 'nearest stop found from GPS');
  await r.waitForTimeout(1500);
  await shot(r, 'gps-2-you-are-here');
  await tap(r, /Xagee u socotaa/);
  await expectText(r, /Waxaad joogtaa Jigjiga Yar/, 'next question: where are you going');
  await shot(r, 'gps-3-where-going');
  await tap(r, /Masalaha/);
  await expectText(r, /Bas 12 · Cali/, 'buses near the rider are listed', 30000);
  await r.waitForTimeout(1500);
  await shot(r, 'gps-4-buses-near');

  console.log('rider who blocks location');
  const d = await (await phone(null)).newPage();
  await d.context().grantPermissions([]);
  await open(d);
  await tap(d, /^Bilow/);
  await tap(d, /^Ka bood/);
  await tap(d, /^Shid goobta/);
  await expectText(d, /Goobta waa xiran tahay|Goobtaada lama helin/, 'blocked location explained');
  await expectText(d, /Gacanta ku dooro tuuladaada/, 'can still choose village by hand');
  await shot(d, 'gps-5-blocked');

  console.log(`\n${fails} failed checks`);
  await b.close();
  process.exit(fails ? 1 : 0);
})().catch((e) => { console.error('CRASH', e.message.split('\n')[0]); process.exit(2); });
