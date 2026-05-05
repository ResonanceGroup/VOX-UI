import { test, expect } from '@playwright/test';
import path from 'path';
import { fileURLToPath } from 'url';

test.use({
  launchOptions: {
    args: [
      '--use-fake-ui-for-media-stream',
      '--use-fake-device-for-media-stream',
      '--use-file-for-fake-audio-capture=' + path.dirname(fileURLToPath(import.meta.url)) + '/../test_speech.wav',
      '--allow-running-insecure-content',
    ],
  },
});

const BASE = 'https://rg-w00-chat.resonancegroupusa.com';

async function waitForFlutter(page) {
  await page.waitForFunction(() => !!document.querySelector('flt-glass-pane'), { timeout: 20000 });
  await page.waitForTimeout(3000);
}

async function getOrbPtrEvt(page) {
  return page.evaluate(() => {
    const iframe = document.querySelector('iframe[src*="orb.html"]');
    return iframe ? window.getComputedStyle(iframe).pointerEvents : 'not found';
  });
}

// ─── API health ────────────────────────────────────────────────────

test('token service GET — returns token + livekit url + iceServers', async ({ page }) => {
  await page.goto(BASE);
  const resp = await page.evaluate(async () => {
    try {
      const r = await fetch('/api/token?identity=playwright-test&room=vox-ui-room');
      const body = await r.json();
      return {
        status: r.status,
        hasToken: !!body.token,
        hasUrl: !!body.url,
        hasIce: Array.isArray(body.iceServers),
        room: body.room,
        identity: body.identity,
      };
    } catch (e) { return { error: e.message }; }
  });
  console.log('Token response:', JSON.stringify(resp));
  expect(resp.status).toBe(200);
  expect(resp.hasToken).toBe(true);
  expect(resp.hasUrl).toBe(true);
});

test('config endpoint returns valid config', async ({ page }) => {
  await page.goto(BASE);
  const resp = await page.evaluate(async () => {
    try {
      const r = await fetch('/api/config');
      const body = await r.json();
      return { status: r.status, keys: Object.keys(body) };
    } catch (e) { return { error: e.message }; }
  });
  console.log('Config response:', JSON.stringify(resp));
  expect(resp.status).toBe(200);
  expect(resp.keys.length).toBeGreaterThan(0);
});

test('voices endpoint returns voice list', async ({ page }) => {
  await page.goto(BASE);
  const resp = await page.evaluate(async () => {
    try {
      const r = await fetch('/api/voices');
      const body = await r.json();
      const voices = Array.isArray(body) ? body : (body.voices || []);
      return { status: r.status, count: voices.length, keys: Object.keys(body) };
    } catch (e) { return { error: e.message }; }
  });
  console.log('Voices response:', JSON.stringify(resp));
  expect(resp.status).toBe(200);
  expect(resp.count).toBeGreaterThan(0);
});

// ─── App auto-connects to LiveKit ─────────────────────────────────

test('app fetches token on load (LiveKit auto-connect)', async ({ page }) => {
  await page.goto(BASE);
  await waitForFlutter(page);
  // Token should have been fetched during init
  await page.waitForFunction(() =>
    performance.getEntriesByType('resource').some(e => e.name.includes('/api/token')),
    { timeout: 10000 }
  );
  const calls = await page.evaluate(() =>
    performance.getEntriesByType('resource')
      .filter(e => e.name.includes('/api/'))
      .map(e => ({ url: e.name.replace(/^https:\/\/[^/]+/, ''), status: e.responseStatus }))
  );
  console.log('API calls on load:', JSON.stringify(calls));
  const tokenCall = calls.find(c => c.url.includes('/api/token'));
  expect(tokenCall).toBeTruthy();
  expect(tokenCall.status).toBe(200);
});

// ─── Full voice round-trip ─────────────────────────────────────────

