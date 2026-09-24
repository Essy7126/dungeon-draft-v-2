import assert from 'node:assert/strict';
import { mkdtemp, mkdir, rm, writeFile } from 'node:fs/promises';
import { createServer as createHttpServer } from 'node:http';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { createObservatoryServer } from '../observatory-lan-server.mjs';

const roots = [];

async function fixture() {
  const root = await mkdtemp(join(tmpdir(), 'observatory-lan-é-'));
  roots.push(root);
  const sha = 'a'.repeat(40);
  const release = join(root, 'releases', sha);
  await mkdir(join(release, 'dist', 'assets'), { recursive: true });
  await mkdir(join(release, 'dist', 'dossier'), { recursive: true });
  await mkdir(join(root, 'state'), { recursive: true });
  await writeFile(join(release, 'dist', 'index.html'), '<!doctype html><p>Observatory</p>');
  await writeFile(join(release, 'dist', 'données.json'), '{"unicode":true}\n');
  await writeFile(join(release, 'dist', 'assets', 'app-12345678.js'), 'export {};\n');
  await writeFile(join(release, 'dist', 'plain.js'), 'export {};\n');
  await writeFile(join(release, 'release.json'), `${JSON.stringify({ source_commit: sha })}\n`);
  await writeFile(join(root, 'state', 'active.json'), `${JSON.stringify({ active_sha: sha, release_path: release })}\n`);
  await writeFile(join(root, 'state', 'status.json'), `${JSON.stringify({
    active_sha: sha,
    detected_sha: 'b'.repeat(40),
    update_status: 'update_failed',
    message: 'Échec simulé.',
    last_success_at_utc: '2026-08-06T10:00:00.000Z',
    last_failure_at_utc: '2026-08-06T10:05:00.000Z',
    private_path: 'C:\\Users\\secret',
  })}\n`);
  const server = createObservatoryServer({ deployRoot: root });
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });
  const address = server.address();
  if (!address || typeof address === 'string') throw new Error('Adresse de test absente.');
  return { root, sha, server, base: `http://127.0.0.1:${address.port}` };
}

test.afterEach(async () => {
  await Promise.all(roots.splice(0).map((root) => rm(root, { recursive: true, force: true })));
});

test('sert uniquement la release active avec MIME et cache adaptés', async (t) => {
  const { server, base } = await fixture();
  t.after(() => server.close());

  const index = await fetch(`${base}/`);
  assert.equal(index.status, 200);
  assert.match(index.headers.get('content-type') ?? '', /^text\/html/);
  assert.equal(index.headers.get('cache-control'), 'no-store');
  assert.equal(index.headers.get('x-content-type-options'), 'nosniff');

  const immutable = await fetch(`${base}/assets/app-12345678.js`);
  assert.equal(immutable.status, 200);
  assert.match(immutable.headers.get('content-type') ?? '', /^text\/javascript/);
  assert.equal(immutable.headers.get('cache-control'), 'public, max-age=31536000, immutable');

  const plain = await fetch(`${base}/plain.js`);
  assert.equal(plain.headers.get('cache-control'), 'no-cache');
  const unicode = await fetch(`${base}/donn%C3%A9es.json`);
  assert.equal(unicode.status, 200);
  assert.deepEqual(await unicode.json(), { unicode: true });
});

test('expose healthz et un statut public sans fuite de chemin', async (t) => {
  const { server, base, sha } = await fixture();
  t.after(() => server.close());

  const health = await (await fetch(`${base}/__observatory/healthz`)).json();
  assert.equal(health.ok, true);
  assert.equal(health.active_sha, sha);
  assert.match(health.server_time, /^\d{4}-\d{2}-\d{2}T/);

  const response = await fetch(`${base}/__observatory/status.json`);
  const text = await response.text();
  const status = JSON.parse(text);
  assert.equal(status.update_status, 'update_failed');
  assert.equal(status.active_sha, sha);
  assert.equal(status.private_path, undefined);
  assert.doesNotMatch(text, /Users|secret/);
});

test('refuse traversée, listing, méthode d’écriture et fichier hors dist', async (t) => {
  const { server, base } = await fixture();
  t.after(() => server.close());

  assert.equal((await fetch(`${base}/dossier/`)).status, 404);
  assert.equal((await fetch(`${base}/..%2Frelease.json`)).status, 403);
  assert.equal((await fetch(`${base}/%2e%2e/release.json`)).status, 404);
  assert.equal((await fetch(`${base}/release.json`)).status, 404);
  assert.equal((await fetch(`${base}/`, { method: 'POST' })).status, 405);
  const head = await fetch(`${base}/`, { method: 'HEAD' });
  assert.equal(head.status, 200);
  assert.equal(await head.text(), '');
});

test('répond 503 sans release active et garde status disponible', async (t) => {
  const root = await mkdtemp(join(tmpdir(), 'observatory-empty-'));
  roots.push(root);
  await mkdir(join(root, 'state'), { recursive: true });
  const server = createObservatoryServer({ deployRoot: root });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => server.close());
  const address = server.address();
  if (!address || typeof address === 'string') throw new Error('Adresse absente.');
  const base = `http://127.0.0.1:${address.port}`;

  assert.equal((await fetch(`${base}/`)).status, 503);
  const status = await (await fetch(`${base}/__observatory/status.json`)).json();
  assert.equal(status.update_status, 'unknown');
});

test('signale un port déjà occupé', async (t) => {
  const occupied = createHttpServer();
  await new Promise((resolve) => occupied.listen(0, '127.0.0.1', resolve));
  t.after(() => occupied.close());
  const address = occupied.address();
  if (!address || typeof address === 'string') throw new Error('Adresse absente.');
  const second = createHttpServer();
  t.after(() => second.close());

  await assert.rejects(
    new Promise((resolve, reject) => {
      second.once('error', reject);
      second.listen(address.port, '127.0.0.1', resolve);
    }),
    { code: 'EADDRINUSE' },
  );
});
