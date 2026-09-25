import test from 'node:test';
import assert from 'node:assert/strict';
import {rules,cards,classes,cardById,equipment,relics,route,upgradedCard} from './content.mjs';
import {makeCombat,copies,initialCopies,heroStats,legalActions,applyAction,endTurn,beginTurn,hitHero,hitEnemy,addGuard,heal,lineOfSight,outcome,playCombat,random} from './combat.mjs';
import {rollLoot,prepareDeck,simulateRun,seedFor,shop} from './run.mjs';

export function fixture(id='n01',{level=10,classId='gardien',spec='',gear=[],relicIds=[],trained=[],boss=false}={}){
  const pool=[id,...cards.filter(c=>c.id!==id).slice(0,12).map(c=>c.id)];
  const s=makeCombat({classId,spec,level,gear,relicIds,trained,deck:copies(pool),encounter:{...route[0],map:'plain',hpBudget:20,roster:[boss?'boss':'brute','archer','mage']},seed:3});
  s.hero.pos=[3,5];s.hero.hp=s.hero.maxHp/2;s.hero.shield=0;s.hero.ap=4;s.hero.mp=1;
  s.hand=[s.allCopies[0].uid];s.draw=s.allCopies.slice(1).map(c=>c.uid);s.discard=[];
  const c=upgradedCard(id,trained),distance=Math.max(1,c.min);
  s.enemies[0].pos=[3,5-distance];s.enemies[1].pos=[4,5-distance];s.enemies[2].pos=[1,1];
  for(const e of s.enemies){e.hp=1000;e.maxHp=1000;e.armor=0;e.damage=50;e.mp=0;e.range=1;}
  if(c.condition==='marked'||c.op==='stasis'){s.enemies[0].mark=40;s.enemies[0].markTurns=2;}
  if(c.condition==='execute')s.enemies[0].hp=300;
  if(c.condition==='moved')s.hero.moved=2;
  if(c.condition==='guarded'||c.op==='guardburst')s.hero.shield=100;
  if(c.condition==='absorbed')s.hero.previousAbsorbed=10;
  return s;
}
export function actionFor(s,id){
  const uid=s.allCopies.find(x=>x.family===id).uid;
  const options=legalActions(s).filter(a=>a.kind==='card'&&a.uid===uid);
  const target=s.enemies[0].pos;return options.find(a=>a.pos.join()===target.join())??options[0];
}
const nearly=(a,b)=>assert.ok(Math.abs(a-b)<1e-7,`${a} != ${b}`);

test('closed manifest has 48 cards, all six ranks, 18 gear, 8 relics, 12 fights',()=>{
  assert.equal(cards.length,48);assert.equal(equipment.length,18);assert.equal(relics.length,8);assert.equal(route.length,12);
  assert.equal(new Set(cards.map(c=>c.id)).size,48);
  const expected={normal:24,elite:12,rare:8,legendary:2,god:1,immortal:1};
  for(const [rank,count]of Object.entries(expected))assert.equal(cards.filter(c=>c.rarity===rank).length,count);
  for(const c of cards){assert.ok(c.ap>=1&&c.ap<=4);assert.ok(c.min<=c.max);assert.ok(Object.keys(c.upgrade).length>0);}
});

for(const c of cards)test(`card ${c.id}: legal resolution, one physical copy, AP and meaningful effect`,()=>{
  const s=fixture(c.id),before=structuredClone(s),action=actionFor(s,c.id);assert.ok(action,'No legal witness');
  applyAction(s,action);assert.equal(s.consumed.length,1);assert.equal(s.consumed[0],before.hand[0]);assert.ok(!s.hand.includes(before.hand[0]));
  assert.equal(s.hero.ap,c.endTurn?0:4-c.ap);assert.equal(s.metrics.cards,1);
  const evidence=s.metrics.damage>0||s.metrics.shieldMade>before.metrics.shieldMade||s.metrics.healing>before.metrics.healing||
    s.metrics.moves>0||s.metrics.drawn>before.metrics.drawn||s.metrics.displaced>0||s.fields.length>0||s.hero.edict||
    s.enemies.some((e,i)=>e.stun>before.enemies[i].stun||e.weaken>before.enemies[i].weaken);
  assert.ok(evidence,'Card produced no observable effect');
  assert.ok(!legalActions(s).some(a=>a.kind==='card'&&a.uid===before.hand[0]));
  assert.ok(s.hero.hp<=s.hero.maxHp&&s.hero.ap>=0);
});

