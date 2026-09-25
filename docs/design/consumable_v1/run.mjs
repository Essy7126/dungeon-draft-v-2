import {rules,classes,cards,cardById,equipment,relics,route,ranks} from './content.mjs';
import {random,initialCopies,heroStats,playCombat} from './combat.mjs';
import {createMarket,transact} from './market.mjs';
export function seedFor(seed,label){let h=seed>>>0;for(const ch of label)h=Math.imul(h^ch.charCodeAt(0),16777619)>>>0;return h;}
const pick=(list,rng)=>list[Math.floor(rng()*list.length)];
export function cardUtility(card,classId){
  let value=card.damage+(card.bonus??0)*.4;
  if(card.shape==='cross')value*=1.55;
  if(card.op==='burn')value+=card.amount*1.4;
  if(card.op==='guard'||card.op==='counter')value+=card.amount*.65;
  if(['slow','push','pull','mark'].includes(card.op))value+=.30;
  if(['move','blink','draw'].includes(card.op))value+=.65;
  if(card.op==='firefield')value+=card.amount*2;
  if(card.op==='icefield')value+=.65;
  if(['edict','renew','heal','swap','stasis'].includes(card.op))value+=1;
  return value/Math.sqrt(card.ap)+(card.affinity===classId?.16:0);
}
export function prepareDeck(inventory,classId,cap=20){
  const sorted=[...inventory].sort((a,b)=>cardUtility(cardById[b.family],classId)-cardUtility(cardById[a.family],classId)||a.uid.localeCompare(b.uid));
  const chosen=[],counts={};
  // Reserve two different defensive families and one mobility family if available.
  for(const ops of [['guard','counter'],['guard','counter'],['move','blink']]){
    const item=sorted.find(x=>!chosen.includes(x)&&ops.includes(cardById[x.family].op)&&!counts[x.family]);
    if(item){chosen.push(item);counts[item.family]=1;}
  }
  for(const item of sorted){if(chosen.length>=cap)break;if(chosen.includes(item)||(counts[item.family]??0)>=rules.copiesPerFamily)continue;chosen.push(item);counts[item.family]=(counts[item.family]??0)+1;}
  return chosen.slice(0,cap);
}
export function familyDrop(rarity,classId,rng){
  const pool=cards.filter(c=>c.rarity===rarity),native=pool.filter(c=>['shared',classId].includes(c.affinity)),foreign=pool.filter(c=>!['shared',classId].includes(c.affinity));
  const preferred=rng()<rules.loot.nativeOrShared?native:foreign;return pick(preferred.length?preferred:pool,rng).id;
}
export function rollLoot(seed,fight,enemyCount,classId,{rates=rules.loot.rates,sizes=rules.loot.sizes}={}){
  const stage=Math.floor((fight-1)/3),result={cards:[],equipment:[],relics:[],bags:Array(7).fill(0)};
  for(let e=0;e<enemyCount;e++){
    for(let channel=0;channel<7;channel++){
      const label=`loot:${fight}:${e}:${channel}`;
      if(random(seedFor(seed,label))()>=rates[stage][channel])continue;result.bags[channel]++;
      const rng=random(seedFor(seed,label+':contents'));
      for(let i=0;i<sizes[channel];i++)result.cards.push({uid:`drop_${fight}_${e}_${channel}_${i}`,family:familyDrop(rules.loot.tiers[channel],classId,rng)});
    }
    if(random(seedFor(seed,`gear:${fight}:${e}`))()<rules.loot.gear[stage])result.equipment.push(pick(equipment.filter(x=>x.stage<=stage+1),random(seedFor(seed,`gearKind:${fight}:${e}`))).id);
    if(random(seedFor(seed,`relic:${fight}:${e}`))()<rules.loot.relic[stage])result.relics.push(pick(relics,random(seedFor(seed,`relicKind:${fight}:${e}`))).id);
  }
  if([5,10].includes(fight)&&enemyCount>0)result.relics.push(pick(relics,random(seedFor(seed,`chiefRelic:${fight}`))).id);
  return result;
}
export function gearUtility(item,classId){
  const m=item.mods;return (m.hp??0)*5+(m.armor??0)*5+(m.magicResist??0)*3+(m.guard??0)*2+(m.damage??0)*5+
    (m.melee??0)*(['assassin','gardien'].includes(classId)?5:1)+(m.ranged??0)*(classId==='arpenteur'?5:2)+(m.magic??0)*(classId==='thaumaturge'?5:1)+
    (m.hand??0)*.8+(m.mp??0)*.22+(m.range??0)*(['arpenteur','thaumaturge'].includes(classId)?.4:.15)+
    (m.openingShield??0)*.4+(m.healing??0)*.8+(m.lifesteal??0)*4+(m.firstHitReduction??0)*.3;
}
const relicUtility=(id,classId)=>({thread:.5,bronze:classId==='gardien'?1.4:.6,embers:classId==='thaumaturge'?1.5:.6,obole:.7,archive:1.1,mirror:1,cup:1.1,seal:['assassin','thaumaturge'].includes(classId)?1.3:.8})[id];
export function chooseGear(inventory,classId){return [...new Set(equipment.map(e=>e.slot))].map(slot=>equipment.filter(e=>e.slot===slot&&inventory.includes(e.id)).sort((a,b)=>gearUtility(b,classId)-gearUtility(a,classId))[0]?.id).filter(Boolean);}
export function chooseRelics(inventory,classId){return [...new Set(inventory)].sort((a,b)=>relicUtility(b,classId)-relicUtility(a,classId)).slice(0,2);}
function refreshEquipment(state){
  const ratio=state.hp/state.maxHp;state.gear=chooseGear(state.gearInventory,state.classId);state.relics=chooseRelics(state.relicInventory,state.classId);
  const stats=heroStats(state.level,state.attributes,state.gear);state.maxHp=stats.maxHp;state.hp=Math.min(state.maxHp,ratio*state.maxHp);
}
function healRun(state,fraction){const mods=heroStats(state.level,state.attributes,state.gear).mods;const healed=Math.min(state.maxHp-state.hp,state.maxHp*fraction*(1+(mods.healing??0)));state.hp+=healed;state.healing+=healed;}
export function shop(state,fight,{economy=true,trade=true,heal=true,gear=true}={}){
  const initialGold=state.gold;const rng=random(seedFor(state.seed,`shop:${fight}`));
  state.markets??={};const market=state.markets[fight]??=createMarket(fight,Math.floor((fight-1)/3)+1,state.classId);
  if(heal&&state.hp/state.maxHp<.65&&state.gold>=rules.economy.healPrice&&market.heal)transact(state,market,{id:'heal',kind:'heal'});
  if(economy){
    for(let i=0;i<rules.economy.bagsPerVisit&&state.inventory.length<18&&state.gold>=rules.economy.bagPrice;i++){
      transact(state,market,{id:'bag'+i,kind:'bag',contents:Array.from({length:rules.economy.bagCards},()=>familyDrop('normal',state.classId,rng))});
    }
  }
  if(trade){
    for(let i=0;i<rules.economy.tradesPerVisit;i++){
      const normals=state.inventory.filter(x=>cardById[x.family].rarity==='normal').sort((a,b)=>cardUtility(cardById[a.family],state.classId)-cardUtility(cardById[b.family],state.classId));
      if(state.inventory.length<20||normals.length<3)break;
      const owned=new Set(state.inventory.map(x=>x.family));
      const wanted=cards.filter(c=>c.rarity==='normal'&&c.affinity===state.classId&&!owned.has(c.id)).sort((a,b)=>cardUtility(b,state.classId)-cardUtility(a,state.classId))[0];
      if(!wanted)break;
      transact(state,market,{id:'trade'+i,kind:'trade',copies:normals.slice(0,3).map(x=>x.uid),family:wanted.id});
    }
  }
  if(gear){
    const stage=Math.floor((fight-1)/3)+1;
    const offers=equipment.filter(e=>e.stage<=stage&&!state.gearInventory.includes(e.id)).sort((a,b)=>gearUtility(b,state.classId)-gearUtility(a,state.classId));
    const offer=offers.find(e=>!state.gear.some(id=>equipment.find(o=>o.id===id).slot===e.slot));
    if(offer&&state.gold>=offer.price+36){transact(state,market,{id:'gear',kind:'gear',item:offer.id});refreshEquipment(state);}
  }
  // Sales are optional, capped in this tested policy, and never fund an automatic sale/buy loop.
  if(economy&&state.inventory.length>45){
    const unwanted=state.inventory.filter(x=>cardById[x.family].rarity==='normal').sort((a,b)=>cardUtility(cardById[a.family],state.classId)-cardUtility(cardById[b.family],state.classId)).slice(0,Math.min(12,state.inventory.length-45));
    transact(state,market,{id:'sale',kind:'sell',copies:unwanted.map(x=>x.uid)});
  }
  if(state.gold<0)throw Error('Negative gold');return initialGold-state.gold;
}
function advance(state,xp){
  const oldMax=state.maxHp;state.xp+=xp;
  const level=rules.xpThresholds.reduce((v,x,i)=>state.xp>=x?i+1:v,1);
  for(let next=state.level+1;next<=level;next++){
    if(rules.attributeLevels.includes(next)){
      const attribute=next%6===0?'vitality':state.classId==='gardien'?'resolve':'power';state.attributes[attribute]=(state.attributes[attribute]??0)+1;
    }
    if(rules.trainingLevels.includes(next)){
      const counts={};for(const c of state.inventory)counts[c.family]=(counts[c.family]??0)+1;
      const family=Object.keys(counts).filter(id=>!state.trained.includes(id)).sort((a,b)=>counts[b]*cardUtility(cardById[b],state.classId)-counts[a]*cardUtility(cardById[a],state.classId))[0];
      if(family)state.trained.push(family);else state.trainingBank=(state.trainingBank??0)+1;
    }
  }
  state.level=level;state.maxHp=heroStats(state.level,state.attributes,state.gear).maxHp;state.hp=Math.min(state.maxHp,state.hp+Math.max(0,state.maxHp-oldMax));
  if(state.level>=4&&!state.spec)state.spec=classes.find(c=>c.id===state.classId).specs[state.specIndex];
}
export function simulateRun({classId='assassin',seed=1,policy='planner',specIndex=0,deckCap=20,lootOptions={},shops=true,trade=true,gear=true,relicLoot=true,forcedGear=[],forcedRelics=[],cardFilter=null,trace=false}={}){
  const s={classId,seed,specIndex,spec:'',level:1,xp:0,attributes:{},trained:[],inventory:initialCopies(classId),gearInventory:[...forcedGear],relicInventory:[...forcedRelics],gear:[...forcedGear],relics:[...forcedRelics],
    gold:rules.initialGold,hp:0,maxHp:0,bought:0,sold:0,dropped:0,consumed:0,tradedInput:0,tradedOutput:0,healing:0,spending:{cards:0,gear:0,heal:0},timeline:[],bagCounts:Array(7).fill(0),cardUses:{},basic:0};
  s.maxHp=heroStats(1,{},s.gear).maxHp;s.hp=s.maxHp;
  for(const encounter of route){
    const deck=prepareDeck(s.inventory,classId,deckCap);
    const result=playCombat({classId,spec:s.spec,level:s.level,attributes:s.attributes,gear:s.gear,relicIds:s.relics,trained:s.trained,deck,hp:s.hp,encounter,seed:seedFor(seed,'combat:'+encounter.index)},policy,{trace});
    for(const uid of result.consumed){const item=s.inventory.find(c=>c.uid===uid);if(!item)throw Error('Consumed unknown copy');s.cardUses[item.family]=(s.cardUses[item.family]??0)+1;}
    const used=new Set(result.consumed);s.inventory=s.inventory.filter(c=>!used.has(c.uid));s.consumed+=used.size;s.basic+=result.metrics.basic;s.hp=result.hp;
    const row={fight:encounter.index,depth:encounter.depth,level:s.level,outcome:result.outcome,turns:result.turns,cards:used.size,basic:result.metrics.basic,hpRatio:s.hp/s.maxHp,stockBefore:deck.length,stockAfter:s.inventory.length,gold:s.gold,lootEnemies:result.lootEnemies,metrics:result.metrics};
    if(trace)row.trace=result.trace;s.timeline.push(row);
    if(result.outcome!=='victory')return {...s,completed:false,failureFight:encounter.index,reason:result.outcome};
    if(encounter.index===12)break;
    s.gold+=(encounter.kind==='elite'?rules.economy.goldElite:rules.economy.goldNormal)+result.metrics.gold;
    const loot=rollLoot(seed,encounter.index,result.lootEnemies,classId,lootOptions);
    const incoming=cardFilter?loot.cards.filter(c=>cardFilter(cardById[c.family])):loot.cards;
    s.inventory.push(...incoming);s.dropped+=incoming.length;loot.bags.forEach((n,i)=>s.bagCounts[i]+=n);
    if(gear)s.gearInventory.push(...loot.equipment);if(relicLoot)s.relicInventory.push(...loot.relics);refreshEquipment(s);
    advance(s,rules.xp[encounter.index-1]);
    if(encounter.refugeAfter)healRun(s,encounter.index===11?rules.economy.freePrebossHeal:rules.economy.freeRefugeHeal);
    if(shops&&encounter.shopAfter)shop(s,encounter.index,{trade,gear});
    const recorded=s.timeline.at(-1);recorded.stockAfterRewards=s.inventory.length;recorded.goldAfter=s.gold;recorded.hpAfter=s.hp/s.maxHp;
    if(new Set(s.inventory.map(c=>c.uid)).size!==s.inventory.length)throw Error('Duplicate physical copy');
    if(s.inventory.length!==rules.initialCards+s.dropped+s.bought+s.tradedOutput-s.tradedInput-s.sold-s.consumed)throw Error('Inventory conservation');
  }
  return {...s,completed:true,failureFight:null,reason:'victory'};
}
