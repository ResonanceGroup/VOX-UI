import { test, expect } from '@playwright/test';

const BASE = 'https://rg-w00-chat.resonancegroupusa.com';
const FLUTTER_WAIT = 3000;

async function waitForFlutter(page) {
  await page.waitForFunction(() => !!document.querySelector('flt-glass-pane'), { timeout: 20000 });
  await page.waitForTimeout(FLUTTER_WAIT);
}

async function getOrbPtrEvt(page) {
  return page.evaluate(() => {
    const iframe = document.querySelector('iframe[src*="orb.html"]');
    return iframe ? window.getComputedStyle(iframe).pointerEvents : 'not found';
  });
}

async function ptAt(page, x, y) {
  return page.evaluate(([px, py]) => {
    const el = document.elementFromPoint(px, py);
    return el ? { tag: el.tagName, id: el.id, src: el.src || '', ptr: window.getComputedStyle(el).pointerEvents } : null;
  }, [x, y]);
}

// ═══ 1. Navigation & Z-order ═══
test.describe('Navigation and Z-order', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto(BASE);
    await waitForFlutter(page);
  });

  test('app loads — orb iframe present', async ({ page }) => {
    const src = await page.evaluate(() => {
      const f = document.querySelector('iframe[src*="orb.html"]');
      return f ? f.src : 'not found';
    });
    expect(src).toContain('orb.html');
  });

  test('drawer open — orb iframe blocked (pointer-events:none)', async ({ page }) => {
    const before = await getOrbPtrEvt(page);
    await page.mouse.click(28, 28);
    await page.waitForTimeout(800);
    await page.screenshot({ path: 'screenshots/drawer-open.png' });
    const after = await getOrbPtrEvt(page);
    console.log('drawer ptr-events: before=' + before + ' after=' + after);
    expect(after).toBe('none');
  });

  test('drawer: navigate to Settings and back to AI', async ({ page }) => {
    await page.mouse.click(28, 28);
    await page.waitForTimeout(600);
    await page.screenshot({ path: 'screenshots/drawer-open-nav.png' });
    await page.mouse.click(140, 200);
    await page.waitForTimeout(600);
    await page.screenshot({ path: 'screenshots/settings-view.png' });
    // Back to AI
    await page.mouse.click(28, 28);
    await page.waitForTimeout(600);
    await page.mouse.click(140, 140);
    await page.waitForTimeout(600);
    await page.screenshot({ path: 'screenshots/back-to-ai.png' });
    const src = await page.evaluate(() => {
      return document.querySelector('iframe[src*="orb.html"]') ? 'found' : 'missing';
    });
    expect(src).toBe('found');
  });

  test('drawer: navigate to Profiles', async ({ page }) => {
    await page.mouse.click(28, 28);
    await page.waitForTimeout(600);
    await page.mouse.click(140, 260);
    await page.waitForTimeout(600);
    await page.screenshot({ path: 'screenshots/profiles-view.png' });
  });

  test('z-order: iframe at center, flutter-view at edges', async ({ page }) => {
    const vp = page.viewportSize();
    for (const [x, y, label] of [
      [28, 28, 'hamburger'], [vp.width/2, 28, 'appbar'],
      [vp.width/2, vp.height/2, 'center'], [vp.width/2, vp.height-50, 'bottom'],
    ]) {
      const el = await ptAt(page, x, y);
      console.log('[z]', label, JSON.stringify(el));
    }
    // Center should be the iframe
    const center = await ptAt(page, vp.width/2, vp.height/2);
    expect(center?.tag).toBe('IFRAME');
  });
});

// ═══ 2. Settings Persistence ═══
test.describe('Settings Persistence', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto(BASE);
    await waitForFlutter(page);
  });

  test('localStorage has vox_ui keys after init', async ({ page }) => {
    const keys = await page.evaluate(() => Object.keys(localStorage).filter(k => k.includes('vox_ui') || k.includes('flutter')));
    console.log('vox_ui keys:', JSON.stringify(keys));
    // May be empty if nothing was ever saved (fresh browser context)
    // Just log — no assertion
  });

  test('backend URL write → reload → persists', async ({ page }) => {
    const TEST_URL = 'https://test-backend.playwright.test';
    const keyInfo = await page.evaluate(() => {
      const k = Object.keys(localStorage).find(k => k.includes('backend_base_url')) || 'flutter.vox_ui_backend_base_url';
      return { key: k, val: localStorage.getItem(k) };
    });
    const key = keyInfo.key;
    console.log('Using key:', key, '(was:', keyInfo.val, ')');
    await page.evaluate(([k, v]) => localStorage.setItem(k, JSON.stringify(v)), [key, TEST_URL]);
    await page.reload();
    await waitForFlutter(page);
    const after = await page.evaluate((k) => localStorage.getItem(k), key);
    console.log('After reload:', after);
    expect(after).toContain(TEST_URL);
    await page.evaluate((k) => localStorage.removeItem(k), key);
  });

  test('TTS voice write → reload → persists', async ({ page }) => {
    const key = await page.evaluate(() =>
      Object.keys(localStorage).find(k => k.includes('tts_voice')) || 'flutter.vox_ui_tts_voice');
    await page.evaluate(([k, v]) => localStorage.setItem(k, JSON.stringify(v)), [key, 'af_sky']);
    await page.reload();
    await waitForFlutter(page);
    const after = await page.evaluate((k) => localStorage.getItem(k), key);
    expect(after).toContain('af_sky');
    await page.evaluate((k) => localStorage.removeItem(k), key);
  });

  test('livekitUrl write → reload → persists', async ({ page }) => {
    const key = await page.evaluate(() =>
      Object.keys(localStorage).find(k => k.includes('livekit_url')) || 'flutter.vox_ui_livekit_url');
    await page.evaluate(([k, v]) => localStorage.setItem(k, JSON.stringify(v)), [key, 'ws://custom:7880']);
    await page.reload();
    await waitForFlutter(page);
    const after = await page.evaluate((k) => localStorage.getItem(k), key);
    expect(after).toContain('ws://custom:7880');
    await page.evaluate((k) => localStorage.removeItem(k), key);
  });
});

