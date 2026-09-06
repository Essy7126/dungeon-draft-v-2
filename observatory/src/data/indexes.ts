import type {
  AIProfile,
  Character,
  Discipline,
  Encounter,
  Enemy,
  EnemySpell,
  Item,
  Room,
  Run,
  Snapshot,
  Spell,
  Wave,
} from '../types';

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
  runsById: ReadonlyMap<string, Run>;
  roomsById: ReadonlyMap<string, Room>;
  wavesById: ReadonlyMap<string, Wave>;
  encountersById: ReadonlyMap<string, Encounter>;
  enemiesById: ReadonlyMap<string, Enemy>;
  enemySpellsById: ReadonlyMap<string, EnemySpell>;
  aiProfilesById: ReadonlyMap<string, AIProfile>;
  roomsByRunId: ReadonlyMap<string, readonly Room[]>;
  wavesByRoomId: ReadonlyMap<string, readonly Wave[]>;
  encountersByRoomId: ReadonlyMap<string, readonly Encounter[]>;
  initialEnemiesByEncounterId: ReadonlyMap<string, readonly Enemy[]>;
  summonableEnemiesByEncounterId: ReadonlyMap<string, readonly Enemy[]>;
  enemySpellsByEnemyId: ReadonlyMap<string, readonly EnemySpell[]>;
  unknownReferences: readonly UnknownReference[];
}

function indexById<T extends { id: string }>(values: readonly T[]): ReadonlyMap<string, T> {
  return new Map(values.map((value) => [value.id, value]));
}

function grouped<T>(entries: readonly (readonly [string, T])[]): ReadonlyMap<string, readonly T[]> {
  const mutable = new Map<string, T[]>();
  for (const [key, value] of entries) {
    const group = mutable.get(key);
    if (group) group.push(value);
    else mutable.set(key, [value]);
  }
  return new Map([...mutable].map(([key, values]) => [key, Object.freeze([...values])])) as ReadonlyMap<string, readonly T[]>;
}

function recordUnknown(
  unknownReferences: UnknownReference[],
  ownerType: string,
  ownerId: string,
  field: string,
  referencedId: string,
  exists: boolean,
) {
  if (!exists) unknownReferences.push({ ownerType, ownerId, field, referencedId });
}

