import test from 'node:test';
import assert from 'node:assert/strict';
import {config,validate,rng,analytic,roll,run,monteCarlo,exactFirstShortage,openingChance} from './simulate.mjs';
test('reject invalid probabilities and route dimensions',()=>{
  validate(config); const c=structuredClone(config); c.rates[0][0]=1.01;
  assert.throws(()=>validate(c)); c.rates[0][0]=.5; c.routes.actual_airain.pop(); assert.throws(()=>validate(c));
});
test('published illustrative baseline reproduced analytically',()=>{
  const a=analytic(config,config.routes.previous_hypothesis);
  assert.equal(a.mobs,43); assert.ok(Math.abs(a.expected[0]-125.25)<1e-10);
  assert.ok(Math.abs(a.at_least_one[5]-(1-.9998**10))<1e-12);
});
test('independent channels may all drop; quantity and compatibility conserved',()=>{
  const c=structuredClone(config); c.rates=c.rates.map(()=>Array(7).fill(1));
  assert.equal(roll(c,2,0,rng(7),1).usable,24);
  const result=roll(c,2,0,rng(7),0); assert.equal(result.usable,0); assert.equal(result.total,24);
});
test('no drops exposes shortage before that fight reward',()=>{
  const c=structuredClone(config); c.rates=c.rates.map(()=>Array(7).fill(0));
  const p={opening:3,normal:6,elite:9,boss:12};
  const r=run(c,c.routes.actual_airain,p,[],1,2);
  assert.equal(r.first_shortage,4); assert.equal(r.acquired,0); assert.equal(r.used,15);
  assert.equal(exactFirstShortage(c,c.routes.actual_airain,p).first_shortage[3],1);
});
test('seed determinism, resource conservation and gold never negative',()=>{
  for(let seed=0;seed<100;seed++) {
    const args=[config,config.routes.actual_airain,config.profiles.central,[3,5,7,10,11],.7,seed];
    const a=run(...args); assert.deepEqual(a,run(...args));
    assert.equal(a.stock,config.initial_cards+a.acquired+a.bought-a.used);
    assert.ok(a.gold>=0); assert.ok(a.stock>=0); assert.ok(a.timeline.every(t=>t.gold>=0));
  }
});
test('closed form opening probability and deck dilution',()=>{
  assert.ok(Math.abs(openingChance(30,1,5)-1/6)<1e-12);
  assert.ok(openingChance(15,3,5)>openingChance(30,3,5));
});
test('exact survival mass sums to one; Monte Carlo independently agrees',()=>{
  const exact=exactFirstShortage(config,config.routes.actual_airain,config.profiles.central);
  assert.ok(Math.abs(exact.completed_budget_rate+exact.first_shortage.reduce((a,b)=>a+b,0)-1)<1e-10);
  const mc=monteCarlo(config,config.routes.actual_airain,config.profiles.central,[],1,20000,999);
  assert.ok(Math.abs(mc.completed_budget_rate-exact.completed_budget_rate)<.015);
});
test('deck cap prevents paying over thirty from an unlimited reserve',()=>{
  const c=structuredClone(config); c.initial_cards=100;
  assert.equal(run(c,c.routes.actual_airain,{opening:31},[],1,1).first_shortage,1);
});
