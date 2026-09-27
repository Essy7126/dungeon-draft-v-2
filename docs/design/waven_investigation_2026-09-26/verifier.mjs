import fs from 'node:fs';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {rules} from '../consumable_v1/content.mjs';
const data=JSON.parse(fs.readFileSync(new URL('./EXPERIENCES.json',import.meta.url)));
assert.equal(data.complete,true);assert.equal(data.rows.length,40);
for(const [name,hash] of Object.entries(data.metadata.sourceHashes)){
  const source=fs.readFileSync(new URL(`../consumable_v1/${name}.mjs`,import.meta.url));
  assert.equal(createHash('sha256').update(source).digest('hex'),hash,`Source changed: ${name}`);
}
const keys=new Set();let completedExecutions=0,copyChecks=0,transactionChecks=0;
for(const row of data.rows){
  const key=row.classId+':'+row.seed;assert.equal(keys.has(key),false);keys.add(key);
  assert.ok(row.seed>=27001&&row.seed<=27010);
  const focus=data.metadata.focus[row.classId];
  for(const variant of data.metadata.variants){
    const r=row[variant];completedExecutions++;
    assert.ok(r.timeline.length>0&&r.timeline.length<=12);
    assert.equal(r.timeline.length,r.won?12:r.failureFight);
    assert.equal(r.won,r.timeline.at(-1).outcome==='victory');
    assert.ok(r.gold>=0);
    assert.equal(r.consumed,r.timeline.reduce((n,t)=>n+t.cards,0));
    for(const t of r.timeline){
      assert.ok(t.audit.opening.length>=Math.min(rules.hand,t.stockBefore));
      assert.ok(t.audit.opening.length<=Math.min(7,t.stockBefore));
      for(const id of focus){assert.ok(t.audit.deck[id]<=t.audit.stock[id]);assert.ok(t.audit.opening.filter(f=>f===id).length<=t.audit.deck[id]);}
      if(variant==='opening'&&t.audit.deck[focus[0]]>0)assert.ok(t.audit.opening.includes(focus[0]));
      copyChecks++;
    }
    const visits={};
    for(const purchase of r.targeted){
      assert.ok([3,5,7,10,11].includes(purchase.visit));assert.ok(focus.includes(purchase.family));
      const id=`${purchase.visit}:${purchase.kind}:${purchase.family}`;assert.equal(visits[id],undefined);visits[id]=true;transactionChecks++;
    }
    const singles=r.targeted.filter(p=>p.kind==='single').length,trades=r.targeted.filter(p=>p.kind==='trade').length;
    assert.ok(r.spending.cards>=singles*rules.economy.buy.normal);assert.ok(r.tradedInput>=trades*3);
  }
  // The shop variant cannot alter combat before the first visit after fight 3.
  for(let i=0;i<Math.min(3,row.baseline.timeline.length);i++){
    const a=row.baseline.timeline[i],b=row.restock.timeline[i];
    for(const field of ['outcome','turns','cards','hpRatio','stockBefore','stockAfter','metrics','audit'])assert.deepEqual(a[field],b[field]);
  }
}
for(const variant of data.metadata.variants){
  assert.equal(data.summary[variant].wins,data.rows.filter(r=>r[variant].won).length);
  assert.equal(data.summary[variant].onlyVariant,data.rows.filter(r=>r[variant].won&&!r.baseline.won).length);
  assert.equal(data.summary[variant].onlyBaseline,data.rows.filter(r=>!r[variant].won&&r.baseline.won).length);
}
const average=xs=>xs.reduce((a,b)=>a+b,0)/xs.length;
const details={};
for(const variant of data.metadata.variants){
  const both=data.rows.filter(r=>r[variant].won&&r.baseline.won);
  const first=data.rows.map(r=>r[variant].timeline[0]);
  details[variant]={firstFightBoth:first.filter(t=>Object.keys(t.audit.stock).every(id=>t.audit.opening.includes(id))).length,
    pairedVictories:both.length,pairedGoldDelta:average(both.map(r=>r[variant].gold-r.baseline.gold)),
    pairedCardSpendingDelta:average(both.map(r=>r[variant].spending.cards-r.baseline.spending.cards)),
    pairedConsumedDelta:average(both.map(r=>r[variant].consumed-r.baseline.consumed)),
    failures:data.rows.filter(r=>!r[variant].won).map(r=>({classId:r.classId,seed:r.seed,fight:r[variant].failureFight}))};
}
const result={passed:true,completedExecutions,copyChecks,transactionChecks,sourceHashesVerified:true,details};
fs.writeFileSync(new URL('./VERIFICATION.json',import.meta.url),JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify(result));
