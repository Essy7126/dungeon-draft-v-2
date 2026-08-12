import type { AbilityDefinition, AbilityId, Cell, RewardEffect } from '../../content/schemas';
import { cardinalLine, cellKey, isBlocked, isInside, manhattan, occupiedKeys, sameCell } from '../grid/grid';
import type { AbilityPreview, GameEvent, GameState, UnitState } from '../model/types';
import { applyPhysicalDamage, applyShield, getHero, mitigatePhysicalDamage } from './combat';

function abilityDefinition(state: GameState, abilityId: AbilityId): AbilityDefinition | null {
  return state.run?.config.abilities.find((ability) => ability.id === abilityId) ?? null;
}

function rewardEffects(state: GameState): RewardEffect[] {
  if (state.run === null) return [];
  return state.run.acquiredRewards.flatMap((rewardId) => {
    const reward = state.run?.config.rewards.find((candidate) => candidate.id === rewardId);
    return reward === undefined ? [] : [reward.effect];
  });
}

function sumReward(state: GameState, predicate: (effect: RewardEffect) => boolean): number {
  return rewardEffects(state).filter(predicate).reduce((sum, effect) => sum + ('amount' in effect ? effect.amount : 0), 0);
}

export function effectiveAbilityDamage(state: GameState, abilityId: AbilityId, target: UnitState | null): number {
  const ability = abilityDefinition(state, abilityId);
  if (ability === null) return 0;
  let damage = ability.baseDamage + sumReward(state, (effect) => effect.type === 'ABILITY_DAMAGE' && effect.abilityId === abilityId);
  if (abilityId === 'pursuit_thrust' && target !== null) {
    damage += sumReward(state, (effect) => effect.type === 'ARMORED_DAMAGE' && target.armor >= effect.armorThreshold);
  }
  return damage;
}

export function effectiveAbilityRange(state: GameState, abilityId: AbilityId): number {
  const ability = abilityDefinition(state, abilityId);
  if (ability === null) return 0;
  return ability.maxRange + sumReward(state, (effect) => effect.type === 'ABILITY_RANGE' && effect.abilityId === abilityId);
}

function illegal(abilityId: AbilityId, reason: string, targetUnitId: string | null, targetCell: Cell | null): AbilityPreview {
  return { legal: false, reason, abilityId, targetUnitId, targetCell, rawDamage: 0, expectedDamage: 0, shieldGain: 0, pushDistance: 0, collision: false, crossedUnitIds: [] };
}

