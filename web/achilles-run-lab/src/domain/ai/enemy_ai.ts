import type { Cell, EnemyDefinition } from '../../content/schemas';
import { compareCells, findPath, hasLineOfSight, manhattan, occupiedKeys, reachableCells, sameCell, cellKey, isBlocked, isInside } from '../grid/grid';
import type { GameEvent, GameState, UnitState } from '../model/types';
import { applyPhysicalDamage, getHero, moveUnit } from '../rules/combat';

const MAX_AI_ACTIONS_PER_ENEMY = 4;

function definitionFor(state: GameState, enemy: UnitState): EnemyDefinition | null {
  if (state.run === null || enemy.definitionId === 'achilles') return null;
  return state.run.config.enemies.find((definition) => definition.id === enemy.definitionId) ?? null;
}

function canAttack(state: GameState, enemy: UnitState, definition: EnemyDefinition, hero: UnitState): boolean {
  if (state.battle === null || enemy.ap < 2 || !enemy.alive || !hero.alive) return false;
  const distance = manhattan(enemy.position, hero.position);
  if (distance < definition.minRange || distance > definition.maxRange) return false;
  return definition.maxRange === 1 || hasLineOfSight(state.battle.grid, enemy.position, hero.position, state.battle.units, hero.id);
}

function bestMove(state: GameState, enemy: UnitState, definition: EnemyDefinition, hero: UnitState): Cell | null {
  if (state.battle === null || enemy.mp <= 0) return null;
  const occupied = occupiedKeys(state.battle.units, enemy.id);
  const reachable = reachableCells(state.battle.grid, enemy.position, enemy.mp, occupied);
  if (reachable.length === 0) return null;

  if (definition.id === 'archer') {
    const firingCells = reachable.filter((cell) => {
      const distance = manhattan(cell, hero.position);
      return distance >= definition.minRange && distance <= definition.maxRange
        && hasLineOfSight(
          state.battle?.grid ?? { width: 0, height: 0, blockedCells: [], reinforcementSpawnCells: [] },
          cell,
          hero.position,
          state.battle?.units.filter((unit) => unit.id !== enemy.id) ?? [],
          hero.id,
        );
    });
    if (firingCells.length > 0) {
      return firingCells.sort((left, right) => {
        const leftPath = findPath(state.battle?.grid ?? { width: 0, height: 0, blockedCells: [], reinforcementSpawnCells: [] }, enemy.position, left, occupied);
        const rightPath = findPath(state.battle?.grid ?? { width: 0, height: 0, blockedCells: [], reinforcementSpawnCells: [] }, enemy.position, right, occupied);
        return (leftPath?.length ?? 99) - (rightPath?.length ?? 99) || compareCells(left, right);
      })[0] ?? null;
    }
    if (manhattan(enemy.position, hero.position) === 1) {
      return reachable.sort((left, right) => manhattan(right, hero.position) - manhattan(left, hero.position) || compareCells(left, right))[0] ?? null;
    }
  }

  return reachable.sort((left, right) => manhattan(left, hero.position) - manhattan(right, hero.position) || compareCells(left, right))[0] ?? null;
}

function performAttack(state: GameState, enemy: UnitState, definition: EnemyDefinition, hero: UnitState, events: GameEvent[]): void {
  if (state.battle === null || state.run === null) return;
  enemy.ap -= 2;
  const adjacent = manhattan(enemy.position, hero.position) === 1;
  const baseDamage = definition.id === 'archer' && adjacent ? 5 : definition.damage;
  const rawDamage = Math.max(1, Math.round(baseDamage * state.run.config.difficulty));
  applyPhysicalDamage(state, enemy.id, hero, rawDamage, events);

  if (hero.alive && adjacent && definition.pushDistance > 0) {
    const direction = { x: hero.position.x - enemy.position.x, y: hero.position.y - enemy.position.y };
    const next = { x: hero.position.x + direction.x, y: hero.position.y + direction.y };
    const occupied = occupiedKeys(state.battle.units, hero.id);
    if (isInside(state.battle.grid, next) && !isBlocked(state.battle.grid, next) && !occupied.has(cellKey(next))) {
      const from = { ...hero.position };
      hero.position = next;
      events.push({ type: 'UNIT_PUSHED', unitId: hero.id, from, to: { ...next } });
    }
  }

  if (hero.alive && enemy.alive && adjacent && hero.guardCounterDamage !== null) {
    const counterDamage = hero.guardCounterDamage;
    hero.guardCounterDamage = null;
    applyPhysicalDamage(state, hero.id, enemy, counterDamage, events);
  }
}

export function executeEnemyPhase(state: GameState, events: GameEvent[]): void {
  if (state.battle === null || state.run === null) return;
  const hero = getHero(state);
  if (hero === null) return;
  const enemyIds = state.battle.units.filter((unit) => unit.team === 'ENEMY' && unit.alive).map((unit) => unit.id).sort();

  for (const enemyId of enemyIds) {
    const enemy = state.battle.units.find((unit) => unit.id === enemyId);
    if (enemy === undefined || !enemy.alive || !hero.alive) continue;
    const definition = definitionFor(state, enemy);
    if (definition === null) continue;
    enemy.ap = enemy.maxAp;
    enemy.mp = enemy.maxMp;
    if (enemy.statuses.includes('STAGGERED')) {
      enemy.ap = Math.max(0, enemy.ap - 1);
      enemy.statuses = [];
    }
    let actions = 0;
    if (canAttack(state, enemy, definition, hero)) {
      performAttack(state, enemy, definition, hero, events);
      actions += 1;
    } else {
      const destination = bestMove(state, enemy, definition, hero);
      if (destination !== null && !sameCell(destination, enemy.position)) {
        const occupied = occupiedKeys(state.battle.units, enemy.id);
        const path = findPath(state.battle.grid, enemy.position, destination, occupied);
        if (path !== null && path.length <= enemy.mp) {
          moveUnit(enemy, destination, path, events);
          enemy.mp -= path.length;
          actions += 1;
        }
      }
      if (canAttack(state, enemy, definition, hero)) {
        performAttack(state, enemy, definition, hero, events);
        actions += 1;
      }
    }
    if (actions > MAX_AI_ACTIONS_PER_ENEMY) throw new Error(`Boucle IA détectée pour ${enemy.id}`);
    enemy.ap = 0;
    enemy.mp = 0;
    events.push({ type: 'ACTIVATION_ENDED', unitId: enemy.id });
  }
}

export function enemyAiProducesLegalDestination(state: GameState, enemyId: string): boolean {
  if (state.battle === null) return false;
  const enemy = state.battle.units.find((unit) => unit.id === enemyId);
  const hero = getHero(state);
  if (enemy === undefined || hero === null) return false;
  const definition = definitionFor(state, enemy);
  if (definition === null) return false;
  const destination = bestMove(state, enemy, definition, hero);
  if (destination === null) return true;
  return isInside(state.battle.grid, destination) && !isBlocked(state.battle.grid, destination)
    && !state.battle.units.some((unit) => unit.alive && unit.id !== enemy.id && sameCell(unit.position, destination));
}
