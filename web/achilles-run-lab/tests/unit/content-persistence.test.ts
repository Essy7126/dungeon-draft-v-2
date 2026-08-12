import { readFile, readdir } from 'node:fs/promises';
import path from 'node:path';
import { describe, expect, test, vi } from 'vitest';
import { createDefaultConfig } from '../../src/content/defaults';
import { importConfigJson, validateConfig } from '../../src/content/content_loader';
import { applyGameCommand, createInitialGameState } from '../../src/domain/run/engine';
import { normalizeSeed, nextRandom, seededShuffle } from '../../src/domain/rng/prng';
import { fnv1a, stableStringify } from '../../src/domain/replay/hash';
import { createRunReport } from '../../src/domain/telemetry/report';
import { clearSave, loadGame, saveGame, SAVE_KEY } from '../../src/persistence/save';

class MemoryStorage implements Storage {
  private readonly values = new Map<string, string>();
  get length(): number { return this.values.size; }
  clear(): void { this.values.clear(); }
  getItem(key: string): string | null { return this.values.get(key) ?? null; }
  key(index: number): string | null { return [...this.values.keys()][index] ?? null; }
  removeItem(key: string): void { this.values.delete(key); }
  setItem(key: string, value: string): void { this.values.set(key, value); }
}

function startedState() {
  const config = createDefaultConfig(12345);
  const result = applyGameCommand(createInitialGameState(), { type: 'START_RUN', seed: config.seed, config });
  if (!result.accepted) throw new Error(result.error);
  return result.state;
}

async function filesRecursively(root: string): Promise<string[]> {
  const entries = await readdir(root, { withFileTypes: true });
  const files: string[] = [];
  for (const entry of entries) {
    const candidate = path.join(root, entry.name);
    if (entry.isDirectory()) files.push(...await filesRecursively(candidate)); else files.push(candidate);
  }
  return files;
}

describe('contenu et persistance', () => {
  test('une configuration Run Lab valide est acceptée', () => {
    const result = validateConfig(createDefaultConfig());
    expect(result.ok).toBe(true);
    if (result.ok) expect(result.config.rooms).toHaveLength(5);
  });

  test('un import JSON valide conserve la configuration', () => {
    const config = createDefaultConfig(99);
    const result = importConfigJson(JSON.stringify(config));
    expect(result.ok).toBe(true);
    if (result.ok) expect(result.config.seed).toBe(99);
  });

  test('un import invalide retourne le chemin exact', () => {
    const config = createDefaultConfig();
    const firstRoom = config.rooms[0];
    if (firstRoom === undefined) throw new Error('Salle de test absente');
    firstRoom.blockedCells.push({ x: 99, y: 1 });
    const result = importConfigJson(JSON.stringify(config));
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.errors.join(' ')).toContain('rooms.0.blockedCells');
  });

  test('un JSON syntaxiquement invalide est rejeté proprement', () => {
    const result = importConfigJson('{ nope');
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.errors[0]).toContain('$:');
  });

  test('sauvegarde puis reprise restaure exactement les hashes', () => {
    const storage = new MemoryStorage(); vi.stubGlobal('localStorage', storage);
    const state = startedState();
    saveGame(state);
    const loaded = loadGame();
    expect(loaded.ok).toBe(true);
    if (loaded.ok) expect(loaded.state.stateHashes).toEqual(state.stateHashes);
    clearSave();
    expect(loadGame().ok).toBe(false);
    vi.unstubAllGlobals();
  });

  test('une sauvegarde invalide est rejetée sans exception', () => {
    const storage = new MemoryStorage(); vi.stubGlobal('localStorage', storage);
    storage.setItem(SAVE_KEY, '{ broken');
    const loaded = loadGame();
    expect(loaded.ok).toBe(false);
    if (!loaded.ok) { expect(loaded.error).toContain('corrompue'); expect(loaded.raw).toBe('{ broken'); }
    vi.unstubAllGlobals();
  });

  test('une version de sauvegarde incompatible est rejetée', () => {
    const storage = new MemoryStorage(); vi.stubGlobal('localStorage', storage);
    storage.setItem(SAVE_KEY, JSON.stringify({ saveVersion: 999, state: {} }));
    expect(loadGame().ok).toBe(false);
    vi.unstubAllGlobals();
  });
});

describe('PRNG et hash', () => {
  test('le PRNG est seedé et reproductible', () => {
    const first = nextRandom(normalizeSeed(42));
    const second = nextRandom(normalizeSeed(42));
    expect(first).toEqual(second);
    expect(first.value).toBeGreaterThanOrEqual(0);
    expect(first.value).toBeLessThan(1);
  });

  test('les seeds nulles et négatives sont normalisées', () => {
    expect(normalizeSeed(0)).not.toBe(0);
    expect(normalizeSeed(-42)).toBe(42);
  });

  test('le shuffle seedé ne mutile pas son entrée', () => {
    const input = [1, 2, 3, 4, 5];
    const result = seededShuffle(input, 123);
    expect(input).toEqual([1, 2, 3, 4, 5]);
    expect([...result.values].sort()).toEqual(input);
  });

  test('stableStringify et FNV sont indépendants de l’ordre des clés', () => {
    expect(fnv1a(stableStringify({ b: 2, a: 1 }))).toBe(fnv1a(stableStringify({ a: 1, b: 2 })));
  });

  test('le domaine ne contient aucun appel à Math.random', async () => {
    const domain = path.resolve('src/domain');
    const files = (await filesRecursively(domain)).filter((file) => file.endsWith('.ts'));
    const matches: string[] = [];
    for (const file of files) if ((await readFile(file, 'utf8')).includes('Math.random(')) matches.push(file);
    expect(matches).toEqual([]);
  });

  test('le rapport sérialise toutes les métriques déterministes', () => {
    const state = startedState();
    const report = createRunReport(state, 123, 'HEADLESS');
    expect(report).toMatchObject({ seed: 12345, durationMs: 123, rendererBackend: 'HEADLESS', result: 'IN_PROGRESS', roomReached: 1 });
    expect(report.commands).toHaveLength(1);
    state.battle = null;
    expect(createRunReport(state, 0, 'HEADLESS').remainingHp).toBe(state.run?.persistentHeroHp);
  });
});
