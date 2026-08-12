import { z } from 'zod';

export const CONTENT_VERSION = 'achilles-web-content-v1';
export const SAVE_VERSION = 1;
export const ENGINE_VERSION = 'achilles-web-engine-v1';

export const CellSchema = z.object({
  x: z.number().int().min(0),
  y: z.number().int().min(0),
});

export const AbilityIdSchema = z.enum([
  'pursuit_thrust',
  'bronze_bash',
  'crossing_step',
  'turning_guard',
]);

export const EnemyIdSchema = z.enum([
  'spearman',
  'archer',
  'brute',
  'elite_brute',
  'centurion',
]);

export const AbilityDefinitionSchema = z.object({
  id: AbilityIdSchema,
  name: z.string().min(1),
  shortName: z.string().min(1),
  description: z.string().min(1),
  apCost: z.literal(2),
  baseDamage: z.number().int().min(0).max(100),
  maxRange: z.number().int().min(0).max(12),
  shield: z.number().int().min(0).max(100),
  pushDistance: z.number().int().min(0).max(4),
  collisionDamage: z.number().int().min(0).max(100),
  counterDamage: z.number().int().min(0).max(100),
});

export const EnemyDefinitionSchema = z.object({
  id: EnemyIdSchema,
  name: z.string().min(1),
  maxHp: z.number().int().min(1).max(999),
  armor: z.number().int().min(0).max(500),
  maxAp: z.number().int().min(1).max(12),
  maxMp: z.number().int().min(0).max(12),
  damage: z.number().int().min(1).max(100),
  minRange: z.number().int().min(1).max(12),
  maxRange: z.number().int().min(1).max(12),
  pushDistance: z.number().int().min(0).max(4),
  elite: z.boolean(),
});

export const RewardEffectSchema = z.discriminatedUnion('type', [
  z.object({ type: z.literal('ABILITY_DAMAGE'), abilityId: AbilityIdSchema, amount: z.number().int() }),
  z.object({ type: z.literal('ABILITY_RANGE'), abilityId: AbilityIdSchema, amount: z.number().int() }),
  z.object({ type: z.literal('ARMORED_DAMAGE'), abilityId: z.literal('pursuit_thrust'), amount: z.number().int(), armorThreshold: z.number().int() }),
  z.object({ type: z.literal('COLLISION_DAMAGE'), amount: z.number().int() }),
  z.object({ type: z.literal('BASH_SHIELD'), amount: z.number().int() }),
  z.object({ type: z.literal('CROSSING_LIMIT'), amount: z.number().int() }),
  z.object({ type: z.literal('CROSSING_MP_REFUND'), amount: z.number().int() }),
  z.object({ type: z.literal('GUARD_SHIELD'), amount: z.number().int() }),
  z.object({ type: z.literal('COUNTER_DAMAGE'), amount: z.number().int() }),
  z.object({ type: z.literal('MAX_HP'), amount: z.number().int() }),
]);

export const RewardDefinitionSchema = z.object({
  id: z.string().min(1),
  name: z.string().min(1),
  ability: z.string().min(1),
  description: z.string().min(1),
  effect: RewardEffectSchema,
});

export const RoomEnemyEntrySchema = z.object({
  enemyId: EnemyIdSchema,
  count: z.number().int().min(0).max(12),
});

export const RoomDefinitionSchema = z.object({
  id: z.string().min(1),
  name: z.string().min(1),
  objective: z.string().min(1),
  active: z.boolean(),
  width: z.literal(12),
  height: z.literal(12),
  blockedCells: z.array(CellSchema),
  playerSpawn: CellSchema,
  enemySpawnZones: z.array(CellSchema).min(1),
  reinforcementSpawnCells: z.array(CellSchema),
  enemies: z.array(RoomEnemyEntrySchema).min(1),
});

export const HeroDefinitionSchema = z.object({
  id: z.literal('achilles'),
  name: z.literal('Achilles'),
  maxHp: z.literal(100),
  armor: z.literal(10),
  maxAp: z.literal(6),
  maxMp: z.literal(3),
});

export const RunLabConfigSchema = z.object({
  contentVersion: z.literal(CONTENT_VERSION),
  seed: z.number().int().min(1).max(2_147_483_647),
  difficulty: z.number().min(0.75).max(2),
  healPercent: z.number().min(0).max(1),
  hero: HeroDefinitionSchema,
  abilities: z.array(AbilityDefinitionSchema).length(4),
  enemies: z.array(EnemyDefinitionSchema).length(5),
  rewards: z.array(RewardDefinitionSchema).min(12),
  rooms: z.array(RoomDefinitionSchema).min(1).max(12),
}).superRefine((config, context) => {
  if (!config.rooms.some((room) => room.active)) {
    context.addIssue({ code: 'custom', path: ['rooms'], message: 'Au moins une salle doit être active.' });
  }
  for (const [roomIndex, room] of config.rooms.entries()) {
    const key = (cell: z.infer<typeof CellSchema>) => `${cell.x},${cell.y}`;
    const blocked = new Set(room.blockedCells.map(key));
    if (blocked.has(key(room.playerSpawn))) {
      context.addIssue({ code: 'custom', path: ['rooms', roomIndex, 'playerSpawn'], message: 'Le point de départ joueur est bloqué.' });
    }
    for (const [cellIndex, cell] of room.blockedCells.entries()) {
      if (cell.x >= room.width || cell.y >= room.height) {
        context.addIssue({ code: 'custom', path: ['rooms', roomIndex, 'blockedCells', cellIndex], message: 'Cellule hors de la grille.' });
      }
    }
    const requestedEnemies = room.enemies.reduce((sum, entry) => sum + entry.count, 0);
    if (requestedEnemies > room.enemySpawnZones.length) {
      context.addIssue({ code: 'custom', path: ['rooms', roomIndex, 'enemies'], message: `${requestedEnemies} ennemis demandés pour ${room.enemySpawnZones.length} cases de spawn.` });
    }
  }
});

export type Cell = z.infer<typeof CellSchema>;
export type AbilityId = z.infer<typeof AbilityIdSchema>;
export type EnemyId = z.infer<typeof EnemyIdSchema>;
export type AbilityDefinition = z.infer<typeof AbilityDefinitionSchema>;
export type EnemyDefinition = z.infer<typeof EnemyDefinitionSchema>;
export type RewardEffect = z.infer<typeof RewardEffectSchema>;
export type RewardDefinition = z.infer<typeof RewardDefinitionSchema>;
export type RoomEnemyEntry = z.infer<typeof RoomEnemyEntrySchema>;
export type RoomDefinition = z.infer<typeof RoomDefinitionSchema>;
export type RunLabConfig = z.infer<typeof RunLabConfigSchema>;

export function formatSchemaErrors(error: z.ZodError): string[] {
  return error.issues.map((issue) => {
    const path = issue.path.length > 0 ? issue.path.join('.') : '$';
    return `${path}: ${issue.message}`;
  });
}
