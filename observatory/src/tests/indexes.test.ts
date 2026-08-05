import { describe, expect, it } from 'vitest';
import { createSnapshotIndex } from '../data/indexes';
import { snapshotFixture } from './fixture';

describe('index du snapshot', () => {
  it('indexe les collections par identifiant', () => {
    const index = createSnapshotIndex(snapshotFixture);
    expect(index.characters.get('elf')?.name).toBe('Élfe');
    expect(index.spells.get('elf_fireball')?.name).toBe('Boule de feu');
    expect(index.items.get('anneau')?.name).toBe('Anneau élémentaire');
  });

  it('ne signale aucune référence inconnue dans la fixture saine', () => {
    expect(createSnapshotIndex(snapshotFixture).unknownReferences).toEqual([]);
  });

  it('signale une référence inconnue sans planter', () => {
    const character = { ...snapshotFixture.characters[0], spell_ids: ['missing_spell'] };
    const changed = { ...snapshotFixture, characters: [character] };
    expect(createSnapshotIndex(changed).unknownReferences).toContainEqual({ ownerType: 'character', ownerId: 'elf', field: 'spell_ids', referencedId: 'missing_spell' });
  });
});
