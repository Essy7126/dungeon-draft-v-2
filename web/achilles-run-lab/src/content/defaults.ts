import type {
  AbilityDefinition,
  Cell,
  EnemyDefinition,
  RewardDefinition,
  RoomDefinition,
  RunLabConfig,
} from './schemas';
import { CONTENT_VERSION } from './schemas';

export const DEFAULT_ABILITIES: AbilityDefinition[] = [
  {
    id: 'pursuit_thrust', name: 'Estoc de poursuite', shortName: 'Estoc', apCost: 2,
    description: 'Frappe la première cible en ligne. Après un pas : portée +1 et dégâts +3.',
    baseDamage: 10, maxRange: 2, shield: 0, pushDistance: 0, collisionDamage: 0, counterDamage: 0,
  },
  {
    id: 'bronze_bash', name: 'Heurt de bronze', shortName: 'Heurt', apCost: 2,
    description: 'Frappe et pousse. Après un Estoc : pousse de 2. Une collision inflige des dégâts et Étourdi.',
    baseDamage: 6, maxRange: 1, shield: 0, pushDistance: 1, collisionDamage: 4, counterDamage: 0,
  },
  {
    id: 'crossing_step', name: 'Traversée', shortName: 'Traversée', apCost: 2,
    description: 'Traverse au plus un ennemi en ligne et l’endommage. Après un Heurt : gagne 5 boucliers.',
    baseDamage: 8, maxRange: 3, shield: 5, pushDistance: 0, collisionDamage: 0, counterDamage: 0,
  },
  {
    id: 'turning_guard', name: 'Garde tournante', shortName: 'Garde', apCost: 2,
    description: 'Gagne 10 boucliers et arme une riposte. Après un pas : riposte +3 dégâts.',
    baseDamage: 0, maxRange: 0, shield: 10, pushDistance: 0, collisionDamage: 0, counterDamage: 6,
  },
];

export const DEFAULT_ENEMIES: EnemyDefinition[] = [
  { id: 'spearman', name: 'Lancier', maxHp: 34, armor: 5, maxAp: 2, maxMp: 3, damage: 8, minRange: 1, maxRange: 1, pushDistance: 0, elite: false },
  { id: 'archer', name: 'Archer', maxHp: 28, armor: 0, maxAp: 2, maxMp: 2, damage: 7, minRange: 2, maxRange: 5, pushDistance: 0, elite: false },
  { id: 'brute', name: 'Brute', maxHp: 58, armor: 20, maxAp: 2, maxMp: 2, damage: 11, minRange: 1, maxRange: 1, pushDistance: 1, elite: false },
  { id: 'elite_brute', name: 'Brute élite', maxHp: 85, armor: 30, maxAp: 2, maxMp: 2, damage: 13, minRange: 1, maxRange: 1, pushDistance: 1, elite: true },
  { id: 'centurion', name: 'Centurion', maxHp: 130, armor: 25, maxAp: 2, maxMp: 3, damage: 10, minRange: 1, maxRange: 1, pushDistance: 0, elite: true },
];

export const DEFAULT_REWARDS: RewardDefinition[] = [
  { id: 'bronze_tip', name: 'Pointe de bronze', ability: 'Estoc', description: 'Estoc : +3 dégâts.', effect: { type: 'ABILITY_DAMAGE', abilityId: 'pursuit_thrust', amount: 3 } },
  { id: 'long_reach', name: 'Allonge', ability: 'Estoc', description: 'Estoc : portée maximale de base +1.', effect: { type: 'ABILITY_RANGE', abilityId: 'pursuit_thrust', amount: 1 } },
  { id: 'armored_prey', name: 'Proie cuirassée', ability: 'Estoc', description: 'Estoc : +5 dégâts contre une cible ayant au moins 20 armure.', effect: { type: 'ARMORED_DAMAGE', abilityId: 'pursuit_thrust', amount: 5, armorThreshold: 20 } },
  { id: 'heavy_rim', name: 'Rebord lourd', ability: 'Heurt', description: 'Heurt : +3 dégâts.', effect: { type: 'ABILITY_DAMAGE', abilityId: 'bronze_bash', amount: 3 } },
  { id: 'wall_shock', name: 'Choc mural', ability: 'Heurt', description: 'Collision de Heurt : +4 dégâts supplémentaires.', effect: { type: 'COLLISION_DAMAGE', amount: 4 } },
  { id: 'guarded_bash', name: 'Heurt couvert', ability: 'Heurt', description: 'Après une poussée, Achilles gagne 4 boucliers.', effect: { type: 'BASH_SHIELD', amount: 4 } },
  { id: 'long_stride', name: 'Longue foulée', ability: 'Traversée', description: 'Traversée : distance maximale +1.', effect: { type: 'ABILITY_RANGE', abilityId: 'crossing_step', amount: 1 } },
  { id: 'through_line', name: 'Ligne traversante', ability: 'Traversée', description: 'Traversée peut croiser au maximum deux ennemis.', effect: { type: 'CROSSING_LIMIT', amount: 1 } },
  { id: 'agile_return', name: 'Retour agile', ability: 'Traversée', description: 'La première Traversée touchant un ennemi rembourse 1 PM.', effect: { type: 'CROSSING_MP_REFUND', amount: 1 } },
  { id: 'thick_guard', name: 'Garde épaisse', ability: 'Garde', description: 'Garde tournante : +5 boucliers.', effect: { type: 'GUARD_SHIELD', amount: 5 } },
  { id: 'sharp_counter', name: 'Riposte acérée', ability: 'Garde', description: 'Riposte : +4 dégâts.', effect: { type: 'COUNTER_DAMAGE', amount: 4 } },
  { id: 'second_breath', name: 'Second souffle', ability: 'Achilles', description: '+15 PV maximum et soin immédiat de 15 PV.', effect: { type: 'MAX_HP', amount: 15 } },
];

