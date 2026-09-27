import fs from 'node:fs';
import assert from 'node:assert/strict';
export function choose(n,k){if(n<0||k<0||k>n)return 0;let x=1;for(let i=1;i<=Math.min(k,n-k);i++)x=x*(n-i+1)/i;return x;}
export function access(n,h,a,b=0){return b?1-choose(n-a,h)/choose(n,h)-choose(n-b,h)/choose(n,h)+choose(n-a-b,h)/choose(n,h):1-choose(n-a,h)/choose(n,h);}
// Independent enumeration on small hands checks the inclusion-exclusion formula.
let count=0,hits=0;
function enumerate(selected,next){if(selected.length===5){count++;if(selected.some(i=>i<3)&&selected.some(i=>i>=3&&i<6))hits++;return;}
  for(let i=next;i<15;i++)enumerate([...selected,i],i+1);}
enumerate([],0);assert.equal(count,choose(15,5));assert.ok(Math.abs(hits/count-access(15,5,3,3))<1e-12);
const result={assumptions:{draw:'Uniform visible hand, without replacement. Waven 16/9 is an announced deck/maximum hand comparison, NOT a verified opening rule.',
  budget:'Toy scenarios, not forecasts of wins or Waven coefficients. P is Catabase prowess; retained resources have stipulated lifetime.'},
  access:[{deck:16,hand:9,a:1,b:1},{deck:20,hand:5,a:1,b:1},{deck:20,hand:5,a:3,b:3},{deck:15,hand:5,a:3,b:3},{deck:30,hand:5,a:3,b:3}].map(x=>({...x,single:access(x.deck,x.hand,x.a),both:access(x.deck,x.hand,x.a,x.b)})),
  heroSignatures:{deck:16,hand:9,copies:4,expectedVisible:9*4/16,atLeastOne:access(16,9,4)},
  orderedDistinctPairs:{hand5:5*4,hand7:7*6,hand9:9*8,ratio9to5:9*8/(5*4)},
  actionBudget:{baseTwoTurns:4+4,storeOne:[3,5],bonusOne:[4,5],bonusInflation:(4+5)/(4+4)-1},
  conversion:{P:40,guard:.8*40,readCoefficient:.5,reads:3,readDamage:.8*40*.5*3,spentCoefficient:1.5,spentDamage:.8*40*1.5,
    guardRemainingIfUndamaged:32,guardRemainingAfterSpend:0},
  teleport:{P:40,damageCoefficient:.25,teleports:2,enemiesPerArrival:3,uncapped:40*.25*2*3,capOneArrival:40*.25*3,capOneTargetOnce:40*.25},
  persistentSource:{P:40,coefficient:.30,activations:3,damage:40*.30*3,permanentCopiesSpent:1,compareOneCopyPerActivation:3},
  hypotheticalEcho:{probabilities:[.2,.5,.8,.95].map(p=>({p,uncappedExpectedActions:1/(1-p),capTwoReplaysExpectedActions:1+p+p*p})),
    assumption:'Independent fixed trigger probability p after each action, maximum two replays. Not a measured Waven Biste critical rate.'},
  historicalGaugeCap:{generated:20,coefficient:.04,bonus:20*.04,assumption:'0.13.1 O\u0027Lympic base effect only; no skill/other modifier added.'},
  reservoirs:{charges:6,publicFixedDamage:6*22,v1AtP40:6*.5*40,v1AtP112:6*.5*112,v1AtP145_6:6*.5*145.6},
  prepared:{deck20family3:1-choose(16,4)/choose(19,4),assumption:'Pin one existing A copy, draw 4 uniformly from other 19; B has 3 copies.'}};
assert.ok(result.access.every(x=>x.both>=0&&x.both<=x.single&&x.single<=1));
assert.equal(result.actionBudget.storeOne.reduce((a,b)=>a+b),result.actionBudget.baseTwoTurns);
assert.equal(result.teleport.uncapped,60);assert.equal(result.persistentSource.damage,36);
const target=new URL('./CALCULS.json',import.meta.url);
if(process.argv.includes('--check'))assert.deepEqual(JSON.parse(fs.readFileSync(target,'utf8')),result);
else fs.writeFileSync(target,JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({check:'passed',result}));