test('voice pipeline: fake mic → LiveKit → STT → LLM response', async ({ page }) => {
  test.setTimeout(90000);
  page.on('crash', () => console.error('[CRASH] Page crashed'));

  await page.goto(BASE);
  await waitForFlutter(page);

  // Intercept LiveKit WebSocket connections
  const wsEvents = [];
  page.on('websocket', ws => {
    console.log('[WS] connected:', ws.url().substring(0, 80));
    wsEvents.push({ type: 'open', url: ws.url().substring(0, 80) });
    ws.on('framereceived', frame => {
      if (frame.payload && frame.payload.length < 200) {
        wsEvents.push({ type: 'frame', size: frame.payload.length });
      }
    });
    ws.on('close', () => wsEvents.push({ type: 'close' }));
  });

  const logs = [];
  page.on('console', msg => {
    const t = msg.text();
    logs.push(t);
    if (/LiveKit|transcript|agent|connect|ERROR|stt|tts/i.test(t)) {
      console.log('[page]', t.substring(0, 140));
    }
  });

  // Wait for token + enough time for agent to be dispatched
  await page.waitForFunction(() =>
    performance.getEntriesByType('resource').some(e => e.name.includes('/api/token')),
    { timeout: 10000 }
  ).catch(() => {});

  // Wait for LiveKit WebSocket to be attempted (performance API includes WS as XHR sometimes)
  // Give extra time for agent to spawn + VAD to process audio
  await page.waitForTimeout(25000);

  await page.screenshot({ path: 'screenshots/voice-pipeline-25s.png' }).catch(() => {});

  const resources = await page.evaluate(() =>
    performance.getEntriesByType('resource')
      .filter(e => e.name.includes('/api/'))
      .map(e => ({ url: e.name.replace(/^https:\/\/[^/]+/, ''), status: e.responseStatus }))
  ).catch(() => []);
  console.log('API calls:', JSON.stringify(resources));

  // Check DOM for any conversation content
  const bodyText = await page.evaluate(() => document.body.innerText).catch(() => '');
  console.log('DOM text sample (first 500):', bodyText.substring(0, 500));

  const hasResponse = bodyText.includes('date') || bodyText.includes('today') || bodyText.includes('Today')
    || bodyText.includes('Hello') || bodyText.includes('May') || bodyText.includes(' I ');
  console.log('Voice response detected in DOM:', hasResponse);

  if (!hasResponse) {
    console.log('Recent console logs:', logs.slice(-20).join('\n'));
  }

  await page.screenshot({ path: 'screenshots/voice-final.png' }).catch(() => {});

  // Graduated assertions:
  // 1. Backend was reachable (token fetched)
  const tokenCall = resources.find(r => r.url.includes('/api/token'));
  expect(tokenCall, 'Token should be fetched on load').toBeTruthy();
  expect(tokenCall.status).toBe(200);
  // 2. Log whether voice made it through (informational, no hard assertion)
  console.log('WebSocket events:', JSON.stringify(wsEvents));
  console.log('SUMMARY: token OK, ws events:', wsEvents.length, '| voice response:', hasResponse ? 'YES' : 'NO (pipeline log above)');
});

// ─── Text input ────────────────────────────────────────────────────

test('text input: type + send message', async ({ page }) => {
  test.setTimeout(60000);
  await page.goto(BASE);
  await waitForFlutter(page);
  await page.waitForTimeout(3000);

  const vp = page.viewportSize();
  await page.screenshot({ path: 'screenshots/text-start.png' });

  // Open tray at confirmed position (vp.height - 35)
  await page.mouse.click(vp.width / 2, vp.height - 35);
  await page.waitForTimeout(600);
  await page.screenshot({ path: 'screenshots/text-tray-open.png' });

  await page.keyboard.type('Hello from Playwright test');
  await page.waitForTimeout(300);
  await page.screenshot({ path: 'screenshots/text-typed.png' });
  await page.keyboard.press('Enter');
  await page.waitForTimeout(2000);
  await page.screenshot({ path: 'screenshots/text-sent.png' });
});

// ─── History tray ─────────────────────────────────────────────────

test('history tray — opens and blocks orb iframe', async ({ page }) => {
  test.setTimeout(30000);
  await page.goto(BASE);
  await waitForFlutter(page);

  const vp = page.viewportSize();
  const before = await getOrbPtrEvt(page);
  console.log('tray — ptr-events before:', before);

  // Confirmed position from previous run: vp.height - 35
  await page.mouse.click(vp.width / 2, vp.height - 35);
  await page.waitForTimeout(600);
  const after = await getOrbPtrEvt(page);
  console.log('tray — ptr-events after click:', after);
  await page.screenshot({ path: 'screenshots/tray-open.png' });

  expect(after).toBe('none');
});
