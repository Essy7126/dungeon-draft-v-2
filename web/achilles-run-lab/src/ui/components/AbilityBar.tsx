import type { AbilityId } from '../../content/schemas';
import type { GameState } from '../../domain/model/types';
import { effectiveAbilityRange } from '../../domain/rules/abilities';
import { getHero } from '../../domain/rules/combat';

interface AbilityBarProps {
  state: GameState;
  selected: AbilityId | null;
  locked: boolean;
  onSelect: (ability: AbilityId) => void;
}

const keyById: Record<AbilityId, string> = {
  pursuit_thrust: '1', bronze_bash: '2', crossing_step: '3', turning_guard: '4',
};

export function AbilityBar({ state, selected, locked, onSelect }: AbilityBarProps) {
  const hero = getHero(state);
  const abilities = state.run?.config.abilities ?? [];
  return (
    <div className="ability-bar" aria-label="Capacités d’Achilles">
      {abilities.map((ability) => {
        const used = hero?.usedAbilities.includes(ability.id) ?? false;
        const available = !locked && !used && (hero?.ap ?? 0) >= ability.apCost;
        const contextual = (ability.id === 'pursuit_thrust' && hero?.lastActionTag === 'STEP')
          || (ability.id === 'bronze_bash' && hero?.lastActionTag === 'SPEAR')
          || (ability.id === 'crossing_step' && hero?.lastActionTag === 'SHIELD')
          || (ability.id === 'turning_guard' && hero?.lastActionTag === 'STEP');
        return (
          <button
            type="button"
            key={ability.id}
            className={`ability-card ${selected === ability.id ? 'selected' : ''} ${used ? 'used' : ''}`}
            onClick={() => onSelect(ability.id)}
            aria-pressed={selected === ability.id}
            data-testid={`ability-${ability.id}`}
          >
            <span className="ability-key">{keyById[ability.id]}</span>
            <span className="ability-copy">
              <strong>{ability.name}</strong>
              <small>{ability.apCost} PA · portée {effectiveAbilityRange(state, ability.id)}</small>
              <span>{ability.description}</span>
              <em>{used ? '✓ Utilisée ce tour' : available ? '◇ Prête' : '× Indisponible'}</em>
              {contextual && <b className="link-bonus">Bonus de liaison actif</b>}
            </span>
          </button>
        );
      })}
    </div>
  );
}
