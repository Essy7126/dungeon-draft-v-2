import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { beforeAll, describe, expect, it } from 'vitest';
import { compileSnapshotValidator, validateSnapshot } from '../data/validation';
import type { Snapshot } from '../types';

let snapshot: Snapshot;

beforeAll(async () => {
  const [snapshotText, schemaText] = await Promise.all([
    readFile(resolve('public', 'data', 'latest.json'), 'utf8'),
    readFile(resolve('..', 'tools', 'observatory', 'schemas', 'observatory_snapshot.schema.json'), 'utf8'),
  ]);
  const result = validateSnapshot(
    JSON.parse(snapshotText),
    compileSnapshotValidator(JSON.parse(schemaText)),
  );
  expect(result.issues).toEqual([]);
  expect(result.snapshot).toBeDefined();
  snapshot = result.snapshot as Snapshot;
});

describe('snapshot réel versionné', () => {
  it('est validé par Ajv et expose la provenance 2.1', () => {
    expect(snapshot.meta.schema_version).toBe('2.1.0');
    expect(snapshot.meta.source_game_commit).toMatch(/^[0-9a-f]{40}$/u);
    expect(snapshot.meta.source_git_available).toBe(true);
    expect(snapshot.meta.source_worktree_dirty_before_export).toBe(false);
  });

  it('dérive ses compteurs des collections réelles', () => {
    const collections = [
      'characters', 'disciplines', 'spells', 'items', 'reward_pools', 'runs',
      'rooms', 'waves', 'encounters', 'enemies', 'enemy_spells', 'ai_profiles',
    ] as const;
    for (const collection of collections) {
      expect(snapshot.summary[collection]).toBe(snapshot[collection].length);
    }
    expect(snapshot.summary.runtime_facts).toBe(snapshot.runtime_facts.length);
    expect(snapshot.summary.authored_wave_profiles).toBe(snapshot.waves.length);
  });

  it('ne contient aucun identifiant dupliqué et résout les références principales', () => {
    const collections = [
      snapshot.characters, snapshot.disciplines, snapshot.spells, snapshot.items,
      snapshot.runs, snapshot.rooms, snapshot.waves, snapshot.encounters,
      snapshot.enemies, snapshot.enemy_spells, snapshot.ai_profiles,
    ];
    for (const entities of collections) {
      const ids = entities.map(({ id }) => id);
      expect(new Set(ids).size).toBe(ids.length);
    }
    const roomIds = new Set(snapshot.rooms.map(({ id }) => id));
    const encounterIds = new Set(snapshot.encounters.map(({ id }) => id));
    for (const run of snapshot.runs) {
      expect(run.name.length).toBeGreaterThan(0);
      run.room_ids.forEach((id) => expect(roomIds.has(id)).toBe(true));
    }
    snapshot.waves.forEach(({ encounter_id }) => {
      expect(encounterIds.has(encounter_id)).toBe(true);
    });
  });
});
