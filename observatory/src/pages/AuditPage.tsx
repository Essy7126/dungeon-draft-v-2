import { useState } from 'react';
import { PageHeader, Panel, SeverityBadge, StatusBadge } from '../components/Primitives';
import { useSnapshot } from '../context/SnapshotContext';
import { formatValue } from '../utils/format';

export function AuditPage() {
  const snapshot = useSnapshot();
  const [severity, setSeverity] = useState('');
  const audits = snapshot.audit_results.filter((audit) => !severity || audit.severity === severity);
  return (
    <>
      <PageHeader eyebrow="Qualité des données" title="Contrat et audits" description="La cible de conception reste distincte de l’état observé et de ce qui n’est pas encore évalué."><span className="count-chip">{snapshot.contract_checks.length + snapshot.audit_results.length} contrôles</span></PageHeader>
      <Panel title="Contrôles du contrat">
        <div className="table-wrap"><table><caption>Cibles comparées aux valeurs observées</caption><thead><tr><th scope="col">Clé</th><th scope="col">Cible</th><th scope="col">Observé</th><th scope="col">Statut</th><th scope="col">Preuve</th></tr></thead><tbody>{snapshot.contract_checks.map((check) => <tr key={check.key}><th scope="row"><code>{check.key}</code><small>{check.message}</small></th><td>{formatValue(check.target)}</td><td>{formatValue(check.observed_value)}</td><td><StatusBadge status={check.status} /></td><td>{check.evidence}</td></tr>)}</tbody></table></div>
      </Panel>
      <Panel title="Résultats d’audit">
        <div className="audit-toolbar"><label>Sévérité<select value={severity} onChange={(event) => setSeverity(event.target.value)}><option value="">Toutes</option><option value="info">Information</option><option value="warning">Avertissement</option><option value="blocking">Bloquant</option></select></label><span>{audits.length} résultat{audits.length > 1 ? 's' : ''}</span></div>
        {audits.length === 0 ? <p className="muted" role="status">Aucun audit de cette sévérité.</p> : <div className="audit-list">{audits.map((audit, index) => <article key={`${audit.rule_id}-${audit.entity_id}-${index}`}><div className="audit-title"><SeverityBadge severity={audit.severity} /><div><p className="entity-id">{audit.rule_id}</p><h3>{audit.message}</h3></div></div><dl className="audit-facts"><div><dt>Domaine</dt><dd>{audit.domain}</dd></div><div><dt>Entité</dt><dd>{audit.entity_type} · {audit.entity_id}</dd></div><div><dt>Preuve</dt><dd>{audit.evidence}</dd></div><div><dt>Source</dt><dd><code>{audit.source_path}</code></dd></div><div><dt>Action suggérée</dt><dd>{audit.suggested_action}</dd></div></dl></article>)}</div>}
      </Panel>
    </>
  );
}
