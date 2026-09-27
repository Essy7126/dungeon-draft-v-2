import fs from 'node:fs';
import assert from 'node:assert/strict';
import {makeCombat,copies,legalActions,applyAction,endTurn,beginTurn} from '../../consumable_v1/combat.mjs';
import {rules,route} from '../../consumable_v1/content.mjs';
const q=rules.loot.nativeOrShared/12;
const economics={bagPrice:36,bagCopies:6,qSpecificNormal:q,expectedSpecificPerBag:6*q,
  chanceSpecificPerBag:1-(1-q)**6,expectedEitherOfTwoPerBag:6*(2*q),chanceEitherOfTwoPerBag:1-(1-2*q)**6,
  goldPerExpectedSpecific:36/(6*q),goldPerExpectedEitherOfTwo:36/(6*2*q),singlePrice:8,
  twoSingles:16,tradeSaleOpportunityCost:3,tradeNetStockChange:-2,
  limits:'Fresh normal bag; 8 shared + 4 native normals; uniform within 70% native/shared pool. Expected-cost ratios are not an unlimited buying strategy: only two bags per visit.'};
function fixture(hp,trained=[]){
  const s=makeCombat({classId:'assassin',level:5,trained,deck:copies(['a02','a02','n01','n03','a01']),
    encounter:{...route[0],level:5,map:'plain',roster:['brute','brute']},seed:7});
  s.hero.pos=[3,4];s.hero.ap=3;
  s.enemies[0].pos=[3,3];s.enemies[1].pos=[4,3];
  for(const e of s.enemies){e.maxHp=200;e.hp=200;e.armor=0;}
  s.enemies[0].hp=hp;s.enemies[0].mark=18;s.enemies[0].markTurns=2;
  return s;
}
function card(s,family,pos){
  const action=legalActions(s).find(a=>a.kind==='card'&&s.allCopies.find(c=>c.uid===a.uid).family===family&&a.pos.join(',')===pos.join(','));
  assert.ok(action,`Expected legal ${family}`);applyAction(s,action);}
function resolve(hp,transfer){
  const s=fixture(hp,transfer?[]:['a02']);card(s,'a02',[3,3]);
  const firstKilled=s.enemies[0].hp<=0;
  // Emulation only: the proposed on-kill effect is absent from V1.
  if(transfer&&firstKilled){s.enemies[1].mark=8;s.enemies[1].markTurns=1;}
  const afterFirst={firstKilled,hpFirst:s.enemies[0].hp,ap:s.hero.ap,markSecond:s.enemies[1].mark};
  const unlimitedAp=structuredClone(s);unlimitedAp.hero.ap=4;
  const secondA02Legal=legalActions(unlimitedAp).some(a=>a.kind==='card'&&unlimitedAp.allCopies.find(c=>c.uid===a.uid).family==='a02');
  assert.equal(secondA02Legal,false,'Family lock applies even with enough AP');
  const beforeEnd=structuredClone(s);endTurn(beforeEnd);if(beforeEnd.hero.hp>0)beginTurn(beforeEnd);
  assert.equal(beforeEnd.enemies[1].mark,0,'One-turn mark expires before next player turn');
  const walk=legalActions(s).find(a=>a.kind==='walk'&&a.pos.join(',')==='4,4');assert.ok(walk);applyAction(s,walk);
  const fallback=structuredClone(s),basic=legalActions(fallback).find(a=>a.kind==='basic'&&a.target===fallback.enemies[1].id);
  assert.ok(basic);applyAction(fallback,basic);
  assert.equal(fallback.enemies[1].mark,afterFirst.markSecond,'Fallback does not consume mark in current V1');
  card(s,'n01',[4,3]);
  return {...afterFirst,secondA02Legal,damageSecondWithN01:200-s.enemies[1].hp,damageSecondWithBasic:200-fallback.enemies[1].hp,
    totalEffectiveDamage:s.metrics.damage,cards:s.metrics.cards,apAfter:s.hero.ap};
}
const transferCases=[76,80,90].map(hp=>({firstHp:hp,damageUpgrade:resolve(hp,false),transferPrototype:resolve(hp,true)}));
assert.ok(Math.abs(transferCases[0].transferPrototype.totalEffectiveDamage-transferCases[0].damageUpgrade.totalEffectiveDamage-8)<1e-8);
assert.equal(transferCases[1].damageUpgrade.firstKilled,true);assert.equal(transferCases[1].transferPrototype.firstKilled,false);
const result={scope:'V1 rules; proposed transfer emulated by inserting mark only after a kill; not an integrated ability or human balance.',economics,
  pressureBudget:[8,9,10,12,14,16,17].map(turn=>({turn,cumulativeMaxHpFraction:turn<9?0:.025*(turn-8)*(turn-7)/2})),transferCases,
  guardPurpose:'Pressure bypasses armor and guard in V1; guard can still prevent ordinary enemy damage during an urgent turn.'};
const target=new URL('./MICRO_SCENARIOS.json',import.meta.url);
if(process.argv.includes('--check'))assert.deepEqual(JSON.parse(fs.readFileSync(target)),result);else fs.writeFileSync(target,JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({passed:true,result}));
