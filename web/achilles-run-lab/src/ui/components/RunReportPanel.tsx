import type { RunReport } from '../../domain/model/types';

interface RunReportPanelProps {
  report: RunReport;
}

export function RunReportPanel({ report }: RunReportPanelProps) {
  return (
    <div className="report-panel" data-testid="run-report">
      <div><span>Seed</span><strong>{report.seed}</strong></div>
      <div><span>Résultat</span><strong>{report.result}</strong></div>
      <div><span>Salle atteinte</span><strong>{report.roomReached}</strong></div>
      <div><span>Rounds</span><strong>{report.rounds}</strong></div>
      <div><span>Dégâts infligés</span><strong>{report.damageDealt}</strong></div>
      <div><span>Dégâts subis</span><strong>{report.damageTaken}</strong></div>
      <div><span>PA dépensés / perdus</span><strong>{report.apSpent} / {report.apUnused}</strong></div>
      <div><span>PM dépensés / perdus</span><strong>{report.mpSpent} / {report.mpUnused}</strong></div>
      <div><span>PV restants</span><strong>{report.remainingHp}</strong></div>
      <div><span>Backend</span><strong>{report.rendererBackend}</strong></div>
      <div><span>Commandes</span><strong>{report.commands.length}</strong></div>
      <div><span>Dernier hash</span><strong className="mono">{report.stateHashes.at(-1) ?? '—'}</strong></div>
    </div>
  );
}