const commonSpawns: Cell[] = [
  { x: 4, y: 6 }, { x: 5, y: 5 }, { x: 5, y: 7 }, { x: 7, y: 4 },
  { x: 7, y: 8 }, { x: 9, y: 5 }, { x: 9, y: 7 }, { x: 10, y: 6 },
];
const reinforcements: Cell[] = [{ x: 10, y: 2 }, { x: 10, y: 9 }, { x: 8, y: 2 }, { x: 8, y: 9 }];

function wallColumn(x: number, gaps: number[]): Cell[] {
  return Array.from({ length: 12 }, (_, y) => ({ x, y })).filter((cell) => !gaps.includes(cell.y));
}

export const DEFAULT_ROOMS: RoomDefinition[] = [
  { id: 'broken_ford', name: 'Gué brisé', objective: 'Apprendre déplacement, Estoc et poussée.', active: true, width: 12, height: 12,
    blockedCells: [{ x: 6, y: 1 }, { x: 6, y: 2 }, { x: 6, y: 9 }, { x: 6, y: 10 }], playerSpawn: { x: 2, y: 6 }, enemySpawnZones: commonSpawns, reinforcementSpawnCells: reinforcements,
    enemies: [{ enemyId: 'spearman', count: 3 }] },
  { id: 'firing_line', name: 'Ligne de tir', objective: 'Gérer portée et ligne de vue.', active: true, width: 12, height: 12,
    blockedCells: [...wallColumn(6, [3, 6, 9]), { x: 3, y: 3 }, { x: 3, y: 9 }], playerSpawn: { x: 2, y: 6 }, enemySpawnZones: commonSpawns, reinforcementSpawnCells: reinforcements,
    enemies: [{ enemyId: 'spearman', count: 2 }, { enemyId: 'archer', count: 1 }] },
  { id: 'shield_court', name: 'Cour des boucliers', objective: 'Provoquer des collisions et rompre la formation.', active: true, width: 12, height: 12,
    blockedCells: [{ x: 5, y: 4 }, { x: 5, y: 8 }, { x: 8, y: 4 }, { x: 8, y: 8 }, { x: 9, y: 6 }], playerSpawn: { x: 2, y: 6 }, enemySpawnZones: commonSpawns, reinforcementSpawnCells: reinforcements,
    enemies: [{ enemyId: 'spearman', count: 2 }, { enemyId: 'brute', count: 1 }] },
  { id: 'bone_rampart', name: 'Rempart d’os', objective: 'Gérer une cible résistante et une pression distante.', active: true, width: 12, height: 12,
    blockedCells: [...wallColumn(7, [2, 6, 10]), { x: 4, y: 5 }, { x: 4, y: 7 }], playerSpawn: { x: 2, y: 6 }, enemySpawnZones: commonSpawns, reinforcementSpawnCells: reinforcements,
    enemies: [{ enemyId: 'elite_brute', count: 1 }, { enemyId: 'archer', count: 1 }] },
  { id: 'centurion_station', name: 'Station du Centurion', objective: 'Finale persistante avec renfort réel.', active: true, width: 12, height: 12,
    blockedCells: [{ x: 5, y: 2 }, { x: 5, y: 3 }, { x: 5, y: 9 }, { x: 8, y: 2 }, { x: 8, y: 3 }, { x: 8, y: 9 }], playerSpawn: { x: 2, y: 6 }, enemySpawnZones: commonSpawns, reinforcementSpawnCells: reinforcements,
    enemies: [{ enemyId: 'centurion', count: 1 }, { enemyId: 'spearman', count: 2 }] },
];

export function createDefaultConfig(seed = 12345): RunLabConfig {
  return structuredClone({
    contentVersion: CONTENT_VERSION,
    seed,
    difficulty: 1,
    healPercent: 0.15,
    hero: { id: 'achilles', name: 'Achilles', maxHp: 100, armor: 10, maxAp: 6, maxMp: 3 },
    abilities: DEFAULT_ABILITIES,
    enemies: DEFAULT_ENEMIES,
    rewards: DEFAULT_REWARDS,
    rooms: DEFAULT_ROOMS,
  });
}
