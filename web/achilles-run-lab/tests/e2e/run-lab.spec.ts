import { expect, test, type Page } from '@playwright/test';
import { createDefaultConfig } from '../../src/content/defaults';
import type { EnemyId, RunLabConfig } from '../../src/content/schemas';

const artifacts = 'artifacts/validation';

function runtimeWatch(page: Page): { errors: string[]; external: string[] } {
  const errors: string[] = [];
  const external: string[] = [];
  page.on('console', (message) => { if (message.type() === 'error') errors.push(message.text()); });
  page.on('pageerror', (error) => errors.push(error.message));
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.origin !== 'http://127.0.0.1:4173') external.push(request.url());
  });
  return { errors, external };
}

function shortConfig(options: { seed: number; roomCount: number; enemyId?: EnemyId; enemyHp?: number; difficulty?: number }): RunLabConfig {
  const config = createDefaultConfig(options.seed);
  config.difficulty = options.difficulty ?? 1;
  const enemyId = options.enemyId ?? 'spearman';
  for (const [index, room] of config.rooms.entries()) {
    room.active = index < options.roomCount;
    room.enemies = [{ enemyId, count: 1 }];
  }
  const enemy = config.enemies.find((candidate) => candidate.id === enemyId);
  if (enemy !== undefined && options.enemyHp !== undefined) { enemy.maxHp = options.enemyHp; enemy.armor = 0; }
  return config;
}

async function startLabConfig(page: Page, config: RunLabConfig): Promise<void> {
  await page.getByTestId('open-lab').click();
  await page.getByTestId('lab-json').fill(JSON.stringify(config));
  await page.getByTestId('lab-import').click();
  await page.getByTestId('lab-start').click();
  await expect(page.getByTestId('battle-canvas')).toBeVisible();
}

async function killFirstEnemy(page: Page): Promise<void> {
  await page.keyboard.press('1');
  await expect(page.getByTestId('ability-pursuit_thrust')).toHaveAttribute('aria-pressed', 'true');
  await expect(page.getByTestId('legal-target-0')).toBeVisible();
  await page.getByTestId('legal-target-0').click();
}

test.beforeEach(async ({ page }) => {
  await page.goto('/?renderer=webgl');
  await page.evaluate(() => localStorage.clear());
  await page.reload();
});

test('menu réel, boutons actifs, console et réseau propres', async ({ page }) => {
  const watch = runtimeWatch(page);
  await page.reload({ waitUntil: 'networkidle' });
  await expect(page.getByRole('heading', { name: /Achilles/i })).toBeVisible();
  await expect(page.getByTestId('new-run')).toBeEnabled();
  await expect(page.getByTestId('continue-run')).toBeEnabled();
  await expect(page.getByTestId('open-lab')).toBeEnabled();
  const buttons = page.getByRole('button');
  for (let index = 0; index < await buttons.count(); index += 1) await expect(buttons.nth(index)).toBeEnabled();
  await page.screenshot({ path: `${artifacts}/menu-1280x720.png` });
  expect(watch.errors).toEqual([]);
  expect(watch.external).toEqual([]);
});

test('run par défaut : seed, 6 PA, 3 PM, déplacement et attaque réelle', async ({ page }) => {
  const watch = runtimeWatch(page);
  await page.getByTestId('new-run').click();
  await expect(page.getByTestId('hero-ap')).toHaveText('6');
  await expect(page.getByTestId('hero-mp')).toHaveText('3');
  await expect(page.locator('.debug-panel summary')).toContainText('WebGL 2');
  await page.waitForTimeout(500);
  await page.screenshot({ path: `${artifacts}/combat-1280x720.png` });

  const move = page.locator('[data-testid^="move-"]').first();
  await expect(move).toBeVisible();
  await move.click();
  await expect(page.getByTestId('hero-mp')).not.toHaveText('3');

  await page.reload();
  await page.getByTestId('continue-run').click();
  await expect(page.getByTestId('hero-mp')).not.toHaveText('3');

  await page.goto('/?renderer=webgl');
  await page.getByTestId('new-run').click();
  const hpBefore = await page.locator('.enemy-list div').first().innerText();
  await page.keyboard.press('1');
  await expect(page.getByTestId('legal-target-0')).toBeVisible();
  await page.screenshot({ path: `${artifacts}/targeting-1280x720.png` });
  await page.getByTestId('legal-target-0').click();
  await expect(page.getByTestId('hero-ap')).toHaveText('4');
  await expect(page.locator('.enemy-list div').first()).not.toHaveText(hpBefore);
  await page.getByTestId('end-turn').click();
  await expect(page.locator('.round-chip')).toContainText('2');
  await expect(page.locator('body')).not.toContainText(/intention ennemie/i);
  expect(watch.errors).toEqual([]);
  expect(watch.external).toEqual([]);
});

