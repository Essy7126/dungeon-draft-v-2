import { execFileSync } from 'node:child_process';
import { mkdir, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { afterEach, describe, expect, it } from 'vitest';

interface BuildMetaResult {
  checkout_commit: string;
  snapshot_source_commit: string;
  comparison_ref: string;
  non_observatory_changed_paths: string[];
  freshness_status: 'current' | 'stale' | 'diverged' | 'unknown';
  generated_at: string;
}

const createdDirectories: string[] = [];

function git(repository: string, ...args: string[]) {
  return execFileSync('git', ['-C', repository, ...args], {
    encoding: 'utf8',
    windowsHide: true,
  }).trim();
}

async function repositoryFixture() {
  const root = resolve('test-artifacts');
  await mkdir(root, { recursive: true });
  const repository = await mkdtemp(resolve(root, 'build-meta-'));
  createdDirectories.push(repository);
  git(repository, 'init', '-b', 'main');
  git(repository, 'config', 'user.email', 'observatory@example.invalid');
  git(repository, 'config', 'user.name', 'Observatory Test');
  await mkdir(resolve(repository, 'core'), { recursive: true });
  await mkdir(resolve(repository, 'observatory'), { recursive: true });
  await writeFile(resolve(repository, 'core', 'game.gd'), 'baseline\n', 'utf8');
  await writeFile(resolve(repository, 'observatory', 'README.md'), 'baseline\n', 'utf8');
  git(repository, 'add', 'core/game.gd', 'observatory/README.md');
  git(repository, 'commit', '-m', 'baseline');
  return { repository, sourceCommit: git(repository, 'rev-parse', 'HEAD') };
}

async function runGenerator(
  repository: string,
  sourceCommit: string,
  gitExecutable = 'git',
) {
  const snapshotPath = resolve(repository, 'snapshot.json');
  const outputPath = resolve(repository, 'build_meta.json');
  await writeFile(
    snapshotPath,
    `${JSON.stringify({ meta: { source_game_commit: sourceCommit } })}\n`,
    'utf8',
  );
  execFileSync(
    process.execPath,
    [
      resolve('scripts', 'generate-build-meta.mjs'),
      `--repo-root=${repository}`,
      `--snapshot=${snapshotPath}`,
      `--output=${outputPath}`,
    ],
    {
      env: { ...process.env, OBSERVATORY_GIT_EXECUTABLE: gitExecutable },
      windowsHide: true,
    },
  );
  return JSON.parse(await readFile(outputPath, 'utf8')) as BuildMetaResult;
}

afterEach(async () => {
  await Promise.all(createdDirectories.splice(0).map((path) => rm(path, {
    recursive: true,
    force: true,
  })));
});

describe('generate-build-meta', () => {
  it('reste current lorsque seuls des chemins Observatory diffèrent', async () => {
    const { repository, sourceCommit } = await repositoryFixture();
    await writeFile(resolve(repository, 'observatory', 'README.md'), 'observatory only\n');
    git(repository, 'add', 'observatory/README.md');
    git(repository, 'commit', '-m', 'observatory');

    const result = await runGenerator(repository, sourceCommit);

    expect(result.freshness_status).toBe('current');
    expect(result.non_observatory_changed_paths).toEqual([]);
  });

  it('devient stale lorsqu’un chemin de jeu diffère', async () => {
    const { repository, sourceCommit } = await repositoryFixture();
    await writeFile(resolve(repository, 'core', 'game.gd'), 'changed gameplay\n');
    git(repository, 'add', 'core/game.gd');
    git(repository, 'commit', '-m', 'gameplay');

    const result = await runGenerator(repository, sourceCommit);

    expect(result.freshness_status).toBe('stale');
    expect(result.non_observatory_changed_paths).toEqual(['core/game.gd']);
  });

  it('devient unknown lorsque Git est indisponible', async () => {
    const { repository, sourceCommit } = await repositoryFixture();

    const result = await runGenerator(repository, sourceCommit, 'git-observatory-missing');

    expect(result.freshness_status).toBe('unknown');
    expect(result.checkout_commit).toBe('unknown');
  });
});
