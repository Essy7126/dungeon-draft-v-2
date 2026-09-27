import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import assert from 'node:assert/strict';
const here=path.dirname(fileURLToPath(import.meta.url));
const out=path.resolve(here,'../../../artifacts/dev/waven-investigation-2026-09-26');
const source=fs.readFileSync(path.join(out,'baseline_run.mjs'),'utf8');
const anchor='if(trace)row.trace=result.trace;';
assert.equal(source.split(anchor).length,2);
const diagnostic=source.replace(anchor,`if(trace){row.trace=result.trace;row.terminal={
  hero:{pos:result.state.hero.pos,hp:result.state.hero.hp,maxHp:result.state.hero.maxHp,p:result.state.hero.p},
  enemies:result.state.enemies.filter(e=>e.hp>0).map(e=>({archetype:e.archetype,hp:e.hp,pos:e.pos})),
  remaining:result.survivors.map(c=>c.family),hand:result.state.hand.map(uid=>result.state.allCopies.find(c=>c.uid===uid).family)
};}`);
const generated=path.join(out,'diagnostic_run.mjs');fs.writeFileSync(generated,diagnostic);
const {simulateRun}=await import(pathToFileURL(generated));
const observations=[];
for(const seed of [27001,27005]){
  const r=simulateRun({classId:'thaumaturge',specIndex:0,seed,trace:true});const last=r.timeline.at(-1);
  assert.equal(r.failureFight,3);
  observations.push({seed,failureFight:r.failureFight,turns:last.turns,gold:r.gold,pressure:last.metrics.pressure,
    totalHpLoss:last.metrics.heroDamage,pressureShare:last.metrics.pressure/last.metrics.heroDamage,
    actions:last.trace.reduce((counts,e)=>(counts[e.action.kind]=(counts[e.action.kind]??0)+1,counts),{}),
    terminal:last.terminal,trace:last.trace});
}
fs.writeFileSync(new URL('./ECHECS_PRECOCES.json',import.meta.url),JSON.stringify(observations,null,2)+'\n');
console.log(JSON.stringify(observations.map(({trace,...o})=>o)));
