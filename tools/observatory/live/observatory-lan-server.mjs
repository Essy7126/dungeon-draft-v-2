import { createReadStream, existsSync, readFileSync, realpathSync, statSync } from 'node:fs';
import { createServer } from 'node:http';
import { extname, isAbsolute, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const MIME_TYPES = new Map([
  ['.css', 'text/css; charset=utf-8'],
  ['.html', 'text/html; charset=utf-8'],
  ['.ico', 'image/x-icon'],
  ['.json', 'application/json; charset=utf-8'],
  ['.js', 'text/javascript; charset=utf-8'],
  ['.map', 'application/json; charset=utf-8'],
  ['.png', 'image/png'],
  ['.svg', 'image/svg+xml; charset=utf-8'],
  ['.webp', 'image/webp'],
  ['.woff2', 'font/woff2'],
]);

function argument(name, fallback) {
  const prefix = `--${name}=`;
  const found = process.argv.slice(2).find((value) => value.startsWith(prefix));
  return found ? found.slice(prefix.length) : fallback;
}

function readJson(path) {
  return JSON.parse(readFileSync(path, 'utf8'));
}

function jsonResponse(response, status, value) {
  response.writeHead(status, {
    'Cache-Control': 'no-store',
    'Content-Type': 'application/json; charset=utf-8',
  });
  response.end(`${JSON.stringify(value)}\n`);
}

function publicStatus(deployRoot, activeSha) {
  let status = {};
  try {
    status = readJson(join(deployRoot, 'state', 'status.json'));
  } catch {
    status = {};
  }
  return {
    active_sha: activeSha || String(status.active_sha ?? ''),
    detected_sha: String(status.detected_sha ?? ''),
    last_success_at_utc: String(status.last_success_at_utc ?? ''),
    last_failure_at_utc: String(status.last_failure_at_utc ?? ''),
    update_status: String(status.update_status ?? (activeSha ? 'current' : 'unknown')),
    message: String(status.message ?? (activeSha ? 'Release active.' : 'Aucune release active.')),
  };
}

function loadActive(deployRoot) {
  const activePath = join(deployRoot, 'state', 'active.json');
  const active = readJson(activePath);
  const releasePath = realpathSync(resolve(String(active.release_path ?? '')));
  const releasesRoot = realpathSync(resolve(deployRoot, 'releases'));
  const relativeRelease = relative(releasesRoot, releasePath);
  if (
    !releasePath
    || isAbsolute(relativeRelease)
    || relativeRelease === '..'
    || relativeRelease.startsWith(`..${sep}`)
  ) throw new Error('La release active sort de releases/.');
  const distPath = realpathSync(join(releasePath, 'dist'));
  if (!existsSync(join(distPath, 'index.html')) || !existsSync(join(releasePath, 'release.json'))) {
    throw new Error('Release active incomplète.');
  }
  return { active, distPath };
}

function cacheControl(pathname) {
  if (pathname === '/' || pathname.endsWith('/index.html') || pathname.endsWith('/latest.json')) {
    return 'no-store';
  }
  if (/\/assets\/[^/]+-[A-Za-z0-9_-]{8,}\.[^/]+$/u.test(pathname)) {
    return 'public, max-age=31536000, immutable';
  }
  return 'no-cache';
}

export function createObservatoryServer({ deployRoot }) {
  const absoluteDeployRoot = resolve(deployRoot);
  return createServer((request, response) => {
    response.setHeader('X-Content-Type-Options', 'nosniff');
    response.setHeader('Referrer-Policy', 'no-referrer');
    response.setHeader('X-Frame-Options', 'DENY');

    if (!['GET', 'HEAD'].includes(request.method ?? '')) {
      jsonResponse(response, 405, { error: 'method_not_allowed' });
      return;
    }

    let active;
    try {
      active = loadActive(absoluteDeployRoot);
    } catch (error) {
      if (request.url === '/__observatory/status.json') {
        jsonResponse(response, 200, publicStatus(absoluteDeployRoot, ''));
      } else {
        jsonResponse(response, 503, {
          ok: false,
          message: error instanceof Error ? error.message : 'Release indisponible.',
        });
      }
      return;
    }

    const activeSha = String(active.active.active_sha ?? '');
    if (request.url === '/__observatory/healthz') {
      jsonResponse(response, 200, {
        ok: true,
        active_sha: activeSha,
        server_time: new Date().toISOString(),
      });
      return;
    }
    if (request.url === '/__observatory/status.json') {
      jsonResponse(response, 200, publicStatus(absoluteDeployRoot, activeSha));
      return;
    }

    let pathname;
    try {
      pathname = decodeURIComponent(new URL(request.url ?? '/', 'http://localhost').pathname);
    } catch {
      jsonResponse(response, 400, { error: 'invalid_path' });
      return;
    }
    if (pathname.includes('\0') || pathname.split('/').includes('..')) {
      jsonResponse(response, 403, { error: 'path_traversal_refused' });
      return;
    }
    const requestedPath = pathname === '/' ? '/index.html' : pathname;
    const filePath = resolve(active.distPath, `.${requestedPath}`);
    const relativeFile = relative(active.distPath, filePath);
    if (
      isAbsolute(relativeFile)
      || relativeFile === '..'
      || relativeFile.startsWith(`..${sep}`)
    ) {
      jsonResponse(response, 403, { error: 'path_traversal_refused' });
      return;
    }
    let stats;
    let realFilePath;
    try {
      stats = statSync(filePath);
      realFilePath = realpathSync(filePath);
    } catch {
      jsonResponse(response, 404, { error: 'not_found' });
      return;
    }
    if (!stats.isFile()) {
      jsonResponse(response, 404, { error: 'not_found' });
      return;
    }
    const relativeRealFile = relative(active.distPath, realFilePath);
    if (
      isAbsolute(relativeRealFile)
      || relativeRealFile === '..'
      || relativeRealFile.startsWith(`..${sep}`)
    ) {
      jsonResponse(response, 403, { error: 'path_traversal_refused' });
      return;
    }
    response.writeHead(200, {
      'Cache-Control': cacheControl(requestedPath),
      'Content-Length': stats.size,
      'Content-Type': MIME_TYPES.get(extname(realFilePath).toLowerCase()) ?? 'application/octet-stream',
    });
    if (request.method === 'HEAD') response.end();
    else createReadStream(realFilePath).pipe(response);
  });
}

export function main() {
  const deployRoot = argument('deploy-root', process.env.LOCALAPPDATA
    ? join(process.env.LOCALAPPDATA, 'DungeonDraftObservatory')
    : 'DungeonDraftObservatory');
  const host = argument('host', '0.0.0.0');
  const port = Number(argument('port', '8080'));
  if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error('Port invalide.');
  const server = createObservatoryServer({ deployRoot });
  server.on('error', (error) => {
    process.stderr.write(`OBSERVATORY_SERVER_ERROR ${error.message}\n`);
    process.exitCode = 1;
  });
  server.listen(port, host, () => {
    process.stdout.write(`OBSERVATORY_SERVER_READY http://${host}:${port}\n`);
  });
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main();
}
