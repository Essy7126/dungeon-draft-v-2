import { Link, useParams } from 'react-router-dom';
import { EnemySpellCard } from '../components/EnemySpellCard';
import { EffectBadge, PageHeader, Panel, SeverityBadge, SourceDetails } from '../components/Primitives';
import { useSnapshot } from '../context/SnapshotContext';
import { createSnapshotIndex } from '../data/indexes';
import { labelAiStrategy, labelEffectTag, labelResistance, labelTacticalRole } from '../data/translations';
import { UnknownEntityPage } from './UnknownEntityPage';

function flag(value: boolean): string { return value ? 'Oui' : 'Non'; }

export function EnemyDetailPage() {
  const { enemyId = '' } = useParams<{ enemyId?: string }>();
  const snapshot = useSnapshot();
  const index = createSnapshotIndex(snapshot);
  const enemy = index.enemiesById.get(enemyId);
  if (!enemy) return <UnknownEntityPage kind="ennemi" id={enemyId} backTo="/enemies" />;
  const profile = index.aiProfilesById.get(enemy.ai_profile_id);
  const spells = index.enemySpellsByEnemyId.get(enemy.id) ?? [];
  const audits = snapshot.audit_results.filter((audit) => audit.entity_id === enemy.id || enemy.spell_ids.includes(audit.entity_id));

  return (
    <>
      <Link className="back-link" to="/enemies">← Tous les ennemis</Link>
      <PageHeader eyebrow={`${enemy.faction_id} · ${labelTacticalRole(enemy.tactical_role_id)}`} title={enemy.name} description={enemy.description}>
        <span className="count-chip">{labelAiStrategy(profile?.strategy.name ?? enemy.ai_behavior.name)}</span>
      </PageHeader>
      <div className="detail-hero enemy-detail-hero">
        <div className="enemy-portrait" role="img" aria-label={`Emplacement visuel de ${enemy.name}`}><span aria-hidden="true">{enemy.name.slice(0, 1)}</span><small>Visuel non chargé depuis res://</small></div>
        <Panel title="Statistiques de production">
          <dl className="stats-table">
            <div><dt>PV maximum</dt><dd>{enemy.max_hp}</dd></div><div><dt>Initiative</dt><dd>{enemy.initiative}</dd></div><div><dt>PA / PM</dt><dd>{enemy.max_ap} / {enemy.max_mp}</dd></div><div><dt>Puissance d’attaque</dt><dd>{enemy.attack_power}</dd></div>
            <div><dt>Armure</dt><dd>{enemy.armour}</dd></div><div><dt>Résistance magique</dt><dd>{enemy.magic_resistance}</dd></div><div><dt>Esquive</dt><dd>{enemy.dodge}</dd></div><div><dt>Critique</dt><dd>{enemy.critical_chance} · ×{enemy.critical_multiplier}</dd></div>
            <div><dt>Portée préférée</dt><dd>{enemy.preferred_range}</dd></div><div><dt>Plage</dt><dd>{enemy.minimum_range}–{enemy.maximum_range}</dd></div><div><dt>Attaque de base active</dt><dd>{flag(enemy.basic_attack_enabled)}</dd></div><div><dt>Garde la distance</dt><dd>{flag(enemy.keep_distance)}</dd></div>
          </dl>
        </Panel>
      </div>
      <div className="effect-list" aria-label="Propriétés tactiques">{enemy.effect_tags.map((tag) => <EffectBadge key={tag}>{labelEffectTag(tag)}</EffectBadge>)}</div>

      <div className="two-column">
        <Panel title="Profil IA">
          {profile ? <dl className="stats-table"><div><dt>Stratégie</dt><dd>{profile.strategy.description}</dd></div><div><dt>Plage idéale</dt><dd>{profile.ideal_minimum_range}–{profile.ideal_maximum_range}</dd></div><div><dt>Évite l’adjacence</dt><dd>{flag(profile.avoid_hero_adjacency)}</dd></div><div><dt>Protège le commandant</dt><dd>{flag(profile.protect_commander_paths)}</dd></div><div><dt>Seuil sentence</dt><dd>{profile.sentence_hp_ratio_threshold}</dd></div><div><dt>Seuil invocation</dt><dd>{profile.summon_when_normals_below}</dd></div></dl> : <p className="unknown-ref">Profil IA inconnu : {enemy.ai_profile_id}</p>}
        </Panel>
        <Panel title="Passifs et résistances">
          <dl className="stats-table"><div><dt>Armure de proximité</dt><dd>{enemy.proximity_armor_per_living_neighbor} × {enemy.proximity_armor_max_neighbors}</dd></div><div><dt>Réduction déplacement forcé</dt><dd>{enemy.first_forced_movement_reduction_per_activation}</dd></div>{Object.entries(enemy.resistances).map(([name, value]) => <div key={name}><dt>{labelResistance(name)}</dt><dd>{value}</dd></div>)}</dl>
          {Object.keys(enemy.resistances).length === 0 && <p className="muted">Aucune résistance élémentaire additionnelle exportée.</p>}
        </Panel>
      </div>

      <Panel title={`Capacités ennemies (${spells.length})`}><div className="enemy-spell-grid">{spells.map((spell) => <EnemySpellCard key={spell.id} spell={spell} />)}</div></Panel>

      <div className="two-column">
        <Panel title="Présence dans la run">
          <ul className="linked-list">{enemy.reachability.initial_room_ids.map((roomId) => {
            const room = index.roomsById.get(roomId);
            return <li key={roomId}>{room ? <Link to={`/rooms/${room.id}`}><strong>{room.name}</strong><span>Roster initial</span></Link> : <span className="unknown-ref">Salle inconnue : {roomId}</span>}</li>;
          })}</ul>
          {enemy.reachability.summonable_by_spell_ids.length > 0 && <p className="summon-note">Invocable par : {enemy.reachability.summonable_by_spell_ids.join(', ')}</p>}
          <details className="source-details"><summary>Rencontres ({enemy.reachability.initial_encounter_ids.length})</summary><ul>{enemy.reachability.initial_encounter_ids.map((id) => <li key={id}><code>{id}</code></li>)}</ul></details>
        </Panel>
        <Panel title={`Audits associés (${audits.length})`}>
          {audits.length ? <div className="audit-list">{audits.map((audit) => <article key={`${audit.rule_id}-${audit.entity_id}`}><div className="audit-title"><SeverityBadge severity={audit.severity} /><strong>{audit.rule_id}</strong></div><p>{audit.message}</p></article>)}</div> : <p className="positive">Aucun audit spécifique à cet ennemi ou à ses capacités.</p>}
        </Panel>
      </div>
      <SourceDetails path={enemy.source_path} />
    </>
  );
}
