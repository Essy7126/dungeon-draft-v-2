import { Link, useParams } from 'react-router-dom';
import { PageHeader, Panel, SourceDetails, StatusBadge, VisualPlaceholder } from '../components/Primitives';
import { useSnapshot } from '../context/SnapshotContext';
import { createSnapshotIndex } from '../data/indexes';
import { contractStatusForCharacter } from '../data/selectors';
import { UnknownEntityPage } from './UnknownEntityPage';

export function CharacterDetailPage() {
  const { characterId = '' } = useParams<{ characterId?: string }>();
  const snapshot = useSnapshot();
  const index = createSnapshotIndex(snapshot);
  const character = index.characters.get(characterId);
  if (!character) return <UnknownEntityPage kind="personnage" id={characterId} backTo="/characters" />;
  const spells = character.spell_ids.map((id) => index.spells.get(id));
  const disciplines = character.discipline_ids.map((id) => index.disciplines.get(id));
  const checks = snapshot.contract_checks.filter((check) => ['party.required_character_ids', 'combat.base_ap', 'combat.base_mp', 'combat.starting_active_spell_slots', 'progression.discipline_count_per_character'].includes(check.key));

  return (
    <>
      <Link className="back-link" to="/characters">← Tous les personnages</Link>
      <PageHeader eyebrow={`Personnage · ${character.id}`} title={character.name} description={character.description}>
        <StatusBadge status={contractStatusForCharacter(snapshot, character)} />
      </PageHeader>
      <div className="detail-hero">
        <VisualPlaceholder />
        <Panel title="Statistiques de base">
          <dl className="stats-table">
            <div><dt>Rôle</dt><dd>{character.role}</dd></div><div><dt>PV maximum</dt><dd>{character.max_hp}</dd></div>
            <div><dt>Points d’action</dt><dd>{character.max_ap}</dd></div><div><dt>Points de mouvement</dt><dd>{character.max_mp}</dd></div>
            <div><dt>Initiative</dt><dd>{character.initiative}</dd></div><div><dt>Attaque de base</dt><dd>{character.attack_power}</dd></div>
            <div><dt>Emplacements actifs</dt><dd>{character.active_spell_slots}</dd></div>
          </dl>
        </Panel>
      </div>
      <div className="two-column">
        <Panel title={`Sorts (${spells.length})`}>
          <ul className="linked-list">{spells.map((spell, indexPosition) => spell ? <li key={spell.id}><Link to={`/spells/${spell.id}`}><strong>{spell.name}</strong><span>{spell.ap_cost} PA · {spell.discipline_id}</span></Link></li> : <li key={character.spell_ids[indexPosition]} className="unknown-ref">Référence inconnue : {character.spell_ids[indexPosition]}</li>)}</ul>
        </Panel>
        <Panel title={`Disciplines (${disciplines.length})`}>
          <ul className="linked-list">{disciplines.map((discipline, indexPosition) => discipline ? <li key={discipline.id}><Link to={`/disciplines/${discipline.id}`}><strong>{discipline.name}</strong><span>{discipline.rank_count} rangs · {discipline.total_choice_count} choix</span></Link></li> : <li key={character.discipline_ids[indexPosition]} className="unknown-ref">Référence inconnue : {character.discipline_ids[indexPosition]}</li>)}</ul>
        </Panel>
      </div>
      <Panel title="Contrôles associés">
        <div className="check-list">{checks.map((check) => <article key={check.key}><StatusBadge status={check.status} /><div><strong>{check.key}</strong><p>{check.message}</p></div></article>)}</div>
      </Panel>
      <SourceDetails path={character.source_path} />
    </>
  );
}
