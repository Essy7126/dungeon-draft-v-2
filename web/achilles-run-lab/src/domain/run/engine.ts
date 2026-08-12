import { RunLabConfigSchema, SAVE_VERSION, ENGINE_VERSION, type Cell, type EnemyDefinition, type EnemyId, type RewardEffect, type RoomDefinition, type RunLabConfig } from '../../content/schemas';
import { executeEnemyPhase } from '../ai/enemy_ai';
import { cellKey, findPath, occupiedKeys } from '../grid/grid';
import type { CommandResult, GameCommand, GameEvent, GameState, RunMetrics, RunState, UnitState } from '../model/types';
import { hashGameState } from '../replay/hash';
import { normalizeSeed, seededShuffle } from '../rng/prng';
import { previewAbility, executeAbility } from '../rules/abilities';
import { cloneGameState, getHero, getLivingEnemies, moveUnit } from '../rules/combat';

function emptyMetrics(): RunMetrics {
  return {
    rounds: 0,
    abilityUsage: { pursuit_thrust: 0, bronze_bash: 0, crossing_step: 0, turning_guard: 0 },
    damageDealt: 0,
    damageTaken: 0,
    apSpent: 0,
    apUnused: 0,
    mpSpent: 0,
    mpUnused: 0,
    invalidCommandCount: 0,
  };
}

export function createInitialGameState(): GameState {
  return {
    saveVersion: SAVE_VERSION,
    contentVersion: 'none',
    engineVersion: ENGINE_VERSION,
    screen: 'menu',
    run: null,
    battle: null,
    rewardOffer: [],
    acceptedCommands: [],
    stateHashes: [],
    eventLog: [],
  };
}

function heroUnit(run: RunState, room: RoomDefinition): UnitState {
  return {
    id: 'achilles', definitionId: 'achilles', name: 'Achilles', team: 'HERO', position: { ...room.playerSpawn },
    hp: Math.min(run.persistentHeroHp, run.persistentHeroMaxHp), maxHp: run.persistentHeroMaxHp,
    armor: run.config.hero.armor, shield: 0, ap: run.config.hero.maxAp, mp: run.config.hero.maxMp,
    maxAp: run.config.hero.maxAp, maxMp: run.config.hero.maxMp, usedAbilities: [], lastActionTag: 'NONE', statuses: [],
    guardCounterDamage: null, agileRefundUsed: false, alive: true,
  };
}

function enemyUnit(definition: EnemyDefinition, id: string, position: Cell, difficulty: number): UnitState {
  const maxHp = Math.max(1, Math.round(definition.maxHp * difficulty));
  return {
    id, definitionId: definition.id, name: definition.name, team: 'ENEMY', position: { ...position },
    hp: maxHp, maxHp, armor: definition.armor, shield: 0, ap: 0, mp: 0,
    maxAp: definition.maxAp, maxMp: definition.maxMp, usedAbilities: [], lastActionTag: 'NONE', statuses: [],
    guardCounterDamage: null, agileRefundUsed: false, alive: true,
  };
}

function activeRoom(run: RunState): RoomDefinition | null {
  const id = run.activeRoomIds[run.currentRoomPosition];
  return id === undefined ? null : run.config.rooms.find((room) => room.id === id) ?? null;
}

function startRoom(state: GameState, events: GameEvent[]): void {
  const run = state.run;
  if (run === null) return;
  const room = activeRoom(run);
  if (room === null) throw new Error('Salle active introuvable.');
  const units: UnitState[] = [heroUnit(run, room)];
  let spawnIndex = 0;
  let instance = 0;
  for (const entry of room.enemies) {
    const definition = run.config.enemies.find((candidate) => candidate.id === entry.enemyId);
    if (definition === undefined) continue;
    for (let count = 0; count < entry.count; count += 1) {
      const cell = room.enemySpawnZones[spawnIndex];
      spawnIndex += 1;
      if (cell === undefined) break;
      instance += 1;
      units.push(enemyUnit(definition, `${definition.id}-${run.currentRoomPosition + 1}-${instance}`, cell, run.config.difficulty));
    }
  }
  state.battle = {
    roomId: room.id,
    roomName: room.name,
    roomPosition: run.currentRoomPosition,
    round: 1,
    grid: { width: room.width, height: room.height, blockedCells: room.blockedCells.map((cell) => ({ ...cell })), reinforcementSpawnCells: room.reinforcementSpawnCells.map((cell) => ({ ...cell })) },
    units,
    reinforcementTriggered: false,
  };
  state.screen = 'battle';
  state.rewardOffer = [];
  run.metrics.rounds += 1;
  events.push({ type: 'ROOM_STARTED', roomId: room.id, roomPosition: run.currentRoomPosition });
}

