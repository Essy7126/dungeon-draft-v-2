import { Link } from 'react-router-dom';
import { PageHeader, Panel, StatusBadge } from '../components/Primitives';
import { useBuildMeta } from '../context/BuildMetaContext';
import { useSnapshot } from '../context/SnapshotContext';
import { labelFreshnessStatus } from '../data/translations';

const kindLabels = {
  production: 'Production',
  test: 'Outil de test',
  debug: 'Debug',
  legacy: 'Legacy',
  unknown: 'Nature inconnue',
} as const;

const flowLabels = {
  single_encounter: 'Rencontre unique',
  wave_chain: 'Chaîne de vagues',
  unknown: 'Mode inconnu',
} as const;

export function RunsPage() {
  const snapshot = useSnapshot();
  const buildMeta = useBuildMeta();
  const runs = [...snapshot.runs].sort((left, right) => (
    Number(right.is_primary) - Number(left.is_primary)
    || left.name.localeCompare(right.name, 'fr')
  ));

  return (
    <>
      <PageHeader
        eyebrow="Parcours exportés"
        title="Runs"
        description="La production et les outils de test sont présentés séparément, sans mélanger leurs compteurs."
      />
      <div className="run-list-grid">
        {runs.map((run) => (
          <Panel
            key={run.id}
            title={run.name}
            className={run.run_kind === 'test' ? 'run-list-card run-list-card--test' : 'run-list-card'}
          >
            <p className="eyebrow">
              {kindLabels[run.run_kind]} · {flowLabels[run.flow_mode]}
              {run.is_primary ? ' · Principale' : ''}
            </p>
            {run.run_kind === 'test' ? <p className="test-tool-warning">Outil de test — ces données ne décrivent pas la production.</p> : null}
            <dl className="key-values">
              <div><dt>Salles</dt><dd>{run.authored_room_count}</dd></div>
              <div><dt>Combats effectifs</dt><dd>{run.effective_combat_count}</dd></div>
              <div><dt>Profils de vague</dt><dd>{run.authored_wave_profile_count}</dd></div>
              <div><dt>Validité</dt><dd><StatusBadge status={run.validation_status === 'valid' ? 'conform' : 'difference'} /></dd></div>
              <div><dt>Fraîcheur</dt><dd>{labelFreshnessStatus(buildMeta.freshness_status)}</dd></div>
            </dl>
            <Link className="detail-link" to={`/runs/${run.id}`}>Voir le détail →</Link>
          </Panel>
        ))}
      </div>
    </>
  );
}
