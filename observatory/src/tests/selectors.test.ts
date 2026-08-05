import { describe, expect, it } from 'vitest';
import { compareRoomToPrevious, contractStatusForCharacter, itemCompatibleWith, normalizeSearch, orderedRoomsForRun, selectEnemies, selectItems, selectSpells, selectedWavesForRoom, sortedByName, spellEffects } from '../data/selectors';
import { formatMultiplier, theoreticalApBudget } from '../utils/format';
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

  it('filtre les ennemis par rôle, présence et stratégie IA', () => {
    const profiles = new Map(snapshotFixture.ai_profiles.map((profile) => [profile.id, profile]));
    const base = { search: '', faction: '', role: '', aiStrategy: '', range: '' as const, reachability: '' as const, effect: '' as const };
    expect(selectEnemies(snapshotFixture.enemies, { ...base, role: 'skirmisher' }, profiles)).toHaveLength(1);
    expect(selectEnemies(snapshotFixture.enemies, { ...base, aiStrategy: 'MELEE_RUSH' }, profiles)).toHaveLength(1);
    expect(selectEnemies(snapshotFixture.enemies, { ...base, reachability: 'summonable' }, profiles)).toHaveLength(0);
  });

  it('ordonne les salles et sélectionne les vagues sans mutation', () => {
    const room = snapshotFixture.rooms[0];
    const before = JSON.stringify(snapshotFixture);
    expect(orderedRoomsForRun(snapshotFixture, 'first_run').map((entry) => entry.id)).toEqual([room.id]);
    expect(selectedWavesForRoom(snapshotFixture, room.id).map((wave) => wave.id)).toEqual(['first_run.room.01.wave.01']);
    expect(JSON.stringify(snapshotFixture)).toBe(before);
  });

  it('compare factuellement une salle à la précédente', () => {
    const room = snapshotFixture.rooms[0];
    const encounter = snapshotFixture.encounters[0];
    const nextRoom = { ...room, id: 'first_run.room.02', index: 2, name: 'Salle 2', wave_ids: [], default_encounter_id: 'encounter.room.02' };
    const nextEncounter = { ...encounter, id: 'encounter.room.02', room_ids: [nextRoom.id], wave_ids: [], initial_enemy_count: 2, living_enemy_cap: 3, base_totals: { ...encounter.base_totals, total_max_hp: 120, total_attack_power: 24 } };
    const changed = { ...snapshotFixture, rooms: [nextRoom, room], encounters: [encounter, nextEncounter] };
    expect(compareRoomToPrevious(changed, nextRoom)).toMatchObject({ hpDelta: 40, attackDelta: 8, enemyCountDelta: 1, livingCapDelta: 1 });
  });

  it('formate les multiplicateurs en français', () => {
    expect(formatMultiplier(1.45)).toBe('×1,45');
  });
});
