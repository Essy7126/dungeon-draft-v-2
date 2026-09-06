import { Link } from 'react-router-dom';
import { useSnapshot } from '../context/SnapshotContext';
import { formatDate, formatValue } from '../utils/format';
import { MetricCard, PageHeader, Panel, SeverityBadge, StatusBadge, TruthBadge } from '../components/Primitives';

export function OverviewPage() {
  const snapshot = useSnapshot();
  const { summary, meta, scope } = snapshot;
  return (
    <>
      <PageHeader eyebrow="Vue globale" title="État du jeu exporté" description="Lecture déterministe des données de production, du contrat et des audits de Dungeon Draft.">
        <div className="version-card"><span>Version analysée</span><strong>{meta.project_name}</strong><code>{meta.source_game_commit.slice(0, 12)}</code></div>
      </PageHeader>

      <section className="metrics-grid" aria-label="Compteurs de contenu">
        <MetricCard label="Héros" value={summary.characters} tone="gold" />
        <MetricCard label="Disciplines" value={summary.disciplines} />
        <MetricCard label="Sorts" value={summary.spells} />
        <MetricCard label="Objets" value={summary.items} />
        <MetricCard label="Récompenses" value={summary.generic_rewards} />
        <MetricCard label="Pools" value={summary.reward_pools} />
      </section>

      <section className="metrics-grid" aria-label="Compteurs de la run">
        <MetricCard label="Runs de production" value={summary.production_run_count} tone="gold" />
        <MetricCard label="Runs de test" value={summary.test_run_count} />
        <MetricCard label="Salles en rencontre unique" value={summary.single_encounter_room_count} />
        <MetricCard label="Combats effectifs de production" value={summary.production_effective_combat_count} />
        <MetricCard label="Profils de vague de test" value={summary.test_authored_wave_profile_count} />
        <MetricCard label="Profils de test sélectionnés" value={summary.test_selected_wave_profile_count} />
      </section>

      <section className="metrics-grid" aria-label="Compteurs des rencontres">
        <MetricCard label="Rencontres" value={summary.encounters} />
        <MetricCard label="Ennemis" value={summary.enemies} />
        <MetricCard label="Sorts ennemis" value={summary.enemy_spells} />
        <MetricCard label="Profils IA" value={summary.ai_profiles} />
        <MetricCard label="Faits runtime" value={summary.runtime_facts} />
        <MetricCard label="Profils de vague bruts" value={summary.waves} detail="Collection JSON conservée" />
      </section>

      <div className="dashboard-grid">
        <Panel title="Santé du contrat" className="dashboard-card">
          <div className="status-list">
            <Link to="/audit"><StatusBadge status="conform" /><strong>{summary.contract_conform}</strong><span>cibles conformes</span></Link>
            <Link to="/audit"><StatusBadge status="difference" /><strong>{summary.contract_difference}</strong><span>écarts observés</span></Link>
            <Link to="/audit"><StatusBadge status="unknown" /><strong>{summary.contract_unknown}</strong><span>valeurs inconnues</span></Link>
            <Link to="/audit"><StatusBadge status="not_evaluated" /><strong>{summary.contract_not_evaluated}</strong><span>non évaluées</span></Link>
          </div>
        </Panel>

        <Panel title="Audits" className="dashboard-card">
          <div className="status-list">
            <Link to="/audit"><SeverityBadge severity="info" /><strong>{summary.audit_info}</strong><span>informations</span></Link>
            <Link to="/audit"><SeverityBadge severity="warning" /><strong>{summary.audit_warning}</strong><span>avertissements</span></Link>
            <Link to="/audit"><SeverityBadge severity="blocking" /><strong>{summary.audit_blocking}</strong><span>blocages</span></Link>
          </div>
        </Panel>

        <Panel title="Traçabilité" className="dashboard-card trace-card">
          <dl className="key-values">
            <div><dt>Généré le</dt><dd>{formatDate(meta.generated_at_utc)} UTC</dd></div>
            <div><dt>Schéma</dt><dd>{meta.schema_version}</dd></div>
            <div><dt>Générateur</dt><dd>{meta.generator_version}</dd></div>
            <div><dt>Godot</dt><dd>{meta.godot_version}</dd></div>
            <div><dt>Branche source</dt><dd><code>{meta.source_branch}</code></dd></div>
          </dl>
        </Panel>
      </div>

      <div className="two-column truth-grid">
        <Panel title="Faits runtime">
          <div className="truth-list">{snapshot.runtime_facts.map((fact) => (
            <article key={fact.key}>
              <header><code>{fact.key}</code><TruthBadge status={fact.truth_status} /></header>
              <p><strong>{formatValue(fact.value)}</strong> · {fact.notes}</p>
              <details><summary>Preuve observée</summary><p>{fact.evidence}</p><ul>{fact.source_paths.map((path) => <li key={path}><code>{path}</code></li>)}</ul></details>
            </article>
          ))}</div>
        </Panel>
        <Panel title="Décisions de conception">
          <div className="truth-list">{snapshot.contract.decisions.map((decision) => (
            <article key={decision.key}>
              <header><code>{decision.key}</code><TruthBadge status={decision.truth_status} /></header>
              <p><strong>{formatValue(decision.value)}</strong> · statut {decision.status}</p>
              <details><summary>Source et rationale</summary><p>{decision.source}</p><p>{decision.rationale}</p></details>
            </article>
          ))}</div>
        </Panel>
      </div>

      <section className="scope-grid" aria-label="Périmètre du snapshot">
        <Panel title="Domaines inclus">
          <ul className="tag-list">{scope.included_domains.map((domain) => <li key={domain}>{domain}</li>)}</ul>
        </Panel>
        <Panel title="Domaines reportés">
          <ul className="scope-list">{scope.deferred_domains.map((entry) => <li key={entry.domain}><strong>{entry.domain}</strong><span>{entry.reason}</span></li>)}</ul>
        </Panel>
        <Panel title="Domaines exclus">
          <ul className="scope-list">{scope.excluded_domains.map((entry) => <li key={`${entry.domain}-${entry.path}`}><strong>{entry.domain}</strong><span>{entry.reason}</span></li>)}</ul>
        </Panel>
      </section>
    </>
  );
}
