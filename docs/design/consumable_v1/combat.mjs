// Reference rules for the proposed V1. Not a port or validation of Godot combat.
import {rules,classes,cards,cardById,equipment,relics,enemyTypes,maps,route,upgradedCard} from './content.mjs';
export const distance=(a,b)=>Math.abs(a[0]-b[0])+Math.abs(a[1]-b[1]);
const key=p=>p.join(',');
const clone=o=>structuredClone(o);
const cap=(x,a,b)=>Math.max(a,Math.min(b,x));
export function random(seed){let a=seed>>>0;return()=>{a=(a+0x6D2B79F5)>>>0;let t=Math.imul(a^(a>>>15),a|1);t^=t+Math.imul(t^(t>>>7),t|61);return((t^(t>>>14))>>>0)/4294967296;};}
export function shuffle(values,rng){const a=[...values];for(let i=a.length-1;i>0;i--){const j=Math.floor(rng()*(i+1));[a[i],a[j]]=[a[j],a[i]];}return a;}
export function heroStats(level=1,attributes={},gear=[]){
  const mods={};
  for(const id of gear){const e=equipment.find(e=>e.id===id);if(!e)throw Error('Unknown gear '+id);for(const[k,v]of Object.entries(e.mods))mods[k]=(mods[k]??0)+v;}
  const slots=gear.map(id=>equipment.find(e=>e.id===id).slot);if(new Set(slots).size!==slots.length)throw Error('Duplicate equipment slot');
  const index=cap(level,1,12)-1;
  return {level,maxHp:Math.round(rules.hp[index]*(1+(attributes.vitality??0)*rules.attributes.vitality+(mods.hp??0))),
    p:rules.prowess[index]*(1+(attributes.power??0)*rules.attributes.power),
    armor:cap((attributes.resolve??0)*rules.attributes.resolveArmor+(mods.armor??0),0,rules.resistanceCap),
    magicResist:cap(mods.magicResist??0,0,rules.resistanceCap),
    guardBonus:(attributes.resolve??0)*rules.attributes.resolveGuard+(mods.guard??0),
    apMax:rules.ap,mpMax:cap(rules.mp+(mods.mp??0),1,5),handMax:cap(rules.hand+(mods.hand??0),1,7),mods};
}
export function copies(families,prefix='test'){return families.map((family,i)=>({uid:prefix+'_'+i,family}));}
export function initialCopies(classId){return copies(classes.find(c=>c.id===classId).starters.flatMap(id=>[id,id,id]),'start');}
export function makeCombat({classId='assassin',spec='',level=1,attributes={},gear=[],relicIds=[],trained=[],deck=initialCopies(classId),hp=null,encounter=route[0],seed=1}={}){
  if(deck.length>rules.deckCap||new Set(deck.map(c=>c.uid)).size!==deck.length)throw Error('Invalid deck');
  const familyCounts={};for(const c of deck){if(!cardById[c.family]||(familyCounts[c.family]=(familyCounts[c.family]??0)+1)>rules.copiesPerFamily)throw Error('Invalid family copies');}
  if(!classes.some(c=>c.id===classId)||relicIds.some(id=>!relics.some(r=>r.id===id))||relicIds.length>2||new Set(relicIds).size!==relicIds.length)throw Error('Invalid hero');
  if(spec&&!classes.find(c=>c.id===classId).specs.includes(spec))throw Error('Invalid specialization');
  const stats=heroStats(level,attributes,gear),map=maps[encounter.map];if(!map)throw Error('Unknown map');
  const weight=encounter.roster.reduce((s,id)=>s+enemyTypes[id].weight,0);
  const spawns=[[3,1],[1,1],[5,1],[3,2]];
  const enemyLevel=encounter.level??level;
  const enemies=encounter.roster.map((id,i)=>{const t=enemyTypes[id],maxHp=Math.round(rules.prowess[enemyLevel-1]*encounter.hpBudget*t.weight/weight);
    return {...t,id:'enemy_'+i,archetype:id,pos:[...spawns[i]],hp:maxHp,maxHp,damage:Math.round(rules.hp[enemyLevel-1]*t.attack),shield:0,
      mark:0,markTurns:0,burn:0,burnTurns:0,slow:0,weaken:0,stun:0,immune:0,carrier:map.hazard==='convoy'&&[1,2].includes(i),sacrificed:false};});
  const s={hero:{...stats,hp:hp===null?stats.maxHp:Math.min(hp,stats.maxHp),classId,spec,relics:[...relicIds],trained:[...trained],pos:[3,5],shield:0,
    ap:0,mp:0,moved:0,previousAbsorbed:0,absorbed:0,counter:0,edict:false,flags:{},combatFlags:{},lifestealUsed:0,cupUses:0},
    enemies,map:clone(map),encounter:clone(encounter),turn:0,seed,allCopies:clone(deck),hand:[],draw:shuffle(deck.map(c=>c.uid),random(seed)),discard:[],consumed:[],used:[],
    fields:[],hazard:{forgeRow:1,clockCenter:[3,5],clockDelayed:false,clockMultiplier:1,reservoir:[0,0],sealed:false},
    metrics:{cards:0,basic:0,damage:0,heroDamage:0,healing:0,shieldMade:0,shieldAbsorbed:0,enemyActions:0,stuns:0,moves:0,displaced:0,drawn:0,gold:0,fieldDamage:0,pressure:0,interactions:0},trace:[]};
  beginTurn(s);if(stats.mods.openingShield)addGuard(s,stats.mods.openingShield*stats.p,false);return s;
}
export function inside(p){return p[0]>=0&&p[0]<rules.grid&&p[1]>=0&&p[1]<rules.grid;}
const wall=(s,p)=>s.map.walls.some(w=>key(w)===key(p));
export function freeCell(s,p,ignore=null){return inside(p)&&!wall(s,p)&&!s.enemies.some(e=>e.hp>0&&e.id!==ignore&&key(e.pos)===key(p))&&key(s.hero.pos)!==key(p);}
export function lineOfSight(s,a,b){
  let[x,y]=a;const dx=Math.abs(b[0]-x),dy=Math.abs(b[1]-y),sx=x<b[0]?1:-1,sy=y<b[1]?1:-1;let err=dx-dy;
  while(x!==b[0]||y!==b[1]){const twice=2*err;if(twice>-dy){err-=dy;x+=sx;}if(twice<dx){err+=dx;y+=sy;}if(wall(s,[x,y]))return false;}return true;
}
export function reachable(s,origin,budget,ignore=null){
  const out=[],queue=[[origin,0]],seen=new Set([key(origin)]);
  for(let i=0;i<queue.length;i++){const[p,n]=queue[i];if(n>=budget)continue;for(const d of [[1,0],[-1,0],[0,1],[0,-1]]){const q=[p[0]+d[0],p[1]+d[1]];
    if(seen.has(key(q))||!freeCell(s,q,ignore))continue;seen.add(key(q));out.push({pos:q,cost:n+1});queue.push([q,n+1]);}}
  return out;
}
const copyCard=(s,uid)=>{const item=s.allCopies.find(c=>c.uid===uid);return item?upgradedCard(item.family,s.hero.trained):null;};
export function cardCost(s,c){return Math.max(1,c.ap-(s.hero.relics.includes('archive')&&!s.hero.combatFlags.archive&&c.ap>=3?1:0));}
export function addGuard(s,value,trigger=true){
  const h=s.hero;let amount=value*(1+h.guardBonus);
  if(trigger&&h.spec==='bastion'&&!h.flags.bastion){amount*=1.25;h.flags.bastion=true;}
  const add=Math.max(0,Math.min(amount,rules.guardCap*h.p-h.shield));h.shield+=add;s.metrics.shieldMade+=add;return add;
}
export function heal(s,value){const h=s.hero,add=Math.max(0,Math.min(h.maxHp-h.hp,value*(1+(h.mods.healing??0))));h.hp+=add;s.metrics.healing+=add;return add;}
export function hitEnemy(s,e,value,{type='physical',pierce=0,direct=false}={}){
  if(e.hp<=0)return 0;const h=s.hero;
  const resistance=type==='physical'?e.armor:0;let damage=Math.max(0,value*(1-resistance*(1-pierce)));
  const absorbed=Math.min(e.shield,damage);e.shield-=absorbed;damage-=absorbed;
  const dealt=Math.min(e.hp,damage);e.hp-=dealt;s.metrics.damage+=dealt;
  if(direct&&(h.mods.lifesteal??0)>0){const budget=Math.max(0,h.maxHp*.10-h.lifestealUsed);const multiplier=1+(h.mods.healing??0);const value=Math.min(budget/multiplier,dealt*h.mods.lifesteal);h.lifestealUsed+=heal(s,value);}
  if(e.hp<=0&&direct){
    if(h.relics.includes('obole'))s.metrics.gold=Math.min(20,s.metrics.gold+4);
    if(h.relics.includes('cup')&&h.cupUses<2){h.cupUses++;heal(s,.35*h.p);}
  }
  return dealt;
}
export function hitHero(s,value,source=null,type='physical',bypass=false){
  const h=s.hero;if(h.hp<=0)return 0;let damage=value,passiveAbsorbed=0;
  if(!bypass){damage*=1-(type==='magic'?h.magicResist:h.armor);
    if(source&&!h.combatFlags.firstHit){damage=Math.max(0,damage-(h.mods.firstHitReduction??0)*h.p);h.combatFlags.firstHit=true;}
    const absorbed=Math.min(h.shield,damage);h.shield-=absorbed;damage-=absorbed;h.absorbed+=absorbed;s.metrics.shieldAbsorbed+=absorbed;passiveAbsorbed=absorbed;
  }
  if(damage>=h.hp&&h.edict&&!bypass){damage=Math.max(0,h.hp-1);h.edict=false;h.combatFlags.edictSaved=true;}
  const dealt=Math.min(h.hp,Math.max(0,damage));h.hp-=dealt;s.metrics.heroDamage+=dealt;
  if(source&&passiveAbsorbed>0&&h.classId==='gardien'&&!h.flags.retaliation){h.flags.retaliation=true;hitEnemy(s,source,rules.retaliation*h.p);}
  if(source&&h.relics.includes('mirror')&&!h.combatFlags.mirror){h.combatFlags.mirror=true;hitEnemy(s,source,.40*h.p);}
  if(source&&h.counter>0&&distance(source.pos,h.pos)===1){hitEnemy(s,source,h.counter);h.counter=0;}
  return dealt;
}
function draw(s,count){
  for(let i=0;i<count&&s.hand.length<s.hero.handMax;i++){
    if(!s.draw.length){if(!s.discard.length)break;s.draw=shuffle(s.discard,random((s.seed+7919*s.turn+s.metrics.drawn)>>>0));s.discard=[];}
    s.hand.push(s.draw.shift());s.metrics.drawn++;
  }
}
export function beginTurn(s){
  const h=s.hero;s.turn++;h.previousAbsorbed=h.absorbed;h.absorbed=0;h.shield=0;h.counter=0;h.edict=false;h.flags={};h.moved=0;h.ap=h.apMax;h.mp=h.mpMax;s.used=[];
  if(h.relics.includes('bronze')&&h.previousAbsorbed>0)addGuard(s,.25*h.p,false);
  draw(s,h.handMax);
}
function condition(s,c,e){
  if(!c.condition)return false;
  return c.condition==='marked'?e.mark>0:c.condition==='moved'?s.hero.moved>=2:c.condition==='guarded'?s.hero.shield>0:c.condition==='absorbed'?s.hero.previousAbsorbed>0:c.condition==='execute'?e.hp/e.maxHp<=.35:false;
}
function directDamage(s,c,e){
  const h=s.hero,d=distance(h.pos,e.pos);let v=(c.damage+(condition(s,c,e)?c.bonus:0))*h.p;
  v*=1+(h.mods.damage??0)+(d===1?(h.mods.melee??0):0)+(d>=3?(h.mods.ranged??0):0)+(c.type==='magic'?(h.mods.magic??0):0);
  if(h.classId==='assassin'&&!h.flags.class&& !s.enemies.some(o=>o!==e&&o.hp>0&&distance(o.pos,e.pos)===1)){v+=.25*h.p;h.flags.class=true;}
  if(h.classId==='arpenteur'&&!h.flags.class&&d>=3){h.mp=Math.min(5,h.mp+1);h.flags.class=true;}
  if(h.spec==='execution'&&!h.flags.spec&&e.hp/e.maxHp<=.35){v+=.30*h.p;h.flags.spec=true;}
  if(h.spec==='ambush'&&!h.flags.spec&&h.moved>=2){addGuard(s,.30*h.p);h.flags.spec=true;}
  if(h.spec==='sniper'&&!h.flags.spec&&d>=4){v+=.25*h.p;h.flags.spec=true;}
  if(h.spec==='skirmish'&&!h.flags.spec&&h.moved>=2){h.mp=Math.min(5,h.mp+1);h.flags.spec=true;}
  if(e.mark>0){v+=e.mark;e.mark=0;e.markTurns=0;}
  return hitEnemy(s,e,v,{type:c.type,pierce:c.pierce??0,direct:true});
}
function statusPassive(s,kind){const h=s.hero;
  if(h.classId==='thaumaturge'&&!h.flags.class){h.flags.class=true;addGuard(s,.20*h.p);}
  if(kind==='slow'&&h.spec==='frost'&&!h.flags.spec){h.flags.spec=true;addGuard(s,.30*h.p);}
}
function moveEnemy(s,e,towards,amount,push=false){
  if(e.hp<=0)return 0;let moved=0;const h=s.hero;
  if(e.boss)amount=Math.min(1,amount);
  for(let i=0;i<amount;i++){
    const dx=towards[0]-e.pos[0],dy=towards[1]-e.pos[1];if(dx===0&&dy===0)break;
    const step=Math.abs(dx)>=Math.abs(dy)?[Math.sign(dx),0]:[0,Math.sign(dy)];
    const q=[e.pos[0]+step[0]*(push?-1:1),e.pos[1]+step[1]*(push?-1:1)];if(!freeCell(s,q,e.id))break;e.pos=q;moved++;
  }
  s.metrics.displaced+=moved;
  if(moved&&push&&h.spec==='crusher'&&!h.flags.spec){h.flags.spec=true;hitEnemy(s,e,.25*h.p);}
  return moved;
}
const cross=(a,b)=>distance(a,b)<=1;
function affected(s,c,target){
  if(c.op==='storm')return s.enemies.filter(e=>e.hp>0&&distance(e.pos,s.hero.pos)<=2);
  if(c.shape==='cross')return s.enemies.filter(e=>e.hp>0&&cross(e.pos,target));
  return s.enemies.filter(e=>e.hp>0&&key(e.pos)===key(target));
}
export function legalActions(s){
  const h=s.hero;if(h.hp<=0||!s.enemies.some(e=>e.hp>0))return [];
  const result=[];
  for(const cell of reachable(s,h.pos,h.mp))result.push({kind:'walk',pos:cell.pos,cost:cell.cost});
  if(h.ap>=1){
    if(!h.flags.basic)for(const e of s.enemies)if(e.hp>0&&distance(h.pos,e.pos)===1)result.push({kind:'basic',target:e.id});
    if(!h.flags.guard)result.push({kind:'guard'});
    if(s.map.hazard==='forge'&&distance(h.pos,[0,3])<=1&&!h.flags.interact)for(const row of [1,3,5])result.push({kind:'interact',mode:'forge',value:row});
    if(s.map.hazard==='hourglass'&&distance(h.pos,[0,3])<=1&&!s.hazard.clockDelayed&&!s.hazard.clockPending&&!h.flags.interact)result.push({kind:'interact',mode:'delay'});
    if(s.map.hazard==='convoy'&&h.ap>=2&&distance(h.pos,[0,3])<=1&&!s.hazard.sealed)result.push({kind:'interact',mode:'seal'});
    if(s.map.hazard==='reservoir'&&!h.flags.interact)for(let i=0;i<2;i++)if(distance(h.pos,[[0,3],[6,3]][i])<=1&&s.hazard.reservoir[i]>0)result.push({kind:'interact',mode:'discharge',value:i});
  }
  const seen=new Set();
  for(const uid of s.hand){const c=copyCard(s,uid);if(!c||seen.has(c.id)||s.used.includes(c.id)||cardCost(s,c)>h.ap)continue;seen.add(c.id);
    if(['guard','draw','counter','heal','edict','renew','storm'].includes(c.op)){result.push({kind:'card',uid,pos:[...h.pos]});continue;}
    if(['move','blink'].includes(c.op)){
      const positions=c.op==='move'?reachable(s,h.pos,c.amount):Array.from({length:49},(_,i)=>({pos:[i%7,Math.floor(i/7)]})).filter(x=>freeCell(s,x.pos)&&distance(x.pos,h.pos)<=c.amount);
      for(const p of positions)result.push({kind:'card',uid,pos:p.pos});continue;
    }
    const positions=['firefield','icefield','converge'].includes(c.op)?Array.from({length:49},(_,i)=>[i%7,Math.floor(i/7)]).filter(p=>!wall(s,p)):s.enemies.filter(e=>e.hp>0).map(e=>e.pos);
    for(const pos of positions){const d=distance(h.pos,pos),e=s.enemies.find(e=>e.hp>0&&key(e.pos)===key(pos));
      if(d<c.min||d>c.max+(h.mods.range??0)||!lineOfSight(s,h.pos,pos))continue;
      if(c.op==='stasis'&&(!e||e.mark<=0||e.immune>0))continue;
      if(c.op==='swap'&&(!e||e.boss))continue;
      result.push({kind:'card',uid,pos:[...pos]});
    }
  }
  return result;
}
export function applyAction(s,a,{validate=true}={}){
  if(validate&&!legalActions(s).some(x=>JSON.stringify(x)===JSON.stringify(a)))throw Error('Illegal action '+JSON.stringify(a));
  const h=s.hero;
  if(a.kind==='walk'){h.pos=[...a.pos];h.mp-=a.cost;h.moved+=a.cost;s.metrics.moves+=a.cost;return;}
  if(a.kind==='basic'){h.ap--;h.flags.basic=true;s.metrics.basic++;hitEnemy(s,s.enemies.find(e=>e.id===a.target),rules.fallbackDamage*h.p);return;}
  if(a.kind==='guard'){h.ap--;h.flags.guard=true;addGuard(s,rules.fallbackGuard*h.p,false);return;}
  if(a.kind==='interact'){
    h.ap-=a.mode==='seal'?2:1;h.flags.interact=true;s.metrics.interactions++;
    if(a.mode==='forge')s.hazard.forgeRow=a.value;
    if(a.mode==='delay'){s.hazard.clockDelayed=true;s.hazard.clockMultiplier=1.5;}
    if(a.mode==='seal')s.hazard.sealed=true;
    if(a.mode==='discharge'){const e=s.enemies.find(e=>e.hp>0);hitEnemy(s,e,s.hazard.reservoir[a.value]*.5*h.p);s.hazard.reservoir[a.value]=0;}
    return;
  }
  const c=copyCard(s,a.uid);h.ap-=cardCost(s,c);if(c.ap>=3&&h.relics.includes('archive')&&!h.combatFlags.archive)h.combatFlags.archive=true;
  s.hand.splice(s.hand.indexOf(a.uid),1);s.consumed.push(a.uid);s.used.push(c.id);s.metrics.cards++;
  if(['move','blink'].includes(c.op)){
    const d=c.op==='move'?reachable(s,h.pos,c.amount).find(x=>key(x.pos)===key(a.pos)).cost:distance(h.pos,a.pos);h.pos=[...a.pos];h.moved+=d;s.metrics.moves+=d;
    if(h.relics.includes('thread')&&!h.flags.thread){h.flags.thread=true;h.mp=Math.min(5,h.mp+1);}return;
  }
  if(c.op==='guard'||c.op==='counter'){addGuard(s,c.amount*h.p);if(c.op==='counter')h.counter=c.counter*h.p;return;}
  if(c.op==='draw'){draw(s,c.amount);return;}
  if(c.op==='heal'){heal(s,c.amount*h.p);addGuard(s,c.shield*h.p);return;}
  if(c.op==='edict'){h.edict=true;if(c.shield)addGuard(s,c.shield*h.p);return;}
  if(c.op==='renew'){heal(s,c.amount*h.maxHp);addGuard(s,c.shield*h.p);h.ap=0;h.mp=0;return;}
  if(c.op==='firefield'||c.op==='icefield'){
    if(s.fields.length>=2)s.fields.shift();
    s.fields.push({kind:c.op,pos:[...a.pos],amount:c.op==='firefield'?(c.amount+(h.relics.includes('embers')?.1:0))*h.p:c.amount,turns:c.duration});return;
  }
  if(c.op==='converge')for(const e of s.enemies)if(e.hp>0&&distance(e.pos,a.pos)<=2)moveEnemy(s,e,a.pos,1);
  for(const e of affected(s,c,a.pos)){
    let usedCard=c;
    if(c.op==='guardburst'){const bonus=Math.min(c.cap,h.shield*c.amount/h.p);h.shield=0;usedCard={...c,damage:c.damage+bonus};}
    let dealt=0;if(usedCard.damage>0)dealt=directDamage(s,usedCard,e);
    if(c.op==='drain')heal(s,dealt*c.amount);
    if(e.hp<=0)continue;
    if(c.op==='mark'){e.mark=Math.max(e.mark,(c.amount+(h.relics.includes('seal')?.20:0))*h.p);e.markTurns=2;statusPassive(s,'mark');}
    if(c.op==='slow'){e.slow=Math.max(e.slow,c.amount);statusPassive(s,'slow');}
    if(c.op==='burn'){let amount=c.amount+(h.relics.includes('embers')?.10:0);if(h.spec==='pyre'&&!h.flags.spec){amount+=.10;h.flags.spec=true;}e.burn=Math.max(e.burn,amount*h.p);e.burnTurns=Math.max(e.burnTurns,c.duration);statusPassive(s,'burn');}
    if(c.op==='push'||c.op==='pull')moveEnemy(s,e,h.pos,c.amount,c.op==='push');
    if(c.op==='disrupt')e.weaken=Math.max(e.weaken,e.boss?.25:c.amount);
    if(c.op==='stasis'){e.mark=0;e.markTurns=0;if(e.boss)e.weaken=Math.max(e.weaken,.25);else e.stun=1;e.immune=4;}
    if(c.op==='swap'){const old=[...h.pos];h.pos=[...e.pos];e.pos=old;s.metrics.displaced++;}
  }
}

