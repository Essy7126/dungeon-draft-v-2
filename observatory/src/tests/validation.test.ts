import { describe, expect, it } from 'vitest';
import { compileSnapshotValidator, validateSnapshot } from '../data/validation';

const minimalSchema: unknown = {
  $schema: 'https://json-schema.org/draft/2020-12/schema',
  type: 'object',
  required: ['meta', 'characters'],
  properties: {
    meta: { type: 'object' },
    characters: { type: 'array' },
  },
};

describe('validation Ajv', () => {
  it('conserve unknown jusqu’à validation', () => {
    const raw: unknown = { meta: {}, characters: [] };
    const result = validateSnapshot(raw, compileSnapshotValidator(minimalSchema));
    expect(result.valid).toBe(true);
    expect(result.snapshot).toBe(raw);
  });

  it('retourne des erreurs structurées', () => {
    const raw: unknown = { meta: {} };
    const result = validateSnapshot(raw, compileSnapshotValidator(minimalSchema));
    expect(result.valid).toBe(false);
    expect(result.issues[0]).toMatchObject({ path: '/', keyword: 'required' });
  });

  it('refuse un schéma qui n’est pas un objet', () => {
    expect(() => compileSnapshotValidator('schema')).toThrow(/objet JSON/);
  });
});