export function previewAbility(
  state: GameState,
  abilityId: AbilityId,
  targetUnitId: string | null,
  targetCell: Cell | null,
): AbilityPreview {
  const battle = state.battle;
  const hero = getHero(state);
  const ability = abilityDefinition(state, abilityId);
  if (state.screen !== 'battle' || battle === null || hero === null || ability === null) return illegal(abilityId, 'Combat indisponible.', targetUnitId, targetCell);
  if (!hero.alive) return illegal(abilityId, 'Achilles est hors combat.', targetUnitId, targetCell);
  if (hero.ap < ability.apCost) return illegal(abilityId, 'PA insuffisants.', targetUnitId, targetCell);
  if (hero.usedAbilities.includes(abilityId)) return illegal(abilityId, 'Capacité déjà utilisée pendant cette activation.', targetUnitId, targetCell);

  if (abilityId === 'turning_guard') {
    const base = ability.shield + sumReward(state, (effect) => effect.type === 'GUARD_SHIELD');
    return { legal: true, reason: 'Garde prête.', abilityId, targetUnitId: 'achilles', targetCell: { ...hero.position }, rawDamage: 0, expectedDamage: 0, shieldGain: base, pushDistance: 0, collision: false, crossedUnitIds: [] };
  }

  if (abilityId === 'crossing_step') {
    if (targetCell === null) return illegal(abilityId, 'Choisissez une case libre en ligne.', null, null);
    const line = cardinalLine(hero.position, targetCell);
    const range = effectiveAbilityRange(state, abilityId);
    if (line === null || line.length === 0 || line.length > range) return illegal(abilityId, `La cible doit être en ligne à ${range} cases maximum.`, null, targetCell);
    if (!isInside(battle.grid, targetCell) || isBlocked(battle.grid, targetCell)) return illegal(abilityId, 'La case finale est bloquée.', null, targetCell);
    if (battle.units.some((unit) => unit.alive && sameCell(unit.position, targetCell))) return illegal(abilityId, 'La case finale est occupée.', null, targetCell);
    if (line.some((cell) => isBlocked(battle.grid, cell))) return illegal(abilityId, 'Traversée impossible à travers un mur.', null, targetCell);
    const crossed = line.flatMap((cell) => battle.units.filter((unit) => unit.alive && unit.team === 'ENEMY' && sameCell(unit.position, cell)).map((unit) => unit.id));
    const limit = 1 + sumReward(state, (effect) => effect.type === 'CROSSING_LIMIT');
    if (crossed.length > limit) return illegal(abilityId, `Traversée limitée à ${limit} cible(s).`, null, targetCell);
    const raw = effectiveAbilityDamage(state, abilityId, null);
    const expected = crossed.reduce((sum, id) => {
      const unit = battle.units.find((candidate) => candidate.id === id);
      return sum + (unit === undefined ? 0 : mitigatePhysicalDamage(raw, unit.armor));
    }, 0);
    const shield = hero.lastActionTag === 'SHIELD' ? ability.shield : 0;
    return { legal: true, reason: crossed.length > 0 ? `${crossed.length} cible(s) traversée(s).` : 'Déplacement tactique sans cible.', abilityId, targetUnitId: null, targetCell, rawDamage: raw, expectedDamage: expected, shieldGain: shield, pushDistance: 0, collision: false, crossedUnitIds: crossed };
  }

  const target = targetUnitId === null ? null : battle.units.find((unit) => unit.id === targetUnitId && unit.alive && unit.team === 'ENEMY') ?? null;
  if (target === null) return illegal(abilityId, 'Choisissez une cible ennemie légale.', targetUnitId, targetCell);
  if (abilityId === 'bronze_bash') {
    if (manhattan(hero.position, target.position) !== 1) return illegal(abilityId, 'Heurt exige une cible adjacente.', target.id, target.position);
    const push = hero.lastActionTag === 'SPEAR' ? 2 : ability.pushDistance;
    const direction = { x: target.position.x - hero.position.x, y: target.position.y - hero.position.y };
    let cursor = { ...target.position };
    let collision = false;
    const occupied = occupiedKeys(battle.units, target.id);
    for (let step = 0; step < push; step += 1) {
      const next = { x: cursor.x + direction.x, y: cursor.y + direction.y };
      if (!isInside(battle.grid, next) || isBlocked(battle.grid, next) || occupied.has(cellKey(next))) { collision = true; break; }
      cursor = next;
    }
    const raw = effectiveAbilityDamage(state, abilityId, target);
    const collisionRaw = collision ? ability.collisionDamage + sumReward(state, (effect) => effect.type === 'COLLISION_DAMAGE') : 0;
    return { legal: true, reason: collision ? 'Poussée avec collision et Étourdi.' : `Poussée de ${push} case(s).`, abilityId, targetUnitId: target.id, targetCell: target.position, rawDamage: raw + collisionRaw, expectedDamage: mitigatePhysicalDamage(raw, target.armor) + (collisionRaw > 0 ? mitigatePhysicalDamage(collisionRaw, target.armor) : 0), shieldGain: sumReward(state, (effect) => effect.type === 'BASH_SHIELD'), pushDistance: push, collision, crossedUnitIds: [] };
  }

  const line = cardinalLine(hero.position, target.position);
  let range = effectiveAbilityRange(state, abilityId);
  let raw = effectiveAbilityDamage(state, abilityId, target);
  if (hero.lastActionTag === 'STEP') { range += 1; raw += 3; }
  if (line === null || line.length < 1 || line.length > range) return illegal(abilityId, `Estoc exige une cible en ligne à ${range} cases maximum.`, target.id, target.position);
  for (const cell of line) {
    if (isBlocked(battle.grid, cell)) return illegal(abilityId, 'Un mur bloque l’Estoc.', target.id, target.position);
    const occupant = battle.units.find((unit) => unit.alive && unit.team === 'ENEMY' && sameCell(unit.position, cell));
    if (occupant !== undefined && occupant.id !== target.id) return illegal(abilityId, 'Une autre cible se trouve en première ligne.', target.id, target.position);
  }
  return { legal: true, reason: hero.lastActionTag === 'STEP' ? 'Bonus Pas actif : portée +1, dégâts +3.' : 'Estoc direct.', abilityId, targetUnitId: target.id, targetCell: target.position, rawDamage: raw, expectedDamage: mitigatePhysicalDamage(raw, target.armor), shieldGain: 0, pushDistance: 0, collision: false, crossedUnitIds: [] };
}

