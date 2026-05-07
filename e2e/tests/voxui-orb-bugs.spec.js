/**
 * voxui-orb-bugs.spec.js
 * Regression tests for three bugs fixed May 5:
 *   1. Mute/unmute CSS class — orb-mic-muted must clear on unmute
 *   2. Initial gray at idle — orb-mic-muted must NOT appear before mic is touched
 *   3. Notifying timeout — source must use 1800ms not 600ms
 *   4. Tray scroll on open — source must call _scrollToBottom() on open
 */
import { test, expect } from '@playwright/test';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const BASE    = 'https://rg-w00-chat.resonancegroupusa.com';
const ORB_DART = '/home/rgadmin/repos/VOX-UI/frontend/lib/widgets/orb_widget_web_impl.dart';
const AI_VIEW  = '/home/rgadmin/repos/VOX-UI/frontend/lib/Views/ai_view.dart';

// Top-level: fake mic for all browser tests
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

// ─── Helpers ─────────────────────────────────────────────────────────────────

async function waitForFlutter(page) {
  await page.waitForFunction(() => !!document.querySelector('flt-glass-pane'), { timeout: 20000 });
  await page.waitForTimeout(3500);
}

async function getOrbClasses(page) {
  return page.evaluate(() => {
    const iframe = document.querySelector('iframe[src*="orb.html"]');
    if (!iframe || !iframe.contentDocument) return [];
    return Array.from(iframe.contentDocument.body.classList);
  });
}

async function sendOrbUpdate(page, payload) {
  await page.evaluate((p) => {
    const iframe = document.querySelector('iframe[src*="orb.html"]');
    if (iframe && iframe.contentWindow) {
      iframe.contentWindow.postMessage({ type: 'livekit-update', payload: p }, '*');
    }
  }, payload);
}

async function getDebugBarText(page) {
  return page.evaluate(() => {
    const iframe = document.querySelector('iframe[src*="orb.html"]');
    if (!iframe || !iframe.contentDocument) return null;
    const dbg = iframe.contentDocument.getElementById('dbg-state');
    return dbg ? dbg.textContent : null;
  });
}

// ═══ Suite 1: Source-level checks (no browser) ════════════════════════════════

const PROXY_JS = '/home/rgadmin/repos/VOX-UI/proxy.js';

test.describe('Source sanity — timer values and mute logic', () => {

  test('proxy normalises /rtc/rtc → /rtc (iOS double-path fix)', () => {
    const src = fs.readFileSync(PROXY_JS, 'utf8');
    expect(src).toMatch(/startsWith.*\/rtc\/rtc/);
    expect(src).toMatch(/replace.*\/rtc\/rtc.*\/rtc/);
    console.log('✅ proxy /rtc/rtc normalisation present');
  });

  test('notifying revert timer is 1800ms (regression: was 600ms)', () => {
    const src = fs.readFileSync(ORB_DART, 'utf8');
    expect(src, 'old 600ms must be gone').not.toMatch(/Duration\(milliseconds:\s*600\)/);
    expect(src, '1800ms must be present').toMatch(/Duration\(milliseconds:\s*1800\)/);
    console.log('✅ notifyRevertTimer = 1800ms');
  });

  test('effectiveMicMuted = svcMuted only (no stale || widget.isMuted)', () => {
    const src = fs.readFileSync(ORB_DART, 'utf8');
    expect(src, 'stale OR must be gone')
      .not.toMatch(/effectiveMicMuted\s*=\s*svcMuted\s*\|\|\s*widget\.isMuted/);
    expect(src, 'direct assignment must be present')
      .toMatch(/effectiveMicMuted\s*=\s*svcMuted\s*;/);
    console.log('✅ effectiveMicMuted = svcMuted (stale OR removed)');
  });

  test('effectiveSpeakerMuted = svcSpeakerMuted only (no stale || widget)', () => {
    const src = fs.readFileSync(ORB_DART, 'utf8');
    expect(src).not.toMatch(/effectiveSpeakerMuted\s*=\s*svcSpeakerMuted\s*\|\|\s*widget\./);
    expect(src).toMatch(/effectiveSpeakerMuted\s*=\s*svcSpeakerMuted\s*;/);
    console.log('✅ effectiveSpeakerMuted = svcSpeakerMuted');
  });

  test('onOpenTray callback calls _scrollToBottom()', () => {
    const src = fs.readFileSync(AI_VIEW, 'utf8');
    // The callback must now be a block containing scrollToBottom
    const match = src.match(/onOpenTray:\s*\(\)\s*\{[^}]*scrollToBottom/s);
    expect(match, 'onOpenTray must call _scrollToBottom()').toBeTruthy();
    console.log('✅ onOpenTray → _scrollToBottom()');
  });

  test('grab handle onTap calls _scrollToBottom() when opening', () => {
    const src = fs.readFileSync(AI_VIEW, 'utf8');
    // After the toggle the code should check _isHistoryTrayOpen and call scrollToBottom
    const match = src.match(/isHistoryTrayOpen.*scrollToBottom|scrollToBottom.*isHistoryTrayOpen/s);
    expect(match, 'grab handle must scroll on open').toBeTruthy();
    console.log('✅ grab handle → _scrollToBottom() on open');
  });

});

