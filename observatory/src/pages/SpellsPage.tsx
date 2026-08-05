import { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { EffectBadge, EmptyState, PageHeader, SourceDetails } from '../components/Primitives';
import { useSnapshot } from '../context/SnapshotContext';
import { selectSpells, spellEffects, type SpellFilters } from '../data/selectors';
import { uniqueSorted } from '../utils/format';

const initialFilters: SpellFilters = { search: '', characterId: '', disciplineId: '', apCost: '', effect: '', damageType: '', element: '' };
const effectLabels: Record<string, string> = { damage: 'Dégâts', heal: 'Soin', shield: 'Bouclier', terrain: 'Terrain', status: 'Statut', push: 'Poussée', pull: 'Attraction', summon: 'Invocation', delayed: 'Résolution différée' };

export function SpellsPage() {
  const snapshot = useSnapshot();
  const [filters, setFilters] = useState(initialFilters);
  const spells = useMemo(() => selectSpells(snapshot.spells, filters), [snapshot.spells, filters]);
  const update = (key: keyof SpellFilters, value: string) => setFilters((current) => ({ ...current, [key]: value }));
  return (
    <>
      <PageHeader eyebrow="Capacités" title="Sorts" description="Effets sérialisés, coûts et contraintes des sorts des héros de production."><span className="count-chip">{spells.length} / {snapshot.spells.length}</span></PageHeader>
      <form className="filter-panel" onSubmit={(event) => event.preventDefault()} aria-label="Filtres des sorts">
        <label className="filter-search">Recherche<input type="search" value={filters.search} onChange={(event) => update('search', event.target.value)} placeholder="Nom, ID ou description" /></label>
        <label>Héros<select value={filters.characterId} onChange={(event) => update('characterId', event.target.value)}><option value="">Tous</option>{snapshot.characters.map((entry) => <option key={entry.id} value={entry.id}>{entry.name}</option>)}</select></label>
        <label>Discipline<select value={filters.disciplineId} onChange={(event) => update('disciplineId', event.target.value)}><option value="">Toutes</option>{snapshot.disciplines.map((entry) => <option key={entry.id} value={entry.id}>{entry.name}</option>)}</select></label>
        <label>Coût PA<select value={filters.apCost} onChange={(event) => update('apCost', event.target.value)}><option value="">Tous</option>{uniqueSorted(snapshot.spells.map((spell) => String(spell.ap_cost))).map((value) => <option key={value}>{value}</option>)}</select></label>
        <label>Effet<select value={filters.effect} onChange={(event) => update('effect', event.target.value)}><option value="">Tous</option>{Object.entries(effectLabels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></label>
        <label>Type de dégâts<select value={filters.damageType} onChange={(event) => update('damageType', event.target.value)}><option value="">Tous</option>{uniqueSorted(snapshot.spells.map((spell) => spell.damage_type.name)).map((value) => <option key={value}>{value}</option>)}</select></label>
        <label>Élément<select value={filters.element} onChange={(event) => update('element', event.target.value)}><option value="">Tous</option>{uniqueSorted(snapshot.spells.map((spell) => spell.element.name)).map((value) => <option key={value}>{value}</option>)}</select></label>
        <button type="button" className="button button--ghost" onClick={() => setFilters(initialFilters)}>Réinitialiser</button>
      </form>
      {spells.length === 0 ? <EmptyState title="Aucun sort trouvé">Modifiez ou réinitialisez les filtres.</EmptyState> : (
        <div className="entity-grid">
          {spells.map((spell) => (
            <article className="entity-card compact-card" key={spell.id}>
              <div className="entity-card__body">
                <div className="entity-heading"><div><p className="entity-id">{spell.id}</p><h2><Link to={`/spells/${spell.id}`}>{spell.name}</Link></h2></div><span className="cost-orb" aria-label={`${spell.ap_cost} points d’action`}>{spell.ap_cost}<small>PA</small></span></div>
                <p>{spell.description}</p>
                <div className="effect-list">{spellEffects(spell).map((effect) => <EffectBadge key={effect}>{effectLabels[effect]}</EffectBadge>)}</div>
                <dl className="inline-facts"><div><dt>Portée</dt><dd>{spell.minimum_range}–{spell.range}</dd></div><div><dt>Dégâts</dt><dd>{spell.damage}</dd></div><div><dt>Soin</dt><dd>{spell.heal}</dd></div><div><dt>Cooldown</dt><dd>{spell.cooldown_activations}</dd></div></dl>
                <p className="relation-line">{spell.referenced_by_character_ids.join(', ')} · {spell.discipline_id}</p>
                <SourceDetails path={spell.source_path} />
              </div>
            </article>
          ))}
        </div>
      )}
    </>
  );
}
