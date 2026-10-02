import { Link } from 'react-router-dom';
import { PageHeader, SourceDetails } from '../components/Primitives';
import { useSnapshot } from '../context/SnapshotContext';
import { createSnapshotIndex } from '../data/indexes';
import { sortedByName } from '../data/selectors';

export function DisciplinesPage() {
  const snapshot = useSnapshot();
  const index = createSnapshotIndex(snapshot);
  return (
    <>
      <PageHeader eyebrow="Progression" title="Disciplines" description="Rangs, seuils d’expérience et choix d’évolution exportés par voie."><span className="count-chip">{snapshot.disciplines.length} disciplines</span></PageHeader>
      <div className="entity-grid">
        {sortedByName(snapshot.disciplines).map((discipline) => {
          const owner = index.characters.get(discipline.character_id);
          return <article key={discipline.id} className="entity-card compact-card"><div className="entity-card__body"><p className="entity-id">{discipline.id}</p><h2><Link to={`/disciplines/${discipline.id}`}>{discipline.name}</Link></h2><p>{discipline.description}</p><p className="relation-line">{owner ? owner.name : `Héros inconnu : ${discipline.character_id}`}</p><dl className="inline-facts"><div><dt>Rangs</dt><dd>{discipline.rank_count}</dd></div><div><dt>Choix</dt><dd>{discipline.total_choice_count}</dd></div><div><dt>XP final</dt><dd>{discipline.ranks.at(-1)?.required_total_xp ?? 0}</dd></div></dl><SourceDetails path={discipline.source_path} /></div></article>;
        })}
      </div>
    </>
  );
}
