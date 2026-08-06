import { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { EffectBadge, EmptyState, PageHeader, SourceDetails } from '../components/Primitives';
import { useSnapshot } from '../context/SnapshotContext';
import { selectEnemies, type EnemyFilters } from '../data/selectors';
import { labelAiStrategy, labelEffectTag, labelTacticalRole } from '../data/translations';
import { uniqueSorted } from '../utils/format';

const initialFilters: EnemyFilters = { search: '', faction: '', role: '', aiStrategy: '', range: '', reachability: '', effect: '' };

export function EnemiesPage() {
  const snapshot = useSnapshot();
  const [filters, setFilters] = useState(initialFilters);
  const profilesById = useMemo(
    () => new Map(snapshot.ai_profiles.map((profile) => [profile.id, profile])),
    [snapshot.ai_profiles],
  );
  const enemies = useMemo(
    () => selectEnemies(snapshot.enemies, filters, profilesById),
    [snapshot.enemies, filters, profilesById],
  );
  const set = <K extends keyof EnemyFilters>(key: K, value: EnemyFilters[K]) => setFilters((current) => ({ ...current, [key]: value }));

  return (
    <>
      <PageHeader eyebrow="Production" title="Ennemis" description="Unités ennemies accessibles dans la première run, leurs rôles, stratégies et capacités propres.">
        <span className="count-chip">{enemies.length} / {snapshot.enemies.length}</span>
      </PageHeader>
      <section className="filter-panel enemy-filters" aria-label="Filtres des ennemis">
        <label className="filter-search">Recherche<input type="search" value={filters.search} onChange={(event) => set('search', event.target.value)} /></label>
        <label>Faction<select value={filters.faction} onChange={(event) => set('faction', event.target.value)}><option value="">Toutes</option>{uniqueSorted(snapshot.enemies.map((enemy) => enemy.faction_id)).map((value) => <option key={value}>{value}</option>)}</select></label>
        <label>Rôle<select value={filters.role} onChange={(event) => set('role', event.target.value)}><option value="">Tous</option>{uniqueSorted(snapshot.enemies.map((enemy) => enemy.tactical_role_id)).map((value) => <option key={value} value={value}>{labelTacticalRole(value)}</option>)}</select></label>
        <label>Stratégie IA<select value={filters.aiStrategy} onChange={(event) => set('aiStrategy', event.target.value)}><option value="">Toutes</option>{uniqueSorted(snapshot.ai_profiles.map((profile) => profile.strategy.name)).map((value) => <option key={value} value={value}>{labelAiStrategy(value)}</option>)}</select></label>
        <label>Portée<select value={filters.range} onChange={(event) => set('range', event.target.value as EnemyFilters['range'])}><option value="">Toutes</option><option value="melee">Mêlée</option><option value="ranged">Distance</option></select></label>
        <label>Présence<select value={filters.reachability} onChange={(event) => set('reachability', event.target.value as EnemyFilters['reachability'])}><option value="">Toutes</option><option value="initial">Roster initial</option><option value="summonable">Invocable</option></select></label>
        <label>Effet<select value={filters.effect} onChange={(event) => set('effect', event.target.value as EnemyFilters['effect'])}><option value="">Tous</option><option value="summoner">Invocateur</option><option value="control">Contrôle</option><option value="support">Support</option><option value="shield">Bouclier</option><option value="mark">Marque</option><option value="forced_movement">Déplacement forcé</option></select></label>
        <button className="button button--ghost" type="button" onClick={() => setFilters(initialFilters)}>Réinitialiser</button>
      </section>
      {enemies.length === 0 ? <EmptyState title="Aucun ennemi trouvé">Modifiez ou réinitialisez les filtres.</EmptyState> : <div className="entity-grid enemy-grid">{enemies.map((enemy) => {
        const profile = profilesById.get(enemy.ai_profile_id);
        return <article className="entity-card enemy-card" key={enemy.id}>
          <div className="enemy-sigil" aria-hidden="true">{enemy.name.slice(0, 1)}</div>
          <div className="entity-card__body">
            <p className="entity-id">{enemy.id}</p><h2><Link to={`/enemies/${enemy.id}`}>{enemy.name}</Link></h2>
            <p>{enemy.description}</p>
            <dl className="stat-strip"><div><dt>PV</dt><dd>{enemy.max_hp}</dd></div><div><dt>PA</dt><dd>{enemy.max_ap}</dd></div><div><dt>PM</dt><dd>{enemy.max_mp}</dd></div><div><dt>Init.</dt><dd>{enemy.initiative}</dd></div><div><dt>Armure</dt><dd>{enemy.armour}</dd></div></dl>
            <dl className="enemy-secondary-stats"><div><dt>Résistance magique</dt><dd>{enemy.magic_resistance}</dd></div><div><dt>Sorts</dt><dd>{enemy.spell_ids.length}</dd></div><div><dt>Salles</dt><dd>{enemy.reachability.initial_room_ids.length}</dd></div></dl>
            <p className="relation-line">{labelTacticalRole(enemy.tactical_role_id)} · {profile ? labelAiStrategy(profile.strategy.name) : enemy.ai_profile_id}</p>
            <div className="effect-list">{enemy.effect_tags.map((tag) => <EffectBadge key={tag}>{labelEffectTag(tag)}</EffectBadge>)}</div>
            <div className="card-footer"><span>{enemy.reachability.initial_roster ? 'Roster initial' : 'Hors roster initial'}</span><span>{enemy.reachability.summonable_by_spell_ids.length ? 'Invocable' : 'Non invocable'}</span></div>
            <SourceDetails path={enemy.source_path} />
          </div>
        </article>;
      })}</div>}
    </>
  );
}
