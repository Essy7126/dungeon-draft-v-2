// Exact probabilities and executable witnesses; never changes the proposed V1.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {rules,cards,classes,route} from '../consumable_v1/content.mjs';
import {makeCombat,copies,legalActions,applyAction,heroStats,random} from '../consumable_v1/combat.mjs';
const out=fileURLToPath(new URL('../../../artifacts/dev/gameplay-critique-2026-09-25/',import.meta.url));
fs.mkdirSync(out,{recursive:true});
let checks=0;
function near(a,b){assert.ok(Math.abs(a-b)<1e-10,`${a} != ${b}`);checks++;}
const sum=a=>a.reduce((s,x)=>s+x,0);
const choose=(n,k)=>{if(k<0||n<k)return 0;let v=1;for(let j=1;j<=k;j++)v=v*(n-j+1)/j;return Math.round(v);};
const both=(n,h)=>1-2*choose(n-3,h)/choose(n,h)+choose(n-6,h)/choose(n,h);
function enumerate(n,h){let total=0,good=0;
  function walk(i,left,a,b){if(!left){total++;if(a&&b)good++;return;}for(let j=i;j<=n-left;j++)walk(j+1,left-1,a||j<3,b||(j>=3&&j<6));}
  walk(0,h,false,false);return {total,probability:good/total};
}
const opening=[15,20,30].map(deck=>{
  const exact=both(deck,5),enumerated=enumerate(deck,5);near(exact,enumerated.probability);
  return {deck,oneFamily:1-choose(deck-3,5)/choose(deck,5),twoFamilies:exact,
    preparedNormalA:1-choose(deck-4,4)/choose(deck-1,4),sixCardHand:both(deck,6),enumeratedHands:enumerated.total};
});
const conv=(a,b)=>{const r=Array(a.length+b.length-1).fill(0);a.forEach((v,i)=>b.forEach((w,j)=>r[i+j]+=v*w));return r;};
function bag(p,k,q){return Array.from({length:k+1},(_,j)=>p*choose(k,j)*q**j*(1-q)**(k-j)+(j===0?1-p:0));}
function arrivals(encounter,q,rarity='normal'){
  let result=[1];const stage=Math.floor((encounter.index-1)/3);
  for(let mob=0;mob<encounter.roster.length;mob++)for(let channel=0;channel<7;channel++)if(rules.loot.tiers[channel]===rarity)
    result=conv(result,bag(rules.loot.rates[stage][channel],rules.loot.sizes[channel],q));
  near(sum(result),1);return result;
}
function distribution(q,subset=route.slice(0,-1),rarity='normal'){
  const d=subset.reduce((pmf,r)=>conv(pmf,arrivals(r,q,rarity)),[1]);near(sum(d),1);return d;
}
const expected=d=>sum(d.map((p,i)=>p*i));
const noFamily=(q,subset,rarity)=>distribution(q,subset,rarity)[0];
const qNormal=.7/cards.filter(c=>c.rarity==='normal'&&['shared','gardien'].includes(c.affinity)).length;
const normal=distribution(1),family=distribution(qNormal),earlyFamily=distribution(qNormal,route.slice(0,3));
const earlyEitherAbsent=2*earlyFamily[0]-noFamily(2*qNormal,route.slice(0,3));
// Fixed demand: consume exactly one copy of a specific starter family per fight.
// Supply arrives AFTER victory. No other consumption, deaths, deck draw or combat.
function continuity(q,copiesPerShop=0){
  let stock=new Map([[3,1]]);const timeline=[];
  for(const r of route){
    const afterSpend=new Map();for(const [n,p]of stock)if(n>=1)afterSpend.set(n-1,(afterSpend.get(n-1)??0)+p);
    const survived=sum([...afterSpend.values()]);timeline.push({fight:r.index,probabilitySufficient:survived});
    if(r.index===12)break;
    const incoming=arrivals(r,q),next=new Map();
    for(const [n,p]of afterSpend)incoming.forEach((w,k)=>{const count=n+k+(r.shopAfter?copiesPerShop:0);next.set(count,(next.get(count)??0)+p*w);});
    stock=next;
  }
  return {probabilitySufficient:timeline.at(-1).probabilitySufficient,timeline};
}
near(continuity(1).probabilitySufficient,1);
near(continuity(0).probabilitySufficient,0);
const supply={qNormal,eligibleKills:sum(route.slice(0,-1).map(r=>r.roster.length)),expectedNormals:expected(normal),
  expectedNativeNormals:expected(normal)*.7*4/12,expectedSharedNormals:expected(normal)*.7*8/12,expectedForeignNormals:expected(normal)*.3,
  expectedSpecificNormal:expected(family),firstThreeNoSpecificFamily:earlyFamily[0],firstThreeMissingEitherOfTwo:earlyEitherAbsent,
  totalAtLeastNine:sum(family.slice(9)),continuousNoMerchant:continuity(qNormal),continuousOneSinglePerMerchant:continuity(qNormal,1),
  continuousSinglePlusTrade:continuity(qNormal,2),
  sensitivityNative45Shared25Foreign30:continuity(.45/4),fixedDemand:'Start with 3; play one chosen normal family once in each of 12 fights. All 32 eligible kills. Five singles: 40 gold. Singles plus five trades: 40 gold and 15 spare normals assumed available. No competing expense model. Budget access, not combat success.'};
