import test from 'node:test';
import assert from 'node:assert/strict';
import {rules,cards,equipment,relics,route,classes} from './content.mjs';
import {fixture,actionFor} from './fixtures.mjs';
import {makeCombat,copies,legalActions,applyAction,hitEnemy,hitHero,endTurn,beginTurn,heroStats,playCombat} from './combat.mjs';
import {createMarket,transact} from './market.mjs';
import {simulateRun} from './run.mjs';
const near=(a,b)=>assert.ok(Math.abs(a-b)<1e-7,`${a} != ${b}`);
test('merchant transactions preserve the after-reward timeline and next encounter continuity',()=>{
  const s=simulateRun({classId:'gardien',seed:10001});assert.ok(s.completed);
  for(let i=0;i<s.timeline.length-1;i++){const a=s.timeline[i],b=s.timeline[i+1];assert.equal(a.stockAfterRewards,b.stockAfter+b.cards);assert.equal(a.goldAfter,b.gold);assert.ok(a.hpAfter>=0&&a.hpAfter<=1);}
});
test('guardian retaliation requires absorption and triggers once without recursive direct rewards',()=>{
  const s=fixture('n02',{relicIds:['obole']});s.hero.shield=100;const e=s.enemies[0],hp=e.hp;
  hitHero(s,10,e);near(hp-e.hp,25);hitHero(s,10,e);near(hp-e.hp,25);assert.equal(s.metrics.gold,0);
  beginTurn(s);s.hero.shield=0;hitHero(s,10,e);near(hp-e.hp,25);s.hero.shield=100;hitHero(s,10,null);near(hp-e.hp,25);
});
test('all 729 complete equipment combinations have finite bounded stats',()=>{
  const slots=[...new Set(equipment.map(e=>e.slot))];let count=0;
  const visit=(ids,index)=>{if(index===slots.length){const h=heroStats(12,{resolve:6},ids);assert.ok(Number.isFinite(h.p)&&Number.isFinite(h.maxHp)&&h.maxHp>0&&h.armor<=.4&&h.mpMax>=1&&h.mpMax<=5&&h.handMax<=7);count++;return;}for(const e of equipment.filter(e=>e.slot===slots[index]))visit([...ids,e.id],index+1);};visit([],0);assert.equal(count,729);
});
for(const card of cards)test('upgrade '+card.id+' has a functional witness',()=>{
  const a=fixture(card.id),b=fixture(card.id,{trained:[card.id]});
  if(card.id==='a09')for(const s of [a,b]){s.enemies[1].pos=[3,1];s.enemies[1].mark=40;s.enemies[1].markTurns=2;}
  if(card.id==='i01')for(const s of [a,b])s.hero.hp=s.hero.maxHp*.1;
  const beforeA=legalActions(a),beforeB=legalActions(b);applyAction(a,actionFor(a,card.id));applyAction(b,actionFor(b,card.id));
  const sig=s=>[s.metrics.damage,s.metrics.shieldMade,s.metrics.healing,s.metrics.drawn,s.fields,s.hero.edict,s.hero.shield];
  assert.ok(JSON.stringify(sig(a))!==JSON.stringify(sig(b))||beforeA.length!==beforeB.length,'Upgrade lacks witness');
});
test('hand redraw never recreates a consumed copy',()=>{
  const s=fixture('n01');applyAction(s,actionFor(s,'n01'));const consumed=s.consumed[0];
  for(let i=0;i<20;i++){endTurn(s);beginTurn(s);assert.ok(![...s.hand,...s.draw,...s.discard].includes(consumed));}
});
test('family cap is enforced at combat entry',()=>assert.throws(()=>makeCombat({deck:copies(['n01','n01','n01','n01'])})));
test('thread enables a melee follow-up that is unreachable without its refunded MP',()=>{
  const states=[fixture('n03'),fixture('n03',{relicIds:['thread']})];
  for(const s of states){s.hero.mp=0;s.enemies[0].pos=[3,1];s.enemies[1].pos=[6,0];s.enemies[2].pos=[0,0];const attack=s.allCopies.find(c=>c.family==='n01');s.hand.push(attack.uid);s.draw=s.draw.filter(uid=>uid!==attack.uid);const move=legalActions(s).find(a=>a.kind==='card'&&a.pos.join()==='3,3');applyAction(s,move);}
  assert.ok(!legalActions(states[0]).some(a=>a.kind==='walk'));
  const walk=legalActions(states[1]).find(a=>a.kind==='walk'&&a.pos.join()==='3,2');assert.ok(walk);applyAction(states[1],walk);
  const hit=actionFor(states[1],'n01');assert.ok(hit);applyAction(states[1],hit);assert.ok(states[1].metrics.damage>0);
});
test('lifesteal cap applies after healing modifiers',()=>{
  const s=fixture('n01',{gear:['j_cup','s_care']});s.hero.hp=1;
  for(let i=0;i<50;i++){s.enemies[0].hp=1000;hitEnemy(s,s.enemies[0],100,{direct:true});}
  near(s.hero.hp-1,s.hero.maxHp*.1);near(s.hero.lifestealUsed,s.hero.maxHp*.1);
});
test('enemy values are fixed by encounter level, not player equipment or level',()=>{
  const a=makeCombat({level:1,encounter:route[8]}),b=makeCombat({level:12,attributes:{power:6},gear:['w_blade'],encounter:route[8]});
  assert.deepEqual(a.enemies,b.enemies);
});
test('all 135 legal equipment pairs respect slot, resistance and mobility limits',()=>{
  let n=0;for(let i=0;i<equipment.length;i++)for(let j=i+1;j<equipment.length;j++)if(equipment[i].slot!==equipment[j].slot){const h=heroStats(12,{resolve:6},[equipment[i].id,equipment[j].id]);assert.ok(h.armor<=.4&&h.mpMax>=1&&h.mpMax<=5&&h.maxHp>0);n++;}assert.equal(n,135);
});
for(let i=0;i<relics.length;i++)for(let j=i+1;j<relics.length;j++)test('relic pair '+relics[i].id+' / '+relics[j].id+' resolves finitely',()=>{
  for(const id of ['t02','n06','g05','n03','l01']){
    const s=fixture(id,{relicIds:[relics[i].id,relics[j].id]});applyAction(s,actionFor(s,id));endTurn(s);beginTurn(s);assert.ok(Number.isFinite(s.hero.hp));assert.equal(s.consumed.length,1);assert.ok(s.metrics.gold<=20&&s.hero.mp<=5&&s.hero.shield<=2.5*s.hero.p);
  }
});
for(const map of ['forge','garden','convoy','hourglass','reservoir'])test('room '+map+' has an executable distinct mechanism',()=>{
  const encounter={...route.find(r=>r.map===map),level:10},s=makeCombat({classId:'gardien',level:10,encounter});s.hero.pos=[0,3];
  if(map==='reservoir'){s.hero.ap=4;for(const e of s.enemies)e.mp=0;endTurn(s);assert.equal(s.hazard.reservoir[0],4);beginTurn(s);const action=legalActions(s).find(a=>a.kind==='interact');assert.ok(action);applyAction(s,action);assert.equal(s.hazard.reservoir[0],0);}
  if(map==='forge'){const action=legalActions(s).find(a=>a.kind==='interact'&&a.value===5);applyAction(s,action);assert.equal(s.hazard.forgeRow,5);endTurn(s);assert.equal(s.hazard.forgeRow,1);}
  if(map==='hourglass'){applyAction(s,legalActions(s).find(a=>a.kind==='interact'));endTurn(s);beginTurn(s);assert.equal(s.hazard.clockPending,true);assert.ok(!legalActions(s).some(a=>a.kind==='interact'));endTurn(s);assert.equal(s.hazard.clockPending,false);}
  if(map==='convoy'){applyAction(s,legalActions(s).find(a=>a.kind==='interact'));assert.equal(s.hazard.sealed,true);endTurn(s);assert.ok(!s.enemies.some(e=>e.sacrificed));}
  if(map==='garden'){s.hero.pos=[3,3];for(const e of s.enemies){e.damage=0;e.mp=0;e.range=0;}const hp=s.hero.hp;endTurn(s);assert.ok(s.hero.hp<hp);}
});
function account(){return {classId:'assassin',level:1,attributes:{},gear:[],gearInventory:[],relicInventory:[],trained:['a01'],gold:1000,hp:1,maxHp:110,healing:0,inventory:copies(['n01','n01','n02']),bought:0,sold:0,tradedInput:0,tradedOutput:0,spending:{cards:0,gear:0,heal:0}};}
test('transactions are atomic and replay protected across save/reload',()=>{
  let s=account(),m=createMarket(3,1,'assassin');const request={id:'buy1',kind:'single',family:'n01'};
  assert.equal(transact(s,m,request),true);const before=JSON.stringify([s,m]);assert.equal(transact(s,m,request),false);assert.equal(JSON.stringify([s,m]),before);
  [s,m]=JSON.parse(before);assert.equal(transact(s,m,request),false);assert.throws(()=>transact(s,m,{id:'bad',kind:'single',family:'d01'}));assert.equal(JSON.stringify([s,m]),before);
});
test('bag and targeted normal trade are lossy, finite, and conserve copies',()=>{
  const s=account(),m=createMarket(3,1,'assassin');transact(s,m,{id:'b',kind:'bag',contents:['n01','n02','n03','n04','n05','n06']});assert.equal(s.inventory.length,9);assert.equal(s.gold,964);
  transact(s,m,{id:'t',kind:'trade',copies:s.inventory.slice(0,3).map(c=>c.uid),family:'a02'});assert.equal(s.inventory.length,7);
  transact(s,m,{id:'sale',kind:'sell',copies:s.inventory.map(c=>c.uid)});assert.equal(s.gold,971);assert.equal(s.inventory.length,0);assert.equal(m.trades,1);
});
test('merchant gear, relic, heal and training respec have explicit finite cost',()=>{
  const s=account(),m=createMarket(7,3,'assassin');
  transact(s,m,{id:'g',kind:'gear',item:'w_blade'});transact(s,m,{id:'r',kind:'relic',item:'archive'});transact(s,m,{id:'h',kind:'heal'});transact(s,m,{id:'p',kind:'respec',from:'a01',to:'a02'});
  assert.equal(s.gold,790);near(s.hp,34);assert.deepEqual(s.trained,['a02']);assert.ok(s.gearInventory.includes('w_blade')&&s.relicInventory.includes('archive'));assert.equal(m.heal,0);assert.equal(m.respec,0);
});
test('all cards and rooms terminate with turn pressure even when no cards remain',()=>{
  for(const cls of classes){const r=playCombat({classId:cls.id,deck:[],encounter:route[2]},'fallback');assert.ok(['victory','defeat','timeout'].includes(r.outcome));assert.ok(r.turns<=24);assert.equal(r.consumed.length,0);}
});