// ═══ Suite 2: orb.html CSS class behavior (postMessage, no LiveKit) ═══════════

test.describe('orb.html — CSS class behaviour via direct postMessage', () => {

  test.beforeEach(async ({ page }) => {
    await page.goto(BASE);
    await waitForFlutter(page);
    await page.waitForTimeout(1000); // let orb init script finish
  });

  test('initial load — orb-mic-muted absent before any interaction', async ({ page }) => {
    const cls = await getOrbClasses(page);
    const dbg = await getDebugBarText(page);
    console.log('Initial classes:', cls.join(', ') || '(none)');
    console.log('Debug bar:', dbg);
    await page.screenshot({ path: 'screenshots/bug-initial-idle.png' });
    expect(cls).not.toContain('orb-mic-muted');
  });

  test('micMuted:true → orb-mic-muted added', async ({ page }) => {
    await sendOrbUpdate(page, { state: 'idle', level: 0, micMuted: true, speakerMuted: false });
    await page.waitForTimeout(200);
    const cls = await getOrbClasses(page);
    console.log('After mute:', cls.join(', '));
    expect(cls).toContain('orb-mic-muted');
  });

  test('micMuted:false after true → orb-mic-muted removed (core unmute regression)', async ({ page }) => {
    await sendOrbUpdate(page, { state: 'idle', level: 0, micMuted: true, speakerMuted: false });
    await page.waitForTimeout(200);
    expect(await getOrbClasses(page)).toContain('orb-mic-muted');

    await sendOrbUpdate(page, { state: 'idle', level: 0, micMuted: false, speakerMuted: false });
    await page.waitForTimeout(200);
    const cls = await getOrbClasses(page);
    console.log('After unmute:', cls.join(', ') || '(none)');
    await page.screenshot({ path: 'screenshots/bug-unmute.png' });
    expect(cls).not.toContain('orb-mic-muted');
  });

  test('rapid unmute storm (5 × 33ms) — ends without orb-mic-muted', async ({ page }) => {
    // Simulate the old audio-level storm: mute once, then 5 rapid unmute sends
    await sendOrbUpdate(page, { state: 'idle', level: 0, micMuted: true, speakerMuted: false });
    for (let i = 0; i < 5; i++) {
      await page.waitForTimeout(33);
      await sendOrbUpdate(page, { state: 'idle', level: 0, micMuted: false, speakerMuted: false });
    }
    await page.waitForTimeout(200);
    const cls = await getOrbClasses(page);
    console.log('After storm:', cls.join(', ') || '(none)');
    expect(cls).not.toContain('orb-mic-muted');
  });

  test('optimistic unmute survives subsequent state transition (regression: _micMuted not synced)', async ({ page }) => {
    // 1. Set muted via postMessage (simulates Flutter sending muted state)
    await sendOrbUpdate(page, { state: 'idle', level: 0, micMuted: true, speakerMuted: false });
    await page.waitForTimeout(200);
    expect(await getOrbClasses(page)).toContain('orb-mic-muted');

    // 2. Click the mic button (optimistic toggle — removes class, must also update _micMuted)
    await page.evaluate(() => {
      const iframe = document.querySelector('iframe[src*="orb.html"]');
      if (iframe && iframe.contentDocument) {
        const btn = iframe.contentDocument.getElementById('mic-button');
        if (btn) btn.click();
      }
    });
    await page.waitForTimeout(100);
    const afterClick = await getOrbClasses(page);
    console.log('After optimistic unmute click:', afterClick.join(', ') || '(none)');
    expect(afterClick, 'orb-mic-muted must be gone immediately after click').not.toContain('orb-mic-muted');

    // 3. Simulate a state transition arriving from Flutter BEFORE the micMuted:false payload
    //    (this is what reverted the orb before the fix)
    await sendOrbUpdate(page, { state: 'processing', level: 0.5 }); // no micMuted key — simulates state-only update
    await page.waitForTimeout(100);
    const afterTransition = await getOrbClasses(page);
    console.log('After state transition (should still be unmuted):', afterTransition.join(', ') || '(none)');
    await page.screenshot({ path: 'screenshots/optimistic-unmute-survives-transition.png' });
    expect(afterTransition, 'orb-mic-muted must not reappear after state transition').not.toContain('orb-mic-muted');
  });

  test('state:disconnected → idle — state-disconnected removed, state-idle added', async ({ page }) => {
    await sendOrbUpdate(page, { state: 'disconnected', level: 0, micMuted: false, speakerMuted: false });
    await page.waitForTimeout(200);
    expect(await getOrbClasses(page)).toContain('state-disconnected');

    await sendOrbUpdate(page, { state: 'idle', level: 0, micMuted: false, speakerMuted: false });
    await page.waitForTimeout(200);
    const cls = await getOrbClasses(page);
    console.log('idle classes:', cls.join(', '));
    expect(cls).toContain('state-idle');
    expect(cls).not.toContain('state-disconnected');
    expect(cls).not.toContain('orb-mic-muted');
  });

  test('state:executing — state-executing set, no orb-mic-muted', async ({ page }) => {
    await sendOrbUpdate(page, { state: 'executing', level: 0, micMuted: false, speakerMuted: false });
    await page.waitForTimeout(200);
    const cls = await getOrbClasses(page);
    console.log('executing classes:', cls.join(', '));
    expect(cls).toContain('state-executing');
    expect(cls).not.toContain('orb-mic-muted');
  });

  test('state:processing — state-processing set, no orb-mic-muted', async ({ page }) => {
    await sendOrbUpdate(page, { state: 'processing', level: 0, micMuted: false, speakerMuted: false });
    await page.waitForTimeout(200);
    const cls = await getOrbClasses(page);
    console.log('processing classes:', cls.join(', '));
    expect(cls).toContain('state-processing');
    expect(cls).not.toContain('orb-mic-muted');
  });

  test('speakerMuted:true → state-speaker-muted only (no mic class)', async ({ page }) => {
    await sendOrbUpdate(page, { state: 'idle', level: 0, micMuted: false, speakerMuted: true });
    await page.waitForTimeout(200);
    const cls = await getOrbClasses(page);
    expect(cls).toContain('state-speaker-muted');
    expect(cls).not.toContain('orb-mic-muted');
  });

});

// ═══ Suite 3: Live LiveKit connection — real state machine ════════════════════

test.describe('Live connection — orb must be idle (not gray) after connect', () => {

  test('after room connect — state-idle set, no state-disconnected, no orb-mic-muted', async ({ page }) => {
    test.setTimeout(60000);
    await page.goto(BASE);
    await waitForFlutter(page);

    await page.waitForFunction(() =>
      performance.getEntriesByType('resource').some(e => e.name.includes('/api/token')),
      { timeout: 15000 }
    ).catch(() => {});

    await page.waitForTimeout(8000); // room connect + agent dispatch

    const cls = await getOrbClasses(page);
    const dbg = await getDebugBarText(page);
    console.log('Classes after connect:', cls.join(', ') || '(none)');
    console.log('Debug bar:', dbg);
    await page.screenshot({ path: 'screenshots/bug-after-connect.png' });

    expect(cls, 'must not be disconnected after connect').not.toContain('state-disconnected');
    expect(cls, 'must not have spurious mic-muted').not.toContain('orb-mic-muted');
    expect(cls, 'must be in idle state').toContain('state-idle');
  });

});
