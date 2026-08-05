import type { Character, Discipline, Item, Snapshot, Spell } from '../types';

export interface UnknownReference {
  ownerType: string;
  ownerId: string;
  field: string;
  referencedId: string;
}

export interface SnapshotIndex {
  characters: ReadonlyMap<string, Character>;
  disciplines: ReadonlyMap<string, Discipline>;
  spells: ReadonlyMap<string, Spell>;
  items: ReadonlyMap<string, Item>;
  unknownReferences: readonly UnknownReference[];
}

function indexById<T extends { id: string }>(values: readonly T[]): ReadonlyMap<string, T> {
  return new Map(values.map((value) => [value.id, value]));
}

export function createSnapshotIndex(snapshot: Snapshot): SnapshotIndex {
  const characters = indexById(snapshot.characters);
  const disciplines = indexById(snapshot.disciplines);
  const spells = indexById(snapshot.spells);
  const items = indexById(snapshot.items);
  const unknownReferences: UnknownReference[] = [];

  for (const character of snapshot.characters) {
    for (const spellId of character.spell_ids) {
      if (!spells.has(spellId)) unknownReferences.push({ ownerType: 'character', ownerId: character.id, field: 'spell_ids', referencedId: spellId });
    }
    for (const disciplineId of character.discipline_ids) {
      if (!disciplines.has(disciplineId)) unknownReferences.push({ ownerType: 'character', ownerId: character.id, field: 'discipline_ids', referencedId: disciplineId });
    }
  }
  for (const discipline of snapshot.disciplines) {
    if (!characters.has(discipline.character_id)) unknownReferences.push({ ownerType: 'discipline', ownerId: discipline.id, field: 'character_id', referencedId: discipline.character_id });
  }
  for (const pool of snapshot.reward_pools) {
    for (const itemId of pool.item_ids) {
      if (!items.has(itemId)) unknownReferences.push({ ownerType: 'reward_pool', ownerId: pool.id, field: 'item_ids', referencedId: itemId });
    }
  }

  return { characters, disciplines, spells, items, unknownReferences };
}
