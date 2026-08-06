import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { FreshnessIndicator } from '../components/FreshnessIndicator';
import { BuildMetaProvider } from '../context/BuildMetaContext';
import { SnapshotProvider } from '../context/SnapshotContext';
import type { BuildMeta } from '../data/buildMeta';
import { snapshotFixture } from './fixture';

function renderFreshness(meta: BuildMeta) {
  return render(
    <SnapshotProvider value={snapshotFixture}>
      <BuildMetaProvider value={meta}>
        <FreshnessIndicator />
      </BuildMetaProvider>
    </SnapshotProvider>,
  );
}

const baseMeta: BuildMeta = {
  checkout_commit: snapshotFixture.meta.source_game_commit,
  snapshot_source_commit: snapshotFixture.meta.source_game_commit,
  comparison_ref: 'HEAD + origin/main',
  non_observatory_changed_paths: [],
  changed_path_classifications: [],
  freshness_status: 'current',
  generated_at: '2026-08-06T10:00:00Z',
};

describe('indicateur global de fraîcheur', () => {
  it('affiche current et le SHA source', () => {
    renderFreshness(baseMeta);
    expect(screen.getByText('Snapshot courant')).toBeInTheDocument();
    expect(screen.getByText(snapshotFixture.meta.source_game_commit.slice(0, 12))).toBeInTheDocument();
  });

  it('détaille stale et ses chemins de jeu', async () => {
    const user = userEvent.setup();
    renderFreshness({
      ...baseMeta,
      freshness_status: 'stale',
      non_observatory_changed_paths: ['core/game.gd', 'battle/battle.gd'],
    });
    await user.click(screen.getByText('Snapshot en retard'));
    expect(screen.getByText(/2 chemins hors Observatory modifiés/)).toBeInTheDocument();
    expect(screen.getByText('core/game.gd')).toBeInTheDocument();
  });

  it('affiche unknown sans prétendre connaître les changements', () => {
    renderFreshness({ ...baseMeta, freshness_status: 'unknown', checkout_commit: 'unknown' });
    expect(screen.getByText('Fraîcheur inconnue')).toBeInTheDocument();
    expect(screen.getByText(/références nécessaires est indisponible/)).toBeInTheDocument();
  });
});
