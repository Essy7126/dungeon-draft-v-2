// Standalone quantity model. No Godot execution, combat AI or measured player behavior.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
const here = path.dirname(fileURLToPath(import.meta.url));
export const config = JSON.parse(fs.readFileSync(path.join(here, 'baseline.json'), 'utf8'));
export function validate(c) {
  if (c.rates.length !== 4 || c.bag_sizes.length !== 7) throw Error('shape');
  for (const row of c.rates) {
    if (row.length !== 7 || row.some(p => !Number.isFinite(p) || p < 0 || p > 1)) throw Error('probability');
  }
  for (const row of Object.values(c.routes)) {
    if (row.length !== 12 || row.some(n => !Number.isInteger(n) || n < 1)) throw Error('route');
  }
  if (c.bag_sizes.some(n => !Number.isInteger(n) || n < 1)) throw Error('bag size');
}
export function rng(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6D2B79F5) >>> 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t ^= t + Math.imul(t ^ (t >>> 7), 61 | t);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
export function variant(c, name) {
  const copy = structuredClone(c);
  if (name === 'early_supply') { copy.rates[0][0] = .75; copy.rates[0][1] = .15; }
  else if (name !== 'baseline') throw Error('variant');
  return copy;
}
export function analytic(c, counts, end = 11) {
  const expected = Array(6).fill(0), variance = Array(6).fill(0), noDrop = Array(6).fill(1);
  const fights = [];
  for (let i = 0; i < end; i++) {
    const rate = c.rates[Math.floor(i / 3)], n = counts[i];
    let normal = 0, total = 0;
    for (let j = 0; j < 7; j++) {
      const t = c.tiers[j], p = rate[j], size = c.bag_sizes[j];
      expected[t] += n * size * p;
      variance[t] += n * size * size * p * (1 - p);
      noDrop[t] *= (1 - p) ** n;
      total += n * size * p;
      if (t === 0) normal += n * size * p;
    }
    fights.push({ fight: i + 1, depth: c.depths[i], mobs: n, normal, total,
      zero_normal: ((1 - rate[0]) * (1 - rate[1])) ** n });
  }
  return { mobs: counts.slice(0, end).reduce((a,b)=>a+b,0), expected, variance,
    at_least_one: noDrop.map(p=>1-p), fights };
}
export function roll(c, count, stage, random, compatibility = 1) {
  const byTier = Array(6).fill(0);
  let usable = 0;
  for (let mob = 0; mob < count; mob++) for (let channel = 0; channel < 7; channel++) {
    if (random() < c.rates[stage][channel]) {
      const size = c.bag_sizes[channel];
      byTier[c.tiers[channel]] += size;
      for (let card = 0; card < size; card++) if (random() < compatibility) usable++;
    }
  }
  return { byTier, usable, total: byTier.reduce((a,b)=>a+b,0) };
}
export function run(c, counts, profile, policy, compatibility, seed) {
  const random = rng(seed);
  let stock = c.initial_cards, gold = c.initial_gold, used = 0, acquired = 0, unusable = 0;
  let bought = 0, spent = 0;
  const timeline = [];
  for (let i = 0; i < 12; i++) {
    const need = i === 0 ? profile.opening : profile[c.kinds[i]];
    if (need > Math.min(stock, c.deck_cap)) return {
      completed_budget: false, first_shortage: i + 1, stock, gold, used, acquired, unusable, bought, spent, timeline
    };
    stock -= need; used += need;
    // Final boss loot cannot fund this run: excluded even after budget completion.
    if (i < 11) {
      const loot = roll(c, counts[i], Math.floor(i / 3), random, compatibility);
      stock += loot.usable; acquired += loot.usable; unusable += loot.total - loot.usable;
      gold += c.kinds[i] === 'elite' ? c.economy.gold_elite : c.economy.gold_normal;
      if (policy.includes(i + 1)) {
        for (let packs = 0; packs < c.economy.packs_per_visit; packs++) {
          if (stock >= c.economy.target_stock || gold < c.economy.pack_price) break;
          stock += c.economy.pack_cards; bought += c.economy.pack_cards;
          gold -= c.economy.pack_price; spent += c.economy.pack_price;
        }
      }
    }
    timeline.push({ fight: i + 1, stock, gold });
  }
  return { completed_budget: true, first_shortage: null, stock, gold, used, acquired, unusable, bought, spent, timeline };
}
function quantile(values, q) {
  if (!values.length) return null;
  const sorted = [...values].sort((a,b)=>a-b);
  return sorted[Math.floor(q * (sorted.length - 1))];
}
export function monteCarlo(c, counts, profile, policy, compatibility, samples, seed) {
  let complete = 0, spending = 0;
  const firstShortage = Array(12).fill(0), stock = [], gold = [];
  for (let s = 0; s < samples; s++) {
    const result = run(c, counts, profile, policy, compatibility, (seed + Math.imul(s, 2654435761)) >>> 0);
    spending += result.spent;
    if (!result.completed_budget) firstShortage[result.first_shortage - 1]++;
    else { complete++; stock.push(result.stock); gold.push(result.gold); }
  }
  const p = complete / samples, z = 1.96, d = 1 + z*z/samples;
  const center = (p + z*z/(2*samples))/d;
  const half = z*Math.sqrt(p*(1-p)/samples + z*z/(4*samples*samples))/d;
  return { samples, completed_budget_rate: p, wilson95: [center-half,center+half],
    first_shortage_counts: firstShortage, average_spend_all_runs: spending/samples,
    conditional_on_completion: { stock_p10: quantile(stock,.1), stock_p50: quantile(stock,.5),
      stock_p90: quantile(stock,.9), gold_p50: quantile(gold,.5) } };
}
function choose(n,k) { if(k<0||k>n) return 0; let v=1; for(let i=1;i<=k;i++) v=v*(n-i+1)/i; return v; }
export function openingChance(deck, copies, hand) { return 1-choose(deck-copies,hand)/choose(deck,hand); }
export function exactFirstShortage(c, counts, profile) {
  // Independent dynamic-programming cross-check: no shops, all drops usable, aggregated quantity PMF.
  let stocks = new Map([[c.initial_cards, 1]]), failures = [];
  for (let i = 0; i < 12; i++) {
    const need = i===0 ? profile.opening : profile[c.kinds[i]];
    let failed=0; const survivors=new Map();
    for(const [s,p] of stocks) {
      if(need>Math.min(s,c.deck_cap)) failed+=p;
      else survivors.set(s-need,(survivors.get(s-need)||0)+p);
    }
    failures.push(failed); stocks=survivors;
    if(i===11) break;
    for(let mob=0;mob<counts[i];mob++) for(let j=0;j<7;j++) {
      const chance=c.rates[Math.floor(i/3)][j]; if(chance===0) continue;
      const next=new Map();
      for(const [s,p] of stocks) {
        next.set(s,(next.get(s)||0)+p*(1-chance));
        const k=s+c.bag_sizes[j]; next.set(k,(next.get(k)||0)+p*chance);
      }
      stocks=next;
    }
  }
  return { completed_budget_rate: [...stocks.values()].reduce((a,b)=>a+b,0), first_shortage: failures };
}
function main() {
  const args=process.argv.slice(2);
  const get=(key, fallback)=> {const i=args.indexOf(key); return i<0?fallback:args[i+1];};
  const samples=Number(get('--runs','20000')), seed=Number(get('--seed','24092026'));
  if(!Number.isInteger(samples)||samples<1||!Number.isInteger(seed)) throw Error('invalid runs/seed');
  validate(config);
  const report={ metadata:{ model:'quantity_only_v1', samples, seed, node:process.version,
    source_commit:config.source_commit, config_sha256:createHash('sha256').update(JSON.stringify(config)).digest('hex'),
    script_sha256:createHash('sha256').update(fs.readFileSync(fileURLToPath(import.meta.url))).digest('hex')},
    analytic:{}, exact:{}, experiments:[], opening:[], economy:{} };
  for(const [route,counts] of Object.entries(config.routes)) report.analytic[route]=analytic(config,counts);
  for(const [name,profile] of Object.entries(config.profiles)) report.exact[name]=exactFirstShortage(config,config.routes.actual_airain,profile);
  for(const version of ['baseline','early_supply']) for(const compatible of [1,.7])
    for(const [name,profile] of Object.entries(config.profiles))
      for(const [policy,visits] of Object.entries(config.economy.shop_policies)) {
        const c=variant(config,version);
        report.experiments.push({version,compatible,profile:name,policy,route:'actual_airain',
          ...monteCarlo(c,c.routes.actual_airain,profile,visits,compatible,samples,seed)});
      }
  for(const deck of [15,20,25,30]) for(const copies of [1,2,3])
    report.opening.push({deck,copies,hand:5,chance:openingChance(deck,copies,5)});
  report.economy={raw_liquidation_ceiling:report.analytic.actual_airain.expected.reduce((s,n,i)=>s+n*config.economy.sell[i],0),
    // Every quoted direct transformation loses liquidation value; specials are NOT modeled.
    buy_sell_margins:config.economy.buy.map((v,i)=>v-config.economy.sell[i]),
    pack_resale:config.economy.pack_cards*config.economy.sell[0],pack_cost:config.economy.pack_price};
  const out=path.resolve(get('--out','artifacts/dev/card-economy-lab'));
  fs.mkdirSync(out,{recursive:true});
  fs.writeFileSync(path.join(out,'results.json'),JSON.stringify(report,null,2)+'\n');
  const csv=['version,compatible,profile,policy,completion,stock_p50_completed,spend_all_runs'];
  for(const e of report.experiments) csv.push([e.version,e.compatible,e.profile,e.policy,e.completed_budget_rate,
    e.conditional_on_completion.stock_p50,e.average_spend_all_runs].join(','));
  fs.writeFileSync(path.join(out,'experiments.csv'),csv.join('\n')+'\n');
  console.log(JSON.stringify({out,samples,cases:report.experiments.length,analytic:report.analytic.actual_airain,exact:report.exact},null,2));
}
if (process.argv[1] && path.resolve(process.argv[1])===fileURLToPath(import.meta.url)) main();
