import { Link } from 'react-router-dom';
import { PageHeader, Panel, SourceDetails, StatusBadge } from '../components/Primitives';
import { useSnapshot } from '../context/SnapshotContext';
import { createSnapshotIndex } from '../data/indexes';

export function RewardsPage() {
  const snapshot = useSnapshot();
  const index = createSnapshotIndex(snapshot);
  const generic = snapshot.reward_pools.find((pool) => pool.kind === 'generic_declared');
  const equipment = snapshot.reward_pools.find((pool) => pool.kind === 'equipment_first_run');
  return (
    <>
      <PageHeader eyebrow="Après-combat" title="Récompenses" description="Déclarations statiques et pool d’équipements de la première run, sans probabilité inventée."><span className="count-chip">{snapshot.summary.generic_rewards} déclarées</span></PageHeader>
      <section className="reward-intro" aria-label="Précision de lecture"><strong>Lecture prudente</strong><p>Les récompenses génériques ci-dessous sont déclarées et référencées par le service. Ce snapshot ne démontre pas qu’elles ont été effectivement attribuées pendant une partie.</p></section>
      <Panel title="Récompenses génériques déclarées">
        {!generic || generic.rewards.length === 0 ? <p className="muted">Aucune récompense générique déclarée.</p> : <div className="reward-grid">{generic.rewards.map((reward) => <article className="reward-card" key={reward.id}><div className="entity-heading"><div><p className="entity-id">{reward.id}</p><h3>{reward.name}</h3></div><StatusBadge status={reward.valid ? 'conform' : 'difference'} /></div><p>{reward.description}</p><dl className="inline-facts"><div><dt>Type</dt><dd>{reward.reward_type.name}</dd></div><div><dt>Cible</dt><dd>{reward.target_policy.name}</dd></div><div><dt>Valeur</dt><dd>{reward.value}</dd></div></dl><p className="usage-label">Statut : {reward.usage_status}</p><SourceDetails path={reward.source_path} /></article>)}</div>}
        {generic && <SourceDetails path={generic.source_path} />}
      </Panel>
      <Panel title="Pool d’équipements de la première run">
        {!equipment ? <p className="muted">Domaine reporté ou pool absent.</p> : <><div className="pool-summary"><div><span>Éligibles</span><strong>{equipment.item_ids.length}</strong></div><div><span>Minimum d’options</span><strong>{equipment.minimum_options}</strong></div><div><span>Mécanisme</span><strong>{equipment.mechanism}</strong></div></div><p>Filtre d’éligibilité : <code>{equipment.required_tag}</code>. Aucun poids ni aucune probabilité ne sont exportés.</p><ul className="linked-list linked-list--columns">{equipment.item_ids.map((itemId) => { const item = index.items.get(itemId); return item ? <li key={itemId}><Link to={`/items/${item.id}`}><strong>{item.name}</strong><span>{item.rarity} · {item.category.name}</span></Link></li> : <li className="unknown-ref" key={itemId}>Référence inconnue : {itemId}</li>; })}</ul><SourceDetails path={equipment.source_path} /></>}
      </Panel>
    </>
  );
}
