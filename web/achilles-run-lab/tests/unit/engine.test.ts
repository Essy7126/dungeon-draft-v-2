import { describe, expect, test } from 'vitest';
import { createDefaultConfig } from '../../src/content/defaults';
import type { AbilityId, Cell } from '../../src/content/schemas';
import { enemyAiProducesLegalDestination } from '../../src/domain/ai/enemy_ai';
import { findPath, hasLineOfSight, occupiedKeys } from '../../src/domain/grid/grid';
import type { CommandResult, GameCommand, GameEvent, GameState, UnitState } from '../../src/domain/model/types';
import { applyGameCommand, createInitialGameState } from '../../src/domain/run/engine';
import { effectiveAbilityDamage, previewAbility } from '../../src/domain/rules/abilities';
import { applyPhysicalDamage, applyShield, getHero, getLivingEnemies, mitigatePhysicalDamage } from '../../src/domain/rules/combat';

function accept(result: CommandResult): GameState {
  if (!result.accepted) throw new Error(result.error);
  return result.state;
}

function start(config = createDefaultConfig(12345)): GameState {
  return accept(applyGameCommand(createInitialGameState(), { type: 'START_RUN', seed: config.seed, config }));
}

function command(state: GameState, value: GameCommand): GameState {
  return accept(applyGameCommand(state, value));
}

function hero(state: GameState): UnitState {
  const unit = getHero(state);
  if (unit === null) throw new Error('Achilles absent');
  return unit;
}

function enemy(state: GameState, index = 0): UnitState {
  const unit = getLivingEnemies(state)[index];
  if (unit === undefined) throw new Error('Ennemi absent');
  return unit;
}

function use(state: GameState, abilityId: AbilityId, target: UnitState | null, cell: Cell | null = null): GameState {
  return command(state, { type: 'USE_ABILITY', unitId: 'achilles', abilityId, targetUnitId: target?.id ?? null, targetCell: cell ?? target?.position ?? null });
}

function clearRoom(state: GameState): GameState {
  if (state.battle === null) throw new Error('Combat absent');
  for (const unit of state.battle.units.filter((candidate) => candidate.team === 'ENEMY')) { unit.alive = false; unit.hp = 0; }
  return command(state, { type: 'END_ACTIVATION', unitId: 'achilles' });
}

describe('déterminisme et économie d’activation', () => {
  test('même seed et mêmes commandes produisent les mêmes hashes', () => {
    const first = command(start(), { type: 'MOVE_UNIT', unitId: 'achilles', destination: { x: 3, y: 6 } });
    const second = command(start(), { type: 'MOVE_UNIT', unitId: 'achilles', destination: { x: 3, y: 6 } });
    expect(first.stateHashes).toEqual(second.stateHashes);
  });

  test('deux seeds peuvent produire des offres différentes', () => {
    const first = clearRoom(start(createDefaultConfig(1)));
    const second = clearRoom(start(createDefaultConfig(2)));
    expect(first.rewardOffer).toHaveLength(3);
    expect(second.rewardOffer).toHaveLength(3);
    expect(first.rewardOffer).not.toEqual(second.rewardOffer);
  });

  test('Achilles commence et recommence son activation avec 6 PA et 3 PM', () => {
    let state = start();
    expect([hero(state).ap, hero(state).mp]).toEqual([6, 3]);
    state = command(state, { type: 'END_ACTIVATION', unitId: 'achilles' });
    expect([hero(state).ap, hero(state).mp]).toEqual([6, 3]);
  });

  test('les PA et PM inutilisés sont perdus et télémétrés', () => {
    const state = command(start(), { type: 'END_ACTIVATION', unitId: 'achilles' });
    expect(state.run?.metrics.apUnused).toBe(6);
    expect(state.run?.metrics.mpUnused).toBe(3);
  });

  test('une capacité ne peut être utilisée deux fois dans la même activation', () => {
    let state = start();
    state = use(state, 'pursuit_thrust', enemy(state));
    const result = applyGameCommand(state, { type: 'USE_ABILITY', unitId: 'achilles', abilityId: 'pursuit_thrust', targetUnitId: enemy(state).id, targetCell: enemy(state).position });
    expect(result.accepted).toBe(false);
    expect(hero(result.state).ap).toBe(4);
  });

  test('une commande illégale ne consomme pas de PA', () => {
    const state = start();
    const result = applyGameCommand(state, { type: 'USE_ABILITY', unitId: 'achilles', abilityId: 'bronze_bash', targetUnitId: enemy(state).id, targetCell: enemy(state).position });
    expect(result.accepted).toBe(false);
    expect(hero(result.state).ap).toBe(6);
    expect(result.state.run?.metrics.invalidCommandCount).toBe(1);
  });

  test('lastActionTag est remis à NONE au tour suivant', () => {
    let state = command(start(), { type: 'MOVE_UNIT', unitId: 'achilles', destination: { x: 3, y: 6 } });
    expect(hero(state).lastActionTag).toBe('STEP');
    state = command(state, { type: 'END_ACTIVATION', unitId: 'achilles' });
    expect(hero(state).lastActionTag).toBe('NONE');
  });

  test('un déplacement normal produit STEP et consomme son chemin', () => {
    const state = command(start(), { type: 'MOVE_UNIT', unitId: 'achilles', destination: { x: 3, y: 6 } });
    expect(hero(state).lastActionTag).toBe('STEP');
    expect(hero(state).mp).toBe(2);
    expect(state.eventLog.at(-1)?.type).toBe('UNIT_MOVED');
  });
});