// Independent event-by-event sampling checks the stock recurrence, not combats.
const rng=random(9252026),sampleCount=100000,success=[0,0,0];
for(let sample=0;sample<sampleCount;sample++){
  const stock=[3,3,3],viable=[true,true,true];
  for(const r of route){
    for(let policy=0;policy<3;policy++){if(stock[policy]<1)viable[policy]=false;stock[policy]--;}
    if(r.index===12)break;
    let found=0;const stage=Math.floor((r.index-1)/3);
    for(let mob=0;mob<r.roster.length;mob++)for(let channel=0;channel<2;channel++)if(rng()<rules.loot.rates[stage][channel])
      for(let i=0;i<rules.loot.sizes[channel];i++)if(rng()<qNormal)found++;
    for(let policy=0;policy<3;policy++)stock[policy]+=found+(r.shopAfter?policy:0);
  }
  viable.forEach((ok,i)=>{if(ok)success[i]++;});
}
const independentSupplyCheck=[0,1,2].map(policy=>{
  const exact=continuity(qNormal,policy).probabilitySufficient,observed=success[policy]/sampleCount;
  assert.ok(Math.abs(exact-observed)<6*Math.sqrt(exact*(1-exact)/sampleCount));checks++;
  return {copiesPerShop:policy,sampleCount,exact,observed};
});
const rare=distribution(1,undefined,'rare'),specificRare=distribution(.7/2,undefined,'rare');
const rarity=['normal','elite','rare','legendary','god','immortal'].map(rank=>{
  const d=distribution(1,undefined,rank),p=1-d[0];return {rank,expected:expected(d),atLeastOne:p,
    medianFullRoutes:p>=1?1:Math.ceil(Math.log(.5)/Math.log(1-p)),atLeastOneIn20:1-(1-p)**20};
});
const availability={...supply,anyRare:1-rare[0],specificNativeRare:1-specificRare[0],rarity};
const drawWitnesses=[];
for(const before of [5,4,3])for(const upgraded of [false,true]){
  const s=makeCombat({deck:copies(['n08','g01','g02','a01','a02','n01','n02','n03','n04']),trained:upgraded?['n08']:[]});
  s.hand=s.allCopies.slice(0,before).map(c=>c.uid);s.draw=s.allCopies.slice(before).map(c=>c.uid);s.discard=[];
  const drawn=s.metrics.drawn,action=legalActions(s).find(a=>a.kind==='card'&&a.uid===s.allCopies[0].uid);
  assert.ok(action);applyAction(s,action);checks++;
  drawWitnesses.push({before,upgraded,newDraws:s.metrics.drawn-drawn,after:s.hand.length,apRemaining:s.hero.ap,copiesConsumed:s.consumed.length});
}
near(drawWitnesses[0].newDraws,1);near(drawWitnesses[1].newDraws,1);
near(drawWitnesses[2].newDraws,2);near(drawWitnesses[3].newDraws,2);
near(drawWitnesses[4].newDraws,2);near(drawWitnesses[5].newDraws,3);
function seq(ids,{range=1,spec='',basicGuard=false,trained=[],targetHP=1000}={}){
  const s=makeCombat({classId:'gardien',spec,level:5,trained,deck:copies(ids),encounter:{...route[0],map:'plain',roster:['brute'],hpBudget:20}});
  s.enemies[0].pos=[3,5-range];s.enemies[0].hp=targetHP;s.enemies[0].maxHp=targetHP;s.enemies[0].armor=0;
  if(basicGuard){const a=legalActions(s).find(a=>a.kind==='guard');assert.ok(a);applyAction(s,a);checks++;}
  for(const id of ids){const uid=s.allCopies.find(c=>c.family===id).uid;const a=legalActions(s).find(a=>a.kind==='card'&&a.uid===uid);assert.ok(a);applyAction(s,a);checks++;}
  return {ids,spec,basicGuard,range,trained,targetHP,P:s.hero.p,damage:s.metrics.damage,targetRemainingHP:s.enemies[0].hp,guard:s.hero.shield,spentAP:4-s.hero.ap,copies:s.consumed.length};
}
const sequences=[seq(['g01','g02']),seq(['g01','g09']),seq(['g01','g09'],{spec:'bastion'}),seq(['g02'],{basicGuard:true})];
near(sequences[0].damage,60);near(sequences[1].damage,47.6);near(sequences[2].damage,54.5);near(sequences[3].damage,60);
const thresholdWitness=[seq(['g02'],{basicGuard:true,targetHP:62}),seq(['g02'],{basicGuard:true,targetHP:62,trained:['g02']})];
near(thresholdWitness[0].targetRemainingHP,2);near(thresholdWitness[1].targetRemainingHP,0);
const reservoirWitness=[0,6].map(power=>{
  const s=makeCombat({classId:'gardien',level:12,attributes:{power},deck:[],encounter:{...route[8],level:12,roster:['brute'],hpBudget:20}});
  s.hero.pos=[0,3];s.hazard.reservoir=[6,0];s.enemies[0].hp=1000;s.enemies[0].maxHp=1000;s.enemies[0].armor=0;
  const a=legalActions(s).find(a=>a.kind==='interact'&&a.mode==='discharge');assert.ok(a);checks++;applyAction(s,a);
  return {powerPoints:power,heroP:s.hero.p,referenceP:rules.prowess[11],charges:6,damage:s.metrics.damage};
});
near(reservoirWitness[0].damage,336);near(reservoirWitness[1].damage,436.8);
const repercussion={thresholdGuardPForCurrentToBeatHeurt:(1.5-.5)/.6,
  proposedAuditVariantAtP40:{damage:(.7+1.5*.8)*40,remainingGuard:(1.15-.8)*40,extraDamageVsHeurt:(1.9-1.5)*40,guardSacrificed:.8*40},
  currentVariableChoiceFullConversionAtP40:{damage:(.5+.6*1.15)*40,guard:0},
  assumptions:'No equipment/relic/upgrade/resistance/enemy response. Distinct proposal formulas are not merged.'};
