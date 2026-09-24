import { mkdir, readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import AxeBuilder from '@axe-core/playwright';
import { expect, test, type Page } from '@playwright/test';
import type { BuildMeta } from '../src/data/buildMeta';
import type { Encounter, Enemy, EnemySpell, Room, Run, Snapshot, Spell } from '../src/types';

const screenshotDir = resolve('test-artifacts', 'screenshots');
let snapshot: Snapshot;
let buildMeta: BuildMeta;

async function open(page: Page, route: string, heading: string) {
  await page.goto(`/#/${route}`);
  await expect(page.getByRole('heading', { level: 1, name: heading })).toBeVisible();
}

function graph(): {
  run: Run;
  room: Room;
  encounter: Encounter;
  enemy: Enemy;
  spell: Spell;
  enemySpell: EnemySpell;
} {
  const run = snapshot.runs.find((entry) => entry.id === snapshot.primary_run_id) ?? snapshot.runs[0];
  const room = snapshot.rooms.find((entry) => entry.id === run.room_ids[0]) ?? snapshot.rooms[0];
  const encounter = snapshot.encounters.find((entry) => entry.id === room.default_encounter_id)
    ?? snapshot.encounters.find((entry) => entry.room_ids.includes(room.id))
    ?? snapshot.encounters[0];
  const enemy = snapshot.enemies.find((entry) => encounter.expanded_initial_enemy_ids.includes(entry.id))
    ?? snapshot.enemies[0];
  const spell = snapshot.spells.find((entry) => entry.referenced_by_character_ids.length > 0)
    ?? snapshot.spells[0];
  const enemySpell = snapshot.enemy_spells.find((entry) => (
    entry.referenced_by_enemy_ids.includes(enemy.id)
    && (
      entry.encounter_enabled_in_ids.includes(encounter.id)
      || entry.encounter_disabled_in_ids.includes(encounter.id)
      || encounter.disabled_ability_ids.includes(entry.id)
    )
  )) ?? snapshot.enemy_spells[0];
  return { run, room, encounter, enemy, spell, enemySpell };
}

test.beforeAll(async () => {
  const [snapshotText, buildMetaText] = await Promise.all([
    readFile(resolve('public', 'data', 'latest.json'), 'utf8'),
    readFile(resolve('public', 'generated', 'build_meta.json'), 'utf8'),
    mkdir(screenshotDir, { recursive: true }),
  ]);
  snapshot = JSON.parse(snapshotText) as Snapshot;
  buildMeta = JSON.parse(buildMetaText) as BuildMeta;
});

test('navigation principale et aria-current', async ({ page }) => {
  const character = snapshot.characters[0];
  await open(page, 'overview', 'État du jeu exporté');
  await page.getByRole('link', { name: 'Personnages' }).click();
  await expect(page.getByRole('heading', { level: 1, name: 'Personnages' })).toBeVisible();
  await expect(page.getByRole('link', { name: 'Personnages' })).toHaveAttribute('aria-current', 'page');
  await page.getByRole('link', { name: character.name }).click();
  await expect(page).toHaveURL(new RegExp(`#/characters/${character.id}$`));
});

test('toutes les routes principales lisent le snapshot réel sans écran blanc', async ({ page }) => {
  const { run, room, enemy, spell } = graph();
  const targets = [
    ['overview', 'État du jeu exporté'],
    ['runs', 'Runs'],
    ['run', run.name],
    [`runs/${run.id}`, run.name],
    [`rooms/${room.id}`, room.name],
    ['enemies', 'Ennemis'],
    [`enemies/${enemy.id}`, enemy.name],
    ['characters', 'Personnages'],
    [`characters/${snapshot.characters[0].id}`, snapshot.characters[0].name],
    ['spells', 'Sorts'],
    [`spells/${spell.id}`, spell.name],
    ['disciplines', 'Disciplines'],
    [`disciplines/${snapshot.disciplines[0].id}`, snapshot.disciplines[0].name],
    ['items', 'Objets'],
    [`items/${snapshot.items[0].id}`, snapshot.items[0].name],
    ['rewards', 'Récompenses'],
    ['audit', 'Contrat et audits'],
  ] as const;
  for (const [route, heading] of targets) await open(page, route, heading);
});

test('sépare la run principale et la run de test', async ({ page }) => {
  const production = snapshot.runs.find((run) => run.run_kind === 'production' && run.is_primary);
  const testRun = snapshot.runs.find((run) => run.run_kind === 'test');
  expect(production).toBeTruthy();
  expect(testRun).toBeTruthy();
  if (!production || !testRun) return;

  await open(page, 'run', production.name);
  await expect(page).toHaveURL(new RegExp(`#/runs/${production.id}$`));
  await expect(page.getByText('Aucun profil de vague.')).toBeVisible();
  await expect(page.getByText('Profils sélectionnés par la seed')).toHaveCount(0);

  await open(page, `runs/${testRun.id}`, testRun.name);
  await expect(page.locator('.test-tool-warning')).toContainText('Outil de test');
  await expect(page.getByText('Profils sélectionnés par la seed')).toBeVisible();
  const testRoom = snapshot.rooms.find((room) => room.run_id === testRun.id);
  expect(testRoom).toBeTruthy();
  if (testRoom) await open(page, `rooms/${testRoom.id}`, testRoom.name);
});

test('affiche le statut LAN et son dernier échec', async ({ page }) => {
  const production = snapshot.runs.find((run) => run.id === snapshot.primary_run_id) ?? snapshot.runs[0];
  await page.route('**/__observatory/status.json', (route) => route.fulfill({
    status: 200,
    contentType: 'application/json',
    body: JSON.stringify({
      active_sha: production.source_path ? snapshot.meta.source_game_commit : '',
      detected_sha: 'f'.repeat(40),
      last_success_at_utc: '2026-08-06T10:00:00.000Z',
      last_failure_at_utc: '2026-08-06T10:05:00.000Z',
      update_status: 'update_failed',
      message: 'Validation candidate échouée ; release valide conservée.',
    }),
  }));
  await open(page, 'overview', 'État du jeu exporté');
  await expect(page.getByText('Mise à jour LAN échouée')).toBeVisible();
  await page.getByText('Mise à jour LAN échouée').click();
  await expect(page.getByText(/release valide conservée/)).toBeVisible();
});

test('affiche le fallback lorsque le statut LAN est absent', async ({ page }) => {
  await page.route('**/__observatory/status.json', (route) => route.fulfill({ status: 404, body: '' }));
  await open(page, 'overview', 'État du jeu exporté');
  await expect(page.locator('.live-status > summary')).toContainText('Statut LAN indisponible');
});

test('navigation de la run à une salle puis aux ennemis', async ({ page }) => {
  const { run, room, enemy } = graph();
  await open(page, 'run', run.name);
  await page.getByRole('link', { name: new RegExp(room.name) }).first().click();
  await expect(page).toHaveURL(new RegExp(`#/rooms/${room.id}$`));
  await page.getByRole('link', { name: 'Ennemis' }).click();
  await page.getByRole('link', { name: enemy.name, exact: true }).click();
  await expect(page).toHaveURL(new RegExp(`#/enemies/${enemy.id}$`));
});

test('rechargement de routes hashées profondes', async ({ page }) => {
  const { spell, enemy } = graph();
  await open(page, `spells/${spell.id}`, spell.name);
  await page.reload();
  await expect(page.getByRole('heading', { level: 1, name: spell.name })).toBeVisible();
  await open(page, `enemies/${enemy.id}`, enemy.name);
  await page.reload();
  await expect(page.getByRole('heading', { level: 1, name: enemy.name })).toBeVisible();
});

test('filtres des sorts et des objets', async ({ page }) => {
  const { spell } = graph();
  await open(page, 'spells', 'Sorts');
  await page.getByRole('searchbox', { name: 'Recherche' }).fill(spell.name);
  await expect(page.getByRole('link', { name: spell.name }).first()).toBeVisible();
  await page.getByRole('searchbox', { name: 'Recherche' }).fill('aucun-resultat-observatory');
  await expect(page.getByText('Aucun sort trouvé')).toBeVisible();
  await open(page, 'items', 'Objets');
  await page.getByLabel('Première run uniquement').check();
  const eligibleCount = snapshot.items.filter((item) => item.tags.includes('first_run_equipment_reward')).length;
  await expect(page.locator('.entity-card')).toHaveCount(eligibleCount);
});

test('filtres des ennemis', async ({ page }) => {
  const { enemy } = graph();
  await open(page, 'enemies', 'Ennemis');
  await page.getByRole('searchbox', { name: 'Recherche' }).fill(enemy.name);
  await expect(page.getByRole('link', { name: enemy.name, exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Réinitialiser' }).click();
  await page.getByLabel('Présence').selectOption('summonable');
  const summonableCount = snapshot.enemies.filter((entry) => entry.reachability.summonable_by_spell_ids.length > 0).length;
  await expect(page.locator('.enemy-card')).toHaveCount(summonableCount);
});

test('bannière de fraîcheur et provenance globale', async ({ page }) => {
  await open(page, 'overview', 'État du jeu exporté');
  const indicator = page.locator(`.freshness--${buildMeta.freshness_status}`);
  await expect(indicator.locator('summary')).toBeVisible();
  await expect(page.locator('.topbar').getByText(snapshot.meta.source_game_commit.slice(0, 12), { exact: true })).toBeVisible();
  await indicator.locator('summary').click();
  const panel = indicator.locator('.freshness__panel');
  await expect(panel.getByText(snapshot.meta.source_game_commit, { exact: true })).toBeVisible();
  await expect(panel.getByText(snapshot.meta.source_branch, { exact: true })).toBeVisible();
});

test('audit groupé, occurrences brutes et navigation contextuelle', async ({ page }) => {
  const ruleId = 'WAVE.ATTACK_MULTIPLIER_NO_ACTIVE_DAMAGE_SOURCE';
  const expectedCount = snapshot.audit_results.filter((audit) => audit.rule_id === ruleId).length;
  await open(page, 'audit', 'Contrat et audits');
  const group = page.locator('.audit-group').filter({ hasText: ruleId });
  await expect(group).toContainText(`${expectedCount} occurrences`);
  await expect(group).toContainText('VÉRIFIÉ');
  await group.getByText(`Afficher les ${expectedCount} occurrences brutes`).click();
  const firstOccurrence = group.locator('.audit-occurrence').first();
  await expect(firstOccurrence).toBeVisible();
  await firstOccurrence.getByRole('link').click();
  await expect(page).toHaveURL(/#\/rooms\//);
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
});

test('filtres d’audit combinés persistés dans l’URL', async ({ page }) => {
  const ruleId = 'WAVE.ATTACK_MULTIPLIER_NO_ACTIVE_DAMAGE_SOURCE';
  const expectedCount = snapshot.audit_results.filter((audit) => audit.rule_id === ruleId).length;
  await open(page, 'audit', 'Contrat et audits');
  await page.getByRole('searchbox', { name: 'Recherche' }).fill('attack_power');
  await page.getByLabel('Sévérité').selectOption('warning');
  await page.getByLabel('Nature de preuve').selectOption('verified');
  await page.getByLabel('Règle').selectOption(ruleId);
  await page.getByLabel('Domaine').selectOption('waves');
  await page.getByLabel('Type d’entité').selectOption('wave');
  await page.getByLabel('Statut').selectOption('open');
  await expect(page.locator('.audit-result-count')).toContainText(`${expectedCount} occurrences · 1 groupe`);
  await expect(page).toHaveURL(/q=attack_power/);
  await expect(page).toHaveURL(/severity=warning/);
  await expect(page).toHaveURL(/truth=verified/);
  await expect(page).toHaveURL(/rule=WAVE/);
});

test('statistiques complètes d’un personnage', async ({ page }) => {
  const character = snapshot.characters[0];
  await open(page, `characters/${character.id}`, character.name);
  for (const label of [
    'Puissance d’attaque', 'Force', 'Armure', 'Résistance magique', 'Esquive',
    'Chance critique', 'Multiplicateur critique', 'Attaque de base active',
    'Emplacements actifs',
  ]) await expect(page.getByText(label, { exact: true })).toBeVisible();
});

test('détails complets d’un sort', async ({ page }) => {
  const { spell } = graph();
  await open(page, `spells/${spell.id}`, spell.name);
  for (const label of [
    'Cooldown initial', 'Une fois par activation', 'Ligne depuis le lanceur',
    'Dégâts de collision', 'Bonus de groupe', 'Drain de PA',
    'Téléportation derrière la cible', 'Résolution différée',
  ]) await expect(page.getByText(label, { exact: true })).toBeVisible();
  await expect(page.getByRole('heading', { name: 'Modificateurs' })).toBeVisible();
});

test('statut d’une capacité dans une rencontre', async ({ page }) => {
  const { room, encounter, enemySpell } = graph();
  const status = encounter.disabled_ability_ids.includes(enemySpell.id)
    || enemySpell.encounter_disabled_in_ids.includes(encounter.id)
    ? 'DÉSACTIVÉE DANS CETTE RENCONTRE'
    : enemySpell.encounter_enabled_in_ids.includes(encounter.id)
      ? enemySpell.condition_hp_at_or_below >= 0 || Boolean(enemySpell.requires_absent_unit_id)
        ? 'CONDITIONNELLE'
        : 'ACTIVE DANS CETTE RENCONTRE'
      : 'INCONNUE';
  await open(page, `rooms/${room.id}`, room.name);
  await expect(page.getByText(status, { exact: true }).first()).toBeVisible();
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
  for (const route of ['items', 'enemies', 'audit']) {
    await page.getByRole('link', { name: route === 'items' ? 'Objets' : route === 'enemies' ? 'Ennemis' : 'Audit' }).click();
    await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
  }
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
    const { run, enemy } = graph();
    await page.setViewportSize(viewport);
    const mobile = viewport.width <= 390;
    await open(page, mobile ? `enemies/${enemy.id}` : 'run', mobile ? enemy.name : run.name);
    const sizes = await page.evaluate(() => ({ scroll: document.documentElement.scrollWidth, client: document.documentElement.clientWidth }));
    expect(sizes.scroll).toBeLessThanOrEqual(sizes.client);
  });
}

test('audit responsive à 390 px', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await open(page, 'audit', 'Contrat et audits');
  const sizes = await page.evaluate(() => ({ scroll: document.documentElement.scrollWidth, client: document.documentElement.clientWidth }));
  expect(sizes.scroll).toBeLessThanOrEqual(sizes.client);
  await expect(page.locator('.audit-group').first()).toBeVisible();
});

for (const target of [
  { route: 'overview', heading: 'État du jeu exporté' },
  { route: 'runs', heading: 'Runs' },
  { route: 'run', heading: 'run' },
  { route: 'characters', heading: 'Personnages' },
  { route: 'enemies', heading: 'Ennemis' },
  { route: 'audit', heading: 'Contrat et audits' },
]) {
  test(`aucune violation Axe sérieuse sur ${target.route}`, async ({ page }) => {
    const { run } = graph();
    await open(page, target.route, target.heading === 'run' ? run.name : target.heading);
    const results = await new AxeBuilder({ page }).analyze();
    expect(results.violations.filter((violation) => ['critical', 'serious'].includes(violation.impact ?? ''))).toEqual([]);
  });
}

test('aucune violation Axe sérieuse sur la run de test', async ({ page }) => {
  const testRun = snapshot.runs.find((run) => run.run_kind === 'test');
  expect(testRun).toBeTruthy();
  if (!testRun) return;
  await open(page, `runs/${testRun.id}`, testRun.name);
  const results = await new AxeBuilder({ page }).analyze();
  expect(results.violations.filter((violation) => ['critical', 'serious'].includes(violation.impact ?? ''))).toEqual([]);
});

test('aucune violation Axe sérieuse sur une salle et un sort', async ({ page }) => {
  const { room, spell } = graph();
  for (const [route, heading] of [[`rooms/${room.id}`, room.name], [`spells/${spell.id}`, spell.name]]) {
    await open(page, route, heading);
    const results = await new AxeBuilder({ page }).analyze();
    expect(results.violations.filter((violation) => ['critical', 'serious'].includes(violation.impact ?? ''))).toEqual([]);
  }
});

test('captures de référence', async ({ page }) => {
  const { run, room, enemy, spell } = graph();
  const targets = [
    [{ width: 1920, height: 1080 }, 'overview', 'État du jeu exporté', 'overview-1920x1080.png'],
    [{ width: 1366, height: 768 }, 'characters', 'Personnages', 'characters-1366x768.png'],
    [{ width: 390, height: 844 }, 'audit', 'Contrat et audits', 'audit-390x844.png'],
    [{ width: 1920, height: 1080 }, 'run', run.name, 'run-1920x1080.png'],
    [{ width: 1366, height: 768 }, `rooms/${room.id}`, room.name, 'room-1366x768.png'],
    [{ width: 390, height: 844 }, `enemies/${enemy.id}`, enemy.name, 'enemy-390x844.png'],
    [{ width: 1366, height: 768 }, `spells/${spell.id}`, spell.name, 'spell-1366x768.png'],
  ] as const;
  for (const [viewport, route, heading, filename] of targets) {
    await page.setViewportSize(viewport);
    await open(page, route, heading);
    await page.screenshot({ path: resolve(screenshotDir, filename), fullPage: true });
  }
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