function beginRun(state: GameState, config: RunLabConfig, seed: number, events: GameEvent[]): void {
  const normalizedSeed = normalizeSeed(seed);
  const activeRoomIds = config.rooms.filter((room) => room.active).map((room) => room.id);
  state.saveVersion = SAVE_VERSION;
  state.contentVersion = config.contentVersion;
  state.engineVersion = ENGINE_VERSION;
  state.acceptedCommands = [];
  state.stateHashes = [];
  state.eventLog = [];
  state.run = {
    seed: normalizedSeed,
    rngState: normalizedSeed,
    config: structuredClone({ ...config, seed: normalizedSeed }),
    activeRoomIds,
    currentRoomPosition: 0,
    persistentHeroHp: config.hero.maxHp,
    persistentHeroMaxHp: config.hero.maxHp,
    acquiredRewards: [],
    result: 'IN_PROGRESS',
    metrics: emptyMetrics(),
  };
  events.push({ type: 'RUN_STARTED', seed: normalizedSeed });
  startRoom(state, events);
}

function rewardAmount(run: RunState, predicate: (effect: RewardEffect) => boolean): number {
  return run.acquiredRewards.flatMap((rewardId) => {
    const reward = run.config.rewards.find((candidate) => candidate.id === rewardId);
    return reward === undefined ? [] : [reward.effect];
  }).filter(predicate).reduce((sum, effect) => sum + ('amount' in effect ? effect.amount : 0), 0);
}

function maybeSpawnReinforcements(state: GameState, events: GameEvent[]): void {
  if (state.battle === null || state.run === null || state.battle.reinforcementTriggered) return;
  const centurion = state.battle.units.find((unit) => unit.definitionId === 'centurion');
  if (centurion === undefined || centurion.hp > centurion.maxHp / 2) return;
  state.battle.reinforcementTriggered = true;
  const definition = state.run.config.enemies.find((enemy) => enemy.id === 'spearman');
  if (definition === undefined) return;
  let spawned = 0;
  for (const cell of state.battle.grid.reinforcementSpawnCells) {
    const occupied = state.battle.units.some((unit) => unit.alive && cellKey(unit.position) === cellKey(cell));
    if (occupied) continue;
    const unit = enemyUnit(definition, `spearman-reinforcement-${spawned + 1}`, cell, state.run.config.difficulty);
    state.battle.units.push(unit);
    spawned += 1;
    events.push({ type: 'REINFORCEMENT_SPAWNED', unitId: unit.id, cell: { ...cell } });
    if (spawned === 2) break;
  }
}

function finishRoomIfCleared(state: GameState, events: GameEvent[]): void {
  if (state.run === null || state.battle === null || getLivingEnemies(state).length > 0) return;
  const hero = getHero(state);
  if (hero === null) return;
  events.push({ type: 'ROOM_WON', roomId: state.battle.roomId });
  state.run.persistentHeroMaxHp = hero.maxHp;
  state.run.persistentHeroHp = hero.hp;
  if (state.run.currentRoomPosition >= state.run.activeRoomIds.length - 1) {
    state.run.result = 'WON';
    state.screen = 'victory';
    events.push({ type: 'RUN_WON' });
    return;
  }
  const heal = Math.round(state.run.persistentHeroMaxHp * state.run.config.healPercent);
  state.run.persistentHeroHp = Math.min(state.run.persistentHeroMaxHp, state.run.persistentHeroHp + heal);
  const remaining = state.run.config.rewards.filter((reward) => !state.run?.acquiredRewards.includes(reward.id));
  const shuffled = seededShuffle(remaining, state.run.rngState);
  state.run.rngState = shuffled.state;
  state.rewardOffer = shuffled.values.slice(0, 3).map((reward) => reward.id);
  state.screen = 'reward';
  events.push({ type: 'REWARD_OFFERED', rewardIds: [...state.rewardOffer] });
}

function startHeroActivation(state: GameState, events: GameEvent[]): void {
  if (state.battle === null || state.run === null) return;
  const hero = getHero(state);
  if (hero === null || !hero.alive) return;
  state.battle.round += 1;
  state.run.metrics.rounds += 1;
  hero.shield = 0;
  hero.guardCounterDamage = null;
  hero.ap = hero.maxAp;
  hero.mp = hero.maxMp;
  hero.usedAbilities = [];
  hero.lastActionTag = 'NONE';
  hero.agileRefundUsed = false;
  events.push({ type: 'ROUND_STARTED', round: state.battle.round });
}

function reject(state: GameState, error: string): CommandResult {
  const next = cloneGameState(state);
  if (next.run !== null) next.run.metrics.invalidCommandCount += 1;
  return { accepted: false, state: next, events: [], error };
}

