import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {simulateRun as originalRun} from '../../consumable_v1/run.mjs';
import {classes} from '../../consumable_v1/content.mjs';

export const here=path.dirname(fileURLToPath(import.meta.url));
export const out=path.resolve(here,'../../../../artifacts/dev/waven-investigation-2026-09-26/suite_02');
fs.mkdirSync(out,{recursive:true});
const sourceUrl=name=>new URL(`../../consumable_v1/${name}.mjs`,import.meta.url);
const sources=Object.fromEntries(['run','combat','content','market'].map(n=>[n,fs.readFileSync(sourceUrl(n),'utf8')]));
export const hashes=Object.fromEntries(Object.entries(sources).map(([n,s])=>[n,createHash('sha256').update(s).digest('hex')]));
export const focus={assassin:['a01','a02'],gardien:['g01','g02'],arpenteur:['r01','r02'],thaumaturge:['t03','t02']};
export const variants=Array.from({length:8},(_,mask)=>({id:'m'+mask,mask,policy:'planner'}));
variants.push({id:'urgence',mask:0,policy:'urgency'},{id:'phase',mask:0,policy:'phase'},{id:'urgence_m7',mask:7,policy:'urgency'});
const replace=(s,a,b)=>{assert.equal(s.split(a).length,2,`Unique anchor ${a}`);return s.replace(a,b);};

function shopHelper(mask){return `
const auditFocus=${JSON.stringify(focus)};
function auditRestock(state,market){
  state.auditPurchases??=[];
  for(const family of auditFocus[state.classId]){
    const count=()=>state.inventory.filter(c=>c.family===family).length;
    if(${!!(mask&1)}&&count()<2&&market.singles[family]>0&&state.gold>=rules.economy.buy.normal){
      transact(state,market,{id:'focus_single_'+family,kind:'single',family});
      state.auditPurchases.push({visit:market.visit,kind:'single',family});
    }
    if(!${!!(mask&2)}||count()>=2||market.trades<=0||state.inventory.length<18)continue;
    const counts={};for(const c of state.inventory)counts[c.family]=(counts[c.family]??0)+1;
    const candidates=state.inventory.filter(c=>cardById[c.family].rarity==='normal'&&!auditFocus[state.classId].includes(c.family))
      .sort((a,b)=>cardUtility(cardById[a.family],state.classId)-cardUtility(cardById[b.family],state.classId));
    const spare=[];for(const c of candidates){if(counts[c.family]>1){spare.push(c.uid);counts[c.family]--;}if(spare.length===3)break;}
    if(spare.length===3){transact(state,market,{id:'focus_trade_'+family,kind:'trade',family,copies:spare});state.auditPurchases.push({visit:market.visit,kind:'trade',family});}
  }
}
`;}
const phaseChooser=`export function auditPhaseScore(s,p){
  if(outcome(s)!=='active')return evaluate(s,p);
  const future=clone(s);endTurn(future);
  if(outcome(future)!=='active')return evaluate(future,p);
  // These defenses expire before the next hero turn. Do not reward them twice.
  future.hero.shield=0;future.hero.counter=0;future.hero.edict=false;
  // evaluate subtracts an estimated threat; the phase has just resolved it exactly.
  return evaluate(future,p)+estimatedThreat(future)/future.hero.p*p.safety;
}
export function chooseAction(s,policy='balanced'){
  const p=typeof policy==='string'?policies[policy]:policy,base=auditPhaseScore(s,p),options=[];
  for(const action of legalActions(s)){
    if(policy==='fallback'&&action.kind==='card')continue;
    const next=clone(s);applyAction(next,action,{validate:false});options.push({action,next,score:auditPhaseScore(next,p)});
  }
  options.sort((a,b)=>b.score-a.score);
  let best=options[0];
  if(p.lookahead>=2)for(const option of options.slice(0,6))for(const action of legalActions(option.next)){
    const next=clone(option.next);applyAction(next,action,{validate:false});const score=auditPhaseScore(next,p);
    if(!best||score>best.score+1e-8)best={action:option.action,score,next};
  }
  return best&&best.score>base+1e-7?best.action:null;
}
`;
export const modules={};
for(const variant of variants){
  let combat=sources.combat;
  if(variant.policy==='urgency'){
    combat=replace(combat,"const p=typeof policy==='string'?policies[policy]:policy,h=s.hero,P=h.p;",`const original=typeof policy==='string'?policies[policy]:policy,h=s.hero,P=h.p;
  let forecast=0;for(let t=s.turn;t<s.turn+4;t++)forecast+=h.maxHp*rules.collapseStep*Math.max(0,t-rules.collapseStart+1);
  const urgency=Math.min(1,forecast/Math.max(1,h.hp));
  const p={...original,safety:original.safety*(1-.85*urgency),resource:original.resource*(1-urgency)};`);
    combat=replace(combat,'value-=Math.max(0,nearest-2)*.075;','value-=Math.max(0,nearest-2)*.075+urgency*.4*Math.max(0,nearest-1);');
  }
  if(variant.policy==='phase'){
    const start=combat.indexOf('export function chooseAction('),end=combat.indexOf('export function playCombat(');
    assert.ok(start>0&&end>start);combat=combat.slice(0,start)+phaseChooser+combat.slice(end);
  }
  combat=replace(combat,"'./content.mjs'",JSON.stringify(sourceUrl('content').href));
  const combatPath=path.join(out,variant.id+'_combat.mjs');fs.writeFileSync(combatPath,combat);
  let run=sources.run;
  run=replace(run,'const deck=prepareDeck(s.inventory,classId,deckCap);',`const deck=prepareDeck(s.inventory,classId,deckCap);
    const auditFocusStock=Object.fromEntries(auditFocus[classId].map(id=>[id,s.inventory.filter(c=>c.family===id).length]));`);
  run=replace(run,'lootEnemies:result.lootEnemies,metrics:result.metrics}',`lootEnemies:result.lootEnemies,metrics:result.metrics,auditFocusStock}`);
  run+=shopHelper(variant.mask);
  if(variant.mask&3){
    run=replace(run,'  if(economy){\n','  if(economy)auditRestock(state,market);\n  if(economy){\n');
    run=replace(run,'for(let i=0;i<rules.economy.tradesPerVisit;i++){','for(let i=0;i<rules.economy.tradesPerVisit;i++){\n      if(market.trades<=0)break;');
  }
  if(variant.mask&4){
    const from="state.inventory.filter(x=>cardById[x.family].rarity==='normal')";assert.equal(run.split(from).length,3);
    run=run.replaceAll(from,"state.inventory.filter(x=>cardById[x.family].rarity==='normal'&&!auditFocus[state.classId].includes(x.family))");
  }
  for(const name of ['content','combat','market'])run=replace(run,`'./${name}.mjs'`,JSON.stringify(name==='combat'?pathToFileURL(combatPath).href:sourceUrl(name).href));
  const runPath=path.join(out,variant.id+'_run.mjs');fs.writeFileSync(runPath,run);
  modules[variant.id]={...await import(pathToFileURL(runPath)),combat:await import(pathToFileURL(combatPath))};
}
export function compact(r){return {won:r.completed,failureFight:r.failureFight,level:r.level,consumed:r.consumed,stock:r.inventory.length,gold:r.gold,
  spending:r.spending,bought:r.bought,tradedInput:r.tradedInput,tradedOutput:r.tradedOutput,sold:r.sold,dropped:r.dropped,uses:r.cardUses,
  targeted:r.auditPurchases??[],timeline:r.timeline};}