test('invalid action is rejected without AP loss or consumed copy',()=>{
  const s=fixture('n01'),snapshot=JSON.stringify(s);assert.throws(()=>applyAction(s,{kind:'card',uid:s.hand[0],pos:[0,0]}));assert.equal(JSON.stringify(s),snapshot);
});
test('duplicate family cannot be played twice in a turn; unused copies survive',()=>{
  const s=fixture('n01');const extra={uid:'extra',family:'n01'};s.allCopies.push(extra);s.hand.push(extra.uid);
  applyAction(s,actionFor(s,'n01'));assert.ok(s.hand.includes('extra'));assert.ok(!legalActions(s).some(a=>a.kind==='card'&&a.uid==='extra'));
  endTurn(s);assert.ok(s.discard.includes('extra'));assert.ok(!s.discard.includes(s.consumed[0]));beginTurn(s);assert.ok(!s.hand.includes(s.consumed[0]));
});
test('named coefficients and prepared mark combine before armor; mark consumed once',()=>{
  const s=fixture('a02');s.enemies[0].armor=.20;applyAction(s,actionFor(s,'a02'));
  nearly(1000-s.enemies[0].hp,(95+55+40)*.8);assert.equal(s.enemies[0].mark,0);
});
test('armor piercing ignores physical reduction; magic uses separate channel',()=>{
  const a=fixture('a07');a.enemies[0].armor=.4;applyAction(a,actionFor(a,'a07'));nearly(1000-a.enemies[0].hp,90);
  const b=fixture('t01');b.enemies[0].armor=.4;applyAction(b,actionFor(b,'t01'));nearly(1000-b.enemies[0].hp,65);
});
test('drain heals on a lethal hit using actual HP removed, not overkill',()=>{
  const s=fixture('t07');s.enemies[0].hp=10;const hp=s.hero.hp;applyAction(s,actionFor(s,'t07'));nearly(s.hero.hp-hp,5);
});
test('guard burst consumes shield once and limits conversion',()=>{
  const s=fixture('g09');s.hero.shield=1000;applyAction(s,actionFor(s,'g09'));nearly(s.metrics.damage,170);assert.equal(s.hero.shield,0);
});
test('guard cap and expiration prevent indefinite hoarding',()=>{
  const s=fixture();addGuard(s,10000);nearly(s.hero.shield,250);beginTurn(s);assert.equal(s.hero.shield,0);
});
test('stasis requires a mark, prevents one activation and has shared immunity',()=>{
  const s=fixture('a09');applyAction(s,actionFor(s,'a09'));assert.equal(s.enemies[0].stun,1);assert.equal(s.enemies[0].immune,4);
  endTurn(s);assert.equal(s.enemies[0].stun,0);assert.equal(s.enemies[0].immune,3);assert.equal(s.metrics.stuns,1);
  const unmarked=fixture('a09');unmarked.enemies[0].mark=0;assert.ok(!actionFor(unmarked,'a09'));
});
test('boss responds to stasis by weakening, not losing its full activation',()=>{
  const s=fixture('a09',{boss:true});applyAction(s,actionFor(s,'a09'));assert.equal(s.enemies[0].stun,0);assert.equal(s.enemies[0].weaken,.25);
});
test('boss movement is capped and boss swap illegal',()=>{
  const s=fixture('g06',{boss:true}),before=[...s.enemies[0].pos];applyAction(s,actionFor(s,'g06'));assert.equal(Math.abs(before[1]-s.enemies[0].pos[1]),1);
  const b=fixture('r08',{boss:true});assert.ok(!legalActions(b).some(a=>a.kind==='card'&&a.pos.join()===b.enemies[0].pos.join()));
});
test('a blocked push does not create collision damage',()=>{
  const s=fixture('n04');s.map.walls.push([3,3]);applyAction(s,actionFor(s,'n04'));nearly(s.metrics.damage,25);assert.equal(s.metrics.displaced,0);
});
test('walls block line of sight while teleport can cross them',()=>{
  const s=fixture('a05');s.map.walls.push([3,4]);assert.equal(lineOfSight(s,[3,5],[3,3]),false);
  assert.ok(legalActions(s).some(a=>a.kind==='card'&&a.pos.join()==='3,3'));
});
test('edict prevents only one lethal impact and never reverses consumption',()=>{
  const s=fixture('d01');s.hero.hp=20;applyAction(s,actionFor(s,'d01'));hitHero(s,500);assert.equal(s.hero.hp,1);assert.equal(s.hero.edict,false);hitHero(s,500);assert.equal(s.hero.hp,0);assert.equal(s.consumed.length,1);
});
test('renew restores health only and ends the activation',()=>{
  const s=fixture('i01');s.hero.hp=50;const before=[...s.hero.pos];applyAction(s,actionFor(s,'i01'));nearly(s.hero.hp,410);assert.deepEqual(s.hero.pos,before);assert.equal(s.hero.ap,0);assert.equal(s.hero.mp,0);assert.equal(s.consumed.length,1);
});
test('save/reload preserves exact continuation including draw and consumption',()=>{
  const a=fixture('n08');applyAction(a,actionFor(a,'n08'));const b=JSON.parse(JSON.stringify(a));endTurn(a);beginTurn(a);endTurn(b);beginTurn(b);assert.deepEqual(a,b);
});
test('pressure damages through guard and edict after the advertised turn',()=>{
  const s=fixture('d01');s.turn=9;s.hero.edict=true;s.hero.shield=10000;for(const e of s.enemies){e.range=0;e.damage=0;}const hp=s.hero.hp;endTurn(s);nearly(hp-s.hero.hp,s.hero.maxHp*.025);
});

