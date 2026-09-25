import {rules,cards,cardById,equipment,relics} from './content.mjs';
import {heroStats} from './combat.mjs';
// Finite merchant inventory. The seed chooses bag contents elsewhere, never on reload.
export function createMarket(visit,stage,classId){
  return {visit,stage,classId,bags:2,heal:1,trades:2,respec:1,
    singles:Object.fromEntries(cards.filter(c=>c.rarity==='normal'&&['shared',classId].includes(c.affinity)).map(c=>[c.id,1])),
    gear:equipment.filter(e=>e.stage<=stage).map(e=>e.id),relics:stage>=3?relics.map(r=>r.id):[],receipts:[]};
}
export function transact(state,market,request){
  // Validate on clones: cancellation and a repeated transaction ID are atomic.
  if(market.receipts.includes(request.id))return false;
  if(!request.id)throw Error('Transaction ID required');
  const s=structuredClone(state),m=structuredClone(market),cost=n=>{if(s.gold<n)throw Error('Insufficient gold');s.gold-=n;};
  const remove=ids=>{if(new Set(ids).size!==ids.length||ids.some(id=>!s.inventory.some(c=>c.uid===id)))throw Error('Invalid copies');s.inventory=s.inventory.filter(c=>!ids.includes(c.uid));};
  const insert=(family,i=0)=>s.inventory.push({uid:`market_${m.visit}_${request.id}_${i}`,family});
  if(request.kind==='single'){
    if(!m.singles[request.family])throw Error('Sold out');cost(rules.economy.buy.normal);m.singles[request.family]--;insert(request.family);s.bought++;s.spending.cards+=rules.economy.buy.normal;
  }else if(request.kind==='bag'){
    if(m.bags<=0||request.contents?.length!==rules.economy.bagCards||request.contents.some(id=>cardById[id]?.rarity!=='normal'))throw Error('Invalid bag');
    cost(rules.economy.bagPrice);m.bags--;request.contents.forEach(insert);s.bought+=request.contents.length;s.spending.cards+=rules.economy.bagPrice;
  }else if(request.kind==='trade'){
    const c=cardById[request.family];if(m.trades<=0||request.copies?.length!==3||c?.rarity!=='normal'||!['shared',m.classId].includes(c.affinity)||request.copies.some(id=>cardById[s.inventory.find(x=>x.uid===id)?.family]?.rarity!=='normal'))throw Error('Invalid trade');
    remove(request.copies);insert(request.family);m.trades--;s.tradedInput+=3;s.tradedOutput++;
  }else if(request.kind==='sell'){
    const items=request.copies.map(id=>s.inventory.find(c=>c.uid===id));if(items.some(c=>!c))throw Error('Unknown copy');remove(request.copies);s.gold+=items.reduce((v,c)=>v+rules.economy.sell[cardById[c.family].rarity],0);s.sold+=items.length;
  }else if(request.kind==='gear'||request.kind==='relic'){
    const isGear=request.kind==='gear',field=isGear?'gear':'relics',collection=isGear?'gearInventory':'relicInventory',catalog=isGear?equipment:relics;
    const item=catalog.find(x=>x.id===request.item);if(!item||!m[field].includes(item.id)||s[collection].includes(item.id))throw Error('Invalid offer');cost(item.price);m[field]=m[field].filter(x=>x!==item.id);s[collection].push(item.id);s.spending.gear+=item.price;
  }else if(request.kind==='heal'){
    if(!m.heal)throw Error('Sold out');cost(rules.economy.healPrice);m.heal--;const bonus=heroStats(s.level,s.attributes,s.gear).mods.healing??0;const amount=Math.min(s.maxHp-s.hp,s.maxHp*rules.economy.healFraction*(1+bonus));s.hp+=amount;s.healing+=amount;s.spending.heal+=rules.economy.healPrice;
  }else if(request.kind==='respec'){
    if(!m.respec||!s.trained.includes(request.from)||s.trained.includes(request.to)||!cardById[request.to])throw Error('Invalid respec');cost(rules.economy.familyRespec);m.respec--;s.trained=s.trained.map(id=>id===request.from?request.to:id);s.spending.training=(s.spending.training??0)+rules.economy.familyRespec;
  }else throw Error('Unknown transaction');
  if(s.gold<0||new Set(s.inventory.map(c=>c.uid)).size!==s.inventory.length)throw Error('Invalid resulting economy');
  m.receipts.push(request.id);Object.assign(state,s);Object.assign(market,m);if(state.markets)state.markets[m.visit]=market;return true;
}
