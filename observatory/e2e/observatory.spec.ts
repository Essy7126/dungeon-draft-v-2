import { mkdir } from 'node:fs/promises';
import { resolve } from 'node:path';
import AxeBuilder from '@axe-core/playwright';
import { expect, test, type Page } from '@playwright/test';

const screenshotDir = resolve('test-artifacts', 'screenshots');

async function open(page: Page, route: string, heading: string) {
  await page.goto(`/#/${route}`);
  await expect(page.getByRole('heading', { level: 1, name: heading })).toBeVisible();
}

test.beforeAll(async () => {
  await mkdir(screenshotDir, { recursive: true });
});

test('navigation principale et aria-current', async ({ page }) => {
  await open(page, 'overview', 'État du jeu exporté');
  await page.getByRole('link', { name: 'Personnages' }).click();
  await expect(page.getByRole('heading', { level: 1, name: 'Personnages' })).toBeVisible();
  await expect(page.getByRole('link', { name: 'Personnages' })).toHaveAttribute('aria-current', 'page');
  await page.getByRole('link', { name: 'Elfe' }).click();
  await expect(page).toHaveURL(/#\/characters\/elf$/);
});

test('navigation de la run à une salle puis aux ennemis', async ({ page }) => {
  await open(page, 'overview', 'État du jeu exporté');
  await page.getByRole('link', { name: 'Run', exact: true }).click();
  await expect(page.getByRole('heading', { level: 1, name: 'Première run' })).toBeVisible();
  await page.getByRole('link', { name: /Salle 1 - Gué forestier/ }).first().click();
  await expect(page).toHaveURL(/#\/rooms\/first_run\.room\.01$/);
  await expect(page.getByRole('heading', { level: 1, name: 'Salle 1 - Gué forestier' })).toBeVisible();
  await page.getByRole('link', { name: 'Ennemis' }).click();
  await expect(page.getByRole('heading', { level: 1, name: 'Ennemis' })).toBeVisible();
  await page.getByRole('link', { name: 'Chef squelette rouge' }).click();
  await expect(page).toHaveURL(/#\/enemies\/skeleton_chief$/);
});

test('rechargement d’une route hashée profonde', async ({ page }) => {
  await open(page, 'spells/elf_fireball', 'Boule de feu');
  await page.reload();
  await expect(page.getByRole('heading', { level: 1, name: 'Boule de feu' })).toBeVisible();
  await open(page, 'enemies/skeleton_chief', 'Chef squelette rouge');
  await page.reload();
  await expect(page.getByRole('heading', { level: 1, name: 'Chef squelette rouge' })).toBeVisible();
});

test('filtres des sorts et des objets', async ({ page }) => {
  await open(page, 'spells', 'Sorts');
  await page.getByRole('searchbox', { name: 'Recherche' }).fill('boule de feu');
  await expect(page.getByRole('link', { name: 'Boule de feu' }).first()).toBeVisible();
  await page.getByRole('searchbox', { name: 'Recherche' }).fill('aucun-resultat');
  await expect(page.getByText('Aucun sort trouvé')).toBeVisible();
  await open(page, 'items', 'Objets');
  await page.getByLabel('Première run uniquement').check();
  await expect(page.locator('.entity-card')).toHaveCount(14);
});

test('filtres des ennemis', async ({ page }) => {
  await open(page, 'enemies', 'Ennemis');
  await page.getByRole('searchbox', { name: 'Recherche' }).fill('centurion');
  await expect(page.locator('.enemy-card')).toHaveCount(1);
  await page.getByRole('button', { name: 'Réinitialiser' }).click();
  await page.getByLabel('Effet').selectOption('summoner');
  await expect(page.getByRole('link', { name: 'Centurion squelette de glace' })).toBeVisible();
  await page.getByLabel('Présence').selectOption('summonable');
  await expect(page.getByText('Aucun ennemi trouvé')).toBeVisible();
});

test('navigation clavier et lien d’évitement', async ({ page }) => {
  await open(page, 'overview', 'État du jeu exporté');
  await page.keyboard.press('Tab');
  const skipLink = page.getByRole('link', { name: 'Aller au contenu' });
  await expect(skipLink).toBeFocused();
  await page.keyboard.press('Enter');
  await expect(page.locator('#main-content')).toBeFocused();
});

test('aucune requête externe ni res://', async ({ page }) => {
  const requests: string[] = [];
  page.on('request', (request) => requests.push(request.url()));
  await open(page, 'overview', 'État du jeu exporté');
  await page.getByRole('link', { name: 'Objets' }).click();
  await expect(page.getByRole('heading', { level: 1, name: 'Objets' })).toBeVisible();
  await page.getByRole('link', { name: 'Ennemis' }).click();
  await expect(page.getByRole('heading', { level: 1, name: 'Ennemis' })).toBeVisible();
  const external = requests.filter((raw) => {
    const url = new URL(raw);
    return url.hostname !== '127.0.0.1' || url.port !== '4173';
  });
  expect(external).toEqual([]);
  expect(requests.filter((url) => url.startsWith('res://'))).toEqual([]);
});

for (const viewport of [
  { width: 1920, height: 1080 },
  { width: 1366, height: 768 },
  { width: 768, height: 1024 },
  { width: 390, height: 844 },
  { width: 320, height: 568 },
]) {
  test(`aucun débordement global à ${viewport.width}×${viewport.height}`, async ({ page }) => {
    await page.setViewportSize(viewport);
    const mobile = viewport.width <= 390;
    await open(page, mobile ? 'enemies/skeleton_chief' : 'run', mobile ? 'Chef squelette rouge' : 'Première run');
    const sizes = await page.evaluate(() => ({ scroll: document.documentElement.scrollWidth, client: document.documentElement.clientWidth }));
    expect(sizes.scroll).toBeLessThanOrEqual(sizes.client);
  });
}

for (const target of [
  { route: 'overview', heading: 'État du jeu exporté' },
  { route: 'characters', heading: 'Personnages' },
  { route: 'items', heading: 'Objets' },
  { route: 'audit', heading: 'Contrat et audits' },
  { route: 'run', heading: 'Première run' },
  { route: 'rooms/first_run.room.01', heading: 'Salle 1 - Gué forestier' },
  { route: 'enemies', heading: 'Ennemis' },
  { route: 'enemies/skeleton_chief', heading: 'Chef squelette rouge' },
]) {
  test(`aucune violation Axe sérieuse sur ${target.route}`, async ({ page }) => {
    await open(page, target.route, target.heading);
    const results = await new AxeBuilder({ page }).analyze();
    const severe = results.violations.filter((violation) => violation.impact === 'critical' || violation.impact === 'serious');
    expect(severe).toEqual([]);
  });
}

test('captures de référence', async ({ page }) => {
  await page.setViewportSize({ width: 1920, height: 1080 });
  await open(page, 'overview', 'État du jeu exporté');
  await page.screenshot({ path: resolve(screenshotDir, 'overview-1920x1080.png'), fullPage: true });

  await page.setViewportSize({ width: 1366, height: 768 });
  await open(page, 'characters', 'Personnages');
  await page.screenshot({ path: resolve(screenshotDir, 'characters-1366x768.png'), fullPage: true });

  await page.setViewportSize({ width: 390, height: 844 });
  await open(page, 'items', 'Objets');
  await page.screenshot({ path: resolve(screenshotDir, 'items-390x844.png'), fullPage: true });

  await page.setViewportSize({ width: 1920, height: 1080 });
  await open(page, 'audit', 'Contrat et audits');
  await page.screenshot({ path: resolve(screenshotDir, 'audit-1920x1080.png'), fullPage: true });

  await page.setViewportSize({ width: 1920, height: 1080 });
  await open(page, 'run', 'Première run');
  await page.screenshot({ path: resolve(screenshotDir, 'run-1920x1080.png'), fullPage: true });

  await page.setViewportSize({ width: 1366, height: 768 });
  await open(page, 'rooms/first_run.room.01', 'Salle 1 - Gué forestier');
  await page.screenshot({ path: resolve(screenshotDir, 'room-1366x768.png'), fullPage: true });

  await page.setViewportSize({ width: 1920, height: 1080 });
  await open(page, 'enemies', 'Ennemis');
  await page.screenshot({ path: resolve(screenshotDir, 'enemies-1920x1080.png'), fullPage: true });

  await page.setViewportSize({ width: 390, height: 844 });
  await open(page, 'enemies/skeleton_chief', 'Chef squelette rouge');
  await page.screenshot({ path: resolve(screenshotDir, 'enemy-390x844.png'), fullPage: true });
});

test('capture de l’erreur de données', async ({ page }) => {
  await page.setViewportSize({ width: 1366, height: 768 });
  await page.route('**/data/latest.json', (route) => route.fulfill({ status: 503, contentType: 'application/json', body: '{}' }));
  await page.goto('/#/overview');
  await expect(page.getByRole('heading', { name: 'Impossible d’ouvrir Observatory' })).toBeVisible();
  await expect(page.getByText('npm run validate:data')).toBeVisible();
  await page.screenshot({ path: resolve(screenshotDir, 'data-error-1366x768.png'), fullPage: true });
});

test('route inconnue locale', async ({ page }) => {
  await open(page, 'route-inconnue', 'Page locale introuvable');
  await expect(page.getByRole('link', { name: 'Revenir à la vue globale' })).toBeVisible();
});
