// Analytical audit, not a combat simulator. Run from the repository root.
// node tools/gameplay_audit_2026_09_28/calculate.mjs <observations.json> [output.json]
import fs from 'node:fs';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
const source = fs.readFileSync('data/cards/consumable_v2/catalog.json');
const d = JSON.parse(source);
const obs = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
assert.equal(obs.completed, true);
assert.equal(obs.encounters.length, 12);
assert.equal(obs.probes.all_native_rosters.length, 32);
const stage = i => Math.min(3, Math.floor((i - 1) / 3));
const rounded = n => Math.floor(n + .5);
const loot = d.rules.loot;
const rarityNames = [...new Set(loot.tiers)];
const perEnemy = loot.rates.map(rates => Object.fromEntries(rarityNames.map(tier => [tier,
  rates.reduce((sum, p, j) => sum + (loot.tiers[j] === tier ? p * loot.sizes[j] : 0), 0)])));
function expectation(counts) {
  const out = Object.fromEntries(rarityNames.map(t => [t, 0]));
  let noRare = 1, noNativeRareFamily = 1, noNativeEliteFamily = 1, noRelic = 1;
  let gear = 0, relic = 0;
  for (let i = 0; i < 11; i++) {
    const s = stage(i + 1), n = counts[i], rates = loot.rates[s];
    for (const r of rarityNames) out[r] += n * perEnemy[s][r];
    noRare *= (1 - rates[3]) ** n;
    noNativeRareFamily *= (1 - rates[3] * .7 / 2) ** n;
    noNativeEliteFamily *= (1 - rates[2] * (1 - (1 - .7 / 3) ** 2)) ** n;
    noRelic *= (1 - loot.relic[s] / 8) ** n;
    gear += n * loot.gear[s]; relic += n * loot.relic[s];
  }
  return {copies: out, gear, randomRelics: relic, totalRelicsWithGuarantees: relic + 2,
    probabilityAnyRare: 1 - noRare,
    probabilitySpecificNativeRareFamily: 1 - noNativeRareFamily,
    probabilitySpecificNativeEliteFamily: 1 - noNativeEliteFamily,
    probabilitySpecificRelicIncludingTwoGuarantees: 1 - noRelic * (7 / 8) ** 2,
    expectedCopiesSpecificNativeNormalFamily: out.normal * .7 / 12,
    expectedCopiesOfThreeClassStarterFamilies: out.normal * .7 * 3 / 12,
    normalMix: {ownClass: 4 / 12 * .7, shared: 8 / 12 * .7, foreign: .3}};
}
function chanceAtLeast(counts, channel) {
  return 1 - counts.slice(0, 11).reduce((p, n, i) => p * (1 - loot.rates[stage(i + 1)][channel]) ** n, 1);
}
const actualCounts = obs.encounters.map(e => e.roster.length);
const referenceCounts = d.route.map(e => e.roster.length);
const branchCounts = ['airain', 'styx', 'lethe'].map(branch => ({branch,
  counts: d.route.map(e => obs.probes.all_native_rosters.find(r => r.depth === e.depth && (r.branch === branch || r.branch === 'common')).roster.length)}));
const countsMax = d.route.map((_, i) => Math.max(...branchCounts.map(b => b.counts[i])));
const countsMin = d.route.map((_, i) => Math.min(...branchCounts.map(b => b.counts[i])));
// Purchases only at merchants. At depth 9 six fights are complete; no relics at depth 4.
const obole = [9, 14, 18].map(depth => {
  const remaining = d.route.filter(e => e.depth > depth && e.index < 12);
  const maxIncome = remaining.reduce((sum, e) => sum + Math.min(20, 4 * countsMax[e.index - 1]), 0);
  return {purchaseDepth: depth, price: d.relics.find(r => r.id === 'obole').price,
    remainingSpendableFights: remaining.map(e => e.index),
    maxIncomeBeforeBoss: maxIncome, maxProfitBeforeBoss: maxIncome - 90,
    assumption: 'Every remaining enemy killed directly; maximum roster over every branch; no extra summons in this profile.'};
});
const normalReplacement = d.route.slice(0, 11).map(e => {
  const n = actualCounts[e.index - 1], p = .7 / 12, q = loot.rates[stage(e.index)][1];
  return {combat: e.index, enemies: n,
    expectedOneChosenNativeNormal: n * perEnemy[stage(e.index)].normal * p,
    probabilityAtLeastOne: 1 - ((1 - p) ** 2 * (1 - q + q * (1 - p) ** 2)) ** n};
});
function choose(n, k) { if (k < 0 || k > n) return 0; let v = 1; for (let i = 1; i <= k; i++) v *= (n - i + 1) / i; return v; }
function both(N, k, a = 3, b = 3) { return 1 - choose(N - a, k) / choose(N, k) - choose(N - b, k) / choose(N, k) + choose(N - a - b, k) / choose(N, k); }
const hands = [15, 30].flatMap(deck => [5, 6].map(hand => ({deck, hand,
  twoThreeCopyFamilies: both(deck, hand),
  openingFirstFamilySecondDrawn: 1 - choose(deck - 1 - 3, hand - 1) / choose(deck - 1, hand - 1)})));