describe('quatre capacités et liaisons', () => {
  test('STEP augmente portée et dégâts de l’Estoc', () => {
    let state = start();
    state = command(state, { type: 'MOVE_UNIT', unitId: 'achilles', destination: { x: 3, y: 6 } });
    const preview = previewAbility(state, 'pursuit_thrust', enemy(state).id, enemy(state).position);
    expect(preview.legal).toBe(true);
    expect(preview.rawDamage).toBe(13);
  });

  test('SPEAR augmente la poussée du Heurt à deux cases', () => {
    const state = start();
    enemy(state).position = { x: 3, y: 6 };
    const afterThrust = use(state, 'pursuit_thrust', enemy(state));
    const preview = previewAbility(afterThrust, 'bronze_bash', enemy(afterThrust).id, enemy(afterThrust).position);
    expect(preview.legal).toBe(true);
    expect(preview.pushDistance).toBe(2);
  });

  test('Heurt applique poussée, collision et STAGGERED', () => {
    const state = start();
    enemy(state).position = { x: 3, y: 6 };
    state.battle?.grid.blockedCells.push({ x: 4, y: 6 });
    const result = applyGameCommand(state, { type: 'USE_ABILITY', unitId: 'achilles', abilityId: 'bronze_bash', targetUnitId: enemy(state).id, targetCell: enemy(state).position });
    expect(result.accepted).toBe(true);
    if (!result.accepted) return;
    expect(result.events.some((event) => event.type === 'COLLISION_TRIGGERED')).toBe(true);
    expect(enemy(result.state).statuses).toContain('STAGGERED');
  });

  test('STAGGERED retire l’attaque suivante puis est consommé', () => {
    let state = start();
    enemy(state).position = { x: 3, y: 6 };
    state.battle?.grid.blockedCells.push({ x: 4, y: 6 });
    state = use(state, 'bronze_bash', enemy(state));
    const staggeredId = enemy(state).id;
    const result = applyGameCommand(state, { type: 'END_ACTIVATION', unitId: 'achilles' });
    if (!result.accepted) throw new Error(result.error);
    expect(result.events.some((event) => event.type === 'DAMAGE_APPLIED' && event.sourceId === staggeredId)).toBe(false);
    expect(enemy(result.state).statuses).not.toContain('STAGGERED');
  });

  test('SHIELD puis Traversée accorde cinq boucliers', () => {
    let state = start();
    enemy(state).position = { x: 3, y: 6 };
    state = use(state, 'bronze_bash', enemy(state));
    expect(hero(state).lastActionTag).toBe('SHIELD');
    state = use(state, 'crossing_step', null, { x: 5, y: 6 });
    expect(hero(state).shield).toBe(5);
    expect(hero(state).position).toEqual({ x: 5, y: 6 });
  });

  test('Traversée ne traverse pas un mur', () => {
    const state = start();
    state.battle?.grid.blockedCells.push({ x: 3, y: 6 });
    expect(previewAbility(state, 'crossing_step', null, { x: 4, y: 6 }).legal).toBe(false);
  });

  test('Traversée respecte la limite d’une cible sans récompense', () => {
    const state = start();
    const enemies = getLivingEnemies(state);
    const first = enemies[0]; const second = enemies[1];
    if (first === undefined || second === undefined) throw new Error('Cibles absentes');
    first.position = { x: 3, y: 6 }; second.position = { x: 4, y: 6 };
    expect(previewAbility(state, 'crossing_step', null, { x: 5, y: 6 }).legal).toBe(false);
  });

  test('STEP augmente la riposte de Garde à neuf dégâts bruts', () => {
    let state = command(start(), { type: 'MOVE_UNIT', unitId: 'achilles', destination: { x: 3, y: 6 } });
    state = use(state, 'turning_guard', null, hero(state).position);
    expect(hero(state).guardCounterDamage).toBe(9);
    expect(hero(state).shield).toBe(10);
  });

  test('la riposte ne se déclenche qu’une fois', () => {
    let state = start();
    const enemies = getLivingEnemies(state);
    const first = enemies[0]; const second = enemies[1];
    if (first === undefined || second === undefined) throw new Error('Cibles absentes');
    first.position = { x: 3, y: 6 }; second.position = { x: 2, y: 5 };
    state = use(state, 'turning_guard', null, hero(state).position);
    const before = enemies.map((unit) => unit.hp);
    state = command(state, { type: 'END_ACTIVATION', unitId: 'achilles' });
    const after = getLivingEnemies(state).slice(0, 2).map((unit) => unit.hp);
    expect(after.filter((hp, index) => hp < (before[index] ?? 0))).toHaveLength(1);
    expect(hero(state).guardCounterDamage).toBeNull();
  });

  test('le bouclier et la garde expirent au début du tour suivant', () => {
    let state = start();
    state = use(state, 'turning_guard', null, hero(state).position);
    for (const foe of getLivingEnemies(state)) foe.position = { x: 10, y: Math.min(11, 2 + Number(foe.id.at(-1) ?? 0)) };
    state = command(state, { type: 'END_ACTIVATION', unitId: 'achilles' });
    expect(hero(state).shield).toBe(0);
    expect(hero(state).guardCounterDamage).toBeNull();
  });
});

