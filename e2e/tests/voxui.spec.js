import { test, expect } from '@playwright/test';

// Helper: wait for Flutter CanvasKit to initialize
async function waitForFlutter(page) {
  await page.waitForFunction(() => !!document.querySelector('flt-glass-pane'), { timeout: 20000 });
  await page.waitForTimeout(3000);
}

async function getOrbPointerEvents(page) {
  return page.evaluate(() => {
    const iframe = document.querySelector('iframe[src*="orb.html"]');
    if (!iframe) return 'iframe not found';
    return window.getComputedStyle(iframe).pointerEvents;
  });
}

async function elementAtPoint(page, x, y) {
  return page.evaluate(([px, py]) => {
    const el = document.elementFromPoint(px, py);
    if (!el) return null;
    return { tag: el.tagName, id: el.id, src: el.src || '', ptrEvt: window.getComputedStyle(el).pointerEvents };
  }, [x, y]);
}

test.describe('VoxUI — Navigation & Z-order', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForFlutter(page);
    await page.screenshot({ path: 'screenshots/initial.png' });
  });

  test('initial load — orb iframe present', async ({ page }) => {
    const iframeSrc = await page.evaluate(() => {
      const iframe = document.querySelector('iframe[src*="orb.html"]');
      return iframe ? iframe.src : 'not found';
    });
    console.log('Orb iframe src:', iframeSrc);
    expect(iframeSrc).toContain('orb.html');
  });

  test('drawer open — orb iframe blocked', async ({ page }) => {
    const before = await getOrbPointerEvents(page);
    console.log('pointer-events before drawer:', before);
    await page.mouse.click(28, 28);
    await page.waitForTimeout(800);
    await page.screenshot({ path: 'screenshots/drawer-open.png' });
    const after = await getOrbPointerEvents(page);
    console.log('pointer-events after drawer click:', after);
    expect(after).toBe('none');
  });

  test('tray open — orb iframe blocked', async ({ page }) => {
    const vp = page.viewportSize();
    const before = await getOrbPointerEvents(page);
    console.log('pointer-events before tray:', before);
    await page.mouse.click(vp.width / 2, vp.height - 30);
    await page.waitForTimeout(800);
    await page.screenshot({ path: 'screenshots/tray-open.png' });
    const after = await getOrbPointerEvents(page);
    console.log('pointer-events after tray click:', after);
    expect(after).toBe('none');
  });

  test('z-order diagnostic at key coordinates', async ({ page }) => {
    const vp = page.viewportSize();
    const pts = [
      [28, 28, 'hamburger'],
      [vp.width / 2, 28, 'appbar-center'],
      [vp.width / 2, vp.height / 2, 'center'],
      [vp.width / 2, vp.height - 30, 'grab-handle'],
    ];
    for (const [x, y, label] of pts) {
      const el = await elementAtPoint(page, x, y);
      console.log(label, JSON.stringify(el));
    }
  });
});

test.describe('VoxUI — Orb state machine (isolated)', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/assets/assets/orb/orb.html');
    await page.waitForTimeout(1500);
  });

  test('orb html loads', async ({ page }) => {
    await page.screenshot({ path: 'screenshots/orb-isolated.png' });
    const hasContent = await page.evaluate(() =>
      !!(document.querySelector('canvas') || document.querySelector('.orb') || document.body.children.length > 0)
    );
    expect(hasContent).toBe(true);
  });

  test('orb idle->speaking via postMessage', async ({ page }) => {
    await page.evaluate(() => {
      window.postMessage(JSON.stringify({ type: 'updateState', state: 'idle', level: 0, theme: 'dark', status: 'Ready' }), '*');
    });
    await page.waitForTimeout(400);
    await page.screenshot({ path: 'screenshots/orb-idle.png' });

    await page.evaluate(() => {
      window.postMessage(JSON.stringify({ type: 'updateState', state: 'speaking', level: 0.8, theme: 'dark', status: 'Speaking' }), '*');
    });
    await page.waitForTimeout(400);
    await page.screenshot({ path: 'screenshots/orb-speaking.png' });
  });

  test('mic click fires toggle-mute', async ({ page }) => {
    await page.evaluate(() => {
      window._muteCount = 0;
      window.addEventListener('message', (e) => {
        try {
          const d = typeof e.data === 'string' ? JSON.parse(e.data) : e.data;
          if (d.type === 'toggle-mute') window._muteCount++;
        } catch (_) {}
      });
    });
    const vp = page.viewportSize();
    await page.mouse.click(vp.width / 2, vp.height - 70);
    await page.waitForTimeout(400);
    const count = await page.evaluate(() => window._muteCount);
    console.log('toggle-mute count:', count);
    await page.screenshot({ path: 'screenshots/orb-after-mic.png' });
  });
});
