// Isolated experiments on the proposed V1, not on the public Godot game.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {classes,cardById} from '../consumable_v1/content.mjs';
import {simulateRun as originalRun} from '../consumable_v1/run.mjs';

const here=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(here,'../../..');
const out=path.join(root,'artifacts/dev/waven-investigation-2026-09-26');
fs.mkdirSync(out,{recursive:true});
const sources=Object.fromEntries(['run','combat','content','market'].map(name=>[name,fs.readFileSync(new URL(`../consumable_v1/${name}.mjs`,import.meta.url),'utf8')]));
const hashes=Object.fromEntries(Object.entries(sources).map(([name,source])=>[name,createHash('sha256').update(source).digest('hex')]));
const focus={assassin:['a01','a02'],gardien:['g01','g02'],arpenteur:['r01','r02'],thaumaturge:['t03','t02']};
const variants=['baseline','opening','restock'];
function replaceOnce(source,from,to){assert.equal(source.split(from).length,2,`Unique anchor: ${from}`);return source.replace(from,to);}
const helper=`
const auditFocus=${JSON.stringify(focus)};
function auditRestock(state,market){
  state.auditPurchases??=[];
  for(const family of auditFocus[state.classId]){
    const count=()=>state.inventory.filter(c=>c.family===family).length;
    if(count()<2&&market.singles[family]>0&&state.gold>=rules.economy.buy.normal){
      transact(state,market,{id:'focus_single_'+family,kind:'single',family});
      state.auditPurchases.push({visit:market.visit,kind:'single',family});
    }
    if(count()>=2||market.trades<=0||state.inventory.length<18)continue;
    const counts={};for(const c of state.inventory)counts[c.family]=(counts[c.family]??0)+1;
    const candidates=state.inventory.filter(c=>cardById[c.family].rarity==='normal'&&!auditFocus[state.classId].includes(c.family))
      .sort((a,b)=>cardUtility(cardById[a.family],state.classId)-cardUtility(cardById[b.family],state.classId));
    const spare=[];for(const c of candidates){if(counts[c.family]>1){spare.push(c.uid);counts[c.family]--;}if(spare.length===3)break;}
    if(spare.length===3){
      transact(state,market,{id:'focus_trade_'+family,kind:'trade',family,copies:spare});
      state.auditPurchases.push({visit:market.visit,kind:'trade',family});
    }
  }
}
`;
const modules={};
for(const variant of variants){
  let combat=sources.combat;
  const pin=variant==='opening'?`
  // Pin one existing, identifiable normal copy. No creation, free play or extra slot.
  const preferred=${JSON.stringify(Object.fromEntries(Object.entries(focus).map(([k,v])=>[k,v[0]])))}[classId];
  const pinned=s.allCopies.find(c=>c.family===preferred)
    ??s.allCopies.find(c=>cardById[c.family].rarity==='normal'&&cardById[c.family].affinity===classId)
    ??s.allCopies.find(c=>cardById[c.family].rarity==='normal');
  s.auditPinned=pinned?.uid??null;
  if(pinned&&!s.hand.includes(pinned.uid)){
    const index=s.draw.indexOf(pinned.uid);
    assertAudit(index>=0&&s.hand.length>0,'Pinned copy unavailable');
    const displaced=s.hand.at(-1);s.hand[s.hand.length-1]=pinned.uid;s.draw[index]=displaced;
  }
  const partition=[...s.hand,...s.draw,...s.discard,...s.consumed];
  assertAudit(partition.length===s.allCopies.length&&new Set(partition).size===partition.length,'Copy conservation');
  assertAudit(s.hand.length===Math.min(s.hero.handMax,s.allCopies.length),'Hand cap');
  assertAudit(!pinned||s.hand.includes(pinned.uid),'Opening guarantee');
  `:'';
  combat=replaceOnce(combat,'beginTurn(s);if(stats.mods.openingShield)',`beginTurn(s);${pin}\n  s.auditOpening=s.hand.map(uid=>s.allCopies.find(c=>c.uid===uid).family);\n  if(stats.mods.openingShield)`);
  combat+='\nfunction assertAudit(value,message){if(!value)throw Error(message);}\n';
  combat=combat.replace("'./content.mjs'",JSON.stringify(new URL('../consumable_v1/content.mjs',import.meta.url).href));
  const combatPath=path.join(out,variant+'_combat.mjs');fs.writeFileSync(combatPath,combat);
  let run=sources.run;
  run=replaceOnce(run,'const deck=prepareDeck(s.inventory,classId,deckCap);',`const deck=prepareDeck(s.inventory,classId,deckCap);
    const auditFocusStock=Object.fromEntries(auditFocus[classId].map(id=>[id,s.inventory.filter(c=>c.family===id).length]));
    const auditFocusDeck=Object.fromEntries(auditFocus[classId].map(id=>[id,deck.filter(c=>c.family===id).length]));`);
  run=replaceOnce(run,'lootEnemies:result.lootEnemies,metrics:result.metrics}',`lootEnemies:result.lootEnemies,metrics:result.metrics,audit:{stock:auditFocusStock,deck:auditFocusDeck,opening:result.state.auditOpening,pinned:result.state.auditPinned??null}}`);
  run+=helper;
  if(variant==='restock'){
    run=replaceOnce(run,'  if(economy){\n', '  if(economy)auditRestock(state,market);\n  if(economy){\n');
    run=replaceOnce(run,'for(let i=0;i<rules.economy.tradesPerVisit;i++){','for(let i=0;i<rules.economy.tradesPerVisit;i++){\n      if(market.trades<=0)break;');
    // Avoid disposing of the two deliberately restocked families later in this shop.
    run=run.replaceAll("state.inventory.filter(x=>cardById[x.family].rarity==='normal')","state.inventory.filter(x=>cardById[x.family].rarity==='normal'&&!auditFocus[state.classId].includes(x.family))");
  }
  for(const name of ['content','combat','market'])run=run.replace(`'./${name}.mjs'`,JSON.stringify(name==='combat'?pathToFileURL(combatPath).href:new URL(`../consumable_v1/${name}.mjs`,import.meta.url).href));
  const runPath=path.join(out,variant+'_run.mjs');fs.writeFileSync(runPath,run);
  modules[variant]={run:await import(pathToFileURL(runPath)),combat:await import(pathToFileURL(combatPath))};
}

