import Ajv2020, { type ErrorObject, type ValidateFunction } from 'ajv/dist/2020';
import addFormats from 'ajv-formats';
import type { Snapshot } from '../types';

export interface ValidationIssue {
  path: string;
  keyword: string;
  message: string;
}

export interface SnapshotValidation {
  valid: boolean;
  snapshot?: Snapshot;
  issues: ValidationIssue[];
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function toIssue(error: ErrorObject): ValidationIssue {
  return {
    path: error.instancePath || '/',
    keyword: error.keyword,
    message: error.message ?? 'Valeur invalide',
  };
}

export function compileSnapshotValidator(schema: unknown): ValidateFunction<Snapshot> {
  if (!isRecord(schema)) {
    throw new Error('Le schéma public n’est pas un objet JSON.');
  }
  const ajv = new Ajv2020({ allErrors: true, strict: true });
  addFormats(ajv);
  if (!ajv.validateSchema(schema)) {
    throw new Error('Le schéma public est incompatible avec Ajv 2020-12.');
  }
  return ajv.compile<Snapshot>(schema);
}

export function validateSnapshot(data: unknown, validator: ValidateFunction<Snapshot>): SnapshotValidation {
  if (validator(data)) {
    return { valid: true, snapshot: data, issues: [] };
  }
  return {
    valid: false,
    issues: (validator.errors ?? []).map(toIssue),
  };
}
