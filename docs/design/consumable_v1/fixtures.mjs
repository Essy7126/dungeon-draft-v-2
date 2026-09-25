import {cards,route,upgradedCard} from './content.mjs';
import {makeCombat,copies,legalActions} from './combat.mjs';
export function fixture(id='n01',{level=10,classId='gardien',spec='',gear=[],relicIds=[],trained=[],boss=false,scenario='ready'}={}){
  const pool=[id,...cards.filter(c=>c.id!==id).slice(0,12).map(c=>c.id)];
  const s=makeCombat({classId,spec,level,gear,relicIds,trained,deck:copies(pool),encounter:{...route[0],map:'plain',hpBudget:20,roster:[boss?'boss':'brute','archer','mage']},seed:3});
  s.hero.pos=[3,5];s.hero.hp=s.hero.maxHp/2;s.hero.shield=0;s.hero.ap=4;s.hero.mp=1;
  s.hand=[s.allCopies[0].uid];s.draw=s.allCopies.slice(1).map(c=>c.uid);s.discard=[];
  const c=upgradedCard(id,trained),distance=Math.max(1,c.min),P=s.hero.p;
  s.enemies[0].pos=[3,5-distance];s.enemies[1].pos=[4,5-distance];s.enemies[2].pos=[1,1];
  for(const e of s.enemies){e.hp=10*P;e.maxHp=10*P;e.armor=0;e.damage=.5*P;e.mp=0;e.range=1;}
  if(c.condition==='marked'||c.op==='stasis'){s.enemies[0].mark=.4*P;s.enemies[0].markTurns=2;}
  if(c.condition==='execute')s.enemies[0].hp=3*P;
  if(c.condition==='moved')s.hero.moved=2;
  if(c.condition==='guarded'||c.op==='guardburst')s.hero.shield=P;
  if(c.condition==='absorbed')s.hero.previousAbsorbed=.1*P;
  if(scenario==='unprepared'){s.hero.moved=0;s.hero.previousAbsorbed=0;s.hero.shield=0;s.enemies[0].mark=0;s.enemies[0].hp=10*P;}
  if(scenario==='armored')s.enemies[0].armor=.4;
  if(scenario==='isolated'){s.enemies[1].pos=[6,0];s.enemies[2].pos=[0,0];}
  if(scenario==='lethal')s.enemies[0].hp=.1*P;
  if(scenario==='wall'){s.map.walls.push([3,4]);if(s.enemies[0].pos.join()==='3,4'){s.enemies[0].pos=[3,3];s.enemies[1].pos=[4,3];}}
  return s;
}
export function actionFor(s,id){
  const uid=s.allCopies.find(x=>x.family===id).uid;
  const options=legalActions(s).filter(a=>a.kind==='card'&&a.uid===uid);
  const target=s.enemies[0].pos;return options.find(a=>a.pos.join()===target.join())??options[0];
}
