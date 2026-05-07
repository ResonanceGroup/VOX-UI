import { chromium } from 'playwright';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const OUT = '/home/rgadmin/repos/VOX-UI/e2e/screenshots/visual-mute-test';

const browser = await chromium.launch({
  args: [
    '--use-fake-ui-for-media-stream',
    '--use-fake-device-for-media-stream',
    '--allow-running-insecure-content',
  ]
});
const page = await browser.newPage({ viewport: { width: 390, height: 844 } });

async function shot(name) {
  await page.screenshot({ path: `${OUT}-${name}.png` });
  console.log(`📸 ${name}`);
}

async function getOrbClasses() {
  return page.evaluate(() => {
    const iframe = document.querySelector('iframe[src*="orb.html"]');
    if (!iframe || !iframe.contentDocument) return [];
    return Array.from(iframe.contentDocument.body.classList);
  });
}

async function sendOrbUpdate(payload) {
  await page.evaluate((p) => {
    const iframe = document.querySelector('iframe[src*="orb.html"]');
    if (iframe?.contentWindow) iframe.contentWindow.postMessage({ type: 'livekit-update', payload: p }, '*');
  }, payload);
}

async function clickMicBtn() {
  await page.evaluate(() => {
    const iframe = document.querySelector('iframe[src*="orb.html"]');
    if (iframe?.contentDocument) iframe.contentDocument.getElementById('mic-button')?.click();
  });
}

await page.goto('https://rg-w00-chat.resonancegroupusa.com');
await page.waitForFunction(() => !!document.querySelector('flt-glass-pane'), { timeout: 20000 });
await page.waitForTimeout(3500);

// baseline — should be colorful idle
await shot('1-baseline-idle');
console.log('1 idle classes:', (await getOrbClasses()).join(', '));

// mute via postMessage (simulate Flutter sending muted)
await sendOrbUpdate({ state: 'idle', level: 0, micMuted: true, speakerMuted: false });
await page.waitForTimeout(300);
await shot('2-after-mute');
console.log('2 muted classes:', (await getOrbClasses()).join(', '));

// unmute via button click (the actual bug path)
await clickMicBtn();
await page.waitForTimeout(100);
await shot('3-immediately-after-unmute-click');
console.log('3 after click classes:', (await getOrbClasses()).join(', '));

// state transition arrives from Flutter (before micMuted:false payload) — the old bug trigger
await sendOrbUpdate({ state: 'processing', level: 0.4 });
await page.waitForTimeout(100);
await shot('4-after-state-transition');
console.log('4 after state transition:', (await getOrbClasses()).join(', '));

// now Flutter sends micMuted:false confirmation
await sendOrbUpdate({ state: 'idle', level: 0, micMuted: false, speakerMuted: false });
await page.waitForTimeout(300);
await shot('5-after-flutter-confirm');
console.log('5 after flutter confirm:', (await getOrbClasses()).join(', '));

await browser.close();
console.log('\nDone. Screenshots saved to', OUT + '-*.png');