function signature(gear){
  const st=heroStats(10,{},gear),a=fixture('n01',{gear});const hp=a.hero.hp;applyAction(a,actionFor(a,'n01'));hitHero(a,50,{hp:1000,armor:0,pos:[3,4],shield:0},'physical');
  const b=fixture('t01',{gear});applyAction(b,actionFor(b,'t01'));
  const c=fixture('r01',{gear});applyAction(c,actionFor(c,'r01'));
  const d=fixture('n02',{gear});applyAction(d,actionFor(d,'n02'));heal(d,50);
  return [makeCombat({gear}).hero.shield,st.maxHp,st.armor,st.magicResist,st.mpMax,st.handMax,a.metrics.damage,a.metrics.healing,a.metrics.heroDamage,b.metrics.damage,c.metrics.damage,d.hero.shield,d.metrics.healing,
    Math.max(...legalActions(fixture('n05',{gear})).filter(x=>x.kind==='card').map(x=>x.pos[1])),st.mods.range??0];
}
for(const item of equipment)test(`equipment ${item.id}: changes effective stats or resolved action`,()=>{assert.notDeepEqual(signature([item.id]),signature([]));});

test('equipment slot uniqueness and resistance caps',()=>{
  assert.throws(()=>heroStats(1,{},['w_blade','w_bow']));const h=heroStats(12,{resolve:100},['b_plate']);assert.equal(h.armor,.4);assert.equal(h.mpMax,2);
});
test('thread refunds MP once per turn after card movement',()=>{
  const s=fixture('n03',{relicIds:['thread']});const before=s.hero.mp;applyAction(s,actionFor(s,'n03'));assert.equal(s.hero.mp,before+1);assert.equal(s.hero.flags.thread,true);
});
test('bronze reacts to absorbed damage, not unused guard',()=>{
  const s=fixture('n02',{relicIds:['bronze']});applyAction(s,actionFor(s,'n02'));hitHero(s,20);beginTurn(s);nearly(s.hero.shield,25);
  const b=fixture('n02',{relicIds:['bronze']});applyAction(b,actionFor(b,'n02'));beginTurn(b);assert.equal(b.hero.shield,0);
});
test('embers increases burning and firefield ticks',()=>{
  const a=fixture('t02',{relicIds:['embers']});applyAction(a,actionFor(a,'t02'));nearly(a.enemies[0].burn,28);
  const b=fixture('t05',{relicIds:['embers']});applyAction(b,actionFor(b,'t05'));nearly(b.fields[0].amount,45);
});
test('obole rewards direct kills only, capped at twenty per combat',()=>{
  const s=fixture('n01',{relicIds:['obole']});for(let i=0;i<8;i++)hitEnemy(s,{hp:1,armor:0,shield:0},10,{direct:true});assert.equal(s.metrics.gold,20);
  const b=fixture('n01',{relicIds:['obole']});hitEnemy(b,b.enemies[0],2000);assert.equal(b.metrics.gold,0);
});
test('archive discounts one costly card without refunding it',()=>{
  const s=fixture('r09',{relicIds:['archive']});applyAction(s,actionFor(s,'r09'));assert.equal(s.hero.ap,2);assert.equal(s.hero.combatFlags.archive,true);assert.equal(s.consumed.length,1);
});
test('mirror fires once per combat and cannot reflect reflections',()=>{
  const s=fixture('n01',{relicIds:['mirror']}),e=s.enemies[0];hitHero(s,20,e);hitHero(s,20,e);nearly(1000-e.hp,40);
});
test('cup heals on two direct kills, ignores overkill and later kills',()=>{
  const s=fixture('n01',{relicIds:['cup']});const hp=s.hero.hp;for(let i=0;i<3;i++)hitEnemy(s,{hp:1,armor:0,shield:0},100,{direct:true});nearly(s.hero.hp-hp,70);assert.equal(s.hero.cupUses,2);
});
test('seal strengthens a mark, without creating an independent repeat hit',()=>{
  const s=fixture('n06',{relicIds:['seal']});applyAction(s,actionFor(s,'n06'));nearly(s.enemies[0].mark,55);nearly(s.metrics.damage,20);
});

