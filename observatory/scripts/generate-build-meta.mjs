import { execFileSync } from 'node:child_process';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const defaultProjectRoot = resolve(here, '..');
const OBSERVATORY_PREFIXES = [
  '.github/workflows/ci.yml',
  '.github/workflows/observatory-ci.yml',
  'observatory/',
  'docs/observatory/',
  'tools/observatory/',
  'test/unit/observatory/',
];
const SNAPSHOT_AFFECTING_PREFIXES = [
  'battle/', 'characters/', 'core/', 'data/', 'hub/', 'traits/', 'ui/', 'units/',
];
const POSSIBLY_AFFECTING_PREFIXES = ['addons/', 'asset/', 'audio/', 'cinematics/', 'scenes/'];

function option(name, fallback) {
  const prefix = `--${name}=`;
  const argument = process.argv.slice(2).find((value) => value.startsWith(prefix));
  return argument ? resolve(argument.slice(prefix.length)) : fallback;
}

function git(repoRoot, args, executable = 'git') {
  const safeRepoRoot = repoRoot.replaceAll('\\', '/');
  return execFileSync(
    executable,
    [
      '-c',
      `safe.directory=${safeRepoRoot}`,
      '--no-optional-locks',
      '-C',
      repoRoot,
      ...args,
    ],
    {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
      windowsHide: true,
    },
  ).trim();
}

function gitBuffer(repoRoot, args, executable = 'git') {
  const safeRepoRoot = repoRoot.replaceAll('\\', '/');
  return execFileSync(
    executable,
    ['-c', `safe.directory=${safeRepoRoot}`, '--no-optional-locks', '-C', repoRoot, ...args],
    { encoding: 'buffer', stdio: ['ignore', 'pipe', 'pipe'], windowsHide: true },
  );
}

function refExists(repoRoot, ref, executable) {
  try {
    git(repoRoot, ['rev-parse', '--verify', `${ref}^{commit}`], executable);
    return true;
  } catch {
    return false;
  }
}

function hasMergeBase(repoRoot, first, second, executable) {
  try {
    return git(repoRoot, ['merge-base', first, second], executable).length > 0;
  } catch {
    return false;
  }
}

function changedPaths(repoRoot, first, second, executable) {
  const output = gitBuffer(
    repoRoot,
    ['-c', 'core.quotepath=false', 'diff', '--name-only', '-z', '--no-renames', first, second, '--'],
    executable,
  );
  return output.toString('utf8').split('\0').filter(Boolean)
    .map((value) => value.replaceAll('\\', '/'));
}

async function manifestRootPaths(manifestPath) {
  if (!manifestPath) return new Set();
  try {
    const manifest = JSON.parse(await readFile(manifestPath, 'utf8'));
    const roots = [
      ...(Array.isArray(manifest.run_roots) ? manifest.run_roots : []),
      ...(Array.isArray(manifest.production_roots) ? manifest.production_roots : []),
    ];
    return new Set(roots.map((root) => String(root?.path ?? '').replace(/^res:\/\//u, ''))
      .filter(Boolean));
  } catch {
    return new Set();
  }
}

function classifyPath(path, roots) {
  if (path.startsWith('docs/')) return 'documentation_only';
  if (OBSERVATORY_PREFIXES.some((prefix) => path.startsWith(prefix))) return 'non_affecting';
  if (roots.has(path) || SNAPSHOT_AFFECTING_PREFIXES.some((prefix) => path.startsWith(prefix))) {
    return 'snapshot_affecting';
  }
  if (path === 'project.godot' || POSSIBLY_AFFECTING_PREFIXES.some((prefix) => path.startsWith(prefix))) {
    return 'possibly_affecting';
  }
  return 'non_affecting';
}

export async function computeBuildMeta({
  repoRoot,
  snapshotPath,
  manifestPath,
  gitExecutable = 'git',
}) {
  const generatedAt = new Date().toISOString();
  let snapshotSourceCommit = 'unknown';
  const roots = await manifestRootPaths(manifestPath);
  try {
    const snapshot = JSON.parse(await readFile(snapshotPath, 'utf8'));
    snapshotSourceCommit = snapshot?.meta?.source_game_commit ?? 'unknown';
  } catch {
    return {
      checkout_commit: 'unknown',
      snapshot_source_commit: snapshotSourceCommit,
      comparison_ref: 'none',
      non_observatory_changed_paths: [],
      changed_path_classifications: [],
      freshness_status: 'unknown',
      generated_at: generatedAt,
    };
  }

  try {
    const checkoutCommit = git(repoRoot, ['rev-parse', 'HEAD'], gitExecutable);
    if (!refExists(repoRoot, snapshotSourceCommit, gitExecutable)) {
      throw new Error('Snapshot commit unavailable');
    }
    const comparisonRefs = ['HEAD'];
    if (refExists(repoRoot, 'origin/main', gitExecutable)) {
      comparisonRefs.push('origin/main');
    }
    const allPaths = new Set();
    let diverged = false;
    for (const reference of comparisonRefs) {
      if (!hasMergeBase(repoRoot, snapshotSourceCommit, reference, gitExecutable)) {
        diverged = true;
        continue;
      }
      for (const path of changedPaths(
        repoRoot,
        snapshotSourceCommit,
        reference,
        gitExecutable,
      )) {
        allPaths.add(path);
      }
    }
    const nonObservatoryPaths = [...allPaths]
      .filter((path) => !OBSERVATORY_PREFIXES.some((prefix) => path.startsWith(prefix)))
      .sort();
    const changedPathClassifications = [...allPaths].sort().map((path) => ({
      path,
      classification: classifyPath(path, roots),
    }));
    return {
      checkout_commit: checkoutCommit,
      snapshot_source_commit: snapshotSourceCommit,
      comparison_ref: comparisonRefs.join(' + '),
      non_observatory_changed_paths: nonObservatoryPaths,
      changed_path_classifications: changedPathClassifications,
      freshness_status: diverged
        ? 'diverged'
        : nonObservatoryPaths.length > 0
          ? 'stale'
          : 'current',
      generated_at: generatedAt,
    };
  } catch {
    return {
      checkout_commit: 'unknown',
      snapshot_source_commit: snapshotSourceCommit,
      comparison_ref: 'none',
      non_observatory_changed_paths: [],
      changed_path_classifications: [],
      freshness_status: 'unknown',
      generated_at: generatedAt,
    };
  }
}

export async function main() {
  const projectRoot = option('project-root', defaultProjectRoot);
  const repoRoot = option('repo-root', resolve(projectRoot, '..'));
  const snapshotPath = option(
    'snapshot',
    resolve(projectRoot, 'public', 'data', 'latest.json'),
  );
  const outputPath = option(
    'output',
    resolve(projectRoot, 'public', 'generated', 'build_meta.json'),
  );
  const manifestPath = option(
    'manifest',
    resolve(projectRoot, '..', 'docs', 'observatory', 'data_source_manifest.json'),
  );
  const result = await computeBuildMeta({
    repoRoot,
    snapshotPath,
    manifestPath,
    gitExecutable: process.env.OBSERVATORY_GIT_EXECUTABLE || 'git',
  });
  await mkdir(dirname(outputPath), { recursive: true });
  await writeFile(outputPath, `${JSON.stringify(result, null, 2)}\n`, 'utf8');
  console.log(`Métadonnées de fraîcheur : ${result.freshness_status}.`);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  await main();
}
