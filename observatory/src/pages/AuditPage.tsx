import { useMemo, useState } from 'react';
import { Link, useHistory, useLocation } from 'react-router-dom';
import {
  PageHeader,
  Panel,
  SeverityBadge,
  StatusBadge,
  TruthBadge,
} from '../components/Primitives';
import { useSnapshot } from '../context/SnapshotContext';
import {
  affectedRoomIds,
  auditEntityLink,
  EMPTY_AUDIT_FILTERS,
  filterAudits,
  groupAudits,
  type AuditFilters,
  type AuditGroup,
} from '../data/audit';
import { labelAuditRule, labelTruthStatus } from '../data/translations';
import type { AuditResult } from '../types';
import { formatValue, uniqueSorted } from '../utils/format';

type AuditView = 'grouped' | 'occurrences';

function initialFilters(search: string): AuditFilters {
  const params = new URLSearchParams(search);
  return {
    search: params.get('q') ?? '',
    severity: (params.get('severity') ?? '') as AuditFilters['severity'],
    truthStatus: (params.get('truth') ?? '') as AuditFilters['truthStatus'],
    ruleId: params.get('rule') ?? '',
    domain: params.get('domain') ?? '',
    entityType: params.get('entity') ?? '',
    status: params.get('status') ?? '',
  };
}

function AuditEntityLink({ audit }: { audit: AuditResult }) {
  const snapshot = useSnapshot();
  const href = auditEntityLink(snapshot, audit.entity_type, audit.entity_id);
  return href
    ? <Link to={href}>{audit.entity_type} · {audit.entity_id}</Link>
    : <span>{audit.entity_type} · <code>{audit.entity_id}</code></span>;
}

function AuditOccurrence({ audit }: { audit: AuditResult }) {
  return (
    <article className="audit-occurrence">
      <div className="audit-title">
        <SeverityBadge severity={audit.severity} />
        <TruthBadge status={audit.truth_status} />
        <div>
          <p className="entity-id">{audit.rule_id}</p>
          <h3>{audit.message}</h3>
        </div>
      </div>
      <dl className="audit-facts">
        <div><dt>Domaine</dt><dd>{audit.domain}</dd></div>
        <div><dt>Entité</dt><dd><AuditEntityLink audit={audit} /></dd></div>
        <div><dt>Statut</dt><dd>{audit.status}</dd></div>
        <div><dt>Source</dt><dd><code>{audit.source_path}</code></dd></div>
      </dl>
      <details className="audit-evidence">
        <summary>Preuve et recommandation</summary>
        <p><strong>Preuve :</strong> {audit.evidence}</p>
        <p><TruthBadge status={audit.suggested_action_truth_status} /> {audit.suggested_action}</p>
      </details>
    </article>
  );
}