function approach(s,e,destination,budget,attackPosition=false){
  const options=[{pos:e.pos,cost:0},...reachable(s,e.pos,budget,e.id)];
  options.sort((a,b)=>{
    const score=x=>distance(x.pos,destination)+(attackPosition&&distance(x.pos,destination)<=e.range&&lineOfSight(s,x.pos,destination)?-20:0)+x.cost*.01;
    return score(a)-score(b)||key(a.pos).localeCompare(key(b.pos));
  });e.pos=[...options[0].pos];
}
export function endTurn(s){
  const h=s.hero,refLevel=s.encounter.level??h.level,refP=rules.prowess[refLevel-1],refHp=rules.hp[refLevel-1];
  s.discard.push(...s.hand);s.hand=[];
  if(!s.enemies.some(e=>e.hp>0)||h.hp<=0)return;
  if(s.map.hazard==='reservoir')for(let i=0;i<2;i++)if(distance(h.pos,[[0,3],[6,3]][i])<=1){s.hazard.reservoir[i]=Math.min(6,s.hazard.reservoir[i]+h.ap);h.ap=0;break;}
  for(const e of s.enemies)e.shield=0;
  for(const f of s.fields){
    if(cross(h.pos,f.pos)&&f.kind==='firefield'){const n=hitHero(s,f.amount,null,'magic');s.metrics.fieldDamage+=n;}
    for(const e of s.enemies)if(e.hp>0&&cross(e.pos,f.pos)){
      if(f.kind==='firefield'){const n=hitEnemy(s,e,f.amount,{type:'magic'});s.metrics.fieldDamage+=n;}
      else e.slow=Math.max(e.slow,f.amount);
    }
    f.turns--;
  }
  s.fields=s.fields.filter(f=>f.turns>0);
  for(const e of s.enemies){
    if(h.hp<=0)break;if(e.hp<=0)continue;
    if(e.burnTurns>0){hitEnemy(s,e,e.burn,{type:'magic'});e.burnTurns--;if(!e.burnTurns)e.burn=0;}if(e.hp<=0)continue;
    if(e.stun>0){e.stun--;s.metrics.stuns++;}
    else if(e.carrier&&!s.hazard.sealed){
      if(distance(e.pos,[3,0])<=1){const chief=s.enemies.find(o=>o.hp>0&&!o.carrier);if(chief){chief.hp+=.8*refP;chief.maxHp+=.8*refP;chief.damage+=.02*refHp;}e.hp=0;e.sacrificed=true;}
      else approach(s,e,[3,0],1);
    }else{
      if(e.support&&s.turn%2===0){const target=s.enemies.filter(o=>o.hp>0).sort((a,b)=>a.hp/a.maxHp-b.hp/b.maxHp)[0];target.shield+=e.support*refP;}
      approach(s,e,h.pos,Math.max(0,e.mp-e.slow),true);
      if(distance(e.pos,h.pos)<=e.range&&lineOfSight(s,e.pos,h.pos)){s.metrics.enemyActions++;hitHero(s,e.damage*(1-e.weaken),e,e.type);}
    }
    e.slow=0;e.weaken=0;if(e.immune>0)e.immune--;if(e.markTurns>0){e.markTurns--;if(e.markTurns===0)e.mark=0;}
    if(s.map.hazard==='reservoir'&&e.hp>0)for(let i=0;i<2;i++)if(distance(e.pos,[[0,3],[6,3]][i])<=1&&s.hazard.reservoir[i]>0){s.hazard.reservoir[i]--;e.hp=Math.min(e.maxHp,e.hp+.3*refP);}
  }
  if(h.hp<=0||!s.enemies.some(e=>e.hp>0))return;
  const hazardHit=(predicate,amount)=>{
    if(predicate(h.pos))hitHero(s,amount);
    for(const e of s.enemies)if(e.hp>0&&predicate(e.pos))hitEnemy(s,e,amount);
  };
  if(s.map.hazard==='forge'){
    if(h.pos[1]===s.hazard.forgeRow)hitHero(s,.60*refP);
    for(const e of s.enemies)if(e.hp>0&&e.pos[1]===s.hazard.forgeRow)hitEnemy(s,e,1.30*refP);
    s.hazard.forgeRow=({1:3,3:5,5:1})[s.hazard.forgeRow];
  }
  if(s.map.hazard==='garden'){
    const chief=s.enemies.find(e=>e.hp>0),radius=[2,3,1][(s.turn-1)%3];if(chief){const pos=[...chief.pos];hazardHit(p=>distance(p,pos)===radius,.60*refP);}
  }
  if(s.map.hazard==='hourglass'){
    if(s.hazard.clockDelayed){s.hazard.clockDelayed=false;s.hazard.clockPending=true;}
    else{const center=s.hazard.clockCenter;hazardHit(p=>(p[0]===center[0]||p[1]===center[1])&&distance(p,center)<=2&&lineOfSight(s,p,center),.70*refP*s.hazard.clockMultiplier);s.hazard.clockMultiplier=1;s.hazard.clockCenter=[...h.pos];s.hazard.clockPending=false;}
  }
  if(h.hp>0&&s.enemies.some(e=>e.hp>0)&&s.turn>=rules.collapseStart){const value=h.maxHp*rules.collapseStep*(s.turn-rules.collapseStart+1);s.metrics.pressure+=hitHero(s,value,null,'physical',true);}
}
export function outcome(s){if(s.hero.hp<=0)return 'defeat';if(!s.enemies.some(e=>e.hp>0))return 'victory';if(s.finishedTimeout)return 'timeout';return 'active';}
function estimatedThreat(s){
  let damage=0;
  for(const e of s.enemies)if(e.hp>0&&e.stun===0&&!(e.carrier&&!s.hazard.sealed)){
    if(distance(e.pos,s.hero.pos)<=e.range+Math.max(0,e.mp-e.slow))damage+=e.damage*(1-e.weaken)*(1-(e.type==='magic'?s.hero.magicResist:s.hero.armor));
  }
  const p=rules.prowess[s.hero.level-1];
  if(s.map.hazard==='forge'&&s.hero.pos[1]===s.hazard.forgeRow)damage+=.6*p;
  if(s.map.hazard==='hourglass'&&!s.hazard.clockDelayed){const d=s.hazard.clockCenter;if((d[0]===s.hero.pos[0]||d[1]===s.hero.pos[1])&&distance(d,s.hero.pos)<=2)damage+=.7*p*s.hazard.clockMultiplier;}
  for(const f of s.fields)if(f.kind==='firefield'&&cross(f.pos,s.hero.pos))damage+=f.amount;
  return Math.max(0,damage-s.hero.shield);
}
export const policies={
  balanced:{resource:.17,safety:.8,lookahead:1},aggressive:{resource:.02,safety:.55,lookahead:1},
  conserve:{resource:.70,safety:1.0,lookahead:1},planner:{resource:.17,safety:.8,lookahead:2},
  fallback:{resource:100,safety:.8,lookahead:1},
};
export function evaluate(s,policy='balanced'){
  const p=typeof policy==='string'?policies[policy]:policy,h=s.hero,P=h.p;
  if(h.hp<=0)return -10000;if(!s.enemies.some(e=>e.hp>0))return 1000+h.hp/P-p.resource*s.metrics.cards;
  let value=h.hp/P*p.safety-estimatedThreat(s)/P*p.safety;
  let nearest=20;
  for(const e of s.enemies)if(e.hp>0){value-=e.hp/P+.8;nearest=Math.min(nearest,distance(e.pos,h.pos));
    value+=Math.min(e.hp,e.burn*e.burnTurns)*.65/P+e.mark*.55/P+(e.stun?.7:0);
  }
  value-=Math.max(0,nearest-2)*.075;
  value+=Math.min(h.shield,P)*.06/P+h.counter*.25/P+(h.edict?.4:0);
  for(const f of s.fields)for(const e of s.enemies)if(e.hp>0&&cross(f.pos,e.pos))value+=f.kind==='firefield'?Math.min(e.hp,f.amount*f.turns)*.55/P:.12;
  value+=s.hazard.reservoir.reduce((a,b)=>a+b,0)*.18;
  value-=s.metrics.cards*p.resource+s.metrics.moves*.012;
  return value;
}
export function chooseAction(s,policy='balanced'){
  const p=typeof policy==='string'?policies[policy]:policy,base=evaluate(s,p),options=[];
  for(const action of legalActions(s)){
    if(policy==='fallback'&&action.kind==='card')continue;
    const next=clone(s);applyAction(next,action,{validate:false});options.push({action,next,score:evaluate(next,p)});
  }
  options.sort((a,b)=>b.score-a.score);
  let best=options[0];
  if(p.lookahead>=2)for(const option of options.slice(0,6)){
    for(const action of legalActions(option.next)){
      const next=clone(option.next);applyAction(next,action,{validate:false});const score=evaluate(next,p);
      if(!best||score>best.score+1e-8)best={action:option.action,score,next};
    }
  }
  return best&&best.score>base+1e-7?best.action:null;
}
export function playCombat(options={},policy='balanced',{trace=false}={}){
  const s=makeCombat(options);
  while(true){
    for(let actions=0;actions<16;actions++){
      if(outcome(s)!=='active')break;
      const action=chooseAction(s,policy);if(!action)break;
      if(trace)s.trace.push({turn:s.turn,action:clone(action),hp:s.hero.hp,ap:s.hero.ap,mp:s.hero.mp});
      applyAction(s,action,{validate:false});
    }
    if(s.hero.hp<=0||!s.enemies.some(e=>e.hp>0))break;
    endTurn(s);if(s.turn>=rules.turnLimit&&outcome(s)==='active')s.finishedTimeout=true;if(outcome(s)!=='active')break;beginTurn(s);
  }
  return {outcome:outcome(s),turns:s.turn,hp:s.hero.hp,maxHp:s.hero.maxHp,consumed:s.consumed,
    survivors:s.allCopies.filter(c=>!s.consumed.includes(c.uid)),lootEnemies:s.enemies.filter(e=>e.hp<=0&&!e.sacrificed).length,
    metrics:s.metrics,trace:s.trace,state:s};
}
