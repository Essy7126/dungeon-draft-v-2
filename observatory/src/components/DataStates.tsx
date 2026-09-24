import { SNAPSHOT_SOURCE, SnapshotLoadError } from '../data/loadSnapshot';

export function LoadingState() {
  return (
    <div className="state-page" role="status" aria-live="polite">
      <div className="loader" aria-hidden="true" />
      <h1>Chargement du snapshot</h1>
      <p>Validation locale des données de conception…</p>
    </div>
  );
}

export function DataErrorPage({ error, onRetry }: { error: unknown; onRetry: () => void }) {
  const known = error instanceof SnapshotLoadError;
  const kind = known ? error.kind : 'incompatible';
  const issues = known ? error.issues : [];
  const messages: Record<string, string> = {
    network: 'La lecture de la source statique a échoué.',
    http: 'La source statique n’est pas disponible.',
    json: 'Le fichier reçu n’est pas un JSON valide.',
    schema: 'Le schéma de validation est invalide.',
    incompatible: 'Le snapshot ne respecte pas le schéma attendu.',
  };
  return (
    <div className="state-page state-page--error" role="alert">
      <p className="eyebrow">Données indisponibles</p>
      <h1>Impossible d’ouvrir Observatory</h1>
      <p>{messages[kind]}</p>
      <dl className="error-summary">
        <div><dt>Type d’erreur</dt><dd>{kind}</dd></div>
        <div><dt>Nombre d’erreurs</dt><dd>{issues.length || 1}</dd></div>
        <div><dt>Source attendue</dt><dd><code>{known ? error.source : SNAPSHOT_SOURCE}</code></dd></div>
      </dl>
      {issues.length > 0 && (
        <section className="error-issues" aria-labelledby="error-issues-title">
          <h2 id="error-issues-title">Premières erreurs structurées</h2>
          <ol>
            {issues.slice(0, 5).map((issue, index) => <li key={`${issue.path}-${index}`}><code>{issue.path}</code> — {issue.message} ({issue.keyword})</li>)}
          </ol>
        </section>
      )}
      <p>Vérification locale : <code>npm run validate:data</code></p>
      <button type="button" className="button" onClick={onRetry}>Réessayer</button>
    </div>
  );
}