export function createSnapshotIndex(snapshot: Snapshot): SnapshotIndex {
  const characters = indexById(snapshot.characters);
  const disciplines = indexById(snapshot.disciplines);
  const spells = indexById(snapshot.spells);
  const items = indexById(snapshot.items);
  const runsById = indexById(snapshot.runs);
  const roomsById = indexById(snapshot.rooms);
  const wavesById = indexById(snapshot.waves);
  const encountersById = indexById(snapshot.encounters);
  const enemiesById = indexById(snapshot.enemies);
  const enemySpellsById = indexById(snapshot.enemy_spells);
  const aiProfilesById = indexById(snapshot.ai_profiles);
  const unknownReferences: UnknownReference[] = [];

  for (const character of snapshot.characters) {
    for (const spellId of character.spell_ids) recordUnknown(unknownReferences, 'character', character.id, 'spell_ids', spellId, spells.has(spellId));
    for (const disciplineId of character.discipline_ids) recordUnknown(unknownReferences, 'character', character.id, 'discipline_ids', disciplineId, disciplines.has(disciplineId));
  }
  for (const discipline of snapshot.disciplines) {
    recordUnknown(unknownReferences, 'discipline', discipline.id, 'character_id', discipline.character_id, characters.has(discipline.character_id));
  }
  for (const pool of snapshot.reward_pools) {
    for (const itemId of pool.item_ids) recordUnknown(unknownReferences, 'reward_pool', pool.id, 'item_ids', itemId, items.has(itemId));
  }
  for (const run of snapshot.runs) {
    for (const roomId of run.room_ids) recordUnknown(unknownReferences, 'run', run.id, 'room_ids', roomId, roomsById.has(roomId));
  }
  for (const room of snapshot.rooms) {
    recordUnknown(unknownReferences, 'room', room.id, 'run_id', room.run_id, runsById.has(room.run_id));
    recordUnknown(unknownReferences, 'room', room.id, 'default_encounter_id', room.default_encounter_id, encountersById.has(room.default_encounter_id));
    for (const waveId of room.wave_ids) recordUnknown(unknownReferences, 'room', room.id, 'wave_ids', waveId, wavesById.has(waveId));
  }
  for (const wave of snapshot.waves) {
    recordUnknown(unknownReferences, 'wave', wave.id, 'room_id', wave.room_id, roomsById.has(wave.room_id));
    recordUnknown(unknownReferences, 'wave', wave.id, 'encounter_id', wave.encounter_id, encountersById.has(wave.encounter_id));
  }
  for (const encounter of snapshot.encounters) {
    for (const roomId of encounter.room_ids) recordUnknown(unknownReferences, 'encounter', encounter.id, 'room_ids', roomId, roomsById.has(roomId));
    for (const waveId of encounter.wave_ids) recordUnknown(unknownReferences, 'encounter', encounter.id, 'wave_ids', waveId, wavesById.has(waveId));
    for (const entry of encounter.roster) recordUnknown(unknownReferences, 'encounter', encounter.id, 'roster.enemy_id', entry.enemy_id, enemiesById.has(entry.enemy_id));
  }
  for (const enemy of snapshot.enemies) {
    if (enemy.ai_profile_id) recordUnknown(unknownReferences, 'enemy', enemy.id, 'ai_profile_id', enemy.ai_profile_id, aiProfilesById.has(enemy.ai_profile_id));
    for (const spellId of enemy.spell_ids) recordUnknown(unknownReferences, 'enemy', enemy.id, 'spell_ids', spellId, enemySpellsById.has(spellId));
  }
  for (const enemySpell of snapshot.enemy_spells) {
    for (const enemyId of enemySpell.referenced_by_enemy_ids) recordUnknown(unknownReferences, 'enemy_spell', enemySpell.id, 'referenced_by_enemy_ids', enemyId, enemiesById.has(enemyId));
    if (enemySpell.summon_enemy_id) recordUnknown(unknownReferences, 'enemy_spell', enemySpell.id, 'summon_enemy_id', enemySpell.summon_enemy_id, enemiesById.has(enemySpell.summon_enemy_id));
    for (const encounterId of [...enemySpell.encounter_enabled_in_ids, ...enemySpell.encounter_disabled_in_ids]) {
      recordUnknown(unknownReferences, 'enemy_spell', enemySpell.id, 'encounter_ids', encounterId, encountersById.has(encounterId));
    }
  }

  const roomsByRunId = grouped(snapshot.rooms.map((room) => [room.run_id, room] as const));
  const wavesByRoomId = grouped(snapshot.waves.map((wave) => [wave.room_id, wave] as const));
  const encountersByRoomId = grouped(snapshot.encounters.flatMap((encounter) => encounter.room_ids.map((roomId) => [roomId, encounter] as const)));
  const initialEnemiesByEncounterId = grouped(snapshot.encounters.flatMap((encounter) => encounter.expanded_initial_enemy_ids.flatMap((enemyId) => {
    const enemy = enemiesById.get(enemyId);
    return enemy ? [[encounter.id, enemy] as const] : [];
  })));
  const summonableEnemiesByEncounterId = grouped(snapshot.enemy_spells.flatMap((spell) => {
    const enemy = enemiesById.get(spell.summon_enemy_id);
    if (!enemy) return [];
    return spell.encounter_enabled_in_ids.map((encounterId) => [encounterId, enemy] as const);
  }));
  const enemySpellsByEnemyId = grouped(snapshot.enemy_spells.flatMap((spell) => spell.referenced_by_enemy_ids.map((enemyId) => [enemyId, spell] as const)));

  return {
    characters,
    disciplines,
    spells,
    items,
    runsById,
    roomsById,
    wavesById,
    encountersById,
    enemiesById,
    enemySpellsById,
    aiProfilesById,
    roomsByRunId,
    wavesByRoomId,
    encountersByRoomId,
    initialEnemiesByEncounterId,
    summonableEnemiesByEncounterId,
    enemySpellsByEnemyId,
    unknownReferences: Object.freeze(unknownReferences),
  };
}
