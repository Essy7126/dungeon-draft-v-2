import type { Character, ContractCheckStatus, Item, Snapshot, Spell } from '../types';

export function normalizeSearch(value: string): string {
  return value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLocaleLowerCase('fr').trim();
}

function containsSearch(values: readonly string[], query: string): boolean {
  const normalized = normalizeSearch(query);
  return !normalized || values.some((value) => normalizeSearch(value).includes(normalized));
}

export function sortedByName<T extends { name: string; id: string }>(values: readonly T[]): T[] {
  return [...values].sort((left, right) => left.name.localeCompare(right.name, 'fr') || left.id.localeCompare(right.id, 'fr'));
}

export interface SpellFilters {
  search: string;
  characterId: string;
  disciplineId: string;
  apCost: string;
  effect: string;
  damageType: string;
  element: string;
}

export function spellEffects(spell: Spell): string[] {
  const effects: string[] = [];
  if (spell.damage > 0) effects.push('damage');
  if (spell.heal > 0) effects.push('heal');
  if (spell.shield_grant > 0) effects.push('shield');
  if (spell.terrain_effect) effects.push('terrain');
  if (spell.applied_status) effects.push('status');
  if (spell.push_distance > 0) effects.push('push');
  if (spell.pull_distance > 0) effects.push('pull');
  if (spell.summon || spell.summon_type) effects.push('summon');
  if (spell.delayed_resolution.name !== 'none') effects.push('delayed');
  return effects;
}

export function selectSpells(spells: readonly Spell[], filters: SpellFilters): Spell[] {
  return sortedByName(spells.filter((spell) =>
    containsSearch([spell.name, spell.id, spell.description], filters.search)
    && (!filters.characterId || spell.referenced_by_character_ids.includes(filters.characterId))
    && (!filters.disciplineId || spell.discipline_id === filters.disciplineId)
    && (!filters.apCost || spell.ap_cost === Number(filters.apCost))
    && (!filters.effect || spellEffects(spell).includes(filters.effect))
    && (!filters.damageType || spell.damage_type.name === filters.damageType)
    && (!filters.element || spell.element.name === filters.element)
  ));
}

export interface ItemFilters {
  search: string;
  rarity: string;
  category: string;
  slot: string;
  characterId: string;
  firstRunOnly: boolean;
  kind: string;
}

export function itemCompatibleWith(item: Item, characterId: string): boolean {
  return item.compatible_character_ids.length === 0 || item.compatible_character_ids.includes(characterId);
}

export function selectItems(items: readonly Item[], filters: ItemFilters): Item[] {
  return sortedByName(items.filter((item) =>
    containsSearch([item.name, item.id, item.description, ...item.tags], filters.search)
    && (!filters.rarity || item.rarity === filters.rarity)
    && (!filters.category || item.category.name === filters.category)
    && (!filters.slot || item.equipment_slot.name === filters.slot)
    && (!filters.characterId || itemCompatibleWith(item, filters.characterId))
    && (!filters.firstRunOnly || item.tags.includes('first_run_equipment_reward'))
    && (!filters.kind || (filters.kind === 'equipment' ? item.equippable : item.consumable))
  ));
}

export function contractStatusForCharacter(snapshot: Snapshot, character: Character): ContractCheckStatus {
  const relevant = snapshot.contract_checks.filter((check) =>
    ['party.required_character_ids', 'combat.base_ap', 'combat.base_mp', 'combat.starting_active_spell_slots', 'progression.discipline_count_per_character'].includes(check.key),
  );
  if (!relevant.length || !snapshot.characters.some((entry) => entry.id === character.id)) return 'unknown';
  if (relevant.some((check) => check.status === 'difference')) return 'difference';
  if (relevant.some((check) => check.status === 'unknown')) return 'unknown';
  if (relevant.every((check) => check.status === 'conform')) return 'conform';
  return 'not_evaluated';
}
