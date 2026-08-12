import type { RunReport } from '../../domain/model/types';

interface MenuScreenProps {
  seed: number;
  onSeed: (seed: number) => void;
  onNewRun: () => void;
  onContinue: () => void;
  onLab: () => void;
  onClear: () => void;
  onExportReport: () => void;
  saveMessage: string | null;
  lastReport: RunReport | null;
}

export function MenuScreen(props: MenuScreenProps) {
  return (
    <main className="menu-screen">
      <section className="title-block">
        <p className="eyebrow">DUNGEON DRAFT · LABORATOIRE WEB</p>
        <h1>Achilles<br /><span>Web Run Lab</span></h1>
        <p className="intro">Une expédition tactique solo en cinq salles. Six PA, trois PM, une lance — et aucune seconde tentative offerte par l’arène.</p>
        <p className="experimental-note">EXPÉRIMENTAL · ces valeurs ne constituent pas une baseline de production.</p>
      </section>
      <section className="menu-panel" aria-label="Menu principal">
        <label className="seed-field">Seed de la run
          <input type="number" min="1" value={props.seed} onChange={(event) => props.onSeed(Math.max(1, Number(event.target.value) || 1))} data-testid="seed-input" />
        </label>
        <button type="button" className="primary" onClick={props.onNewRun} data-testid="new-run">Nouvelle run <span>→</span></button>
        <button type="button" onClick={props.onContinue} data-testid="continue-run">Continuer <span>↗</span></button>
        <button type="button" onClick={props.onLab} data-testid="open-lab">Run Lab <span>⌁</span></button>
        <div className="menu-secondary">
          <button type="button" onClick={props.onClear}>Effacer la sauvegarde</button>
          <button type="button" onClick={props.onExportReport}>Exporter le dernier rapport</button>
        </div>
        {props.saveMessage !== null && <p className="system-message" role="status">{props.saveMessage}</p>}
        {props.lastReport !== null && <p className="last-run">Dernière run · {props.lastReport.result} · salle {props.lastReport.roomReached} · seed {props.lastReport.seed}</p>}
      </section>
      <footer>Prototype local autonome · le projet Godot principal reste inchangé</footer>
      <div className="desktop-warning">Cette candidate cible les écrans desktop de 1280 px et plus.</div>
    </main>
  );
}
