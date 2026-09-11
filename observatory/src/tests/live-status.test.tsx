import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { LiveStatusIndicator } from '../components/LiveStatusIndicator';
import { loadLiveStatus, UNAVAILABLE_LIVE_STATUS } from '../data/liveStatus';

afterEach(() => vi.unstubAllGlobals());

describe('statut live Observatory', () => {
  it('utilise un fallback explicite lorsque l’endpoint est absent', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new Error('absent')));

    await expect(loadLiveStatus()).resolves.toEqual(UNAVAILABLE_LIVE_STATUS);
    render(<LiveStatusIndicator />);
    expect(await screen.findByText('Statut LAN indisponible')).toBeInTheDocument();
  });

  it('signale une mise à jour échouée sans masquer la release active', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        active_sha: 'a'.repeat(40),
        detected_sha: 'b'.repeat(40),
        last_success_at_utc: '2026-08-06T10:00:00.000Z',
        last_failure_at_utc: '2026-08-06T10:05:00.000Z',
        update_status: 'update_failed',
        message: 'Validation npm échouée.',
      }),
    }));

    const user = userEvent.setup();
    render(<LiveStatusIndicator />);
    await waitFor(() => expect(screen.getByText('Mise à jour LAN échouée')).toBeInTheDocument());
    await user.click(screen.getByText('Mise à jour LAN échouée'));
    expect(screen.getByText(/Release active/)).toHaveTextContent('aaaaaaaaaaaa');
    expect(screen.getByText(/Commit détecté/)).toHaveTextContent('bbbbbbbbbbbb');
    expect(screen.getByText('Validation npm échouée.')).toBeInTheDocument();
  });
});
