import { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { EmptyState, PageHeader, SourceDetails, StatusBadge } from '../components/Primitives';
import { useSnapshot } from '../context/SnapshotContext';
import { selectItems, type ItemFilters } from '../data/selectors';
import { uniqueSorted } from '../utils/format';

const initialFilters: ItemFilters = { search: '', rarity: '', category: '', slot: '', characterId: '', firstRunOnly: false, kind: '' };

export function ItemsPage() {
  const snapshot = useSnapshot();
  const [filters, setFilters] = useState(initialFilters);
  const items = useMemo(() => selectItems(snapshot.items, filters), [snapshot.items, filters]);
  const update = (key: keyof ItemFilters, value: string | boolean) => setFilters((current) => ({ ...current, [key]: value }));
  return (
    <>
      <PageHeader eyebrow="Catalogue" title="Objets" description="Équipements et consommables exportés, avec compatibilités, bonus et pools déclarés."><span className="count-chip">{items.length} / {snapshot.items.length}</span></PageHeader>
      <form className="filter-panel" onSubmit={(event) => event.preventDefault()} aria-label="Filtres des objets">
        <label className="filter-search">Recherche<input type="search" value={filters.search} onChange={(event) => update('search', event.target.value)} placeholder="Nom, ID, tag…" /></label>
        <label>Rareté<select value={filters.rarity} onChange={(event) => update('rarity', event.target.value)}><option value="">Toutes</option>{uniqueSorted(snapshot.items.map((item) => item.rarity)).map((value) => <option key={value}>{value}</option>)}</select></label>
        <label>Catégorie<select value={filters.category} onChange={(event) => update('category', event.target.value)}><option value="">Toutes</option>{uniqueSorted(snapshot.items.map((item) => item.category.name)).map((value) => <option key={value}>{value}</option>)}</select></label>
        <label>Emplacement<select value={filters.slot} onChange={(event) => update('slot', event.target.value)}><option value="">Tous</option>{uniqueSorted(snapshot.items.map((item) => item.equipment_slot.name)).map((value) => <option key={value}>{value}</option>)}</select></label>
        <label>Héros compatible<select value={filters.characterId} onChange={(event) => update('characterId', event.target.value)}><option value="">Tous</option>{snapshot.characters.map((entry) => <option key={entry.id} value={entry.id}>{entry.name}</option>)}</select></label>
        <label>Type<select value={filters.kind} onChange={(event) => update('kind', event.target.value)}><option value="">Tous</option><option value="equipment">Équipement</option><option value="consumable">Consommable</option></select></label>
        <label className="checkbox-label"><input type="checkbox" checked={filters.firstRunOnly} onChange={(event) => update('firstRunOnly', event.target.checked)} /> Première run uniquement</label>
        <button type="button" className="button button--ghost" onClick={() => setFilters(initialFilters)}>Réinitialiser</button>
      </form>
      {items.length === 0 ? <EmptyState title="Aucun objet trouvé">Aucun objet ne correspond aux filtres actifs.</EmptyState> : (
        <div className="entity-grid">
          {items.map((item) => <article className="entity-card item-card" key={item.id}><div className="item-glyph" aria-hidden="true">◇</div><div className="entity-card__body"><div className="entity-heading"><div><p className="entity-id">{item.id}</p><h2><Link to={`/items/${item.id}`}>{item.name}</Link></h2></div><StatusBadge status={item.valid ? 'conform' : 'difference'} /></div><p>{item.description}</p><div className="effect-list"><span className="effect-badge">{item.rarity}</span><span className="effect-badge">{item.category.name}</span>{item.equippable && <span className="effect-badge">Équipement</span>}{item.consumable && <span className="effect-badge">Consommable</span>}</div><p className="compatibility">{item.compatible_character_ids.length === 0 ? 'Compatible avec tous les héros' : `Compatible avec ${item.compatible_character_ids.length} héros de production sur ${snapshot.characters.length}`}</p><div className="card-footer"><span>{item.stat_modifiers.length} bonus / pénalités</span><span>{item.spell_modifiers.length} effets de sort</span></div><SourceDetails path={item.source_path} /></div></article>)}
        </div>
      )}
    </>
  );
}
