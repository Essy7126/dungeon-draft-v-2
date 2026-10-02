export type LiveUpdateStatus = 'current' | 'updating' | 'update_failed' | 'unknown';

export interface LiveStatus {
  active_sha: string;
  detected_sha: string;
  last_success_at_utc: string;
  last_failure_at_utc: string;
  update_status: LiveUpdateStatus;
  message: string;
}

export const LIVE_STATUS_SOURCE = '__observatory/status.json';

export const UNAVAILABLE_LIVE_STATUS: LiveStatus = {
  active_sha: '',
  detected_sha: '',
  last_success_at_utc: '',
  last_failure_at_utc: '',
  update_status: 'unknown',
  message: 'Statut LAN indisponible dans ce mode de consultation.',
};

function isLiveUpdateStatus(value: unknown): value is LiveUpdateStatus {
  return ['current', 'updating', 'update_failed', 'unknown'].includes(String(value));
}

export async function loadLiveStatus(): Promise<LiveStatus> {
  try {
    const response = await fetch(new URL(LIVE_STATUS_SOURCE, document.baseURI), {
      cache: 'no-store',
    });
    if (!response.ok) return UNAVAILABLE_LIVE_STATUS;
    const value: unknown = await response.json();
    if (!value || typeof value !== 'object') return UNAVAILABLE_LIVE_STATUS;
    const candidate = value as Partial<LiveStatus>;
    if (!isLiveUpdateStatus(candidate.update_status)) return UNAVAILABLE_LIVE_STATUS;
    return {
      active_sha: String(candidate.active_sha ?? ''),
      detected_sha: String(candidate.detected_sha ?? ''),
      last_success_at_utc: String(candidate.last_success_at_utc ?? ''),
      last_failure_at_utc: String(candidate.last_failure_at_utc ?? ''),
      update_status: candidate.update_status,
      message: String(candidate.message ?? ''),
    };
  } catch {
    return UNAVAILABLE_LIVE_STATUS;
  }
}
