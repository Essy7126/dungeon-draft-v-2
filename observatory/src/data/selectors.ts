import type { AIProfile, Character, ContractCheckStatus, Encounter, Enemy, Item, Room, Snapshot, Spell, Wave } from '../types';

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

export interface EnemyFilters {
  search: string;
  faction: string;
  role: string;
  aiStrategy: string;
  range: '' | 'melee' | 'ranged';
  reachability: '' | 'initial' | 'summonable';
  effect: '' | 'summoner' | 'control' | 'support' | 'shield' | 'mark' | 'forced_movement';
}

export function selectEnemies(enemies: readonly Enemy[], filters: EnemyFilters, profilesById: ReadonlyMap<string, AIProfile> = new Map()): Enemy[] {
  return sortedByName(enemies.filter((enemy) =>
    containsSearch([enemy.name, enemy.id, enemy.description, enemy.faction_id, enemy.tactical_role_id, ...enemy.effect_tags], filters.search)
    && (!filters.faction || enemy.faction_id === filters.faction)
    && (!filters.role || enemy.tactical_role_id === filters.role)
    && (!filters.aiStrategy || profilesById.get(enemy.ai_profile_id)?.strategy.name === filters.aiStrategy)
    && (!filters.range || (filters.range === 'melee' ? enemy.combat_style.name === 'melee' : enemy.combat_style.name !== 'melee'))
    && (!filters.reachability || (filters.reachability === 'initial' ? enemy.reachability.initial_roster : enemy.reachability.summonable_by_spell_ids.length > 0))
    && (!filters.effect || enemy.effect_tags.includes(filters.effect))
  ));
}

export function orderedRoomsForRun(snapshot: Snapshot, runId: string): Room[] {
  return snapshot.rooms.filter((room) => room.run_id === runId).sort((left, right) => left.index - right.index || left.id.localeCompare(right.id));
}

export function orderedWavesForRoom(snapshot: Snapshot, roomId: string): Wave[] {
  return snapshot.waves.filter((wave) => wave.room_id === roomId).sort((left, right) => left.index - right.index || left.id.localeCompare(right.id));
}

export function selectedWavesForRoom(snapshot: Snapshot, roomId: string): Wave[] {
  return orderedWavesForRoom(snapshot, roomId).filter((wave) => wave.is_selected_by_default_seed);
}

export function encounterForRoom(snapshot: Snapshot, room: Room): Encounter | undefined {
  return snapshot.encounters.find((encounter) => encounter.id === room.default_encounter_id)
    ?? snapshot.encounters.find((encounter) => encounter.room_ids.includes(room.id));
}

export interface RoomComparison {
  previousRoom: Room;
  hpDelta: number;
  attackDelta: number;
  enemyCountDelta: number;
  livingCapDelta: number;
}

export function compareRoomToPrevious(snapshot: Snapshot, room: Room): RoomComparison | null {
  const previousRoom = orderedRoomsForRun(snapshot, room.run_id).find((entry) => entry.index === room.index - 1);
  if (!previousRoom) return null;
  const encounter = encounterForRoom(snapshot, room);
  const previousEncounter = encounterForRoom(snapshot, previousRoom);
  if (!encounter || !previousEncounter) return null;
  return {
    previousRoom,
    hpDelta: encounter.base_totals.total_max_hp - previousEncounter.base_totals.total_max_hp,
    attackDelta: encounter.base_totals.total_attack_power - previousEncounter.base_totals.total_attack_power,
    enemyCountDelta: encounter.initial_enemy_count - previousEncounter.initial_enemy_count,
    livingCapDelta: encounter.living_enemy_cap - previousEncounter.living_enemy_cap,
  };
}
