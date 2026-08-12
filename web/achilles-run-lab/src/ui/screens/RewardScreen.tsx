import type { RewardDefinition, RewardEffect } from '../../content/schemas';
import type { GameState } from '../../domain/model/types';

interface RewardScreenProps {
  state: GameState;
  onSelect: (rewardId: string) => void;
  onContinue: () => void;
}

function effectTotal(state: GameState, predicate: (effect: RewardEffect) => boolean): number {
  if (state.run === null) return 0;
  return state.run.acquiredRewards.flatMap((id) => {
    const reward = state.run?.config.rewards.find((candidate) => candidate.id === id);
    return reward === undefined ? [] : [reward.effect];
  }).filter(predicate).reduce((sum, effect) => sum + effect.amount, 0);
}

function values(state: GameState, reward: RewardDefinition): string {
  const effect = reward.effect;
  if (effect.type === 'ABILITY_DAMAGE') {
    const base = state.run?.config.abilities.find((ability) => ability.id === effect.abilityId)?.baseDamage ?? 0;
    const before = base + effectTotal(state, (owned) => owned.type === 'ABILITY_DAMAGE' && owned.abilityId === effect.abilityId);
    return `${before} → ${before + effect.amount} dégâts`;
  }
  if (effect.type === 'ABILITY_RANGE') {
    const base = state.run?.config.abilities.find((ability) => ability.id === effect.abilityId)?.maxRange ?? 0;
    const before = base + effectTotal(state, (owned) => owned.type === 'ABILITY_RANGE' && owned.abilityId === effect.abilityId);
    return `${before} → ${before + effect.amount} cases`;
  }
  if (effect.type === 'MAX_HP') {
    const before = state.run?.persistentHeroMaxHp ?? 100;
    return `${before} → ${before + effect.amount} PV max`;
  }
  return `Effet permanent · +${effect.amount}`;
}

export function RewardScreen({ state, onSelect, onContinue }: RewardScreenProps) {
  const rewards = state.rewardOffer.map((id) => state.run?.config.rewards.find((reward) => reward.id === id)).filter((reward): reward is RewardDefinition => reward !== undefined);
  return (
    <div className="overlay-screen reward-screen" data-testid="reward-screen">
      <div className="overlay-card wide">
        <p className="eyebrow">SALLE NETTOYÉE · CHOIX PERMANENT</p>
        <h2>{rewards.length > 0 ? 'Choisissez votre avantage' : 'Avantage acquis'}</h2>
        <p>Les choix non retenus seront défaussés. Les PV d’Achilles persistent entre les salles.</p>
        {rewards.length > 0 ? (
          <div className="reward-grid">
            {rewards.map((reward, index) => (
              <button type="button" key={reward.id} onClick={() => onSelect(reward.id)} data-testid={`reward-${index}`}>
                <span className="reward-number">0{index + 1}</span><small>{reward.ability}</small><strong>{reward.name}</strong><p>{reward.description}</p><b>{values(state, reward)}</b><em>Choisir cet avantage →</em>
              </button>
            ))}
          </div>
        ) : <button type="button" className="primary continue-room" onClick={onContinue} data-testid="continue-room">Entrer dans la salle suivante →</button>}
        <div className="build-summary"><span>BUILD ACTUEL</span><strong>{state.run?.acquiredRewards.length === 0 ? 'Aucun avantage' : state.run?.acquiredRewards.join(' · ')}</strong></div>
      </div>
    </div>
  );
}
