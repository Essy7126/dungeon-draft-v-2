import type { RunReport } from '../../domain/model/types';
import { RunReportPanel } from '../components/RunReportPanel';

interface EndScreenProps {
  kind: 'victory' | 'defeat' | 'report';
  report: RunReport;
  onSameSeed: () => void;
  onNewSeed: () => void;
  onMenu: () => void;
  onReport: () => void;
  onExport: () => void;
}

export function EndScreen(props: EndScreenProps) {
  const victory = props.kind === 'victory' || (props.kind === 'report' && props.report.result === 'WON');
  return (
    <div className={`overlay-screen end-screen ${victory ? 'won' : 'lost'}`} data-testid={`${props.kind}-screen`}>
      <div className="overlay-card end-card">
        <p className="eyebrow">RUN TERMINÉE · SEED {props.report.seed}</p>
        <h2>{props.kind === 'report' ? 'Rapport de run' : victory ? 'Victoire' : 'Défaite'}</h2>
        <p>{victory ? 'La Station du Centurion est tombée. La candidate a parcouru toutes les salles actives.' : 'Achilles est tombé dans l’arène. La seed reste disponible pour une nouvelle tentative.'}</p>
        <RunReportPanel report={props.report} />
        <div className="end-actions">
          <button type="button" className="primary" onClick={props.onSameSeed}>Recommencer · même seed</button>
          <button type="button" onClick={props.onNewSeed}>Nouvelle seed</button>
          {props.kind !== 'report' && <button type="button" onClick={props.onReport}>Rapport détaillé</button>}
          <button type="button" onClick={props.onExport}>Exporter JSON</button>
          <button type="button" onClick={props.onMenu}>Revenir au menu</button>
        </div>
      </div>
    </div>
  );
}
