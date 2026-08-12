import type { AbilityId, Cell } from '../../content/schemas';
import { effectiveAbilityRange, previewAbility } from './abilities';
import { cardinalNeighbors, occupiedKeys, reachableCells } from '../grid/grid';
import type { AbilityPreview, GameState } from '../model/types';
import { getHero, getLivingEnemies } from './combat';

export function legalMoveCells(state: GameState): Cell[] {
  const hero = getHero(state);
  if (state.battle === null || hero === null || hero.mp <= 0 || state.screen !== 'battle') return [];
  return reachableCells(state.battle.grid, hero.position, hero.mp, occupiedKeys(state.battle.units, hero.id));
}

export function legalAbilityPreviews(state: GameState, abilityId: AbilityId): AbilityPreview[] {
  if (state.battle === null) return [];
  if (abilityId === 'turning_guard') {
    const preview = previewAbility(state, abilityId, 'achilles', getHero(state)?.position ?? null);
    return preview.legal ? [preview] : [];
  }
  if (abilityId === 'crossing_step') {
    const hero = getHero(state);
    if (hero === null) return [];
    const range = effectiveAbilityRange(state, abilityId);
    const cells: Cell[] = [];
    let frontier: Cell[] = [hero.position];
    for (let distance = 1; distance <= range; distance += 1) {
      frontier = frontier.flatMap((cell) => cardinalNeighbors(state.battle?.grid ?? { width: 0, height: 0, blockedCells: [], reinforcementSpawnCells: [] }, cell));
      cells.push(...frontier.filter((cell) => cell.x === hero.position.x || cell.y === hero.position.y));
    }
    const unique = [...new Map(cells.map((cell) => [`${cell.x},${cell.y}`, cell])).values()];
    return unique.map((cell) => previewAbility(state, abilityId, null, cell)).filter((preview) => preview.legal);
  }
  return getLivingEnemies(state)
    .map((enemy) => previewAbility(state, abilityId, enemy.id, enemy.position))
    .filter((preview) => preview.legal);
}

export function allLegalAbilityPreviews(state: GameState): AbilityPreview[] {
  const ids: AbilityId[] = ['pursuit_thrust', 'bronze_bash', 'crossing_step', 'turning_guard'];
  return ids.flatMap((id) => legalAbilityPreviews(state, id));
}
