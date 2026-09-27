import fs from 'node:fs';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {rules,classes} from '../../consumable_v1/content.mjs';
const merchant=JSON.parse(fs.readFileSync(new URL('./MARCHAND.json',import.meta.url)));
const pilot=JSON.parse(fs.readFileSync(new URL('./PILOTAGE.json',import.meta.url)));
assert.equal(merchant.complete,true);assert.equal(pilot.complete,true);
assert.equal(merchant.rows.length,40);assert.equal(pilot.rows.length,40);
assert.deepEqual(merchant.metadata.sourceHashes,pilot.metadata.sourceHashes);
for(const [name,hash] of Object.entries(merchant.metadata.sourceHashes))assert.equal(createHash('sha256').update(fs.readFileSync(new URL(`../../consumable_v1/${name}.mjs`,import.meta.url))).digest('hex'),hash);
const variants=[...merchant.metadata.variants,...pilot.metadata.variants];
assert.equal(variants.length,11);
const keyed=new Map(pilot.rows.map(r=>[r.classId+':'+r.seed,r]));assert.equal(keyed.size,40);
const rows=merchant.rows.map(r=>({...r,...keyed.get(r.classId+':'+r.seed)}));
assert.equal(new Set(rows.map(r=>r.classId+':'+r.seed)).size,40);
let inventoryChecks=0,fightChecks=0,transactionChecks=0;
for(const row of rows)for(const v of variants){
  const r=row[v.id];assert.ok(r);assert.ok(r.gold>=0);
  assert.equal(r.stock,rules.initialCards+r.dropped+r.bought+r.tradedOutput-r.tradedInput-r.sold-r.consumed);inventoryChecks++;
  assert.equal(r.consumed,r.timeline.reduce((n,t)=>n+t.cards,0));
  assert.equal(r.timeline.length,r.won?12:r.failureFight);assert.equal(r.won,r.timeline.at(-1).outcome==='victory');
  const purchases=new Set();
  for(const t of r.targeted){
    assert.ok([3,5,7,10,11].includes(t.visit));assert.ok(merchant.metadata.focus[row.classId].includes(t.family));
    assert.ok(t.kind==='single'?v.mask&1:v.mask&2);
    const id=t.visit+':'+t.kind+':'+t.family;assert.equal(purchases.has(id),false);purchases.add(id);transactionChecks++;
  }
  assert.ok(r.bought>=r.targeted.filter(t=>t.kind==='single').length);
  assert.ok(r.spending.cards>=r.targeted.filter(t=>t.kind==='single').length*8);
  assert.ok(r.tradedInput>=r.targeted.filter(t=>t.kind==='trade').length*3);
  for(const t of r.timeline){assert.ok(t.cards<=t.stockBefore);fightChecks++;}
  if(v.id.startsWith('m'))for(let i=0;i<Math.min(3,row.m0.timeline.length);i++){
    const a=row.m0.timeline[i],b=r.timeline[i];for(const key of ['outcome','turns','cards','hpRatio','metrics','auditFocusStock'])assert.deepEqual(a[key],b[key]);
  }
}
const mean=xs=>xs.length?xs.reduce((a,b)=>a+b,0)/xs.length:null;
function summary(list,id,reference='m0'){
  const selected=list.map(r=>r[id]),fights=selected.flatMap(r=>r.timeline),joint=list.filter(r=>r[id].won&&r[reference].won);
  return {n:list.length,wins:selected.filter(r=>r.won).length,
    rescued:list.filter(r=>r[id].won&&!r[reference].won).length,lost:list.filter(r=>!r[id].won&&r[reference].won).length,
    fightsWon:mean(selected.map(r=>r.timeline.filter(t=>t.outcome==='victory').length)),
    consumed:mean(selected.map(r=>r.consumed)),cardSpending:mean(selected.map(r=>r.spending.cards)),endingGold:mean(selected.map(r=>r.gold)),endingStock:mean(selected.map(r=>r.stock)),
    targetedSingles:selected.reduce((n,r)=>n+r.targeted.filter(t=>t.kind==='single').length,0),targetedTrades:selected.reduce((n,r)=>n+r.targeted.filter(t=>t.kind==='trade').length,0),
    meanTurnsPerFight:mean(fights.map(t=>t.turns)),fightsWithPressure:fights.filter(t=>t.metrics.pressure>0).length,totalFights:fights.length,
    meanPressureHp:mean(selected.map(r=>r.timeline.reduce((n,t)=>n+t.metrics.pressure,0))),
    beforeShopDefeats:selected.filter(r=>!r.won&&r.failureFight<=3).length,
    commonWins:joint.length,commonWinConsumedDelta:mean(joint.map(r=>r[id].consumed-r[reference].consumed)),
    commonWinCardSpendingDelta:mean(joint.map(r=>r[id].spending.cards-r[reference].spending.cards)),commonWinGoldDelta:mean(joint.map(r=>r[id].gold-r[reference].gold)),
    failures:list.filter(r=>!r[id].won).map(r=>({classId:r.classId,seed:r.seed,fight:r[id].failureFight,turn:r[id].timeline.at(-1).turns,pressure:r[id].timeline.at(-1).metrics.pressure}))};
}
const summaries=Object.fromEntries(variants.map(v=>[v.id,summary(rows,v.id)]));
const wins=mask=>summaries['m'+mask].wins;
const factors=Object.fromEntries([['A',1],['T',2],['P',4]].map(([name,bit])=>{
  const contexts=Array.from({length:8},(_,i)=>i).filter(m=>!(m&bit));
  const effects=contexts.map(mask=>({without:mask,with:mask|bit,winDelta:wins(mask|bit)-wins(mask)}));
  return [name,{effects,averageConditionalWinDelta:mean(effects.map(e=>e.winDelta)),
    shapleyWins:effects.reduce((n,e)=>{const size=(e.without.toString(2).match(/1/g)??[]).length;return n+e.winDelta*(size===1?1/6:1/3);},0)}];
}));
assert.ok(Math.abs(Object.values(factors).reduce((n,x)=>n+x.shapleyWins,0)-(wins(7)-wins(0)))<1e-10);
const report={complete:true,sourceHashes:merchant.metadata.sourceHashes,checks:{inventoryChecks,fightChecks,transactionChecks,sourceHashesMatch:true,beforeShopParity:true},
  summaries,byClass:Object.fromEntries(classes.map(c=>[c.id,Object.fromEntries(variants.map(v=>[v.id,summary(rows.filter(r=>r.classId===c.id),v.id)]))])),
  factors,pairInteractionsAtBaseline:{AT:wins(3)-wins(1)-wins(2)+wins(0),AP:wins(5)-wins(1)-wins(4)+wins(0),TP:wins(6)-wins(2)-wins(4)+wins(0)},
  protectionPairsIdentical:rows.every(r=>[0,1,2,3].every(m=>JSON.stringify(r['m'+m])===JSON.stringify(r['m'+(m+4)]))),
  purchaseAndTradeVersusPurchase:summary(rows,'m3','m1'),
  combinedVersusUrgency:summary(rows,'urgence_m7','urgence'),combinedVersusRestock:summary(rows,'urgence_m7','m7')};
fs.writeFileSync(new URL('./SYNTHESE.json',import.meta.url),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({checks:report.checks,summaries:Object.fromEntries(Object.entries(summaries).map(([k,{failures,...v}])=>[k,v])),factors}));
