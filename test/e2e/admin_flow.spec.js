// @ts-check
const { test, expect } = require('@playwright/test');

test.describe('Admin flow', () => {
  test.beforeEach(async ({ page }) => {
    // Login as admin user (meow1)
    await page.goto('/signin');

    // Check if we're already logged in (redirected to dashboard)
    const url = page.url();
    if (url.includes('/dashboard') || url.includes('/channels')) {
      return; // Already logged in
    }

    // Fill in login form
    await page.fill('input[name="username"]', 'meow1');
    await page.fill('input[name="password"]', 'password');
    await page.click('input[type="submit"]');
    await page.waitForURL(/\/(dashboard|channels)/, { timeout: 30000 });
  });

  test('can access admin dashboard', async ({ page }) => {
    await page.goto('/admin');
    // Admin nav shows "Admin" text and Dashboard is visible
    await expect(page.locator('text=Admin')).toBeVisible();
    await expect(page.locator('text=Dashboard')).toBeVisible();
  });

  test('admin settings page has all sections', async ({ page }) => {
    await page.goto('/admin/settings/edit');

    // General settings
    await expect(page.locator('h2:has-text("General")')).toBeVisible();
    await expect(page.locator('input[name="site_name"]')).toBeVisible();
    await expect(page.locator('input[name="allow_signups"]')).toBeVisible();

    // PWA settings
    await expect(page.locator('h3:has-text("Progressive Web App")')).toBeVisible();
    await expect(page.locator('input[name="pwa_enabled"]')).toBeVisible();

    // API & Integrations settings
    await expect(page.locator('h3:has-text("API & Integrations")')).toBeVisible();
    await expect(page.locator('input[name="api_enabled"]')).toBeVisible();
    await expect(page.locator('input[name="home_assistant_enabled"]')).toBeVisible();

    // LiteLLM settings
    await expect(page.locator('h3:has-text("AI & LiteLLM")')).toBeVisible();
  });

  test('can save admin settings', async ({ page }) => {
    await page.goto('/admin/settings/edit');

    // Change site name
    const siteNameInput = page.locator('input[name="site_name"]');
    await siteNameInput.fill('Test HomeChat');

    // Submit form
    await page.click('input[type="submit"][value="Save Settings"]');

    // Should stay on settings page (no redirect on success)
    await expect(page).toHaveURL(/\/admin\/settings/);
  });

  test('admin tokens page is accessible', async ({ page }) => {
    await page.goto('/admin/tokens');

    // Should show tokens management
    await expect(page.locator('text=Admin')).toBeVisible();
    await expect(page.locator('text=Tokens')).toBeVisible();
  });

  test('admin bots page is accessible', async ({ page }) => {
    await page.goto('/admin/bots');

    await expect(page.locator('text=Admin')).toBeVisible();
    await expect(page.locator('text=Bots')).toBeVisible();
  });

  test('admin users page is accessible', async ({ page }) => {
    await page.goto('/admin/users');

    await expect(page.locator('text=Admin')).toBeVisible();
    await expect(page.locator('text=Users')).toBeVisible();
  });

  test('HA setup page shows documentation', async ({ page }) => {
    await page.goto('/admin/integrations');

    await expect(page.locator('text=Admin')).toBeVisible();
    // Should show setup documentation
    await expect(page.locator('text=Home Assistant')).toBeVisible();
  });

  test('admin navigation works correctly', async ({ page }) => {
    await page.goto('/admin');

    // Navigate through all admin pages
    const navLinks = [
      { text: 'Settings', url: /\/admin\/settings/ },
      { text: 'Tokens', url: /\/admin\/tokens/ },
      { text: 'Bots', url: /\/admin\/bots/ },
      { text: 'Users', url: /\/admin\/users/ },
      { text: 'HA Setup', url: /\/admin\/integrations/ },
      { text: 'Dashboard', url: /\/admin$/ },
    ];

    for (const link of navLinks) {
      await page.click(`a:has-text("${link.text}")`);
      await expect(page).toHaveURL(link.url);
    }
  });
});

test.describe('Admin access control', () => {
  test('non-admin cannot access admin pages', async ({ page }) => {
    // Try to access admin without login
    await page.goto('/admin');

    // Should redirect to signin or show error
    const url = page.url();
    const hasError = await page.locator('text=Admins only').count() > 0;
    const redirectedToSignin = url.includes('/signin');

    expect(hasError || redirectedToSignin).toBe(true);
  });
});
