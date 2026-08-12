import type { Cell } from '../../content/schemas';
import type { GameEvent, GameState, UnitState } from '../model/types';

export function mitigatePhysicalDamage(rawDamage: number, armor: number): number {
  if (rawDamage <= 0) return 0;
  const mitigated = armor >= 0
    ? Math.round(rawDamage * 100 / (armor + 100))
    : Math.round(rawDamage * (2 - 100 / (100 - armor)));
  return Math.max(1, mitigated);
}

export function getHero(state: GameState): UnitState | null {
  return state.battle?.units.find((unit) => unit.id === 'achilles') ?? null;
}

export function getLivingEnemies(state: GameState): UnitState[] {
  return state.battle?.units.filter((unit) => unit.team === 'ENEMY' && unit.alive) ?? [];
}

export function applyShield(unit: UnitState, amount: number, events: GameEvent[]): void {
  if (amount <= 0) return;
  unit.shield += amount;
  events.push({ type: 'SHIELD_APPLIED', unitId: unit.id, amount });
}

export function applyPhysicalDamage(
  state: GameState,
  sourceId: string,
  target: UnitState,
  rawDamage: number,
  events: GameEvent[],
): { amount: number; absorbed: number } {
  const mitigated = mitigatePhysicalDamage(rawDamage, target.armor);
  const absorbed = Math.min(target.shield, mitigated);
  target.shield -= absorbed;
  const amount = mitigated - absorbed;
  target.hp = Math.max(0, target.hp - amount);
  events.push({ type: 'DAMAGE_APPLIED', sourceId, targetId: target.id, raw: rawDamage, amount, absorbed });
  if (state.run !== null) {
    if (sourceId === 'achilles') state.run.metrics.damageDealt += amount;
    if (target.id === 'achilles') state.run.metrics.damageTaken += amount;
  }
  if (target.hp === 0 && target.alive) {
    target.alive = false;
    target.ap = 0;
    target.mp = 0;
    events.push({ type: 'UNIT_DIED', unitId: target.id });
  }
  return { amount, absorbed };
}

export function moveUnit(unit: UnitState, destination: Cell, path: Cell[], events: GameEvent[]): void {
  const from = { ...unit.position };
  unit.position = { ...destination };
  events.push({ type: 'UNIT_MOVED', unitId: unit.id, from, to: { ...destination }, path: path.map((cell) => ({ ...cell })) });
}

export function cloneGameState(state: GameState): GameState {
  return structuredClone(state);
}
