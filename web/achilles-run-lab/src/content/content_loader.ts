import { createDefaultConfig } from './defaults';
import { formatSchemaErrors, RunLabConfigSchema, type RunLabConfig } from './schemas';

export type ContentLoadResult =
  | { ok: true; config: RunLabConfig }
  | { ok: false; errors: string[] };

export function validateConfig(input: unknown): ContentLoadResult {
  const result = RunLabConfigSchema.safeParse(input);
  if (!result.success) return { ok: false, errors: formatSchemaErrors(result.error) };
  return { ok: true, config: result.data };
}

export function loadDefaultConfig(seed = 12345): RunLabConfig {
  const result = validateConfig(createDefaultConfig(seed));
  if (!result.ok) throw new Error(`Contenu par défaut invalide:\n${result.errors.join('\n')}`);
  return result.config;
}

export function importConfigJson(json: string): ContentLoadResult {
  try {
    return validateConfig(JSON.parse(json) as unknown);
  } catch (error) {
    return { ok: false, errors: [`$: JSON invalide — ${error instanceof Error ? error.message : String(error)}`] };
  }
}