const condensation={P40:{baseFireTick:.35*40,convertedGuard:.35*40,commonBriefGuard:.45*40,firmGuard:1.15*40},
  withUpgradedFireAndEmbersTickP:.35+.1+.1,capP:.60,AP:2,copies:1,fireLost:true,
  assumption:'As written: converts exactly one remaining fire tick into guard. Terrain damage prevented by extinguishing is a separate utility.'};
const stats={power:heroStats(12,{power:6}),vitality:heroStats(12,{vitality:6}),resolve:heroStats(12,{resolve:6})};
const statComparison=Object.entries(stats).map(([allocation,s])=>({allocation,hp:s.maxHp,P:s.p,armor:s.armor,guardFirm:1.15*s.p*(1+s.guardBonus)}));
const incomingExamples=[0,300,600].flatMap(baseGuard=>[0,.5,1].map(physicalShare=>({baseGuard,physicalShare,
  power:(675+1.3*baseGuard),vitality:918+baseGuard,resolve:(675+1.3*baseGuard)/(1-.12*physicalShare)})));
const pressure=[9,10,11,12,13,14,15,16,17].map(turn=>({turn,cumulativeMaxHpFraction:.025*(turn-8)*(turn-7)/2}));
const powerKillThresholds=[1.0,1.2,1.3,1.5,2.0,2.6,3.0].map(enemyHpP=>({enemyHpP,baseCopies:Math.ceil(enemyHpP),sixPowerCopies:Math.ceil(enemyHpP/1.3)}));
const damageOnlyUpgrades=cards.filter(c=>Object.keys(c.upgrade).length===1&&'damage'in c.upgrade).length;
near(damageOnlyUpgrades,33);
const raritySlotGroups=Object.fromEntries(classes.map(cls=>[cls.id,cards.filter(c=>c.affinity===cls.id).map(c=>c.rarity)]));
const ownDir=path.dirname(fileURLToPath(import.meta.url));
const sources=['../consumable_v1/content.mjs','../consumable_v1/combat.mjs','../consumable_v1/run.mjs','../consumable_v1/market.mjs','../spell_comparison_2026-09-25/AUDIT_ET_PRIORITES.md','../slay_the_spire_complete_2026-09-25/APPLICATION_CATABASE.md','../wakfu_character_builds_2026-09-25/APPLICATION_CATABASE.md','calculs.mjs'];
const hashes=Object.fromEntries(sources.map(f=>[f,createHash('sha256').update(fs.readFileSync(path.resolve(ownDir,f))).digest('hex')]));
const result={metadata:{date:new Date().toISOString(),node:process.version,sourceVersion:rules.version,checks,hashes,
  scope:'Exact finite-stock/hand probability calculations, deterministic V1 effect witnesses and stated algebraic counterfactuals. Not Godot validation or player testing.'},
  opening,availability,independentSupplyCheck,drawWitnesses,sequences,thresholdWitness,reservoirWitness,repercussion,condensation,statComparison,incomingExamples,pressure,powerKillThresholds,damageOnlyUpgrades,raritySlotGroups};
fs.writeFileSync(path.join(out,'calculs.json'),JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({checks,opening,availability:{...availability,continuousNoMerchant:availability.continuousNoMerchant.probabilitySufficient,continuousOneSinglePerMerchant:availability.continuousOneSinglePerMerchant.probabilitySufficient,sensitivityNative45Shared25Foreign30:availability.sensitivityNative45Shared25Foreign30.probabilitySufficient},drawWitnesses,sequences,statComparison,pressure},null,2));
