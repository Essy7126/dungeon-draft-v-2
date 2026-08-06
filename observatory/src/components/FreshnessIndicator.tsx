import { useBuildMeta } from '../context/BuildMetaContext';
import { useSnapshot } from '../context/SnapshotContext';
import { labelFreshnessStatus } from '../data/translations';
import { formatDate } from '../utils/format';

export function FreshnessIndicator() {
  const snapshot = useSnapshot();
  const buildMeta = useBuildMeta();
  const { meta } = snapshot;
  const changedPaths = buildMeta.non_observatory_changed_paths;

  return (
    <details className={`freshness freshness--${buildMeta.freshness_status}`}>
      <summary>
        <span className="freshness__status">
          <span className="status-dot" aria-hidden="true" />
          {labelFreshnessStatus(buildMeta.freshness_status)}
        </span>
        <code>{meta.source_game_commit.slice(0, 12)}</code>
      </summary>
      <div className="freshness__panel">
        <dl>
          <div><dt>SHA source</dt><dd><code>{meta.source_game_commit}</code></dd></div>
          <div><dt>Branche</dt><dd><code>{meta.source_branch}</code></dd></div>
          <div><dt>Généré le</dt><dd>{formatDate(meta.generated_at_utc)} UTC</dd></div>
          <div><dt>Checkout source</dt><dd>{meta.source_worktree_dirty_before_export ? 'Sale' : 'Propre'}</dd></div>
          <div><dt>Git à l’export</dt><dd>{meta.source_git_available ? 'Disponible' : 'Indisponible'}</dd></div>
          <div><dt>Certification</dt><dd>{meta.source_generated_from_clean_checkout ? 'Checkout propre certifié' : 'Non certifiée'}</dd></div>
        </dl>
        {buildMeta.freshness_status === 'stale' ? (
          <>
            <p>{changedPaths.length} fichier{changedPaths.length > 1 ? 's' : ''} de jeu diffère{changedPaths.length > 1 ? 'nt' : ''}. L’effet fonctionnel exige un nouvel export pour être connu.</p>
            <ul>{changedPaths.slice(0, 5).map((path) => <li key={path}><code>{path}</code></li>)}</ul>
          </>
        ) : null}
        {buildMeta.freshness_status === 'diverged' ? <p>Les références Git ne partagent pas de base comparable.</p> : null}
        {buildMeta.freshness_status === 'unknown' ? <p>Git ou l’une des références nécessaires est indisponible.</p> : null}
      </div>
    </details>
  );
}
