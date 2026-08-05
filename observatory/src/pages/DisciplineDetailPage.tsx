import { Link, useParams } from 'react-router-dom';
import { PageHeader, SourceDetails } from '../components/Primitives';
import { useSnapshot } from '../context/SnapshotContext';
import { createSnapshotIndex } from '../data/indexes';
import { UnknownEntityPage } from './UnknownEntityPage';

export function DisciplineDetailPage() {
  const { disciplineId = '' } = useParams<{ disciplineId?: string }>();
  const snapshot = useSnapshot();
  const index = createSnapshotIndex(snapshot);
  const discipline = index.disciplines.get(disciplineId);
  if (!discipline) return <UnknownEntityPage kind="discipline" id={disciplineId} backTo="/disciplines" />;
  const owner = index.characters.get(discipline.character_id);
  return (
    <>
      <Link className="back-link" to="/disciplines">← Toutes les disciplines</Link>
      <PageHeader eyebrow={`Discipline · ${discipline.id}`} title={discipline.name} description={discipline.description}><div className="rank-summary"><strong>{discipline.rank_count}</strong><span>rangs</span><strong>{discipline.total_choice_count}</strong><span>choix</span></div></PageHeader>
      <p className="owner-line">Héros : {owner ? <Link to={`/characters/${owner.id}`}>{owner.name}</Link> : <span className="unknown-ref">{discipline.character_id}</span>}</p>
      <div className="rank-timeline">
        {discipline.ranks.map((rank) => (
          <section key={rank.rank} className="rank-card" aria-labelledby={`rank-${rank.rank}`}>
            <header><span className="rank-number" aria-hidden="true">{rank.rank}</span><div><p className="eyebrow">Seuil {rank.required_total_xp} XP</p><h2 id={`rank-${rank.rank}`}>Rang {rank.rank}</h2></div><span>{rank.choices.length} choix</span></header>
            {rank.choices.length === 0 ? <p className="muted">Aucun choix à ce rang.</p> : <div className="choice-grid">{rank.choices.map((choice) => (
              <article key={choice.upgrade_id} className="choice-card"><p className="entity-id">{choice.upgrade_id}</p><h3>{choice.name}</h3><p>{choice.description}</p><dl><div><dt>Sort ciblé</dt><dd>{choice.target_spell_id ? (index.spells.has(choice.target_spell_id) ? <Link to={`/spells/${choice.target_spell_id}`}>{index.spells.get(choice.target_spell_id)?.name}</Link> : <span className="unknown-ref">{choice.target_spell_id}</span>) : 'Aucun'}</dd></div><div><dt>Prérequis</dt><dd>{choice.prerequisite_ids.join(', ') || 'Aucun'}</dd></div><div><dt>Exclusions</dt><dd>{choice.excluded_ids.join(', ') || 'Aucune'}</dd></div><div><dt>Modificateurs</dt><dd>{choice.modifiers.map((modifier) => modifier.resource_type).join(', ') || 'Aucun'}</dd></div></dl><SourceDetails path={choice.source_path} /></article>
            ))}</div>}
          </section>
        ))}
      </div>
      <SourceDetails path={discipline.source_path} />
    </>
  );
}