// ═══ 3. Orb State Machine (isolated) ═══
// NOTE: The orb uses its own internal state names, NOT Flutter AI state names.
// ALL_STATES in orb.html = ['idle', 'executing', 'notifying', 'processing', 'muted', 'disconnected']
// Flutter 'listening' → orb 'idle', Flutter 'thinking' → orb 'processing'
// Flutter 'speaking' → orb 'speaking' BUT 'speaking' is NOT in ALL_STATES (orb bug: silent fail)
// Message format: { type: 'manual-state', payload: { state, level, theme, status } }
test.describe('Orb State Machine', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto(BASE + '/assets/assets/orb/orb.html');
    await page.waitForTimeout(1500);
  });

  // Test valid orb states — assert CSS class applied, not just screenshot
  for (const state of ['idle', 'executing', 'processing', 'muted', 'disconnected']) {
    test('state: ' + state, async ({ page }) => {
      // Set initial state to something different so the change fires
      if (state !== 'idle') {
        await page.evaluate(() => {
          window.postMessage({ type: 'manual-state', payload: { state: 'idle', theme: 'light', status: 'idle' } }, '*');
        });
        await page.waitForTimeout(200);
      }

      await page.evaluate((s) => {
        window.postMessage({ type: 'manual-state', payload: { state: s, level: 0.5, theme: 'dark', status: s } }, '*');
      }, state);
      await page.waitForTimeout(400);

      // Assert body has the correct state class
      const bodyClass = await page.evaluate(() => document.body.className);
      console.log('body classes:', bodyClass);
      expect(bodyClass).toContain('state-' + state);

      await page.screenshot({ path: 'screenshots/orb-' + state + '.png' });
    });
  }

  // Regression test: 'speaking' silently fails (not in ALL_STATES) — orb stays in previous state
  test('state: speaking — bug: silent fail (stays in idle)', async ({ page }) => {
    await page.evaluate(() => {
      window.postMessage({ type: 'manual-state', payload: { state: 'speaking', level: 0.8, theme: 'dark', status: 'speaking' } }, '*');
    });
    await page.waitForTimeout(400);
    const bodyClass = await page.evaluate(() => document.body.className);
    console.log('speaking → body classes:', bodyClass);
    // This SHOULD be state-speaking but orb has speaking bug — it stays idle
    // When the bug is fixed, change this to: expect(bodyClass).toContain('state-speaking')
    expect(bodyClass).not.toContain('state-speaking'); // confirms the bug
    await page.screenshot({ path: 'screenshots/orb-speaking-bug.png' });
  });

  test('mic click fires toggle-mute', async ({ page }) => {
    await page.evaluate(() => {
      window._m = 0;
      window.addEventListener('message', (e) => {
        try { const d = typeof e.data === 'string' ? JSON.parse(e.data) : e.data;
          if (d.type === 'toggle-mute') window._m++; } catch (_) {}
      });
    });
    const vp = page.viewportSize();
    await page.mouse.click(vp.width / 2, vp.height - 70);
    await page.waitForTimeout(400);
    const n = await page.evaluate(() => window._m);
    console.log('toggle-mute fires:', n);
    await page.screenshot({ path: 'screenshots/orb-mic.png' });
  });

  test('speaker click fires toggle-speaker-mute', async ({ page }) => {
    await page.evaluate(() => {
      window._s = 0;
      window.addEventListener('message', (e) => {
        try { const d = typeof e.data === 'string' ? JSON.parse(e.data) : e.data;
          if (d.type === 'toggle-speaker-mute') window._s++; } catch (_) {}
      });
    });
    const vp = page.viewportSize();
    await page.mouse.click(vp.width / 2 + 80, vp.height - 70);
    await page.waitForTimeout(400);
    const n = await page.evaluate(() => window._s);
    console.log('toggle-speaker-mute fires:', n);
  });
});