function AuditGroupCard({ group }: { group: AuditGroup }) {
  const snapshot = useSnapshot();
  const rooms = affectedRoomIds(snapshot, group);
  const first = group.occurrences[0];
  const contextualLinks = new Map<string, string>();
  for (const occurrence of group.occurrences) {
    const href = auditEntityLink(snapshot, occurrence.entity_type, occurrence.entity_id);
    if (href && !contextualLinks.has(href)) contextualLinks.set(href, occurrence.entity_id);
  }

  return (
    <article className="audit-group">
      <header className="audit-group__header">
        <div>
          <p className="entity-id">{group.rule_id}</p>
          <h3>{labelAuditRule(group.rule_id)}</h3>
        </div>
        <div className="audit-group__badges">
          <SeverityBadge severity={group.severity} />
          <TruthBadge status={group.truth_status} />
        </div>
      </header>
      <dl className="audit-group__metrics">
        <div><dt>Occurrences</dt><dd>{group.occurrences.length} occurrence{group.occurrences.length > 1 ? 's' : ''}</dd></div>
        <div><dt>Entités</dt><dd>{group.entity_ids.length} entité{group.entity_ids.length > 1 ? 's' : ''}</dd></div>
        {rooms.length > 0 ? <div><dt>Salles</dt><dd>{rooms.length} salles touchées</dd></div> : null}
        <div><dt>Domaines</dt><dd>{group.domains.join(', ')}</dd></div>
        <div><dt>Types d’entités</dt><dd>{group.entity_types.join(', ')}</dd></div>
      </dl>
      <p className="audit-group__evidence"><strong>Première preuve :</strong> {first.evidence}</p>
      <p className="audit-group__recommendation"><TruthBadge status="recommendation" /> <strong>Recommandation :</strong> {first.suggested_action}</p>
      {contextualLinks.size > 0 ? (
        <div className="audit-entity-links" aria-label="Entités concernées">
          {[...contextualLinks].map(([href, entityId]) => <Link key={href} to={href}>{entityId}</Link>)}
        </div>
      ) : null}
      <details className="audit-occurrences">
        <summary>Afficher les {group.occurrences.length} occurrence{group.occurrences.length > 1 ? 's' : ''} brute{group.occurrences.length > 1 ? 's' : ''}</summary>
        <div className="audit-list">{group.occurrences.map((audit, index) => <AuditOccurrence key={`${audit.rule_id}-${audit.entity_id}-${index}`} audit={audit} />)}</div>
      </details>
    </article>
  );
}

