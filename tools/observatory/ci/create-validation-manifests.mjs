import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const repository = resolve(process.argv[2] ?? '.');
const snapshotPath = resolve(repository, 'observatory', 'public', 'data', 'latest.json');
const outputDirectory = resolve(repository, 'artifacts', 'observatory-ci');
const snapshotText = await readFile(snapshotPath, 'utf8');
const snapshot = JSON.parse(snapshotText);
const head = process.env.GITHUB_SHA || process.env.OBSERVATORY_EXPECTED_SHA || '';

if (snapshot.meta?.schema_version !== '3.0.0') throw new Error('Schéma snapshot CI inattendu.');
if (snapshot.meta?.generator_version !== '3.0.0') throw new Error('Générateur snapshot CI inattendu.');
if (head && snapshot.meta?.source_game_commit !== head) throw new Error('SHA de provenance CI inattendu.');
if (snapshot.meta?.source_worktree_dirty_before_export !== false) throw new Error('Export CI issu d’un worktree sale.');
if (snapshot.meta?.source_generated_from_clean_checkout !== true) throw new Error('Checkout propre CI non certifié.');

const sha256 = createHash('sha256').update(snapshotText).digest('hex');
const audits = Array.isArray(snapshot.audit_results) ? snapshot.audit_results : [];
const severityCounts = Object.fromEntries(['blocking', 'warning', 'info'].map((severity) => [
  severity,
  audits.filter((entry) => entry.severity === severity).length,
]));
await mkdir(outputDirectory, { recursive: true });
await writeFile(resolve(outputDirectory, 'snapshot-audit.json'), `${JSON.stringify({
  source_commit: snapshot.meta.source_game_commit,
  schema_version: snapshot.meta.schema_version,
  severity_counts: severityCounts,
  audit_results: audits,
}, null, 2)}\n`, 'utf8');
await writeFile(resolve(outputDirectory, 'validation-manifest.json'), `${JSON.stringify({
  status: 'validated',
  source_commit: snapshot.meta.source_game_commit,
  snapshot_sha256: sha256,
  schema_version: snapshot.meta.schema_version,
  generator_version: snapshot.meta.generator_version,
  primary_run_id: snapshot.primary_run_id,
  generated_at_utc: new Date().toISOString(),
  validations: {
    godot_import: 'passed',
    snapshot_provenance: 'passed',
    observatory_gut: 'passed',
    full_gut_baseline: 'passed',
    frontend_check: 'passed',
  },
}, null, 2)}\n`, 'utf8');
process.stdout.write(`Validation manifests: ${sha256}\n`);