for(const [classId,spec,card,prepare,metric] of [
  ['assassin','execution','n01',s=>{s.enemies[0].hp=300;},s=>s.metrics.damage],
  ['assassin','ambush','n01',s=>{s.hero.moved=2;},s=>s.metrics.shieldMade],
  ['gardien','bastion','n02',s=>{},s=>s.metrics.shieldMade],
  ['gardien','crusher','n04',s=>{},s=>s.metrics.damage],
  ['arpenteur','sniper','r01',s=>{s.enemies[0].pos=[3,1];},s=>s.metrics.damage],
  ['arpenteur','skirmish','n01',s=>{s.hero.moved=2;},s=>s.hero.mp],
  ['thaumaturge','pyre','t02',s=>{},s=>s.enemies[0].burn],
  ['thaumaturge','frost','t01',s=>{},s=>s.metrics.shieldMade],
])test(`specialization ${spec}: conditional effect exceeds same class without it`,()=>{
  const a=fixture(card,{classId,spec}),b=fixture(card,{classId});prepare(a);prepare(b);applyAction(a,actionFor(a,card));applyAction(b,actionFor(b,card));assert.ok(metric(a)>metric(b));
});

test('monotone rates and independent mob channels; initial starter count',()=>{
  for(let i=1;i<4;i++)for(let j=0;j<7;j++)assert.ok(rules.loot.rates[i][j]>=rules.loot.rates[i-1][j]);
  for(const c of classes)assert.equal(initialCopies(c.id).length,15);
  const all=rollLoot(1,1,2,'assassin',{rates:Array.from({length:4},()=>Array(7).fill(1))});assert.deepEqual(all.bags,Array(7).fill(2));assert.equal(all.cards.length,20);
});
test('loot deterministic and independent of combat random stream',()=>{
  const a=rollLoot(99,6,3,'gardien');const rng=random(99);for(let i=0;i<100;i++)rng();assert.deepEqual(a,rollLoot(99,6,3,'gardien'));assert.notEqual(seedFor(99,'loot'),seedFor(99,'combat'));
});
test('all basic purchase/sale/trade loops lose value',()=>{
  for(const rarity of Object.keys(rules.economy.buy))assert.ok(rules.economy.buy[rarity]>rules.economy.sell[rarity]);
  assert.ok(rules.economy.bagPrice>rules.economy.bagCards*rules.economy.sell.normal);assert.ok(rules.economy.tradeInput>1);
  assert.equal(rules.economy.gearSellRatio,undefined); // No equipment resale in this V1.
});
test('prepared deck enforces physical uniqueness, family caps and maximum thirty',()=>{
  const inventory=copies(cards.flatMap(c=>Array(5).fill(c.id)));const deck=prepareDeck(inventory,'gardien',30),count={};
  assert.equal(deck.length,30);for(const c of deck)count[c.family]=(count[c.family]??0)+1;assert.ok(Object.values(count).every(n=>n<=3));
});
test('same complete run yields identical result and conserves copies',()=>{
  const a=simulateRun({seed:99,classId:'assassin'}),b=simulateRun({seed:99,classId:'assassin'});assert.deepEqual(a,b);
  assert.equal(a.inventory.length,15+a.dropped+a.bought+a.tradedOutput-a.tradedInput-a.sold-a.consumed);assert.ok(a.gold>=0);
});