test('récompense, sélection, salle suivante et sauvegarde', async ({ page }) => {
  await startLabConfig(page, shortConfig({ seed: 200, roomCount: 2, enemyHp: 1 }));
  await killFirstEnemy(page);
  await expect(page.getByTestId('reward-screen')).toBeVisible();
  await expect(page.locator('.reward-grid button')).toHaveCount(3);
  await page.screenshot({ path: `${artifacts}/reward-1280x720.png` });
  await page.getByTestId('reward-0').click();
  await expect(page.getByTestId('continue-room')).toBeVisible();
  await page.getByTestId('continue-room').click();
  await expect(page.locator('.room-heading')).toContainText('SALLE 2/2');
  await page.reload();
  await page.getByTestId('continue-run').click();
  await expect(page.locator('.room-heading')).toContainText('SALLE 2/2');
});

test('Run Lab modifie, valide, importe, réordonne et lance sa composition', async ({ page }) => {
  await page.getByTestId('open-lab').click();
  await expect(page.getByTestId('run-lab')).toBeVisible();
  await page.getByTestId('lab-seed').fill('424242');
  await page.getByTestId('enemy-hp-spearman').fill('1');
  await page.locator('[data-testid="lab-room-0"] .add-entry').click();
  await page.locator('[data-testid="lab-room-0"] .entries > div').last().locator('select').selectOption('archer');
  await page.locator('[data-testid="lab-room-1"] button[aria-label="Monter la salle"]').click();
  await page.screenshot({ path: `${artifacts}/run-lab-1280x720.png` });

  const imported = shortConfig({ seed: 5150, roomCount: 1, enemyHp: 1 });
  await page.getByTestId('lab-json').fill(JSON.stringify(imported));
  await page.getByTestId('lab-import').click();
  await expect(page.getByTestId('lab-seed')).toHaveValue('5150');
  await page.getByTestId('lab-start').click();
  await expect(page.locator('.debug-panel')).toContainText('5150');
});

test('victoire complète reproductible sur une configuration courte', async ({ page }) => {
  await startLabConfig(page, shortConfig({ seed: 901, roomCount: 1, enemyHp: 1 }));
  await killFirstEnemy(page);
  await expect(page.getByRole('heading', { name: 'Victoire' })).toBeVisible();
  await expect(page.getByTestId('run-report')).toContainText('WON');
  await page.screenshot({ path: `${artifacts}/victory-short-scenario.png` });
});

test('défaite atteignable par les règles de production', async ({ page }) => {
  await startLabConfig(page, shortConfig({ seed: 902, roomCount: 1, enemyId: 'brute', enemyHp: 500, difficulty: 2 }));
  for (let turn = 0; turn < 15 && await page.getByTestId('defeat-screen').count() === 0; turn += 1) {
    await page.getByTestId('end-turn').click();
    await page.waitForTimeout(80);
  }
  await expect(page.getByRole('heading', { name: 'Défaite' })).toBeVisible();
  await expect(page.getByTestId('run-report')).toContainText('LOST');
});

test('fallback procédural, 1920×1080 et absence d’exception', async ({ page }) => {
  const watch = runtimeWatch(page);
  await page.setViewportSize({ width: 1920, height: 1080 });
  await page.goto('/?renderer=webgl');
  await page.getByTestId('new-run').click();
  await page.waitForTimeout(400);
  await page.screenshot({ path: `${artifacts}/combat-1920x1080.png` });

  await page.setViewportSize({ width: 1280, height: 720 });
  await page.goto('/?renderer=webgl&model=fallback');
  await page.getByTestId('new-run').click();
  await page.waitForTimeout(400);
  await page.locator('.debug-panel summary').click();
  await expect(page.locator('.debug-panel')).toContainText('FALLBACK');
  await page.locator('.debug-panel summary').click();
  await expect(page.locator('[data-testid^="move-"]').first()).toBeVisible();
  await page.screenshot({ path: `${artifacts}/fallback-model-1280x720.png` });
  expect(watch.errors).toEqual([]);
  expect(watch.external).toEqual([]);
});

test('un JSON Run Lab invalide affiche le chemin de schéma', async ({ page }) => {
  await page.getByTestId('open-lab').click();
  const config = createDefaultConfig(3);
  const firstRoom = config.rooms[0];
  if (firstRoom === undefined) throw new Error('Salle de test absente');
  firstRoom.blockedCells.push({ x: 99, y: 1 });
  await page.getByTestId('lab-json').fill(JSON.stringify(config));
  await page.getByTestId('lab-import').click();
  await expect(page.getByRole('alert')).toContainText('rooms.0.blockedCells');
});