let xp = 0;
const progression = d.route.map((e, index) => {
  const before = d.rules.xpThresholds.filter(t => t <= xp).length;
  if (index < 11) xp += d.rules.xp[index];
  return {combat: e.index, depth: e.depth, before, after: d.rules.xpThresholds.filter(t => t <= xp).length, xp};
});
const pressure = [110, 350, 675].map(hp => {
  let sum = 0;
  return {maxHP: hp, rounds: Array.from({length: 17}, (_, i) => i + 8).map(round => {
    const damage = rounded(hp * .025 * Math.max(0, round - 8)); sum += damage;
    return {endOfRound: round, damage, cumulative: sum, fraction: sum / hp};
  })};
});
const nativeSpells = [...new Set(obs.probes.all_native_rosters.flatMap(r => r.roster.flatMap(u => u.spells.map(s => s.id))))].sort();
const types = Object.groupBy(d.cards, c => c.rarity);
const upgrades = Object.groupBy(d.cards, c => Object.keys(c.upgrade).length === 1 && 'damage' in c.upgrade ? 'damageOnly' : 'other');
function familyAvailability(card, classId) {
  const pool = d.cards.filter(c => c.rarity === card.rarity);
  const native = pool.filter(c => ['shared', classId].includes(c.affinity));
  const foreign = pool.filter(c => !['shared', classId].includes(c.affinity));
  const isNative = native.includes(card);
  const p = isNative ? (foreign.length ? .7 : 1) / native.length : (native.length ? .3 : 1) / foreign.length;
  let zero = 1, mean = 0;
  for (let i = 0; i < 11; i++) {
    for (let ch = 0; ch < loot.tiers.length; ch++) {
      if (loot.tiers[ch] !== card.rarity) continue;
      const r = loot.rates[stage(i + 1)][ch], size = loot.sizes[ch];
      zero *= (1 - r * (1 - (1 - p) ** size)) ** actualCounts[i];
      mean += actualCounts[i] * r * size * p;
    }
  }
  return {probabilityAtLeastOneFromLoot: 1 - zero, meanFromLoot: mean};
}
// Inventory mass-balance scenarios do not predict consumption or win rates.
const totalDrops = Object.values(expectation(actualCounts).copies).reduce((a, b) => a + b, 0);
const output = {
  assumptions: ['Normal difficulty; all eligible enemies killed; no sacrificed couriers; no purchases, sales or trades in drop expectations.',
    'Independent Bernoulli drop channels and uniform family pools; analytical distribution, not replay of Godot PRNG.',
    'One observed first-choice path, seed 33; all 32 native rosters enumerated for branch count bounds.',
    'No boss loot or post-victory use of money; results do not estimate player win rate.'],
  catalogSha256: crypto.createHash('sha256').update(source).digest('hex'),
  perEnemy, actualCounts, referenceCounts, branchCounts, countsMin, countsMax,
  dropsActual: expectation(actualCounts), dropsReference: expectation(referenceCounts),
  exceptional: Object.fromEntries([[4,'legendary'],[5,'god'],[6,'immortal']].map(([i,t]) => [t,chanceAtLeast(actualCounts,i)])),
  obole, normalReplacement, hands, progression, pressure,
  nativeSpells, nativeSpellCount: nativeSpells.length,
  rarityFamilyCounts: Object.fromEntries(Object.entries(types).map(([r, cs]) => [r, cs.length])),
  cardAvailability: d.cards.map(c => ({id: c.id, name: c.name, rarity: c.rarity,
    classId: c.affinity === 'shared' ? 'assassin' : c.affinity,
    ...familyAvailability(c, c.affinity === 'shared' ? 'assassin' : c.affinity)})),
  upgrades: Object.fromEntries(Object.entries(upgrades).map(([r, cs]) => [r, cs.map(c => c.id)])),
  stockMassBalance: [4, 8, 12].map(consumedPerFight => ({consumedPerFight,
    expectedStockBeforeBoss: 15 + totalDrops - 11 * consumedPerFight,
    warning: 'Arithmetic total only; early shortages, useful families, drawing and 30-card preparation cap are not modeled.'}))
};
assert.equal(d.cards.length, 48);
assert.equal(referenceCounts.length, 12);
assert.equal(output.rarityFamilyCounts.normal, 24);
assert.equal(progression[10].after, 12);
assert.ok(hands[0].twoThreeCopyFamilies < hands[0].openingFirstFamilySecondDrawn);
assert.ok(Math.abs(Object.values(output.dropsActual.normalMix).reduce((a,b) => a+b,0) - 1) < 1e-12);
assert.equal(pressure[0].rounds[0].damage, 0);
const text = JSON.stringify(output, null, 2) + '\n';
if (process.argv[3]) fs.writeFileSync(process.argv[3], text);
else process.stdout.write(text);
console.error('Analytical audit complete; invariants passed. Not a balance campaign.');
