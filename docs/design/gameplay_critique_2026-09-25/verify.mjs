import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const dir=path.dirname(fileURLToPath(import.meta.url));
const read=f=>fs.readFileSync(path.resolve(dir,f),'utf8');
const result=JSON.parse(read('RESULTATS.json'));
for(const [file,hash]of Object.entries(result.metadata.hashes))assert.equal(createHash('sha256').update(read(file)).digest('hex'),hash,`Stale input: ${file}`);
const probe=JSON.parse(read('EXPERIENCE_GARDIEN.json'));
assert.equal(probe.metadata.sourceSha256,result.metadata.hashes['../consumable_v1/run.mjs']);
assert.equal(probe.rows.length,20);
const summary=probe.metadata.summary;
assert.equal(summary.baselineWins,probe.rows.filter(r=>r.baseline.won).length);
assert.equal(summary.powerWins,probe.rows.filter(r=>r.power.won).length);
assert.equal(summary.onlyBaseline,probe.rows.filter(r=>r.baseline.won&&!r.power.won).length);
assert.equal(summary.onlyPower,probe.rows.filter(r=>r.power.won&&!r.baseline.won).length);
let links=0;
for(const file of ['README.md'])for(const m of read(file).matchAll(/\]\(([^)]+)\)/g)){
  const target=m[1].replace(/^<|>$/g,'').split('#')[0];if(!target||/^[a-z]+:/i.test(target))continue;
  assert.ok(fs.existsSync(path.resolve(dir,decodeURIComponent(target))),`${file} -> ${target}`);links++;
}
const output={sourceHashes:'match',calculationAssertions:result.metadata.checks,pairedSeeds:probe.rows.length,completedRuns:40,localLinks:links};
console.log(JSON.stringify(output));
