import { EffectBadge, SourceDetails } from './Primitives';
import type { EnemySpell } from '../types';

export function EnemySpellCard({ spell }: { spell: EnemySpell }) {
  const targets = [spell.can_target_enemy && 'ennemi', spell.can_target_ally && 'allié', spell.can_target_free_cell && 'case libre', spell.can_target_self && 'soi'].filter(Boolean).join(', ') || 'aucune cible statique';
  const conditions = [spell.condition_hp_at_or_below >= 0 && `PV ≤ ${spell.condition_hp_at_or_below}`, spell.requires_absent_unit_id && `${spell.requires_absent_unit_id} absent`].filter(Boolean).join(' · ') || 'Aucune';
  return (
    <article className="enemy-spell-card">
      <header>
        <div><p className="entity-id">{spell.id}</p><h3>{spell.name}</h3></div>
        <span className="cost-orb" aria-label={`${spell.ap_cost} points d’action`}>{spell.ap_cost}<small>PA</small></span>
      </header>
      <p>{spell.description}</p>
      <div className="effect-list" aria-label="Effets">
        {spell.effect_tags.map((tag) => <EffectBadge key={tag}>{tag.replace('_', ' ')}</EffectBadge>)}
      </div>
      <dl className="inline-facts enemy-spell-facts">
        <div><dt>Portée</dt><dd>{spell.minimum_range}–{spell.range}</dd></div>
        <div><dt>Dégâts</dt><dd>{spell.damage}</dd></div>
        <div><dt>Recharge</dt><dd>{spell.cooldown_activations}</dd></div>
        <div><dt>Usages max.</dt><dd>{spell.max_uses_per_combat || '∞'}</dd></div>
      </dl>
      <dl className="spell-detail-list">
        <div><dt>Ciblage</dt><dd>{targets}{spell.needs_line_of_sight ? ' · ligne de vue' : ''}</dd></div>
        <div><dt>Soin / bouclier</dt><dd>{spell.heal} / {spell.shield_grant}</dd></div>
        <div><dt>Statut / terrain</dt><dd>{spell.applied_status?.resource_path || 'aucun'} / {spell.terrain_effect?.resource_path || 'aucun'}</dd></div>
        <div><dt>Mouvement</dt><dd>poussée {spell.push_distance} · attraction {spell.pull_distance}</dd></div>
        <div><dt>Conditions</dt><dd>{conditions}</dd></div>
        <div><dt>Rencontres</dt><dd>{spell.encounter_enabled_in_ids.length} active(s) · {spell.encounter_disabled_in_ids.length} désactivée(s)</dd></div>
      </dl>
      {spell.summon_enemy_id && <p className="summon-note">Invocation : <strong>{spell.summon_enemy_id}</strong> · {spell.summon_starting_hp} PV · plafond équipe {spell.summon_max_living_team}</p>}
      <SourceDetails path={spell.source_path} />
    </article>
  );
}
