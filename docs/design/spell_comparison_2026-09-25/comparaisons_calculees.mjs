// Reproducible comparisons, using the independent V1 reference model.
// These witnesses do not validate Godot, win rates, or player enjoyment.
import fs from 'node:fs';
import {fileURLToPath} from 'node:url';
import {makeCombat,copies,legalActions,applyAction} from '../consumable_v1/combat.mjs';
import {cardById,route} from '../consumable_v1/content.mjs';
import assert from 'node:assert/strict';

function sequence(ids,{range=1,spec=''}={}){
  const s=makeCombat({classId:'gardien',spec,level:5,deck:copies(ids),
    encounter:{...route[0],map:'plain',roster:['brute'],hpBudget:20},seed:5});
  s.hero.pos=[3,5];
  s.enemies[0].pos=[3,5-range];
  s.enemies[0].hp=1000;s.enemies[0].maxHp=1000;s.enemies[0].armor=0;
  const log=[];
  for(const id of ids){
    const uid=s.allCopies.find(c=>c.family===id).uid;
    const action=legalActions(s).find(a=>a.kind==='card'&&a.uid===uid&&
      (cardById[id].op==='guard'||a.pos.join(',')===s.enemies[0].pos.join(',')));
    assert.ok(action,'Missing legal action: '+id);
    applyAction(s,action);
    log.push({id,damage:s.metrics.damage,shield:s.hero.shield,apLeft:s.hero.ap,copiesConsumed:s.consumed.length});
  }
  return {cards:ids,spec,prowess:s.hero.p,log};
}
const choose=(n,k)=>{
  if(k<0||k>n)return 0;
  let r=1;for(let i=1;i<=k;i++)r=r*(n-i+1)/i;return Math.round(r);
};
const both=(n,hand,a=3,b=3)=>1-choose(n-a,hand)/choose(n,hand)-choose(n-b,hand)/choose(n,hand)+choose(n-a-b,hand)/choose(n,hand);
// Independently enumerate all opening hands to check the probability formula.
function enumerated(n,k){let total=0,ok=0;
  function walk(start,left,a,b){if(!left){total++;if(a&&b)ok++;return;}
    for(let i=start;i<=n-left;i++)walk(i+1,left-1,a||i<3,b||(i>=3&&i<6));}
  walk(0,k,false,false);return ok/total;
}
const probabilities=[15,30].flatMap(n=>[5,6].map(hand=>{
  const p=both(n,hand);assert.ok(Math.abs(p-enumerated(n,hand))<1e-12);
  return {deck:n,hand,copiesA:3,copiesB:3,bothProbability:p};
}));
const sequences=[sequence(['a01','a02']),sequence(['g01','g02']),sequence(['g01','g09']),
  sequence(['g01','g09'],{spec:'bastion'}),sequence(['g03']),sequence(['g06']),
  sequence(['r04'],{range:3}),sequence(['r06'],{range:3})];
const nearly=(a,b)=>assert.ok(Math.abs(a-b)<1e-9,`${a} != ${b}`);
nearly(sequences[0].log.at(-1).damage,92);
nearly(sequences[1].log.at(-1).damage,60);
nearly(sequences[2].log.at(-1).damage,47.6);
nearly(sequences[3].log.at(-1).damage,54.5);
const result={scope:'V1 reference model only. P=40, no equipment/relic/upgrades, no armor, no enemy action. Guardian has no outgoing damage passive here. Bastion used only where stated. One surviving target. Opening-hand probabilities: uniform draw without replacement, no mulligan.',probabilities,sequences};
fs.writeFileSync(fileURLToPath(new URL('./calculs_comparatifs.json',import.meta.url)),JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify(result,null,2));
