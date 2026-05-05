# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: voxui.spec.js >> VoxUI — Navigation & Z-order >> tray open — orb iframe blocked
- Location: tests/voxui.spec.js:52:3

# Error details

```
Error: expect(received).toBe(expected) // Object.is equality

Expected: "none"
Received: "auto"
```

# Page snapshot

```yaml
- generic [ref=e1]:
  - button "Enable accessibility" [ref=e2]
  - iframe [ref=e8]:
    - generic [ref=f1e2]:
      - generic:
        - generic:
          - img
      - generic [ref=f1e3]:
        - button "Toggle Microphone" [ref=f1e4] [cursor=pointer]:
          - img [ref=f1e5]
        - button "Toggle Speaker" [ref=f1e8] [cursor=pointer]:
          - img [ref=f1e9]
      - generic [ref=f1e13]:
        - generic [ref=f1e14]: ⚙️
        - generic [ref=f1e15]: Thinking...
```

# Test source

```ts
  1   | import { test, expect } from '@playwright/test';
  2   | 
  3   | // Helper: wait for Flutter CanvasKit to initialize
  4   | async function waitForFlutter(page) {
  5   |   await page.waitForFunction(() => !!document.querySelector('flt-glass-pane'), { timeout: 20000 });
  6   |   await page.waitForTimeout(3000);
  7   | }
  8   | 
  9   | async function getOrbPointerEvents(page) {
  10  |   return page.evaluate(() => {
  11  |     const iframe = document.querySelector('iframe[src*="orb.html"]');
  12  |     if (!iframe) return 'iframe not found';
  13  |     return window.getComputedStyle(iframe).pointerEvents;
  14  |   });
  15  | }
  16  | 
  17  | async function elementAtPoint(page, x, y) {
  18  |   return page.evaluate(([px, py]) => {
  19  |     const el = document.elementFromPoint(px, py);
  20  |     if (!el) return null;
  21  |     return { tag: el.tagName, id: el.id, src: el.src || '', ptrEvt: window.getComputedStyle(el).pointerEvents };
  22  |   }, [x, y]);
  23  | }
  24  | 
  25  | test.describe('VoxUI — Navigation & Z-order', () => {
  26  |   test.beforeEach(async ({ page }) => {
  27  |     await page.goto('/');
  28  |     await waitForFlutter(page);
  29  |     await page.screenshot({ path: 'screenshots/initial.png' });
  30  |   });
  31  | 
  32  |   test('initial load — orb iframe present', async ({ page }) => {
  33  |     const iframeSrc = await page.evaluate(() => {
  34  |       const iframe = document.querySelector('iframe[src*="orb.html"]');
  35  |       return iframe ? iframe.src : 'not found';
  36  |     });
  37  |     console.log('Orb iframe src:', iframeSrc);
  38  |     expect(iframeSrc).toContain('orb.html');
  39  |   });
  40  | 
  41  |   test('drawer open — orb iframe blocked', async ({ page }) => {
  42  |     const before = await getOrbPointerEvents(page);
  43  |     console.log('pointer-events before drawer:', before);
  44  |     await page.mouse.click(28, 28);
  45  |     await page.waitForTimeout(800);
  46  |     await page.screenshot({ path: 'screenshots/drawer-open.png' });
  47  |     const after = await getOrbPointerEvents(page);
  48  |     console.log('pointer-events after drawer click:', after);
  49  |     expect(after).toBe('none');
  50  |   });
  51  | 
  52  |   test('tray open — orb iframe blocked', async ({ page }) => {
  53  |     const vp = page.viewportSize();
  54  |     const before = await getOrbPointerEvents(page);
  55  |     console.log('pointer-events before tray:', before);
  56  |     await page.mouse.click(vp.width / 2, vp.height - 30);
  57  |     await page.waitForTimeout(800);
  58  |     await page.screenshot({ path: 'screenshots/tray-open.png' });
  59  |     const after = await getOrbPointerEvents(page);
  60  |     console.log('pointer-events after tray click:', after);
> 61  |     expect(after).toBe('none');
      |                   ^ Error: expect(received).toBe(expected) // Object.is equality
  62  |   });
  63  | 
  64  |   test('z-order diagnostic at key coordinates', async ({ page }) => {
  65  |     const vp = page.viewportSize();
  66  |     const pts = [
  67  |       [28, 28, 'hamburger'],
  68  |       [vp.width / 2, 28, 'appbar-center'],
  69  |       [vp.width / 2, vp.height / 2, 'center'],
  70  |       [vp.width / 2, vp.height - 30, 'grab-handle'],
  71  |     ];
  72  |     for (const [x, y, label] of pts) {
  73  |       const el = await elementAtPoint(page, x, y);
  74  |       console.log(label, JSON.stringify(el));
  75  |     }
  76  |   });
  77  | });
  78  | 
  79  | test.describe('VoxUI — Orb state machine (isolated)', () => {
  80  |   test.beforeEach(async ({ page }) => {
  81  |     await page.goto('/assets/assets/orb/orb.html');
  82  |     await page.waitForTimeout(1500);
  83  |   });
  84  | 
  85  |   test('orb html loads', async ({ page }) => {
  86  |     await page.screenshot({ path: 'screenshots/orb-isolated.png' });
  87  |     const hasContent = await page.evaluate(() =>
  88  |       !!(document.querySelector('canvas') || document.querySelector('.orb') || document.body.children.length > 0)
  89  |     );
  90  |     expect(hasContent).toBe(true);
  91  |   });
  92  | 
  93  |   test('orb idle->speaking via postMessage', async ({ page }) => {
  94  |     await page.evaluate(() => {
  95  |       window.postMessage(JSON.stringify({ type: 'updateState', state: 'idle', level: 0, theme: 'dark', status: 'Ready' }), '*');
  96  |     });
  97  |     await page.waitForTimeout(400);
  98  |     await page.screenshot({ path: 'screenshots/orb-idle.png' });
  99  | 
  100 |     await page.evaluate(() => {
  101 |       window.postMessage(JSON.stringify({ type: 'updateState', state: 'speaking', level: 0.8, theme: 'dark', status: 'Speaking' }), '*');
  102 |     });
  103 |     await page.waitForTimeout(400);
  104 |     await page.screenshot({ path: 'screenshots/orb-speaking.png' });
  105 |   });
  106 | 
  107 |   test('mic click fires toggle-mute', async ({ page }) => {
  108 |     await page.evaluate(() => {
  109 |       window._muteCount = 0;
  110 |       window.addEventListener('message', (e) => {
  111 |         try {
  112 |           const d = typeof e.data === 'string' ? JSON.parse(e.data) : e.data;
  113 |           if (d.type === 'toggle-mute') window._muteCount++;
  114 |         } catch (_) {}
  115 |       });
  116 |     });
  117 |     const vp = page.viewportSize();
  118 |     await page.mouse.click(vp.width / 2, vp.height - 70);
  119 |     await page.waitForTimeout(400);
  120 |     const count = await page.evaluate(() => window._muteCount);
  121 |     console.log('toggle-mute count:', count);
  122 |     await page.screenshot({ path: 'screenshots/orb-after-mic.png' });
  123 |   });
  124 | });
  125 | 
```