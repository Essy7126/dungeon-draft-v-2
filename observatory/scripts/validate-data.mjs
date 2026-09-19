import { readFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import Ajv2020 from 'ajv/dist/2020.js';
import addFormats from 'ajv-formats';

const here = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(here, '..');
const schemaPath = resolve(projectRoot, '..', 'tools', 'observatory', 'schemas', 'observatory_snapshot.schema.json');
const snapshotPath = resolve(projectRoot, 'public', 'data', 'latest.json');

const [schemaText, snapshotText] = await Promise.all([
  readFile(schemaPath, 'utf8'),
  readFile(snapshotPath, 'utf8'),
]);

let schema;
let snapshot;
try {
  schema = JSON.parse(schemaText);
  snapshot = JSON.parse(snapshotText);
} catch (error) {
  console.error('JSON invalide:', error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
}

if (!process.exitCode) {
  const ajv = new Ajv2020({ allErrors: true, strict: true });
  addFormats(ajv);
  const validate = ajv.compile(schema);
  if (!validate(snapshot)) {
    console.error(`Snapshot invalide (${validate.errors?.length ?? 0} erreur(s)).`);
    for (const error of (validate.errors ?? []).slice(0, 20)) {
      console.error(`${error.instancePath || '/'} ${error.message ?? 'invalide'}`);
    }
    process.exitCode = 1;
  } else if (
    snapshot.meta?.source_git_available !== true
    || snapshot.meta?.source_worktree_dirty_before_export !== false
    || snapshot.meta?.source_generated_from_clean_checkout !== true
    || !/^[0-9a-f]{40}$/u.test(snapshot.meta?.source_game_commit ?? '')
  ) {
    console.error('Snapshot release refusé : provenance Git propre non certifiée.');
    process.exitCode = 1;
  } else {
    const bytes = Buffer.byteLength(snapshotText, 'utf8');
    console.log(`Snapshot valide : ${bytes} octets.`);
  }
}
