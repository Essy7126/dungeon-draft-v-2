import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import assert from 'node:assert/strict';
import {out,modules} from './laboratoire.mjs';
const oldCases=[27001,27005].map(seed=>{
  const r=modules.urgence.simulateRun({classId:'thaumaturge',specIndex:0,seed,trace:true});
  return {seed,completed:r.completed,failureFight:r.failureFight,timeline:r.timeline};
});
let combat=fs.readFileSync(path.join(out,'phase_combat.mjs'),'utf8');
const anchor='const action=chooseAction(s,policy);if(!action)break;';
assert.equal(combat.split(anchor).length,2);
combat=combat.replace(anchor,`const action=chooseAction(s,policy);
      if(trace&&s.encounter.index===2)s.trace.push({diagnostic:true,turn:s.turn,heroPos:[...s.hero.pos],hp:s.hero.hp,ap:s.hero.ap,mp:s.hero.mp,
        enemies:s.enemies.filter(e=>e.hp>0).map(e=>({id:e.id,hp:e.hp,pos:[...e.pos]})),action:action?clone(action):null});
      if(!action)break;`);
const cp=path.join(out,'phase_diagnostic_combat.mjs');fs.writeFileSync(cp,combat);
let run=fs.readFileSync(path.join(out,'phase_run.mjs'),'utf8');
run=run.replace(JSON.stringify(pathToFileURL(path.join(out,'phase_combat.mjs')).href),JSON.stringify(pathToFileURL(cp).href));
const rp=path.join(out,'phase_diagnostic_run.mjs');fs.writeFileSync(rp,run);
const {simulateRun}=await import(pathToFileURL(rp));
const r=simulateRun({classId:'assassin',seed:28001,specIndex:0,trace:true});assert.equal(r.failureFight,2);
const fight=r.timeline.at(-1);
const phaseFailure={classId:'assassin',seed:28001,failureFight:r.failureFight,turns:fight.turns,metrics:fight.metrics,
  trace:fight.trace.filter(t=>t.diagnostic)};
fs.writeFileSync(new URL('./DIAGNOSTICS.json',import.meta.url),JSON.stringify({oldCases,phaseFailure},null,2)+'\n');
console.log(JSON.stringify({oldCases:oldCases.map(r=>({seed:r.seed,won:r.completed,failure:r.failureFight,fight3:r.timeline[2]})),
  phaseFailure:{...phaseFailure,trace:phaseFailure.trace.filter(t=>[1,8,17].includes(t.turn))}}));
