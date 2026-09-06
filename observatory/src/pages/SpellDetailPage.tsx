import { Link, useParams } from 'react-router-dom';
import { ModifierList } from '../components/ModifierList';
import { EffectBadge, PageHeader, Panel, SourceDetails, VisualPlaceholder } from '../components/Primitives';
import { useSnapshot } from '../context/SnapshotContext';
import { createSnapshotIndex } from '../data/indexes';
import { spellEffects } from '../data/selectors';
import {
  humanizeIdentifier,
  labelDamageType,
  labelEffectTag,
  labelElement,
} from '../data/translations';
import { theoreticalApBudget } from '../utils/format';
import { UnknownEntityPage } from './UnknownEntityPage';

export function SpellDetailPage() {
  const { spellId = '' } = useParams<{ spellId?: string }>();
  const snapshot = useSnapshot();
  const index = createSnapshotIndex(snapshot);
  const spell = index.spells.get(spellId);
  if (!spell) return <UnknownEntityPage kind="sort" id={spellId} backTo="/spells" />;
  const owner = spell.referenced_by_character_ids.map((id) => index.characters.get(id)).find(Boolean);
  const discipline = index.disciplines.get(spell.discipline_id);
  const budget = theoreticalApBudget(owner?.max_ap ?? 0, spell.ap_cost);
  const targets = [spell.can_target_enemy && 'Ennemi', spell.can_target_ally && 'Allié', spell.can_target_free_cell && 'Case libre', spell.can_target_self && 'Soi-même'].filter((value): value is string => Boolean(value));
  return (
    <>
      <Link className="back-link" to="/spells">← Tous les sorts</Link>
      <PageHeader eyebrow={`Sort · ${spell.id}`} title={spell.name} description={spell.description}><span className="cost-orb cost-orb--large">{spell.ap_cost}<small>PA</small></span></PageHeader>
      <div className="detail-hero"><VisualPlaceholder /><Panel title="Lecture rapide"><div className="effect-list">{spellEffects(spell).map((effect) => <EffectBadge key={effect}>{labelEffectTag(effect)}</EffectBadge>)}</div><p><strong>Portée :</strong> {spell.minimum_range} à {spell.range} cases</p><p><strong>Ciblage :</strong> {targets.join(', ') || 'Non renseigné'}</p>{budget !== null && <p className="budget-note">Budget PA seul : jusqu’à {budget} utilisation{budget > 1 ? 's' : ''} théorique{budget > 1 ? 's' : ''}.<small>Hors cooldown, ciblage, limite d’usage et autres règles du sort.</small></p>}</Panel></div>
      <div className="two-column">
        <Panel title="Effets exportés"><dl className="stats-table">
          <div><dt>Dégâts</dt><dd>{spell.damage}</dd></div><div><dt>Type de dégâts</dt><dd>{labelDamageType(spell.damage_type.name)}</dd></div>
          <div><dt>Élément</dt><dd>{labelElement(spell.element.name)}</dd></div><div><dt>Chance critique</dt><dd>{spell.critical_chance}</dd></div>
          <div><dt>Soin</dt><dd>{spell.heal}</dd></div><div><dt>Bouclier</dt><dd>{spell.shield_grant}</dd></div>
          <div><dt>Zone</dt><dd>{humanizeIdentifier(spell.aoe_shape.name)} · taille {spell.aoe_size}</dd></div><div><dt>Ligne depuis le lanceur</dt><dd>{spell.line_from_caster ? 'Oui' : 'Non'}</dd></div>
          <div><dt>Poussée</dt><dd>{spell.push_distance}</dd></div><div><dt>Attraction</dt><dd>{spell.pull_distance}</dd></div>
          <div><dt>Dégâts de collision</dt><dd>{spell.collision_damage}</dd></div><div><dt>Bonus de groupe</dt><dd>{spell.cluster_bonus_damage}</dd></div>
          <div><dt>Drain de PA</dt><dd>{spell.ap_drain}</dd></div><div><dt>Téléportation derrière la cible</dt><dd>{spell.teleport_behind_target ? 'Oui' : 'Non'}</dd></div>
          <div><dt>Résolution différée</dt><dd>{humanizeIdentifier(spell.delayed_resolution.name)}</dd></div>
        </dl></Panel>
        <Panel title="Contraintes"><dl className="stats-table">
          <div><dt>Ligne de vue</dt><dd>{spell.needs_line_of_sight ? 'Oui' : 'Non'}</dd></div><div><dt>Cooldown</dt><dd>{spell.cooldown_activations}</dd></div>
          <div><dt>Cooldown initial</dt><dd>{spell.initial_cooldown}</dd></div><div><dt>Une fois par activation</dt><dd>{spell.once_per_activation ? 'Oui' : 'Non'}</dd></div>
          <div><dt>Limite par combat</dt><dd>{spell.max_uses_per_combat || 'Aucune exportée'}</dd></div><div><dt>Terrain</dt><dd>{spell.terrain_effect?.resource_type ?? 'Aucun'}</dd></div>
          <div><dt>Statut</dt><dd>{spell.applied_status?.resource_type ?? 'Aucun'}</dd></div><div><dt>Invocation</dt><dd>{spell.summon_type || spell.summon?.resource_type || 'Aucune'}</dd></div>
        </dl></Panel>
      </div>
      <div className="two-column">
        <Panel title="Modificateurs"><ModifierList modifiers={spell.modifiers} /></Panel>
        <Panel title="Relations et sérialisation">
          <p>Héros : {owner ? <Link to={`/characters/${owner.id}`}>{owner.name}</Link> : <span className="unknown-ref">référence inconnue</span>}</p>
          <p>Discipline : {discipline ? <Link to={`/disciplines/${discipline.id}`}>{discipline.name}</Link> : <span className="unknown-ref">{spell.discipline_id}</span>}</p>
          {spell.serialization_warnings.length > 0 ? <ul className="negative">{spell.serialization_warnings.map((warning) => <li key={warning}>{warning}</li>)}</ul> : <p className="positive">Aucun avertissement de sérialisation.</p>}
          <details className="source-details"><summary>Ressources visuelles et sonores</summary><code>{spell.icon_path || 'Icône non exportée'}</code><code>{spell.vfx_scene_path || 'VFX non exporté'}</code><code>{spell.sound_path || 'Son non exporté'}</code></details>
        </Panel>
      </div>
      <SourceDetails path={spell.source_path} />
    </>
  );
}
