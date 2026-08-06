import { EffectBadge, SourceDetails } from './Primitives';
import { ModifierList } from './ModifierList';
import type { EnemySpell } from '../types';
import { encounterAbilityStatus } from '../data/selectors';
import {
  labelDamageType,
  labelEffectTag,
  labelElement,
  labelEncounterAbilityStatus,
  humanizeIdentifier,
} from '../data/translations';

export function EnemySpellCard({
  spell,
  encounterId = '',
  disabledAbilityIds = [],
}: {
  spell: EnemySpell;
  encounterId?: string;
  disabledAbilityIds?: readonly string[];
}) {
  const targets = [spell.can_target_enemy && 'ennemi', spell.can_target_ally && 'allié', spell.can_target_free_cell && 'case libre', spell.can_target_self && 'soi'].filter(Boolean).join(', ') || 'aucune cible statique';
  const conditions = [spell.condition_hp_at_or_below >= 0 && `PV ≤ ${spell.condition_hp_at_or_below}`, spell.requires_absent_unit_id && `${spell.requires_absent_unit_id} absent`].filter(Boolean).join(' · ') || 'Aucune';
  const encounterStatus = encounterId
    ? encounterAbilityStatus(spell, encounterId, disabledAbilityIds)
    : null;
  return (
    <article className="enemy-spell-card">
      <header>
        <div><p className="entity-id">{spell.id}</p><h3>{spell.name}</h3></div>
        <span className="cost-orb" aria-label={`${spell.ap_cost} points d’action`}>{spell.ap_cost}<small>PA</small></span>
      </header>
      {encounterStatus ? <p className={`encounter-status encounter-status--${encounterStatus}`}>{labelEncounterAbilityStatus(encounterStatus)}</p> : null}
      <p>{spell.description}</p>
      <div className="effect-list" aria-label="Effets">
        {spell.effect_tags.map((tag) => <EffectBadge key={tag}>{labelEffectTag(tag)}</EffectBadge>)}
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
      <details className="technical-details spell-technical-details">
        <summary>Contraintes et effets complets</summary>
        <dl className="spell-detail-list">
          <div><dt>Type / élément</dt><dd>{labelDamageType(spell.damage_type.name)} · {labelElement(spell.element.name)}</dd></div>
          <div><dt>Cooldown initial</dt><dd>{spell.initial_cooldown}</dd></div>
          <div><dt>Une fois par activation</dt><dd>{spell.once_per_activation ? 'Oui' : 'Non'}</dd></div>
          <div><dt>Ligne depuis le lanceur</dt><dd>{spell.line_from_caster ? 'Oui' : 'Non'}</dd></div>
          <div><dt>Chance critique</dt><dd>{spell.critical_chance}</dd></div>
          <div><dt>Dégâts de collision</dt><dd>{spell.collision_damage}</dd></div>
          <div><dt>Bonus de groupe</dt><dd>{spell.cluster_bonus_damage}</dd></div>
          <div><dt>Drain de PA</dt><dd>{spell.ap_drain}</dd></div>
          <div><dt>Téléportation derrière la cible</dt><dd>{spell.teleport_behind_target ? 'Oui' : 'Non'}</dd></div>
          <div><dt>Résolution différée</dt><dd>{humanizeIdentifier(spell.delayed_resolution.name)}</dd></div>
          <div><dt>Type d’invocation</dt><dd>{spell.summon_type || spell.summon?.resource_type || 'Aucun'}</dd></div>
          <div><dt>Cooldowns initiaux invoqués</dt><dd>{Object.keys(spell.summon_initial_cooldowns).length > 0 ? JSON.stringify(spell.summon_initial_cooldowns) : 'Aucun'}</dd></div>
        </dl>
        <h4>Modificateurs</h4>
        <ModifierList modifiers={spell.modifiers} />
        {spell.serialization_warnings.length > 0 ? <p className="negative">Avertissements de sérialisation : {spell.serialization_warnings.join(' · ')}</p> : null}
      </details>
      {spell.summon_enemy_id && <p className="summon-note">Invocation : <strong>{spell.summon_enemy_id}</strong> · {spell.summon_starting_hp} PV · plafond équipe {spell.summon_max_living_team}</p>}
      <SourceDetails path={spell.source_path} />
    </article>
  );
}
