import { Link } from 'react-router-dom';
import { PageHeader, SourceDetails, StatusBadge, VisualPlaceholder } from '../components/Primitives';
import { useSnapshot } from '../context/SnapshotContext';
import { contractStatusForCharacter, sortedByName } from '../data/selectors';

export function CharactersPage() {
  const snapshot = useSnapshot();
  return (
    <>
      <PageHeader eyebrow="Production" title="Personnages" description="Le trio réellement chargé par la première run, ses statistiques et ses liens de progression.">
        <span className="count-chip">{snapshot.characters.length} héros</span>
      </PageHeader>
      <div className="entity-grid entity-grid--characters">
        {sortedByName(snapshot.characters).map((character) => (
          <article key={character.id} className="entity-card character-card">
            <VisualPlaceholder />
            <div className="entity-card__body">
              <div className="entity-heading"><div><p className="entity-id">{character.id}</p><h2><Link to={`/characters/${character.id}`}>{character.name}</Link></h2></div><StatusBadge status={contractStatusForCharacter(snapshot, character)} /></div>
              <p>{character.role} · {character.presentation_summary}</p>
              <dl className="stat-strip">
                <div><dt>PV</dt><dd>{character.max_hp}</dd></div>
                <div><dt>PA</dt><dd>{character.max_ap}</dd></div>
                <div><dt>PM</dt><dd>{character.max_mp}</dd></div>
                <div><dt>INIT.</dt><dd>{character.initiative}</dd></div>
                <div><dt>ATQ.</dt><dd>{character.attack_power}</dd></div>
              </dl>
              <div className="card-footer"><span>{character.spell_ids.length} sorts</span><span>{character.discipline_ids.length} disciplines</span></div>
              <SourceDetails path={character.source_path} />
            </div>
          </article>
        ))}
      </div>
    </>
  );
}