export function executeAbility(state: GameState, preview: AbilityPreview, events: GameEvent[]): void {
  if (!preview.legal || state.battle === null || state.run === null) return;
  const hero = getHero(state);
  const ability = abilityDefinition(state, preview.abilityId);
  if (hero === null || ability === null) return;
  const priorTag = hero.lastActionTag;
  hero.ap -= ability.apCost;
  hero.usedAbilities.push(preview.abilityId);
  state.run.metrics.apSpent += ability.apCost;
  state.run.metrics.abilityUsage[preview.abilityId] += 1;

  switch (preview.abilityId) {
    case 'pursuit_thrust': {
      const target = state.battle.units.find((unit) => unit.id === preview.targetUnitId);
      if (target !== undefined) applyPhysicalDamage(state, hero.id, target, preview.rawDamage, events);
      hero.lastActionTag = 'SPEAR';
      break;
    }
    case 'bronze_bash': {
      const target = state.battle.units.find((unit) => unit.id === preview.targetUnitId);
      if (target === undefined) break;
      const baseRaw = effectiveAbilityDamage(state, preview.abilityId, target);
      applyPhysicalDamage(state, hero.id, target, baseRaw, events);
      let pushed = 0;
      if (target.alive) {
        const direction = { x: target.position.x - hero.position.x, y: target.position.y - hero.position.y };
        const occupied = occupiedKeys(state.battle.units, target.id);
        for (let step = 0; step < preview.pushDistance; step += 1) {
          const next = { x: target.position.x + direction.x, y: target.position.y + direction.y };
          if (!isInside(state.battle.grid, next) || isBlocked(state.battle.grid, next) || occupied.has(cellKey(next))) break;
          const from = { ...target.position };
          target.position = next;
          pushed += 1;
          events.push({ type: 'UNIT_PUSHED', unitId: target.id, from, to: { ...next } });
        }
        if (pushed < preview.pushDistance) {
          const collisionDamage = ability.collisionDamage + sumReward(state, (effect) => effect.type === 'COLLISION_DAMAGE');
          events.push({ type: 'COLLISION_TRIGGERED', unitId: target.id, damage: collisionDamage });
          applyPhysicalDamage(state, hero.id, target, collisionDamage, events);
          if (target.hp > 0 && !target.statuses.includes('STAGGERED')) {
            target.statuses.push('STAGGERED');
            events.push({ type: 'STATUS_APPLIED', unitId: target.id, status: 'STAGGERED' });
          }
        }
      }
      const bashShield = pushed > 0 ? sumReward(state, (effect) => effect.type === 'BASH_SHIELD') : 0;
      applyShield(hero, bashShield, events);
      hero.lastActionTag = 'SHIELD';
      break;
    }
    case 'crossing_step': {
      if (preview.targetCell === null) break;
      const line = cardinalLine(hero.position, preview.targetCell) ?? [];
      const from = { ...hero.position };
      for (const unitId of preview.crossedUnitIds) {
        const target = state.battle.units.find((unit) => unit.id === unitId);
        if (target !== undefined) applyPhysicalDamage(state, hero.id, target, preview.rawDamage, events);
      }
      hero.position = { ...preview.targetCell };
      events.push({ type: 'UNIT_MOVED', unitId: hero.id, from, to: { ...hero.position }, path: line });
      if (priorTag === 'SHIELD') applyShield(hero, preview.shieldGain, events);
      const refund = preview.crossedUnitIds.length > 0 && !hero.agileRefundUsed
        ? sumReward(state, (effect) => effect.type === 'CROSSING_MP_REFUND') : 0;
      if (refund > 0) {
        hero.mp = Math.min(hero.maxMp, hero.mp + refund);
        hero.agileRefundUsed = true;
      }
      hero.lastActionTag = 'STEP';
      break;
    }
    case 'turning_guard': {
      applyShield(hero, preview.shieldGain, events);
      let counterDamage = ability.counterDamage + sumReward(state, (effect) => effect.type === 'COUNTER_DAMAGE');
      if (priorTag === 'STEP') counterDamage += 3;
      hero.guardCounterDamage = counterDamage;
      hero.lastActionTag = 'GUARD';
      break;
    }
    default: {
      const exhaustive: never = preview.abilityId;
      throw new Error(`Capacité non gérée : ${String(exhaustive)}`);
    }
  }
}
