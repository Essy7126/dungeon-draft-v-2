import { copyFile, mkdir } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(here, '..');
const source = resolve(projectRoot, '..', 'tools', 'observatory', 'schemas', 'observatory_snapshot.schema.json');
const destination = resolve(projectRoot, 'public', 'generated', 'observatory_snapshot.schema.json');

await mkdir(dirname(destination), { recursive: true });
await copyFile(source, destination);
console.log('Schema Observatory synchronisé vers public/generated.');
