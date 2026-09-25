import { readdir, readFile, access, mkdir, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import assert from 'node:assert/strict';

const dir = path.dirname(fileURLToPath(import.meta.url));
const names = (await readdir(dir)).filter(x => x.endsWith('.md'));
const errors = [];
const external = new Set();
const spellSources = new Set();
let localLinks = 0;
let tables = 0;
for (const name of names) {
  const text = await readFile(path.join(dir, name), 'utf8');
  for (const match of text.matchAll(/\]\(([^)]+)\)/g)) {
    const target = match[1];
    if (/^https?:/.test(target)) {
      try { new URL(target); external.add(target); } catch { errors.push(`${name}: URL ${target}`); }
    } else if (!target.startsWith('#')) {
      localLinks++;
      try { await access(path.resolve(dir, target.split('#')[0])); } catch { errors.push(`${name}: lien manquant ${target}`); }
    }
  }
  let width = null;
  for (const [index, line] of text.split('\n').entries()) {
    if (line.startsWith('|')) {
      const cells = line.split('|').length;
      if (width === null) { width = cells; tables++; }
      else if (width !== cells) errors.push(`${name}:${index + 1}: largeur de tableau incohérente`);
      if (['DOFUS.md', 'WAKFU.md'].includes(name) && line.startsWith('| [')) {
        const source = line.match(/\]\((https:[^)]+)\)/)?.[1];
        if (source) spellSources.add(source);
      }
    } else width = null;
  }
  if (text.includes('\ufffd')) errors.push(`${name}: caractère de remplacement Unicode`);
}
const results = JSON.parse(await readFile(path.join(dir, 'resultats_calcules.json'), 'utf8'));
assert.equal(results.cases.length, 14);
assert.equal(results.checkedGroups, 15);
assert.equal(spellSources.size, 91);
const report = { documents: names.length, localLinks, externalUrlsSyntaxOnly: external.size, uniqueSpellSources: spellSources.size, tables, errors, limitation: 'Liens locaux et syntaxe des URL vérifiés ; aucun contrôle automatique de disponibilité HTTP ni test des jeux.' };
const out = path.resolve(dir, '../../../artifacts/dev/dofus_wakfu_spell_identity_2026-09-25');
await mkdir(out, { recursive: true });
await writeFile(path.join(out, 'validation.json'), JSON.stringify(report, null, 2) + '\n', 'utf8');
console.log(JSON.stringify(report, null, 2));
if (errors.length) process.exitCode = 1;
