// Audit-only sensitivity experiment: change Guardian's automatic stat allocation.
// No game/model source is overwritten. This is not an optimized human policy.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {simulateRun} from '../consumable_v1/run.mjs';
const root=fileURLToPath(new URL('../../../',import.meta.url));
const out=path.join(root,'artifacts/dev/gameplay-critique-2026-09-25');
fs.mkdirSync(out,{recursive:true});
const sourcePath=fileURLToPath(new URL('../consumable_v1/run.mjs',import.meta.url));
const source=fs.readFileSync(sourcePath,'utf8');
const from="next%6===0?'vitality':state.classId==='gardien'?'resolve':'power'";
const to="next%6===0?'vitality':'power'";
assert.equal(source.split(from).length,2,'Exactly one allocation expression must match');
let generated=source.replace(from,to);
for(const name of ['content','combat','market'])generated=generated.replace(`'./${name}.mjs'`,JSON.stringify(new URL(`../consumable_v1/${name}.mjs`,import.meta.url).href));
const generatedPath=path.join(out,'guardian_power_policy.mjs');
fs.writeFileSync(generatedPath,generated);
const candidate=await import(pathToFileURL(generatedPath));
const rows=[];
const compact=r=>({won:r.completed,failureFight:r.failureFight,level:r.level,attributes:r.attributes,consumed:r.consumed,stock:r.inventory.length,gold:r.gold,trained:r.trained,uses:r.cardUses,
  timeline:r.timeline.map(t=>({fight:t.fight,turns:t.turns,cards:t.cards,hpRatio:t.hpRatio,stockBefore:t.stockBefore,stockAfterRewards:t.stockAfterRewards}))});
for(let seed=26001;seed<=26020;seed++){
  const options={classId:'gardien',specIndex:0,seed};
  const baseline=compact(simulateRun(options));
  const power=compact(candidate.simulateRun(options));
  rows.push({seed,baseline,power});
  console.log(JSON.stringify({seed,baseline:baseline.won,power:power.won}));
}
const summary={n:rows.length,baselineWins:rows.filter(r=>r.baseline.won).length,powerWins:rows.filter(r=>r.power.won).length,
  onlyBaseline:rows.filter(r=>r.baseline.won&&!r.power.won).length,onlyPower:rows.filter(r=>r.power.won&&!r.baseline.won).length};
const metadata={date:new Date().toISOString(),node:process.version,sourceSha256:createHash('sha256').update(source).digest('hex'),transformation:{from,to},
  assumptions:'20 new paired seeds; Guardian/Bastion only; same planner, drops, shops and deck cap 20. Allocation 4 resolve + 2 vitality becomes 4 power + 2 vitality at level 12. Divergent actions change future draws and purchases. Exploratory sensitivity, not human balance.',summary};
fs.writeFileSync(path.join(out,'policy_probe.json'),JSON.stringify({metadata,rows},null,2)+'\n');
console.log(JSON.stringify({complete:true,...summary}));