function applyReward(state: GameState, rewardId: string, events: GameEvent[]): string | null {
  if (state.run === null || state.screen !== 'reward') return 'Aucune récompense n’est disponible.';
  if (!state.rewardOffer.includes(rewardId)) return 'Cette récompense ne fait pas partie de l’offre.';
  const reward = state.run.config.rewards.find((candidate) => candidate.id === rewardId);
  if (reward === undefined) return 'Récompense inconnue.';
  state.run.acquiredRewards.push(rewardId);
  if (reward.effect.type === 'MAX_HP') {
    state.run.persistentHeroMaxHp += reward.effect.amount;
    state.run.persistentHeroHp = Math.min(state.run.persistentHeroMaxHp, state.run.persistentHeroHp + reward.effect.amount);
  }
  state.rewardOffer = [];
  events.push({ type: 'REWARD_SELECTED', rewardId });
  return null;
}

function dispatchMutable(state: GameState, command: GameCommand, events: GameEvent[]): string | null {
  switch (command.type) {
    case 'START_RUN': {
      const parsed = RunLabConfigSchema.safeParse(command.config);
      if (!parsed.success) return `Configuration invalide : ${parsed.error.issues[0]?.path.join('.') ?? '$'}`;
      beginRun(state, parsed.data, command.seed, events);
      return null;
    }
    case 'RESTART_RUN': {
      if (state.run === null) return 'Aucune run à recommencer.';
      beginRun(state, state.run.config, command.seed, events);
      return null;
    }
    case 'MOVE_UNIT': {
      if (state.screen !== 'battle' || state.battle === null || state.run === null) return 'Aucun combat actif.';
      const hero = getHero(state);
      if (hero === null || !hero.alive) return 'Achilles ne peut pas se déplacer.';
      if (hero.mp <= 0) return 'PM insuffisants.';
      const occupied = occupiedKeys(state.battle.units, hero.id);
      const path = findPath(state.battle.grid, hero.position, command.destination, occupied);
      if (path === null || path.length === 0) return 'Destination inaccessible.';
      if (path.length > hero.mp) return 'Destination hors de portée en PM.';
      moveUnit(hero, command.destination, path, events);
      hero.mp -= path.length;
      hero.lastActionTag = 'STEP';
      state.run.metrics.mpSpent += path.length;
      return null;
    }
    case 'USE_ABILITY': {
      const preview = previewAbility(state, command.abilityId, command.targetUnitId, command.targetCell);
      if (!preview.legal) return preview.reason;
      executeAbility(state, preview, events);
      maybeSpawnReinforcements(state, events);
      finishRoomIfCleared(state, events);
      return null;
    }
    case 'END_ACTIVATION': {
      if (state.screen !== 'battle' || state.run === null || state.battle === null) return 'Aucun combat actif.';
      const hero = getHero(state);
      if (hero === null || !hero.alive) return 'Achilles ne peut pas terminer son activation.';
      state.run.metrics.apUnused += hero.ap;
      state.run.metrics.mpUnused += hero.mp;
      hero.ap = 0;
      hero.mp = 0;
      events.push({ type: 'ACTIVATION_ENDED', unitId: hero.id });
      executeEnemyPhase(state, events);
      maybeSpawnReinforcements(state, events);
      if (hero.hp <= 0) {
        state.run.persistentHeroHp = 0;
        state.run.result = 'LOST';
        state.screen = 'defeat';
        events.push({ type: 'RUN_LOST' });
        return null;
      }
      finishRoomIfCleared(state, events);
      if (getLivingEnemies(state).length > 0) startHeroActivation(state, events);
      return null;
    }
    case 'SELECT_REWARD':
      return applyReward(state, command.rewardId, events);
    case 'CONTINUE_TO_NEXT_ROOM': {
      if (state.screen !== 'reward' || state.run === null || state.rewardOffer.length > 0) return 'Sélectionnez d’abord une récompense.';
      state.run.currentRoomPosition += 1;
      startRoom(state, events);
      return null;
    }
    default: {
      const exhaustive: never = command;
      return `Commande inconnue : ${String(exhaustive)}`;
    }
  }
}

export function applyGameCommand(state: GameState, command: GameCommand): CommandResult {
  const next = cloneGameState(state);
  const events: GameEvent[] = [];
  const error = dispatchMutable(next, command, events);
  if (error !== null) return reject(state, error);
  next.acceptedCommands.push(structuredClone(command));
  next.eventLog.push(...events);
  if (next.eventLog.length > 250) next.eventLog = next.eventLog.slice(-250);
  next.stateHashes.push(hashGameState(next));
  return { accepted: true, state: next, events };
}

export function currentRoomDefinition(state: GameState): RoomDefinition | null {
  return state.run === null ? null : activeRoom(state.run);
}

export function getRewardEffectTotal(state: GameState, type: RewardEffect['type']): number {
  return state.run === null ? 0 : rewardAmount(state.run, (effect) => effect.type === type);
}

export function enemyDefinition(state: GameState, id: EnemyId): EnemyDefinition | null {
  return state.run?.config.enemies.find((definition) => definition.id === id) ?? null;
}