const strip=r=>{const x=structuredClone(r);for(const t of x.timeline)delete t.auditFocusStock;return x;};
export function contracts(){
  const options={classId:'assassin',seed:28001,specIndex:0};
  assert.deepEqual(strip(modules.m0.simulateRun(options)),originalRun(options));
  const previous=JSON.parse(fs.readFileSync(new URL('../EXPERIENCES.json',import.meta.url)));
  const reference=previous.rows.find(r=>r.classId==='assassin'&&r.seed===27001).restock;
  const actual=compact(modules.m7.simulateRun({classId:'assassin',seed:27001,specIndex:0}));
  for(const key of ['won','failureFight','consumed','stock','gold','spending','bought','tradedInput','tradedOutput','sold','uses','targeted'])assert.deepEqual(actual[key],reference[key],key);
  for(const cl of classes){
    const state=modules.phase.combat.makeCombat({classId:cl.id,seed:44});const before=structuredClone(state);
    assert.ok(Number.isFinite(modules.phase.combat.auditPhaseScore(state,modules.phase.combat.policies.planner)));assert.deepEqual(state,before);
    assert.deepEqual(modules.urgence.combat.chooseAction(state,'planner'),modules.m0.combat.chooseAction(state,'planner'),'No urgency before pressure horizon');
  }
  return {baselineParity:true,previousCompositeParity:true,phaseMutationCases:4,earlyUrgencyParityCases:4};
}
