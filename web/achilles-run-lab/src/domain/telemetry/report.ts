import type { GameState, RunReport } from '../model/types';
import { getHero } from '../rules/combat';

export function createRunReport(state: GameState, durationMs: number, rendererBackend: string): RunReport {
  if (state.run === null) throw new Error('Aucune run à rapporter.');
  const hero = getHero(state);
  return {
    seed: state.run.seed,
    contentVersion: state.contentVersion,
    engineVersion: state.engineVersion,
    result: state.run.result,
    roomReached: state.run.currentRoomPosition + 1,
    rounds: state.run.metrics.rounds,
    commands: structuredClone(state.acceptedCommands),
    stateHashes: [...state.stateHashes],
    rewards: [...state.run.acquiredRewards],
    abilityUsage: { ...state.run.metrics.abilityUsage },
    damageDealt: state.run.metrics.damageDealt,
    damageTaken: state.run.metrics.damageTaken,
    apSpent: state.run.metrics.apSpent,
    apUnused: state.run.metrics.apUnused,
    mpSpent: state.run.metrics.mpSpent,
    mpUnused: state.run.metrics.mpUnused,
    remainingHp: hero?.hp ?? state.run.persistentHeroHp,
    durationMs,
    rendererBackend,
  };
}
