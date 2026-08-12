import type { AbilityId, Cell, EnemyId, RunLabConfig } from '../../content/schemas';

export type Team = 'HERO' | 'ENEMY';
export type LastActionTag = 'NONE' | 'STEP' | 'SPEAR' | 'SHIELD' | 'GUARD';
export type StatusId = 'STAGGERED';
export type GameScreen = 'menu' | 'battle' | 'reward' | 'victory' | 'defeat' | 'report';

export interface UnitState {
  id: string;
  definitionId: 'achilles' | EnemyId;
  name: string;
  team: Team;
  position: Cell;
  hp: number;
  maxHp: number;
  armor: number;
  shield: number;
  ap: number;
  mp: number;
  maxAp: number;
  maxMp: number;
  usedAbilities: AbilityId[];
  lastActionTag: LastActionTag;
  statuses: StatusId[];
  guardCounterDamage: number | null;
  agileRefundUsed: boolean;
  alive: boolean;
}

export interface GridState {
  width: number;
  height: number;
  blockedCells: Cell[];
  reinforcementSpawnCells: Cell[];
}

export interface BattleState {
  roomId: string;
  roomName: string;
  roomPosition: number;
  round: number;
  grid: GridState;
  units: UnitState[];
  reinforcementTriggered: boolean;
}

export interface RunMetrics {
  rounds: number;
  abilityUsage: Record<AbilityId, number>;
  damageDealt: number;
  damageTaken: number;
  apSpent: number;
  apUnused: number;
  mpSpent: number;
  mpUnused: number;
  invalidCommandCount: number;
}

export type RunResult = 'IN_PROGRESS' | 'WON' | 'LOST';

export interface RunState {
  seed: number;
  rngState: number;
  config: RunLabConfig;
  activeRoomIds: string[];
  currentRoomPosition: number;
  persistentHeroHp: number;
  persistentHeroMaxHp: number;
  acquiredRewards: string[];
  result: RunResult;
  metrics: RunMetrics;
}

export interface GameState {
  saveVersion: number;
  contentVersion: string;
  engineVersion: string;
  screen: GameScreen;
  run: RunState | null;
  battle: BattleState | null;
  rewardOffer: string[];
  acceptedCommands: GameCommand[];
  stateHashes: string[];
  eventLog: GameEvent[];
}

export type GameCommand =
  | { type: 'START_RUN'; seed: number; config: RunLabConfig }
  | { type: 'MOVE_UNIT'; unitId: 'achilles'; destination: Cell }
  | { type: 'USE_ABILITY'; unitId: 'achilles'; abilityId: AbilityId; targetUnitId: string | null; targetCell: Cell | null }
  | { type: 'END_ACTIVATION'; unitId: 'achilles' }
  | { type: 'SELECT_REWARD'; rewardId: string }
  | { type: 'CONTINUE_TO_NEXT_ROOM' }
  | { type: 'RESTART_RUN'; seed: number };

export type GameEvent =
  | { type: 'RUN_STARTED'; seed: number }
  | { type: 'ROOM_STARTED'; roomId: string; roomPosition: number }
  | { type: 'UNIT_MOVED'; unitId: string; from: Cell; to: Cell; path: Cell[] }
  | { type: 'DAMAGE_APPLIED'; sourceId: string; targetId: string; raw: number; amount: number; absorbed: number }
  | { type: 'SHIELD_APPLIED'; unitId: string; amount: number }
  | { type: 'UNIT_PUSHED'; unitId: string; from: Cell; to: Cell }
  | { type: 'COLLISION_TRIGGERED'; unitId: string; damage: number }
  | { type: 'STATUS_APPLIED'; unitId: string; status: StatusId }
  | { type: 'UNIT_DIED'; unitId: string }
  | { type: 'REINFORCEMENT_SPAWNED'; unitId: string; cell: Cell }
  | { type: 'ROOM_WON'; roomId: string }
  | { type: 'REWARD_OFFERED'; rewardIds: string[] }
  | { type: 'REWARD_SELECTED'; rewardId: string }
  | { type: 'RUN_WON' }
  | { type: 'RUN_LOST' }
  | { type: 'ACTIVATION_ENDED'; unitId: string }
  | { type: 'ROUND_STARTED'; round: number };

export type CommandResult =
  | { accepted: true; state: GameState; events: GameEvent[] }
  | { accepted: false; state: GameState; events: []; error: string };

export interface AbilityPreview {
  legal: boolean;
  reason: string;
  abilityId: AbilityId;
  targetUnitId: string | null;
  targetCell: Cell | null;
  rawDamage: number;
  expectedDamage: number;
  shieldGain: number;
  pushDistance: number;
  collision: boolean;
  crossedUnitIds: string[];
}

export interface RunReport {
  seed: number;
  contentVersion: string;
  engineVersion: string;
  result: RunResult;
  roomReached: number;
  rounds: number;
  commands: GameCommand[];
  stateHashes: string[];
  rewards: string[];
  abilityUsage: Record<AbilityId, number>;
  damageDealt: number;
  damageTaken: number;
  apSpent: number;
  apUnused: number;
  mpSpent: number;
  mpUnused: number;
  remainingHp: number;
  durationMs: number;
  rendererBackend: string;
}