export function AuditPage() {
  const snapshot = useSnapshot();
  const history = useHistory();
  const location = useLocation();
  const [filters, setFilters] = useState<AuditFilters>(() => initialFilters(location.search));
  const [view, setView] = useState<AuditView>(() => new URLSearchParams(location.search).get('view') === 'occurrences' ? 'occurrences' : 'grouped');
  const audits = useMemo(
    () => filterAudits(snapshot.audit_results, filters),
    [snapshot.audit_results, filters],
  );
  const groups = useMemo(() => groupAudits(audits), [audits]);

  const replaceQuery = (nextFilters: AuditFilters, nextView: AuditView) => {
    const params = new URLSearchParams();
    if (nextFilters.search) params.set('q', nextFilters.search);
    if (nextFilters.severity) params.set('severity', nextFilters.severity);
    if (nextFilters.truthStatus) params.set('truth', nextFilters.truthStatus);
    if (nextFilters.ruleId) params.set('rule', nextFilters.ruleId);
    if (nextFilters.domain) params.set('domain', nextFilters.domain);
    if (nextFilters.entityType) params.set('entity', nextFilters.entityType);
    if (nextFilters.status) params.set('status', nextFilters.status);
    if (nextView === 'occurrences') params.set('view', nextView);
    history.replace({ pathname: location.pathname, search: params.toString() });
  };

  const updateFilter = <K extends keyof AuditFilters,>(key: K, value: AuditFilters[K]) => {
    const next = { ...filters, [key]: value };
    setFilters(next);
    replaceQuery(next, view);
  };

  const updateView = (next: AuditView) => {
    setView(next);
    replaceQuery(filters, next);
  };

  const reset = () => {
    setFilters(EMPTY_AUDIT_FILTERS);
    setView('grouped');
    replaceQuery(EMPTY_AUDIT_FILTERS, 'grouped');
  };

  return (
    <>
      <PageHeader eyebrow="Qualité des données" title="Contrat et audits" description="La cible de conception, la nature de la preuve et la santé observée restent trois informations distinctes.">
        <span className="count-chip">{snapshot.contract_checks.length + snapshot.audit_results.length} contrôles bruts</span>
      </PageHeader>
      <Panel title="Contrôles du contrat">
        <div className="table-wrap" role="region" aria-label="Tableau des contrôles du contrat" tabIndex={0}>
          <table>
            <caption>Cibles comparées aux valeurs observées</caption>
            <thead><tr><th scope="col">Clé</th><th scope="col">Cible</th><th scope="col">Observé</th><th scope="col">Santé</th><th scope="col">Nature de preuve</th><th scope="col">Entités affectées</th><th scope="col">Preuve</th></tr></thead>
            <tbody>{snapshot.contract_checks.map((check) => <tr key={check.key}>
              <th scope="row"><code>{check.key}</code><small>{check.message}</small></th>
              <td>{formatValue(check.target)}</td><td>{formatValue(check.observed_value)}</td>
              <td><StatusBadge status={check.status} /></td><td><TruthBadge status={check.truth_status} /></td>
              <td>{check.affected_entity_ids.join(', ') || 'Portée globale'}</td><td>{check.evidence}</td>
            </tr>)}</tbody>
          </table>
        </div>
      </Panel>
      <Panel title="Résultats d’audit">
        <form className="filter-panel audit-filters" onSubmit={(event) => event.preventDefault()} aria-label="Filtres des audits">
          <label className="filter-search">Recherche<input type="search" value={filters.search} onChange={(event) => updateFilter('search', event.target.value)} placeholder="Règle, message, preuve ou entité" /></label>
          <label>Sévérité<select value={filters.severity} onChange={(event) => updateFilter('severity', event.target.value as AuditFilters['severity'])}><option value="">Toutes</option><option value="info">Information</option><option value="warning">Avertissement</option><option value="blocking">Bloquant</option></select></label>
          <label>Nature de preuve<select value={filters.truthStatus} onChange={(event) => updateFilter('truthStatus', event.target.value as AuditFilters['truthStatus'])}><option value="">Toutes</option>{uniqueSorted(snapshot.audit_results.map((audit) => audit.truth_status)).map((value) => <option key={value} value={value}>{labelTruthStatus(value as AuditResult['truth_status'])}</option>)}</select></label>
          <label>Règle<select value={filters.ruleId} onChange={(event) => updateFilter('ruleId', event.target.value)}><option value="">Toutes</option>{uniqueSorted(snapshot.audit_results.map((audit) => audit.rule_id)).map((value) => <option key={value}>{value}</option>)}</select></label>
          <label>Domaine<select value={filters.domain} onChange={(event) => updateFilter('domain', event.target.value)}><option value="">Tous</option>{uniqueSorted(snapshot.audit_results.map((audit) => audit.domain)).map((value) => <option key={value}>{value}</option>)}</select></label>
          <label>Type d’entité<select value={filters.entityType} onChange={(event) => updateFilter('entityType', event.target.value)}><option value="">Tous</option>{uniqueSorted(snapshot.audit_results.map((audit) => audit.entity_type)).map((value) => <option key={value}>{value}</option>)}</select></label>
          <label>Statut<select value={filters.status} onChange={(event) => updateFilter('status', event.target.value)}><option value="">Tous</option>{uniqueSorted(snapshot.audit_results.map((audit) => audit.status)).map((value) => <option key={value}>{value}</option>)}</select></label>
          <label>Affichage<select value={view} onChange={(event) => updateView(event.target.value as AuditView)}><option value="grouped">Groupé</option><option value="occurrences">Occurrences</option></select></label>
          <button type="button" className="button button--ghost" onClick={reset}>Réinitialiser</button>
        </form>
        <p className="audit-result-count">{audits.length} occurrence{audits.length > 1 ? 's' : ''} · {groups.length} groupe{groups.length > 1 ? 's' : ''}</p>
        {audits.length === 0 ? <p className="muted" role="status">Aucun audit ne correspond aux filtres.</p> : view === 'grouped'
          ? <div className="audit-groups">{groups.map((group) => <AuditGroupCard key={group.key} group={group} />)}</div>
          : <div className="audit-list">{audits.map((audit, index) => <AuditOccurrence key={`${audit.rule_id}-${audit.entity_id}-${index}`} audit={audit} />)}</div>}
      </Panel>
    </>
  );
}
