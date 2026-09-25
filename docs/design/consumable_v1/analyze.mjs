import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {rules,manifest,cards,cardById,classes,specs,equipment,relics,route,upgradedCard} from './content.mjs';
import {fixture,actionFor} from './fixtures.mjs';
import {applyAction,endTurn,beginTurn,makeCombat,playCombat,copies,heroStats,policies} from './combat.mjs';
import {simulateRun,rollLoot} from './run.mjs';
const root=path.dirname(fileURLToPath(import.meta.url));
const out=path.resolve(root,'../../../artifacts/dev/consumable-v1');fs.mkdirSync(out,{recursive:true});
const csv=(rows)=>{if(!rows.length)return '';const keys=Object.keys(rows[0]);const cell=x=>'"'+String(typeof x==='object'?JSON.stringify(x):x??'').replaceAll('"','""')+'"';return [keys,...rows.map(r=>keys.map(k=>r[k]))].map(row=>row.map(cell).join(',')).join('\n')+'\n';};
const save=(name,rows)=>fs.writeFileSync(path.join(out,name),csv(rows));
const mean=a=>a.reduce((x,y)=>x+y,0)/(a.length||1);
const quantile=(a,q)=>[...a].sort((x,y)=>x-y)[Math.floor((a.length-1)*q)]??0;
function wilson(w,n){const z=1.96,p=w/n,d=1+z*z/n,center=(p+z*z/(2*n))/d,half=z*Math.sqrt(p*(1-p)/n+z*z/(4*n*n))/d;return [center-half,center+half];}
const round=x=>Math.round(x*1000000)/1000000;
const cardRows=[];
for(const c of cards)for(const level of [1,4,8,12])for(const scenario of ['ready','unprepared','armored','isolated','lethal','wall'])for(const upgraded of [false,true]){
  const s=fixture(c.id,{level,scenario,trained:upgraded?[c.id]:[]}),before=structuredClone(s),action=actionFor(s,c.id),control=structuredClone(s);
  if(action)applyAction(s,action);
  const immediate=s.metrics.damage;
  for(let i=0;i<2;i++){endTurn(s);endTurn(control);if(i===0){beginTurn(s);beginTurn(control);}}
  for(const v of [s.hero.hp,s.hero.shield,s.metrics.damage])assert.ok(Number.isFinite(v));
  cardRows.push({id:c.id,level,scenario,upgraded,legal:!!action,ap:upgradedCard(c.id,upgraded?[c.id]:[]).ap,
    immediate:round(immediate),damageTwoPhases:round(s.metrics.damage-control.metrics.damage),hpSaved:round(s.hero.hp-control.hero.hp),
    guardProduced:round(s.metrics.shieldMade-before.metrics.shieldMade),movement:s.metrics.moves,displacement:s.metrics.displaced,
    extraDraw:s.metrics.drawn-control.metrics.drawn,stuns:s.metrics.stuns-control.metrics.stuns,
    markRemaining:round(s.enemies.reduce((n,e)=>n+e.mark,0)),conditions:scenario==='ready'?'prepared':'controlled variation'});
}
save('card_scenarios.csv',cardRows);
save('card_summary.csv',cards.map(c=>{
  const rows=cardRows.filter(r=>r.id===c.id),ready=rows.find(r=>r.level===12&&r.scenario==='ready'&&!r.upgraded),up=rows.find(r=>r.level===12&&r.scenario==='ready'&&r.upgraded);
  return {id:c.id,name:c.name,rarity:c.rarity,scenarios:rows.length,legal:rows.filter(r=>r.legal).length,damageP:round(ready.damageTwoPhases/rules.prowess[11]),guardP:round(ready.guardProduced/rules.prowess[11]),hpSaved:ready.hpSaved,damagePerAP:round(ready.damageTwoPhases/ready.ap),upgradeDamageGain:round(up.damageTwoPhases-ready.damageTwoPhases),base:c,upgrade:c.upgrade};
}));
// Identical-class paired encounter comparisons. The bot is fixed, not optimized per item.
const effects=[];
for(const cls of classes){
  const families=cards.filter(c=>['normal','elite'].includes(c.rarity)&&['shared',cls.id].includes(c.affinity)).map(c=>c.id);
  const deck=copies(families.flatMap(id=>[id,id]).slice(0,30));
  for(const encounterIndex of [4,6,9])for(const seed of [701,702]){
    const encounter=route[encounterIndex],options={classId:cls.id,level:encounter.index,deck,encounter,seed};
    const base=playCombat(options,'planner');
    for(const [kind,list]of [['gear',equipment],['relic',relics],['spec',cls.specs.map(id=>({id}))]])for(const item of list){
      const changed=playCombat({...options,gear:kind==='gear'?[item.id]:[],relicIds:kind==='relic'?[item.id]:[],spec:kind==='spec'?item.id:''},'planner');
      effects.push({class:cls.id,kind,id:item.id,fight:encounter.index,seed,baseWin:base.outcome==='victory',win:changed.outcome==='victory',deltaCards:changed.metrics.cards-base.metrics.cards,deltaTurns:changed.turns-base.turns,deltaHpFraction:round(changed.hp/changed.maxHp-base.hp/base.maxHp),deltaGold:changed.metrics.gold-base.metrics.gold});
    }
  }
  console.log('Item comparisons: '+cls.id);
}
save('item_comparisons.csv',effects);
save('item_summary.csv',[...equipment.map(x=>['gear',x.id]),...relics.map(x=>['relic',x.id]),...Object.keys(specs).map(id=>['spec',id])].map(([kind,id])=>{
  const r=effects.filter(x=>x.kind===kind&&x.id===id);return {kind,id,n:r.length,meanDeltaCards:round(mean(r.map(x=>x.deltaCards))),meanDeltaHp:round(mean(r.map(x=>x.deltaHpFraction))),changed:r.filter(x=>x.deltaCards||x.deltaTurns||x.deltaHpFraction||x.deltaGold||x.win!==x.baseWin).length,winDelta:r.filter(x=>x.win).length-r.filter(x=>x.baseWin).length};
}));
const scenarios=[
  {name:'v1',n:25,options:{}},
  {name:'greedy',n:10,options:{policy:'balanced'}},
  {name:'aggressive',n:10,options:{policy:'aggressive'}},
  {name:'conserve',n:10,options:{policy:'conserve'}},
  {name:'no_rare',n:10,options:{cardFilter:c=>['normal','elite'].includes(c.rarity)}},
  {name:'no_shops',n:10,options:{shops:false}},
  {name:'no_gear',n:10,options:{gear:false}},
  {name:'no_relics',n:10,options:{relicLoot:false}},
  {name:'deck15',n:10,options:{deckCap:15}},
  {name:'deck30',n:10,options:{deckCap:30}},
  {name:'fallback',n:10,options:{policy:'fallback'}},
  {name:'old_drop_variance',n:10,options:{lootOptions:{sizes:[3,3,2,1,1,1,1],rates:[[.75,.15,.05,.005,0,0,0],[.8,.2,.1,.015,.001,0,0],[.9,.3,.18,.04,.004,.0003,0],[.95,.45,.28,.08,.01,.0015,.0002]]}}},
];
const rows=[],detail=[];
for(const scenario of scenarios)for(const cls of classes)for(const specIndex of scenario.name==='v1'?[0,1]:[0]){
  const runs=[];
  for(let i=0;i<scenario.n;i++){
    const seed=10001+i,s=simulateRun({classId:cls.id,seed,specIndex,...scenario.options});runs.push(s);
    detail.push({scenario:scenario.name,class:cls.id,spec:cls.specs[specIndex],seed,completed:s.completed,failureFight:s.failureFight,consumed:s.consumed,stock:s.inventory.length,gold:s.gold,bought:s.bought,dropped:s.dropped,basic:s.basic,spending:s.spending,timeline:s.timeline.map(({metrics,...r})=>r),uses:s.cardUses});
  }
  const wins=runs.filter(r=>r.completed).length,ci=wilson(wins,runs.length);
  rows.push({scenario:scenario.name,class:cls.id,spec:cls.specs[specIndex],n:runs.length,wins,rate:wins/runs.length,ciLow:round(ci[0]),ciHigh:round(ci[1]),earlyFailures:runs.filter(r=>!r.completed&&r.failureFight<=3).length,
    meanCards:round(mean(runs.map(r=>r.consumed))),medianFinalStock:quantile(runs.map(r=>r.inventory.length),.5),medianWinStock:quantile(runs.filter(r=>r.completed).map(r=>r.inventory.length),.5),meanGold:round(mean(runs.map(r=>r.gold))),failureFights:runs.filter(r=>!r.completed).reduce((a,r)=>(a[r.failureFight]=(a[r.failureFight]??0)+1,a),{})});
  console.log(JSON.stringify(rows.at(-1)));
  save('run_summary.csv',rows);fs.writeFileSync(path.join(out,'runs.json'),JSON.stringify(detail));
}
const stages=[0,1,2,3].map(stage=>({stage:stage+1,...Object.fromEntries(['normal','elite','rare','legendary','god','immortal'].map(rank=>[rank,rules.loot.tiers.reduce((s,r,i)=>s+(r===rank?rules.loot.rates[stage][i]*rules.loot.sizes[i]:0),0)]))}));
save('drop_expectations.csv',stages);
const probabilities=[];
for(let channel=0;channel<7;channel++){
  const opportunities=route.slice(0,-1).map(r=>({n:r.roster.length,p:rules.loot.rates[Math.floor((r.index-1)/3)][channel]}));
  const none=opportunities.reduce((v,x)=>v*(1-x.p)**x.n,1),ev=opportunities.reduce((v,x)=>v+x.n*x.p*rules.loot.sizes[channel],0),variance=opportunities.reduce((v,x)=>v+x.n*x.p*(1-x.p)*rules.loot.sizes[channel]**2,0);
  probabilities.push({channel,tier:rules.loot.tiers[channel],expected:round(ev),variance:round(variance),atLeastOne:round(1-none),note:'32 eligible kills; convoy sacrifice reduces actual rewards'});
}
save('drop_probabilities.csv',probabilities);
const files=['content.mjs','combat.mjs','run.mjs','market.mjs','fixtures.mjs','analyze.mjs','model.test.mjs','contracts.test.mjs'];
fs.writeFileSync(path.join(out,'metadata.json'),JSON.stringify({version:rules.version,node:process.version,date:new Date().toISOString(),sourceCommit:rules.source_commit,runCount:detail.length,cardScenarios:cardRows.length,itemComparisons:effects.length,policies,hashes:Object.fromEntries(files.map(f=>[f,createHash('sha256').update(fs.readFileSync(path.join(root,f))).digest('hex')]))},null,2));
fs.writeFileSync(path.join(root,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
for(const f of ['card_summary.csv','item_summary.csv','run_summary.csv','drop_expectations.csv','drop_probabilities.csv','metadata.json'])fs.copyFileSync(path.join(out,f),path.join(root,f));
console.log('Complete: '+detail.length+' runs, '+effects.length+' paired item comparisons, '+cardRows.length+' card scenarios.');
