// @ts-check
const { test, expect } = require('@playwright/test');

test.describe('Mobile viewport tests', () => {
  test.beforeEach(async ({ page }) => {
    // Login as test user
    await page.goto('/signin');

    // Check if already logged in
    const url = page.url();
    if (url.includes('/dashboard') || url.includes('/channels')) {
      return;
    }

    await page.fill('input[name="username"]', 'meow1');
    await page.fill('input[name="password"]', 'password');
    await page.click('input[type="submit"]');
    await page.waitForURL(/\/(dashboard|channels)/, { timeout: 30000 });
  });

  test('sidebar toggle works on mobile', async ({ page }) => {
    // On mobile, sidebar should be hidden by default
    const sidebar = page.locator('[data-sidebar-target="panel"]');

    // Check sidebar is off-screen (has -translate-x-full)
    await expect(sidebar).toHaveClass(/-translate-x-full/);

    // Click hamburger menu to open sidebar
    const hamburger = page.locator('button[data-action*="sidebar#open"]').first();
    await hamburger.click();

    // Sidebar should now be visible
    await expect(sidebar).toHaveClass(/translate-x-0/);

    // Body should have overflow-hidden when sidebar is open
    await expect(page.locator('body')).toHaveClass(/overflow-hidden/);

    // Close sidebar by clicking backdrop
    const backdrop = page.locator('[data-sidebar-target="backdrop"]');
    await backdrop.click();

    // Sidebar should be hidden again
    await expect(sidebar).toHaveClass(/-translate-x-full/);
  });

  test('message bubbles have appropriate width on mobile', async ({ page }) => {
    // Navigate to a channel
    await page.goto('/channels/1');

    // Wait for messages to load
    await page.waitForSelector('.message-bubble', { timeout: 5000 }).catch(() => {});

    // Check message content has correct max-width class
    const messageContent = page.locator('.message-content').first();
    if (await messageContent.count() > 0) {
      // On mobile, should have max-w-[85%]
      const classes = await messageContent.getAttribute('class');
      expect(classes).toContain('max-w-[85%]');
    }
  });

  test('settings page loads without tabs', async ({ page }) => {
    await page.goto('/settings/edit');

    // Should see all sections visible (no tabs)
    await expect(page.locator('h2:has-text("Profile")')).toBeVisible();
    await expect(page.locator('h2:has-text("Change Password")')).toBeVisible();
    await expect(page.locator('h2:has-text("Preferences")')).toBeVisible();

    // Save button should be visible
    await expect(page.locator('input[type="submit"][value="Save Changes"]')).toBeVisible();
  });
});

test.describe('Admin pages on mobile', () => {
  test.beforeEach(async ({ page }) => {
    // Login as admin user
    await page.goto('/signin');

    // Check if already logged in
    const url = page.url();
    if (url.includes('/dashboard') || url.includes('/channels')) {
      return;
    }

    await page.fill('input[name="username"]', 'meow1');
    await page.fill('input[name="password"]', 'password');
    await page.click('input[type="submit"]');
    await page.waitForURL(/\/(dashboard|channels)/, { timeout: 30000 });
  });

  test('admin settings page shows all sections', async ({ page }) => {
    await page.goto('/admin/settings/edit');

    // Should see General, PWA, API & Integrations, and LiteLLM sections
    await expect(page.locator('h2:has-text("General")')).toBeVisible();
    await expect(page.locator('h3:has-text("Progressive Web App")')).toBeVisible();
    await expect(page.locator('h3:has-text("API & Integrations")')).toBeVisible();
    await expect(page.locator('h3:has-text("AI & LiteLLM")')).toBeVisible();
  });

  test('admin nav shows all links including Settings', async ({ page }) => {
    await page.goto('/admin');

    // Check nav links exist
    await expect(page.locator('a:has-text("Dashboard")')).toBeVisible();
    await expect(page.locator('a:has-text("Settings")')).toBeVisible();
    await expect(page.locator('a:has-text("Tokens")')).toBeVisible();
    await expect(page.locator('a:has-text("Bots")')).toBeVisible();
    await expect(page.locator('a:has-text("Users")')).toBeVisible();
    await expect(page.locator('a:has-text("HA Setup")')).toBeVisible();
  });
});
