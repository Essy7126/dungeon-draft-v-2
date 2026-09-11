import { Link, useParams } from 'react-router-dom';
import { PageHeader, Panel, SourceDetails, StatusBadge, VisualPlaceholder } from '../components/Primitives';
import { useSnapshot } from '../context/SnapshotContext';
import { createSnapshotIndex } from '../data/indexes';
import { formatValue } from '../utils/format';
import { UnknownEntityPage } from './UnknownEntityPage';

export function ItemDetailPage() {
  const { itemId = '' } = useParams<{ itemId?: string }>();
  const snapshot = useSnapshot();
  const index = createSnapshotIndex(snapshot);
  const item = index.items.get(itemId);
  if (!item) return <UnknownEntityPage kind="objet" id={itemId} backTo="/items" />;
  const compatible = item.compatible_character_ids.length === 0 ? snapshot.characters : item.compatible_character_ids.map((id) => index.characters.get(id)).filter((value) => value !== undefined);
  return (
    <>
      <Link className="back-link" to="/items">← Tous les objets</Link>
      <PageHeader eyebrow={`Objet · ${item.id}`} title={item.name} description={item.description}><StatusBadge status={item.valid ? 'conform' : 'difference'} /></PageHeader>
      <div className="detail-hero"><VisualPlaceholder /><Panel title="Classification"><dl className="stats-table"><div><dt>Rareté</dt><dd>{item.rarity}</dd></div><div><dt>Catégorie</dt><dd>{item.category.name}</dd></div><div><dt>Emplacement</dt><dd>{item.equipment_slot.name}</dd></div><div><dt>Type</dt><dd>{item.equippable ? 'Équipement' : item.consumable ? 'Consommable' : 'Autre'}</dd></div><div><dt>Première run</dt><dd>{item.tags.includes('first_run_equipment_reward') ? 'Éligible' : 'Non'}</dd></div><div><dt>Pools</dt><dd>{item.pool_ids.join(', ') || 'Aucun'}</dd></div></dl></Panel></div>
      <div className="two-column"><Panel title="Bonus et pénalités">{item.stat_modifiers.length ? <table><caption>Modificateurs de statistiques</caption><thead><tr><th scope="col">Statistique</th><th scope="col">Valeur</th><th scope="col">Type</th></tr></thead><tbody>{item.stat_modifiers.map((modifier) => <tr key={`${modifier.stat_id}-${modifier.source_path}`}><th scope="row">{modifier.stat_id}</th><td className={modifier.value < 0 ? 'negative' : 'positive'}>{modifier.value > 0 ? '+' : ''}{modifier.value}</td><td>{modifier.modifier_type.name}</td></tr>)}</tbody></table> : <p className="muted">Aucun modificateur de statistique.</p>}</Panel><Panel title="Effets">{item.spell_modifiers.length ? <ul className="modifier-list">{item.spell_modifiers.map((modifier) => <li key={modifier.resource_path}><strong>{modifier.resource_type}</strong>{Object.entries(modifier).filter(([key]) => !['resource_type', 'resource_path'].includes(key)).map(([key, value]) => <span key={key}>{key} : {formatValue(value)}</span>)}</li>)}</ul> : <p className="muted">Aucun effet de sort.</p>}</Panel></div>
      <Panel title="Compatibilité"><p>{item.compatible_character_ids.length === 0 ? 'Compatible avec tous les héros' : `Compatible avec ${compatible.length} héros de production sur ${snapshot.characters.length}`}</p><ul className="tag-list">{compatible.map((character) => <li key={character.id}><Link to={`/characters/${character.id}`}>{character.name}</Link></li>)}</ul></Panel>
      <Panel title="Tags"><ul className="tag-list">{item.tags.map((tag) => <li key={tag}>{tag}</li>)}</ul></Panel>
      <SourceDetails path={item.source_path} />
    </>
  );
}
