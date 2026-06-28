const { test, expect } = require('playwright/test');

test.use({ channel: 'chrome' });

test('smoke admin opens', async ({ page }) => {
  await page.goto('http://localhost:10531');
  await expect(page).toHaveURL(/localhost:10531/);
});
