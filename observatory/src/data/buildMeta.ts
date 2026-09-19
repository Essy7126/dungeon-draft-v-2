export type FreshnessStatus = 'current' | 'stale' | 'diverged' | 'unknown';
export type PathClassification =
  | 'snapshot_affecting'
  | 'possibly_affecting'
  | 'non_affecting'
  | 'documentation_only';

export interface ClassifiedPath {
  path: string;
  classification: PathClassification;
}

export interface BuildMeta {
  checkout_commit: string;
  snapshot_source_commit: string;
  comparison_ref: string;
  non_observatory_changed_paths: string[];
  changed_path_classifications: ClassifiedPath[];
  freshness_status: FreshnessStatus;
  generated_at: string;
}

export const BUILD_META_SOURCE = 'generated/build_meta.json';

export const UNKNOWN_BUILD_META: BuildMeta = {
  checkout_commit: 'unknown',
  snapshot_source_commit: 'unknown',
  comparison_ref: 'none',
  non_observatory_changed_paths: [],
  changed_path_classifications: [],
  freshness_status: 'unknown',
  generated_at: '',
};

function isFreshnessStatus(value: unknown): value is FreshnessStatus {
  return ['current', 'stale', 'diverged', 'unknown'].includes(String(value));
}

function isPathClassification(value: unknown): value is PathClassification {
  return ['snapshot_affecting', 'possibly_affecting', 'non_affecting', 'documentation_only']
    .includes(String(value));
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
      changed_path_classifications: Array.isArray(candidate.changed_path_classifications)
        ? candidate.changed_path_classifications.flatMap((entry) => {
          if (!entry || typeof entry !== 'object') return [];
          const value = entry as Partial<ClassifiedPath>;
          return isPathClassification(value.classification)
            ? [{ path: String(value.path ?? ''), classification: value.classification }]
            : [];
        })
        : [],
      freshness_status: candidate.freshness_status,
      generated_at: String(candidate.generated_at ?? ''),
    };
  } catch {
    return UNKNOWN_BUILD_META;
  }
}
