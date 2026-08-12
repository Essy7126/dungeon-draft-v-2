import type { AbilityId, Cell } from '../../content/schemas';
import { legalAbilityPreviews, legalMoveCells } from '../../domain/rules/legal_actions';
import type { GameEvent, GameState, UnitState } from '../../domain/model/types';
import { getHero, getLivingEnemies } from '../../domain/rules/combat';
import { AbilityBar } from '../components/AbilityBar';

interface CombatScreenProps {
  state: GameState;
  selectedAbility: AbilityId | null;
  selectedUnitId: string | null;
  locked: boolean;
  fastAnimations: boolean;
  onFastAnimations: (value: boolean) => void;
  onSelectAbility: (abilityId: AbilityId) => void;
  onMove: (cell: Cell) => void;
  onUse: (abilityId: AbilityId, targetUnitId: string | null, targetCell: Cell | null) => void;
  onEnd: () => void;
  onCancel: () => void;
  onMenu: () => void;
  onAssist: () => void;
}

function targetLabel(unit: UnitState): string {
  return `${unit.name} · ${unit.hp}/${unit.maxHp} PV · armure ${unit.armor}${unit.shield > 0 ? ` · bouclier ${unit.shield}` : ''}`;
}

function eventFeedback(event: GameEvent | undefined): string | null {
  if (event === undefined) return null;
  if (event.type === 'DAMAGE_APPLIED') return `−${event.amount} PV${event.absorbed > 0 ? ` · ${event.absorbed} absorbés` : ''}`;
  if (event.type === 'UNIT_PUSHED') return 'POUSSÉE';
  if (event.type === 'COLLISION_TRIGGERED') return `COLLISION · ${event.damage}`;
  if (event.type === 'SHIELD_APPLIED') return `+${event.amount} BOUCLIER`;
  if (event.type === 'UNIT_DIED') return 'CIBLE ÉLIMINÉE';
  if (event.type === 'REINFORCEMENT_SPAWNED') return 'RENFORT ENTRÉ EN COMBAT';
  return null;
}

export function CombatScreen(props: CombatScreenProps) {
  const hero = getHero(props.state);
  const battle = props.state.battle;
  const previews = props.selectedAbility === null ? [] : legalAbilityPreviews(props.state, props.selectedAbility);
  const moves = props.selectedAbility === null ? legalMoveCells(props.state) : [];
  const selectedTarget = battle?.units.find((unit) => unit.id === props.selectedUnitId) ?? null;
  const latestEvents = props.state.eventLog.slice(-7).reverse();
  const feedback = eventFeedback(props.state.eventLog.at(-1));
  if (hero === null || battle === null || props.state.run === null) return <div />;
  return (
    <div className="combat-ui">
      <header className="combat-header">
        <div className="brand-mark"><span>DD</span><strong>ACHILLES LAB</strong></div>
        <div className="room-heading"><small>SALLE {battle.roomPosition + 1}/{props.state.run.activeRoomIds.length}</small><h2>{battle.roomName}</h2></div>
        <div className="round-chip">ROUND <strong>{battle.round}</strong></div>
        <button type="button" className="ghost" onClick={props.onMenu}>Menu / pause</button>
      </header>
      <aside className="hero-hud">
        <div className="portrait">A</div>
        <div className="hero-meta"><small>HÉROS</small><strong>Achilles</strong><span>Armure {hero.armor}</span></div>
        <div className="vital-row"><span>PV</span><b>{hero.hp} / {hero.maxHp}</b><div><i style={{ width: `${100 * hero.hp / hero.maxHp}%` }} /></div></div>
        <div className="shield-row"><span>Bouclier</span><b>{hero.shield}</b></div>
        <div className="resource-pair"><div><span>PA</span><strong data-testid="hero-ap">{hero.ap}</strong><small>/ {hero.maxAp}</small></div><div><span>PM</span><strong data-testid="hero-mp">{hero.mp}</strong><small>/ {hero.maxMp}</small></div></div>
        <div className="link-state"><span>Liaison contextuelle</span><strong>{hero.lastActionTag === 'NONE' ? 'Aucun bonus actif' : hero.lastActionTag}</strong><small>Éphémère · remise à zéro au prochain tour</small></div>
        <label className="toggle"><input type="checkbox" checked={props.fastAnimations} onChange={(event) => props.onFastAnimations(event.target.checked)} /> Animations rapides</label>
        <button type="button" className="assist-button" onClick={props.onAssist}>Bot V1 · jouer l’activation</button>
      </aside>
      <aside className="tactical-panel">
        <div className="panel-title"><span>ÉTAT DU COMBAT</span><b>{getLivingEnemies(props.state).length} ennemi(s)</b></div>
        <div className="enemy-list">
          {getLivingEnemies(props.state).map((enemy) => <div key={enemy.id} className={enemy.id === props.selectedUnitId ? 'active' : ''}><span>{enemy.name}</span><b>{enemy.hp}/{enemy.maxHp}</b></div>)}
        </div>
        <div className="target-sheet">
          <small>CIBLE SÉLECTIONNÉE</small>
          <strong>{selectedTarget === null ? 'Aucune' : targetLabel(selectedTarget)}</strong>
          {selectedTarget?.statuses.includes('STAGGERED') === true && <span>◆ ÉTOURDI : −1 PA à sa prochaine activation</span>}
        </div>
        <div className="legal-actions" data-testid="legal-actions">
          <small>{props.selectedAbility === null ? 'CASES ATTEIGNABLES' : 'CIBLES LÉGALES · APERÇU EXACT'}</small>
          {moves.slice(0, 12).map((cell) => <button type="button" key={`${cell.x}-${cell.y}`} onClick={() => props.onMove(cell)} data-testid={`move-${cell.x}-${cell.y}`}>◇ Case {cell.x + 1}:{cell.y + 1}</button>)}
          {previews.map((preview, index) => (
            <button type="button" key={`${preview.targetUnitId ?? 'cell'}-${preview.targetCell?.x ?? index}-${preview.targetCell?.y ?? index}`} onClick={() => props.onUse(preview.abilityId, preview.targetUnitId, preview.targetCell)} data-testid={`legal-target-${index}`}>
              ◆ {preview.targetUnitId ?? `Case ${(preview.targetCell?.x ?? 0) + 1}:${(preview.targetCell?.y ?? 0) + 1}`} · {preview.expectedDamage} dégâts{preview.shieldGain > 0 ? ` · +${preview.shieldGain} bouclier` : ''}{preview.collision ? ' · COLLISION' : ''}
            </button>
          ))}
          {moves.length === 0 && previews.length === 0 && <p>Aucune cible légale pour cette action.</p>}
        </div>
        <div className="event-feed" aria-label="Journal de combat">
          <small>JOURNAL CONDENSÉ</small>
          {latestEvents.map((event, index) => <p key={`${event.type}-${index}`}>{event.type.replaceAll('_', ' ')}</p>)}
        </div>
      </aside>
      <div className="combat-footer">
        <AbilityBar state={props.state} selected={props.selectedAbility} locked={props.locked} onSelect={props.onSelectAbility} />
        <div className="turn-actions">
          <button type="button" onClick={props.onCancel}>Annuler <kbd>Échap</kbd></button>
          <button type="button" className="end-turn" onClick={props.onEnd} data-testid="end-turn">Fin d’activation <kbd>Espace</kbd></button>
        </div>
      </div>
      {props.locked && <div className="input-lock" role="status">Résolution…</div>}
      {feedback !== null && <div className="event-burst" aria-live="polite">{feedback}</div>}
    </div>
  );
}
