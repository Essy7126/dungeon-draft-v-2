export type FreshnessStatus = 'current' | 'stale' | 'diverged' | 'unknown';

export interface BuildMeta {
  checkout_commit: string;
  snapshot_source_commit: string;
  comparison_ref: string;
  non_observatory_changed_paths: string[];
  freshness_status: FreshnessStatus;
  generated_at: string;
}

export const BUILD_META_SOURCE = 'generated/build_meta.json';

export const UNKNOWN_BUILD_META: BuildMeta = {
  checkout_commit: 'unknown',
  snapshot_source_commit: 'unknown',
  comparison_ref: 'none',
  non_observatory_changed_paths: [],
  freshness_status: 'unknown',
  generated_at: '',
};

function isFreshnessStatus(value: unknown): value is FreshnessStatus {
  return ['current', 'stale', 'diverged', 'unknown'].includes(String(value));
}

export async function loadBuildMeta(): Promise<BuildMeta> {
  try {
    const response = await fetch(new URL(BUILD_META_SOURCE, document.baseURI));
    if (!response.ok) return UNKNOWN_BUILD_META;
    const value: unknown = await response.json();
    if (!value || typeof value !== 'object') return UNKNOWN_BUILD_META;
    const candidate = value as Partial<BuildMeta>;
    if (!isFreshnessStatus(candidate.freshness_status)) return UNKNOWN_BUILD_META;
    return {
      checkout_commit: String(candidate.checkout_commit ?? 'unknown'),
      snapshot_source_commit: String(candidate.snapshot_source_commit ?? 'unknown'),
      comparison_ref: String(candidate.comparison_ref ?? 'none'),
      non_observatory_changed_paths: Array.isArray(candidate.non_observatory_changed_paths)
        ? candidate.non_observatory_changed_paths.map(String)
        : [],
      freshness_status: candidate.freshness_status,
      generated_at: String(candidate.generated_at ?? ''),
    };
  } catch {
    return UNKNOWN_BUILD_META;
  }
}