// Engine-level contracts, including tiny and normal-free decks.
for(const cl of classes){
  for(let seed=1;seed<=30;seed++){
    const s=modules.opening.combat.makeCombat({classId:cl.id,seed});
    assert.equal(s.auditOpening.length,5);assert.equal(s.auditOpening.includes(focus[cl.id][0]),true);
  }
  for(const deck of [[],[{uid:'rare',family:cl.id==='gardien'?'g09':'a09'}],[{uid:'one',family:focus[cl.id][0]}]]){
    const s=modules.opening.combat.makeCombat({classId:cl.id,deck});assert.equal(s.hand.length,deck.length);
    assert.equal(s.allCopies.length,deck.length);
  }
}
const compact=r=>({won:r.completed,failureFight:r.failureFight,level:r.level,consumed:r.consumed,stock:r.inventory.length,gold:r.gold,
  spending:r.spending,bought:r.bought,tradedInput:r.tradedInput,tradedOutput:r.tradedOutput,sold:r.sold,uses:r.cardUses,
  targeted:r.auditPurchases??[],timeline:r.timeline});
const stripInstrumentation=r=>{const clone=structuredClone(r);for(const t of clone.timeline)delete t.audit;return clone;};
const parityOptions={classId:'assassin',specIndex:0,seed:27001};
assert.deepEqual(stripInstrumentation(modules.baseline.run.simulateRun(parityOptions)),originalRun(parityOptions),'Instrumented baseline must reproduce original');
if(process.argv.includes('--contracts-only')){console.log(JSON.stringify({contracts:'passed',openingCases:132,baselineParity:true,hashes}));process.exit(0);}
const rows=[];
for(const cl of classes){
  for(let seed=27001;seed<=27010;seed++){
    const row={classId:cl.id,spec:cl.specs[0],seed};
    for(const variant of variants)row[variant]=compact(modules[variant].run.simulateRun({classId:cl.id,specIndex:0,seed}));
    rows.push(row);console.log(JSON.stringify({class:cl.id,seed,wins:variants.map(v=>row[v].won)}));
    fs.writeFileSync(path.join(out,'runs.partial.json'),JSON.stringify({complete:false,rows},null,2)+'\n');
  }
}
const average=a=>a.reduce((s,v)=>s+v,0)/a.length;
const summarize=list=>Object.fromEntries(variants.map(v=>{const r=list.map(x=>x[v]);const fights=r.flatMap(x=>x.timeline);return[v,{
  wins:r.filter(x=>x.won).length,n:r.length,fightsWon:average(r.map(x=>x.timeline.filter(t=>t.outcome==='victory').length)),
  consumed:average(r.map(x=>x.consumed)),endingGold:average(r.map(x=>x.gold)),cardSpending:average(r.map(x=>x.spending.cards)),
  focusStockBoth:fights.filter(t=>Object.values(t.audit.stock).every(n=>n>0)).length/fights.length,
  focusDeckBoth:fights.filter(t=>Object.values(t.audit.deck).every(n=>n>0)).length/fights.length,
  focusOpeningBoth:fights.filter(t=>Object.keys(t.audit.stock).every(id=>t.audit.opening.includes(id))).length/fights.length,
  targetedSingles:r.reduce((n,x)=>n+x.targeted.filter(t=>t.kind==='single').length,0),targetedTrades:r.reduce((n,x)=>n+x.targeted.filter(t=>t.kind==='trade').length,0),
  onlyVariant:list.filter(x=>x[v].won&&!x.baseline.won).length,onlyBaseline:list.filter(x=>!x[v].won&&x.baseline.won).length,
  sharedVictoryN:list.filter(x=>x[v].won&&x.baseline.won).length,
  sharedVictoryConsumedDelta:average(list.filter(x=>x[v].won&&x.baseline.won).map(x=>x[v].consumed-x.baseline.consumed))
}];}));
const result={complete:true,metadata:{date:new Date().toISOString(),node:process.version,sourceHashes:hashes,
  variants,focus,seedFirst:27001,seedLast:27010,specIndex:0,deckCap:20,policy:'planner',contracts:{openingCases:132,baselineParity:true},
  interpretation:'Exploratory paired V1 model runs, not public Godot or human balance. Opening pins one existing normal copy. Restock targets two normals to count 2, after healing, before other purchases; finite singles/trades, reserve >=18 before focus trade, preserve last other normal and protect focus from generic trades/sales. No opening+restock combined arm.'},
  summary:summarize(rows),byClass:Object.fromEntries(classes.map(c=>[c.id,summarize(rows.filter(r=>r.classId===c.id))])),rows};
assert.equal(rows.length,40);
fs.writeFileSync(path.join(out,'runs.json'),JSON.stringify(result,null,2)+'\n');
fs.writeFileSync(path.join(here,'EXPERIENCES.json'),JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({complete:true,summary:result.summary,byClass:result.byClass}));
