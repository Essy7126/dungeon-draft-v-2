import { describe, expect, it } from 'vitest';
import { contractStatusForCharacter, itemCompatibleWith, normalizeSearch, selectItems, selectSpells, sortedByName, spellEffects } from '../data/selectors';
import { theoreticalApBudget } from '../utils/format';
import { snapshotFixture } from './fixture';

describe('sélecteurs déterministes', () => {
  it('normalise les recherches avec accents', () => {
    expect(normalizeSearch('  Élémentaire  ')).toBe('elementaire');
  });

  it('trouve un sort avec une recherche sans accent', () => {
    const result = selectSpells(snapshotFixture.spells, { search: 'degats de feu', characterId: '', disciplineId: '', apCost: '', effect: '', damageType: '', element: '' });
    expect(result.map((spell) => spell.id)).toEqual(['elf_fireball']);
  });

  it('combine les filtres de sort', () => {
    const result = selectSpells(snapshotFixture.spells, { search: '', characterId: 'elf', disciplineId: 'mage', apCost: '3', effect: 'terrain', damageType: 'magical', element: 'fire' });
    expect(result).toHaveLength(1);
  });

  it('détecte les catégories d’effet', () => {
    expect(spellEffects(snapshotFixture.spells[0])).toEqual(['damage', 'terrain']);
  });

  it('filtre les objets de première run', () => {
    const result = selectItems(snapshotFixture.items, { search: '', rarity: '', category: '', slot: '', characterId: '', firstRunOnly: true, kind: '' });
    expect(result.map((item) => item.id)).toEqual(['anneau']);
  });

  it('distingue consommable et équipement', () => {
    const result = selectItems(snapshotFixture.items, { search: '', rarity: '', category: '', slot: '', characterId: '', firstRunOnly: false, kind: 'consumable' });
    expect(result.map((item) => item.id)).toEqual(['potion']);
  });

  it('interprète une compatibilité vide comme universelle', () => {
    expect(itemCompatibleWith(snapshotFixture.items[0], 'elf')).toBe(true);
  });

  it('interprète une compatibilité renseignée comme restreinte', () => {
    expect(itemCompatibleWith(snapshotFixture.items[1], 'elf')).toBe(true);
    expect(itemCompatibleWith(snapshotFixture.items[1], 'mage')).toBe(false);
  });

  it('calcule le budget PA théorique', () => {
    expect(theoreticalApBudget(6, 3)).toBe(2);
    expect(theoreticalApBudget(6, 0)).toBeNull();
  });

  it('trie sans muter la collection source', () => {
    const source = [...snapshotFixture.items].reverse();
    const before = source.map((item) => item.id);
    expect(sortedByName(source).map((item) => item.id)).toEqual(['anneau', 'potion']);
    expect(source.map((item) => item.id)).toEqual(before);
  });

  it('mappe la conformité d’un personnage', () => {
    expect(contractStatusForCharacter(snapshotFixture, snapshotFixture.characters[0])).toBe('conform');
  });
});
