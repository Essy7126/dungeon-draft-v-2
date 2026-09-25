// Replays every recorded run and rejects any gameplay change. Worker threads only
// parallelize numerical calculations; all data stays in the local repository.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {Worker,isMainThread,workerData,parentPort} from 'node:worker_threads';
import assert from 'node:assert/strict';
import {simulateRun} from './run.mjs';
import {classes} from './content.mjs';
const root=path.dirname(fileURLToPath(import.meta.url)),out=path.resolve(root,'../../../artifacts/dev/consumable-v1');
const options={v1:{},greedy:{policy:'balanced'},aggressive:{policy:'aggressive'},conserve:{policy:'conserve'},no_rare:{cardFilter:c=>['normal','elite'].includes(c.rarity)},no_shops:{shops:false},no_gear:{gear:false},no_relics:{relicLoot:false},deck15:{deckCap:15},deck30:{deckCap:30},fallback:{policy:'fallback'},old_drop_variance:{lootOptions:{sizes:[3,3,2,1,1,1,1],rates:[[.75,.15,.05,.005,0,0,0],[.8,.2,.1,.015,.001,0,0],[.9,.3,.18,.04,.004,.0003,0],[.95,.45,.28,.08,.01,.0015,.0002]]}}};
if(!isMainThread){
  const result=[];
  for(const row of workerData){
    const specIndex=classes.find(c=>c.id===row.class).specs.indexOf(row.spec),s=simulateRun({classId:row.class,specIndex,seed:row.seed,...options[row.scenario]});
    for(const [key,value]of Object.entries({completed:s.completed,failureFight:s.failureFight,consumed:s.consumed,stock:s.inventory.length,gold:s.gold,bought:s.bought,dropped:s.dropped,basic:s.basic,spending:s.spending,uses:s.cardUses}))assert.deepEqual(value,row[key],row.class+' '+row.seed+' '+key);
    for(let i=0;i<s.timeline.length-1;i++){const a=s.timeline[i],b=s.timeline[i+1];assert.equal(a.stockAfterRewards,b.stockAfter+b.cards);assert.equal(a.goldAfter,b.gold);}
    result.push({...row,timeline:s.timeline.map(({metrics,...r})=>r)});
  }
  parentPort.postMessage(result);
}else{
  const before=JSON.parse(fs.readFileSync(path.join(out,'runs.json'),'utf8'));assert.equal(before.length,640);
  const parts=await Promise.all(classes.map(cls=>new Promise((resolve,reject)=>{const w=new Worker(new URL(import.meta.url),{workerData:before.filter(r=>r.class===cls.id)});w.once('message',resolve);w.once('error',reject);w.once('exit',code=>{if(code!==0)reject(Error('Worker exit '+code));});})));
  const key=r=>[r.scenario,r.class,r.spec,r.seed].join(':'),byKey=new Map(parts.flat().map(r=>[key(r),r]));
  const after=before.map(r=>byKey.get(key(r)));assert.equal(after.filter(Boolean).length,640);
  fs.writeFileSync(path.join(out,'runs.json'),JSON.stringify(after));
  const meta=JSON.parse(fs.readFileSync(path.join(root,'metadata.json'),'utf8'));
  meta.replay={date:new Date().toISOString(),runs:640,gameplayResults:'all identical',change:'after-reward timeline reference corrected',previousRunHash:meta.hashes['run.mjs']};
  for(const name of ['run.mjs','contracts.test.mjs','replay_runs.mjs'])meta.hashes[name]=createHash('sha256').update(fs.readFileSync(path.join(root,name))).digest('hex');
  for(const dir of [root,out])fs.writeFileSync(path.join(dir,'metadata.json'),JSON.stringify(meta,null,2)+'\n');
  console.log('640/640 replays identical in outcome, copies, gold, purchases, drops, basic attacks, spending and card usage; all timeline continuity checks passed.');
}