describe('dégâts, grille et IA', () => {
  test('la mitigation utilise la constante 100 et un plancher de un', () => {
    expect(mitigatePhysicalDamage(100, 100)).toBe(50);
    expect(mitigatePhysicalDamage(1, 500)).toBe(1);
    expect(mitigatePhysicalDamage(100, -100)).toBe(150);
    expect(mitigatePhysicalDamage(0, 0)).toBe(0);
  });

  test('un gain de bouclier nul ne produit aucun événement', () => {
    const state = start();
    const events: GameEvent[] = [];
    applyShield(hero(state), 0, events);
    expect(events).toEqual([]);
  });

  test('le bouclier absorbe avant les PV', () => {
    const state = start();
    const target = hero(state); target.shield = 5;
    const events: GameEvent[] = [];
    applyPhysicalDamage(state, enemy(state).id, target, 11, events);
    expect(target.shield).toBe(0);
    expect(target.hp).toBe(95);
    expect(events[0]).toMatchObject({ type: 'DAMAGE_APPLIED', absorbed: 5, amount: 5 });
  });

  test('le pathfinding contourne les obstacles', () => {
    const state = start();
    if (state.battle === null) throw new Error('Combat absent');
    state.battle.grid.blockedCells.push({ x: 3, y: 6 });
    const path = findPath(state.battle.grid, { x: 2, y: 6 }, { x: 4, y: 6 }, new Set());
    expect(path).not.toBeNull();
    expect(path?.length).toBeGreaterThan(2);
    expect(path).not.toContainEqual({ x: 3, y: 6 });
  });

  test('deux unités ne peuvent pas occuper la même case', () => {
    const state = start();
    const occupied = occupiedKeys(state.battle?.units ?? [], 'achilles');
    const result = state.battle === null ? null : findPath(state.battle.grid, hero(state).position, enemy(state).position, occupied);
    expect(result).toBeNull();
  });

  test('la ligne de vue de l’Archer est bloquée par un mur', () => {
    const state = start();
    if (state.battle === null) throw new Error('Combat absent');
    const archer = state.run?.config.enemies.find((unit) => unit.id === 'archer');
    expect(archer?.minRange).toBe(2);
    state.battle.grid.blockedCells.push({ x: 3, y: 6 });
    expect(hasLineOfSight(state.battle.grid, { x: 2, y: 6 }, { x: 4, y: 6 }, state.battle.units, enemy(state).id)).toBe(false);
  });

  test('l’IA choisit uniquement une destination légale', () => {
    const state = start();
    expect(enemyAiProducesLegalDestination(state, enemy(state).id)).toBe(true);
  });

  test('l’Archer se repositionne puis tire avec ligne de vue', () => {
    const config = createDefaultConfig(8);
    const firstRoom = config.rooms[0];
    if (firstRoom === undefined) throw new Error('Salle de test absente');
    firstRoom.enemies = [{ enemyId: 'archer', count: 1 }];
    let state = start(config);
    enemy(state).position = { x: 3, y: 6 };
    const before = hero(state).hp;
    state = command(state, { type: 'END_ACTIVATION', unitId: 'achilles' });
    expect(hero(state).hp).toBeLessThan(before);
    expect(enemy(state).position).not.toEqual({ x: 3, y: 6 });
  });

  test('une Brute pousse Achilles sur une case libre', () => {
    const config = createDefaultConfig(10);
    const firstRoom = config.rooms[0];
    if (firstRoom === undefined) throw new Error('Salle de test absente');
    firstRoom.enemies = [{ enemyId: 'brute', count: 1 }];
    let state = start(config);
    enemy(state).position = { x: 3, y: 6 };
    state = command(state, { type: 'END_ACTIVATION', unitId: 'achilles' });
    expect(hero(state).position).toEqual({ x: 1, y: 6 });
  });

  test('l’IA termine dix tours sans boucle', () => {
    let state = start();
    for (let round = 0; round < 10 && state.screen === 'battle'; round += 1) state = command(state, { type: 'END_ACTIVATION', unitId: 'achilles' });
    expect(state.run?.metrics.rounds).toBeLessThanOrEqual(11);
    expect(state.stateHashes.length).toBeGreaterThan(1);
  });
});

