import { useEffect, useState } from 'react';
import {
  loadLiveStatus,
  UNAVAILABLE_LIVE_STATUS,
  type LiveStatus,
} from '../data/liveStatus';

const labels = {
  current: 'LAN à jour',
  updating: 'Mise à jour LAN',
  update_failed: 'Mise à jour LAN échouée',
  unknown: 'Statut LAN indisponible',
} as const;

export function LiveStatusIndicator() {
  const [status, setStatus] = useState<LiveStatus>(UNAVAILABLE_LIVE_STATUS);

  useEffect(() => {
    let active = true;
    const refresh = () => void loadLiveStatus().then((value) => {
      if (active) setStatus(value);
    });
    refresh();
    const timer = window.setInterval(refresh, 30_000);
    return () => {
      active = false;
      window.clearInterval(timer);
    };
  }, []);

  return (
    <details className={`live-status live-status--${status.update_status}`}>
      <summary>
        <span className="status-dot" aria-hidden="true" />
        <span>{labels[status.update_status]}</span>
      </summary>
      <div className="live-status__panel">
        <p>{status.message}</p>
        {status.active_sha && <p>Release active : <code>{status.active_sha.slice(0, 12)}</code></p>}
        {status.detected_sha && status.detected_sha !== status.active_sha && (
          <p>Commit détecté : <code>{status.detected_sha.slice(0, 12)}</code></p>
        )}
        {status.last_success_at_utc && <p>Dernier succès : <time dateTime={status.last_success_at_utc}>{status.last_success_at_utc}</time></p>}
        {status.last_failure_at_utc && <p>Dernier échec : <time dateTime={status.last_failure_at_utc}>{status.last_failure_at_utc}</time></p>}
      </div>
    </details>
  );
}
