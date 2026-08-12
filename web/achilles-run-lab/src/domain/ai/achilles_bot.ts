import type { AbilityId } from '../../content/schemas';
import { compareCells, manhattan } from '../grid/grid';
import type { AbilityPreview, GameCommand, GameState } from '../model/types';
import { getHero, getLivingEnemies } from '../rules/combat';
import { allLegalAbilityPreviews, legalMoveCells } from '../rules/legal_actions';

const ABILITY_ORDER: Record<AbilityId, number> = {
  pursuit_thrust: 0,
  bronze_bash: 1,
  crossing_step: 2,
  turning_guard: 3,
};

function previewTargetHp(state: GameState, preview: AbilityPreview): number {
  if (state.battle === null || preview.targetUnitId === null) return Number.POSITIVE_INFINITY;
  return state.battle.units.find((unit) => unit.id === preview.targetUnitId)?.hp ?? Number.POSITIVE_INFINITY;
}

export function chooseAchillesCommand(state: GameState): GameCommand {
  if (state.run === null) throw new Error('Le bot exige une run active.');
  if (state.screen === 'reward') {
    if (state.rewardOffer.length === 0) return { type: 'CONTINUE_TO_NEXT_ROOM' };
    const priority = ['second_breath', 'bronze_tip', 'heavy_rim', 'wall_shock', 'thick_guard', 'sharp_counter', 'armored_prey', 'long_reach', 'guarded_bash', 'long_stride', 'through_line', 'agile_return'];
    const rewardId = [...state.rewardOffer].sort((left, right) => priority.indexOf(left) - priority.indexOf(right) || left.localeCompare(right))[0];
    if (rewardId === undefined) throw new Error('Offre de récompense vide.');
    return { type: 'SELECT_REWARD', rewardId };
  }
  if (state.screen !== 'battle') throw new Error(`Le bot ne peut pas agir depuis ${state.screen}.`);
  const hero = getHero(state);
  if (hero === null) throw new Error('Achilles introuvable.');
  const emergencyGuard = hero.hp <= hero.maxHp * 0.35
    ? allLegalAbilityPreviews(state).find((preview) => preview.abilityId === 'turning_guard')
    : undefined;
  if (emergencyGuard !== undefined) {
    return { type: 'USE_ABILITY', unitId: 'achilles', abilityId: 'turning_guard', targetUnitId: 'achilles', targetCell: hero.position };
  }
  const damaging = allLegalAbilityPreviews(state).filter((preview) => preview.expectedDamage > 0)
    .sort((left, right) => {
      const leftLethal = left.expectedDamage >= previewTargetHp(state, left) ? 1 : 0;
      const rightLethal = right.expectedDamage >= previewTargetHp(state, right) ? 1 : 0;
      return rightLethal - leftLethal
        || right.expectedDamage - left.expectedDamage
        || Number(right.collision) - Number(left.collision)
        || ABILITY_ORDER[left.abilityId] - ABILITY_ORDER[right.abilityId]
        || (left.targetUnitId ?? '').localeCompare(right.targetUnitId ?? '');
    });
  const attack = damaging[0];
  if (attack !== undefined) {
    return { type: 'USE_ABILITY', unitId: 'achilles', abilityId: attack.abilityId, targetUnitId: attack.targetUnitId, targetCell: attack.targetCell };
  }

  const enemies = getLivingEnemies(state);
  const currentDistance = Math.min(...enemies.map((enemy) => manhattan(hero.position, enemy.position)));
  const move = legalMoveCells(state).sort((left, right) => {
    const leftDistance = Math.min(...enemies.map((enemy) => manhattan(left, enemy.position)));
    const rightDistance = Math.min(...enemies.map((enemy) => manhattan(right, enemy.position)));
    return leftDistance - rightDistance || compareCells(left, right);
  })[0];
  if (move !== undefined) {
    const nextDistance = Math.min(...enemies.map((enemy) => manhattan(move, enemy.position)));
    if (nextDistance < currentDistance) return { type: 'MOVE_UNIT', unitId: 'achilles', destination: move };
  }

  const guard = allLegalAbilityPreviews(state).find((preview) => preview.abilityId === 'turning_guard');
  if (guard !== undefined && (hero.hp <= hero.maxHp / 2 || hero.shield === 0)) {
    return { type: 'USE_ABILITY', unitId: 'achilles', abilityId: 'turning_guard', targetUnitId: 'achilles', targetCell: hero.position };
  }
  return { type: 'END_ACTIVATION', unitId: 'achilles' };
}