describe('run, récompenses et fins', () => {
  test('le Centurion déclenche exactement deux renforts une seule fois', () => {
    const config = createDefaultConfig(9);
    config.rooms.forEach((room) => { room.active = room.id === 'centurion_station'; });
    let state = start(config);
    const boss = getLivingEnemies(state).find((unit) => unit.definitionId === 'centurion');
    if (boss === undefined) throw new Error('Boss absent');
    boss.hp = 60;
    const result = applyGameCommand(state, { type: 'USE_ABILITY', unitId: 'achilles', abilityId: 'pursuit_thrust', targetUnitId: boss.id, targetCell: boss.position });
    if (!result.accepted) throw new Error(result.error);
    expect(result.events.filter((event) => event.type === 'REINFORCEMENT_SPAWNED')).toHaveLength(2);
    state = result.state;
    boss.hp = 60;
    const next = applyGameCommand(state, { type: 'END_ACTIVATION', unitId: 'achilles' });
    expect(next.accepted && next.events.filter((event) => event.type === 'REINFORCEMENT_SPAWNED')).toHaveLength(0);
  });

  test('les PV persistent et le soin inter-salles est appliqué', () => {
    let state = start(); hero(state).hp = 50;
    state = clearRoom(state);
    expect(state.run?.persistentHeroHp).toBe(65);
    const pick = state.rewardOffer[0]; if (pick === undefined) throw new Error('Offre absente');
    state = command(state, { type: 'SELECT_REWARD', rewardId: pick });
    state = command(state, { type: 'CONTINUE_TO_NEXT_ROOM' });
    expect(hero(state).hp).toBe(state.run?.persistentHeroHp);
  });

  test('les statuts et boucliers sont nettoyés entre les salles', () => {
    let state = start(); hero(state).statuses = ['STAGGERED']; hero(state).shield = 12;
    state = clearRoom(state);
    const pick = state.rewardOffer[0]; if (pick === undefined) throw new Error('Offre absente');
    state = command(state, { type: 'SELECT_REWARD', rewardId: pick });
    state = command(state, { type: 'CONTINUE_TO_NEXT_ROOM' });
    expect(hero(state).statuses).toEqual([]);
    expect(hero(state).shield).toBe(0);
  });

  test('second_breath applique exactement son effet', () => {
    let state = clearRoom(start());
    if (state.run === null) throw new Error('Run absente');
    state.rewardOffer = ['second_breath'];
    const before = state.run.persistentHeroMaxHp;
    state = command(state, { type: 'SELECT_REWARD', rewardId: 'second_breath' });
    expect(state.run?.persistentHeroMaxHp).toBe(before + 15);
    expect(state.run?.acquiredRewards).toContain('second_breath');
  });

  test('une offre contient trois récompenses sans doublon', () => {
    const state = clearRoom(start());
    expect(state.rewardOffer).toHaveLength(3);
    expect(new Set(state.rewardOffer).size).toBe(3);
  });

  test('la dernière salle se termine en victoire', () => {
    const config = createDefaultConfig(77);
    config.rooms.forEach((room, index) => { room.active = index === 0; room.enemies = [{ enemyId: 'spearman', count: 1 }]; });
    const spearman = config.enemies.find((unit) => unit.id === 'spearman'); if (spearman === undefined) throw new Error('Lancier absent');
    spearman.maxHp = 1; spearman.armor = 0;
    let state = start(config);
    state = use(state, 'pursuit_thrust', enemy(state));
    expect(state.screen).toBe('victory');
    expect(state.run?.result).toBe('WON');
  });

  test('la mort d’Achilles termine la run en défaite', () => {
    const state = start(); hero(state).hp = 1;
    const lost = command(state, { type: 'END_ACTIVATION', unitId: 'achilles' });
    expect(lost.screen).toBe('defeat');
    expect(lost.run?.result).toBe('LOST');
  });

  test('RESTART_RUN recommence avec la seed demandée', () => {
    const state = start();
    const restarted = command(state, { type: 'RESTART_RUN', seed: 777 });
    expect(restarted.run?.seed).toBe(777);
    expect(restarted.battle?.round).toBe(1);
  });

  test('continuer avant un choix de récompense est refusé', () => {
    const state = clearRoom(start());
    const result = applyGameCommand(state, { type: 'CONTINUE_TO_NEXT_ROOM' });
    expect(result.accepted).toBe(false);
  });

  test('une récompense hors offre est refusée', () => {
    const state = clearRoom(start());
    const result = applyGameCommand(state, { type: 'SELECT_REWARD', rewardId: 'inconnue' });
    expect(result.accepted).toBe(false);
  });

  test('une configuration sans salle active est refusée au démarrage', () => {
    const config = createDefaultConfig(); config.rooms.forEach((room) => { room.active = false; });
    const result = applyGameCommand(createInitialGameState(), { type: 'START_RUN', seed: 1, config });
    expect(result.accepted).toBe(false);
  });

  test('les bonus de récompense modifient réellement les dégâts', () => {
    const state = start();
    const before = effectiveAbilityDamage(state, 'pursuit_thrust', enemy(state));
    state.run?.acquiredRewards.push('bronze_tip');
    expect(effectiveAbilityDamage(state, 'pursuit_thrust', enemy(state))).toBe(before + 3);
  });
});
