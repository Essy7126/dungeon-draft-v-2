import { describe, expect, it } from 'vitest';
import { createSnapshotIndex } from '../data/indexes';
import { snapshotFixture } from './fixture';

describe('index du snapshot', () => {
  it('indexe les collections par identifiant', () => {
    const index = createSnapshotIndex(snapshotFixture);
    expect(index.characters.get('elf')?.name).toBe('Élfe');
    expect(index.spells.get('elf_fireball')?.name).toBe('Boule de feu');
    expect(index.items.get('anneau')?.name).toBe('Anneau élémentaire');
    expect(index.runsById.get('first_run')?.name).toBe('Première run');
    expect(index.roomsById.get('first_run.room.01')?.index).toBe(1);
    expect(index.wavesByRoomId.get('first_run.room.01')?.map((wave) => wave.id)).toEqual(['first_run.room.01.wave.01']);
    expect(index.initialEnemiesByEncounterId.get('encounter.room.01')?.map((enemy) => enemy.id)).toEqual(['goblin']);
    expect(index.enemySpellsByEnemyId.get('goblin')?.map((spell) => spell.id)).toEqual(['goblin_strike']);
  });

  it('ne signale aucune référence inconnue dans la fixture saine', () => {
    expect(createSnapshotIndex(snapshotFixture).unknownReferences).toEqual([]);
  });

  it('signale une référence inconnue sans planter', () => {
    const character = { ...snapshotFixture.characters[0], spell_ids: ['missing_spell'] };
    const changed = { ...snapshotFixture, characters: [character] };
    expect(createSnapshotIndex(changed).unknownReferences).toContainEqual({ ownerType: 'character', ownerId: 'elf', field: 'spell_ids', referencedId: 'missing_spell' });
  });

  it('signale une référence ennemie inconnue sans planter', () => {
    const encounter = { ...snapshotFixture.encounters[0], roster: [{ enemy_id: 'missing_enemy', count: 1 }] };
    const changed = { ...snapshotFixture, encounters: [encounter] };
    expect(createSnapshotIndex(changed).unknownReferences).toContainEqual({ ownerType: 'encounter', ownerId: 'encounter.room.01', field: 'roster.enemy_id', referencedId: 'missing_enemy' });
  });

  it('construit les index sans muter le snapshot', () => {
    const before = JSON.stringify(snapshotFixture);
    createSnapshotIndex(snapshotFixture);
    expect(JSON.stringify(snapshotFixture)).toBe(before);
  });
});
