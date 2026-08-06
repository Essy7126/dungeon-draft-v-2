import { useCallback, useEffect, useState } from 'react';
import { HashRouter, Redirect, Route, Switch } from 'react-router-dom';
import { AppShell } from './components/AppShell';
import { DataErrorPage, LoadingState } from './components/DataStates';
import { BuildMetaProvider } from './context/BuildMetaContext';
import { SnapshotProvider, useSnapshot } from './context/SnapshotContext';
import { loadBuildMeta, type BuildMeta } from './data/buildMeta';
import { loadSnapshot } from './data/loadSnapshot';
import type { Snapshot } from './types';
import { AuditPage } from './pages/AuditPage';
import { CharacterDetailPage } from './pages/CharacterDetailPage';
import { CharactersPage } from './pages/CharactersPage';
import { DisciplineDetailPage } from './pages/DisciplineDetailPage';
import { DisciplinesPage } from './pages/DisciplinesPage';
import { ItemDetailPage } from './pages/ItemDetailPage';
import { ItemsPage } from './pages/ItemsPage';
import { NotFoundPage } from './pages/NotFoundPage';
import { OverviewPage } from './pages/OverviewPage';
import { RewardsPage } from './pages/RewardsPage';
import { SpellDetailPage } from './pages/SpellDetailPage';
import { SpellsPage } from './pages/SpellsPage';
import { EnemiesPage } from './pages/EnemiesPage';
import { EnemyDetailPage } from './pages/EnemyDetailPage';
import { RoomDetailPage } from './pages/RoomDetailPage';
import { RunPage } from './pages/RunPage';
import { RunsPage } from './pages/RunsPage';

type LoadState =
  | { kind: 'loading' }
  | { kind: 'success'; snapshot: Snapshot; buildMeta: BuildMeta }
  | { kind: 'error'; error: unknown };

function PrimaryRunRedirect() {
  const snapshot = useSnapshot();
  return <Redirect to={`/runs/${snapshot.primary_run_id}`} />;
}

export default function App() {
  const [state, setState] = useState<LoadState>({ kind: 'loading' });
  const reload = useCallback(() => {
    setState({ kind: 'loading' });
    void Promise.all([loadSnapshot(), loadBuildMeta()]).then(
      ([snapshot, buildMeta]) => setState({ kind: 'success', snapshot, buildMeta }),
      (error: unknown) => setState({ kind: 'error', error }),
    );
  }, []);

  useEffect(() => reload(), [reload]);

  if (state.kind === 'loading') return <main className="standalone-main"><LoadingState /></main>;
  if (state.kind === 'error') return <main className="standalone-main"><DataErrorPage error={state.error} onRetry={reload} /></main>;

  return (
    <SnapshotProvider value={state.snapshot}>
      <BuildMetaProvider value={state.buildMeta}>
        <HashRouter>
          <AppShell>
            <Switch>
              <Route exact path="/"><Redirect to="/overview" /></Route>
              <Route exact path="/overview"><OverviewPage /></Route>
              <Route exact path="/run"><PrimaryRunRedirect /></Route>
              <Route exact path="/runs"><RunsPage /></Route>
              <Route path="/runs/:runId"><RunPage /></Route>
              <Route path="/rooms/:roomId"><RoomDetailPage /></Route>
              <Route exact path="/enemies"><EnemiesPage /></Route>
              <Route path="/enemies/:enemyId"><EnemyDetailPage /></Route>
              <Route exact path="/characters"><CharactersPage /></Route>
              <Route path="/characters/:characterId"><CharacterDetailPage /></Route>
              <Route exact path="/spells"><SpellsPage /></Route>
              <Route path="/spells/:spellId"><SpellDetailPage /></Route>
              <Route exact path="/disciplines"><DisciplinesPage /></Route>
              <Route path="/disciplines/:disciplineId"><DisciplineDetailPage /></Route>
              <Route exact path="/items"><ItemsPage /></Route>
              <Route path="/items/:itemId"><ItemDetailPage /></Route>
              <Route exact path="/rewards"><RewardsPage /></Route>
              <Route exact path="/audit"><AuditPage /></Route>
              <Route><NotFoundPage /></Route>
            </Switch>
          </AppShell>
        </HashRouter>
      </BuildMetaProvider>
    </SnapshotProvider>
  );
}
