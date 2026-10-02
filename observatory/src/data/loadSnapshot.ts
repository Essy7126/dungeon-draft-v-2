import type { Snapshot } from '../types';
import { compileSnapshotValidator, validateSnapshot, type ValidationIssue } from './validation';

export type SnapshotErrorKind = 'network' | 'http' | 'json' | 'schema' | 'incompatible';

export class SnapshotLoadError extends Error {
  readonly kind: SnapshotErrorKind;
  readonly issues: ValidationIssue[];
  readonly source: string;

  constructor(kind: SnapshotErrorKind, message: string, source: string, issues: ValidationIssue[] = []) {
    super(message);
    this.name = 'SnapshotLoadError';
    this.kind = kind;
    this.source = source;
    this.issues = issues;
  }
}

export const SNAPSHOT_SOURCE = 'public/data/latest.json';
export const SCHEMA_SOURCE = 'public/generated/observatory_snapshot.schema.json';

async function fetchJson(relativePath: string): Promise<unknown> {
  const url = new URL(relativePath.replace(/^public\//, ''), document.baseURI);
  let response: Response;
  try {
    response = await fetch(url);
  } catch {
    throw new SnapshotLoadError('network', 'La source locale n’a pas pu être chargée.', relativePath);
  }
  if (!response.ok) {
    throw new SnapshotLoadError('http', `La source locale a répondu avec le statut HTTP ${response.status}.`, relativePath);
  }
  try {
    const parsed: unknown = await response.json();
    return parsed;
  } catch {
    throw new SnapshotLoadError('json', 'La source locale ne contient pas un JSON valide.', relativePath);
  }
}

export async function loadSnapshot(): Promise<Snapshot> {
  const [rawSnapshot, rawSchema] = await Promise.all([
    fetchJson(SNAPSHOT_SOURCE),
    fetchJson(SCHEMA_SOURCE),
  ]);

  let validator;
  try {
    validator = compileSnapshotValidator(rawSchema);
  } catch (error) {
    throw new SnapshotLoadError(
      'schema',
      error instanceof Error ? error.message : 'Le schéma public est invalide.',
      SCHEMA_SOURCE,
    );
  }

  const result = validateSnapshot(rawSnapshot, validator);
  if (!result.valid || !result.snapshot) {
    throw new SnapshotLoadError(
      'incompatible',
      'Le snapshot est incompatible avec le schéma Observatory courant.',
      SNAPSHOT_SOURCE,
      result.issues,
    );
  }
  return result.snapshot;
}
