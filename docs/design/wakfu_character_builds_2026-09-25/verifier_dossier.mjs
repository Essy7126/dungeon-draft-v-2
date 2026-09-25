import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { build } from './construire_lectures.mjs';
import { calculate } from './calculs.mjs';

const dir = path.dirname(fileURLToPath(import.meta.url));
const checks = [];
function verify(name, fn) { fn(); checks.push(name); }
let dataset;
verify('Fraîcheur du catalogue lisible et structuré depuis les lectures', () => { dataset = build({ check: true }); });
verify('Couverture : 18 classes, 38 fiches, 36 ajouts distincts', () => {
  assert.deepEqual(dataset.coverage, { classes: 18, readings: 38, passive: 37, active: 1, priorUniqueIds: 130, repeatedIds: [758, 7196], additionalUniqueIds: 36, combinedUniqueIds: 166 });
  assert.equal(new Set(dataset.spells.map(s => s.id)).size, 38);
  for (const s of dataset.spells) {
    assert.ok(Number.isInteger(s.id) && s.id > 0);
    assert.equal(new URL(s.source).hostname, 'wakfuli.com');
    for (const field of ['contrat', 'analyse', 'limite']) assert.ok(s[field].length > 30, `${s.id} ${field}`);
  }
});
let math;
verify('Fraîcheur des 15 scénarios et succès des 15 assertions', () => {
  math = calculate({ check: true });
  assert.equal(math.scenarios, 15);
  assert.equal(math.assertions, 15);
  assert.equal(new Set(math.cases.map(c => c.id)).size, 15);
  const ids = new Set(dataset.spells.map(s => s.id));
  for (const item of math.cases) for (const id of item.sourceIds) assert.ok(ids.has(id), `${item.id} source ${id}`);
});
verify('Portraits : deux directions et une épreuve pour chacune des 18 classes', () => {
  const body = fs.readFileSync(path.join(dir, 'PERSONNAGES.md'), 'utf8');
  const portraits = body.split(/^## /m).slice(1);
  assert.equal(portraits.length, 18);
  assert.deepEqual(new Set(portraits.map(p => p.split(' — ')[0])), new Set(dataset.spells.map(s => s.classe)));
  for (const portrait of portraits) {
    for (const marker of ['**Architecture.**', '**A —', '**B —', '**Épreuve et transfert.**']) assert.ok(portrait.includes(marker), marker);
  }
});
const files = fs.readdirSync(dir).filter(name => fs.statSync(path.join(dir, name)).isFile() && name !== 'VERIFICATION.json').sort();
let localLinks = 0;
const external = new Set();
verify('Liens locaux, syntaxe URL, tableaux et encodage', () => {
  for (const name of files.filter(n => n.endsWith('.md'))) {
    const body = fs.readFileSync(path.join(dir, name), 'utf8');
    assert.ok(!body.includes('\ufffd'), name);
    for (const match of body.matchAll(/\]\(([^)\s]+)\)/g)) {
      const target = match[1];
      if (/^https?:/.test(target)) { assert.equal(new URL(target).protocol, 'https:'); external.add(target); }
      else if (!target.startsWith('#')) {
        const resolved = path.resolve(dir, decodeURIComponent(target.split('#')[0]));
        assert.ok(fs.existsSync(resolved) || resolved === path.join(dir, 'VERIFICATION.json'), `${name}: ${target}`);
        localLinks++;
      }
    }
    let width = null;
    for (const line of body.split(/\r?\n/)) {
      if (!line.startsWith('|')) { width = null; continue; }
      const cells = line.split('|').length;
      if (width === null) width = cells;
      assert.equal(cells, width, `Largeur de tableau ${name}`);
    }
  }
});
const report = {
  checkedAt: new Date().toISOString(), status: 'passed', checks,
  coverage: dataset.coverage,
  math: { scenarios: math.scenarios, assertions: math.assertions },
  localLinks, externalUrlsSyntaxOnly: external.size,
  clientRuntimeTested: false, godotRuntimeTested: false,
  limitation: 'Intégrité et conséquences des modèles déclarés ; aucune mesure de popularité, test du client WAKFU ou équilibrage global certifié.',
  fingerprints: Object.fromEntries(files.filter(name => name !== 'WORKLOG.md').map(name => [name, createHash('sha256').update(fs.readFileSync(path.join(dir, name))).digest('hex')])),
};
fs.writeFileSync(path.join(dir, 'VERIFICATION.json'), JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify({ status: report.status, checks: checks.length, coverage: report.coverage, math: report.math, localLinks, externalUrlsSyntaxOnly: external.size }, null, 2));
