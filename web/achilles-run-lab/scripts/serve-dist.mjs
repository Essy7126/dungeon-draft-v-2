import { createReadStream, existsSync, statSync } from 'node:fs';
import { createServer } from 'node:http';
import path from 'node:path';

const root = path.resolve('dist');
const mime = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8', '.json': 'application/json', '.glb': 'model/gltf-binary', '.png': 'image/png', '.map': 'application/json' };
createServer((request, response) => {
  const urlPath = decodeURIComponent((request.url ?? '/').split('?')[0] ?? '/');
  const requested = path.resolve(root, `.${urlPath}`);
  const safePath = requested.startsWith(root) && existsSync(requested) && statSync(requested).isFile() ? requested : path.join(root, 'index.html');
  response.setHeader('Content-Type', mime[path.extname(safePath)] ?? 'application/octet-stream');
  response.setHeader('Cache-Control', 'no-store');
  createReadStream(safePath).pipe(response);
}).listen(4173, '127.0.0.1', () => process.stdout.write('Achilles Web Run Lab : http://127.0.0.1:4173\n'));
