import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  timeout: 30000,
  reporter: [['html', { outputFolder: 'report', open: 'never' }], ['line']],
  use: {
    baseURL: 'https://rg-w00-chat.resonancegroupusa.com',
    screenshot: 'on',
    video: 'off',
    trace: 'on-first-retry',
  },
  projects: [
    {
      name: 'chromium',
      use: { channel: 'chromium' },
    },
  ],
});
