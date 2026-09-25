// Research only: stock financing, static source extraction and mathematical examples.
// This does not execute Godot, estimate wins, or model player decisions.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { config, variant, analytic, monteCarlo, exactFirstShortage, openingChance } from '../simulate.mjs';
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '../../../..');
export function monotonicViolations(c) {
  const failures = [];
  for (let stage = 1; stage < c.rates.length; stage++) {
    for (let j = 0; j < c.channels.length; j++) {
      if (c.rates[stage][j] < c.rates[stage - 1][j]) failures.push({
        stage: stage + 1, channel: c.channels[j], previous: c.rates[stage - 1][j], next: c.rates[stage][j]
      });
    }
  }
  return failures;
}
export function monotonicCandidate() {
  const c = structuredClone(config);
  [[.75, .15], [.80, .20], [.90, .30], [.95, .45]].forEach((v, i) => {
    c.rates[i][0] = v[0]; c.rates[i][1] = v[1];
  });
  return c;
}
export function numberArray(text, name, type = 'const') {
  const expression = type === 'const'
    ? new RegExp(`const ${name} := \\[([^\\]]+)\\]`)
    : new RegExp(`${name} = PackedInt32Array\\(([^)]+)\\)`);
  const match = text.match(expression);
  if (!match) throw Error(`Missing numeric array ${name}`);
  const numbers = match[1].split(',').map(v => Number(v.trim()));
  if (numbers.some(v => !Number.isFinite(v))) throw Error(`Invalid numeric array ${name}`);
  return numbers;
}
export function progression(xp, depths, thresholds, hp, prowess) {
  let total = 0;
  const levelAt = value => thresholds.reduce((level, threshold, index) => value >= threshold ? index + 1 : level, 1);
  return xp.map((reward, i) => {
    const before = levelAt(total); total += reward;
    return { fight: i + 1, depth: depths[i], xp_reward: reward, total_xp_after: total,
      level_before: before, level_after: levelAt(total), hp_before: hp[before - 1], prowess_before: prowess[before - 1] };
  });
}
export function independentAtLeastOne(p, attempts) { return 1 - (1 - p) ** attempts; }
export function bagVariance(p, size) { return size * size * p * (1 - p); }
export function relativeSampleSize(p, relativeHalfWidth = .2) {
  return Math.ceil(1.96 ** 2 * (1 - p) / (p * relativeHalfWidth ** 2));
}
export function duplicateGroups(text) {
  // Deliberately limited to single-line numeric rows in ROWS and ADVANCED.
  // Same shape is not proof of gameplay equivalence: class, element and passives differ.
  const regex = /^\s*\["([^"]+)", "([^"]+)", "([^"]+)", (\d+), (\d+), (\d+), ([\d.]+), "([^"]+)", ([\d.]+), "([^"]+)"\],/gm;
  const groups = new Map(); let count = 0;
  for (const match of text.matchAll(regex)) {
    const key = match.slice(4, 10).join('|'); count++;
    const members = groups.get(key) ?? [];
    members.push({ id: match[1], class: match[2], name: match[3] }); groups.set(key, members);
  }
  return { examined_rows: count, groups: [...groups.entries()].filter(([, v]) => v.length > 1).map(([shape, members]) => ({shape, members})) };
}
function main() {
  const args = process.argv.slice(2);
  const get = (flag, fallback) => { const i = args.indexOf(flag); return i < 0 ? fallback : args[i + 1]; };
  const samples = Number(get('--runs', '20000')), seed = Number(get('--seed', '25092026'));
  if (!Number.isInteger(samples) || samples < 1 || !Number.isInteger(seed)) throw Error('Invalid runs/seed');
  const sources = [
    'core/expedition/catabase_route_v6.gd',
    'data/runs/progression/odyssey/achilles_champion_progression_v0.tres',
    'core/expedition/class_card_catalog.gd',
    'core/expedition/card_ecosystem_catalog.gd',
    'core/expedition/class_cards.gd',
  ];
  const texts = sources.map(p => fs.readFileSync(path.join(root, p), 'utf8'));
  const sha = text => createHash('sha256').update(text).digest('hex');
  const report = {
    metadata: { model: 'systems_research_v1', source_commit_inspected: config.source_commit,
      runs_per_case: samples, seed, node: process.version,
      source_hashes: Object.fromEntries(sources.map((p, i) => [p, sha(texts[i])])),
      script_hash: sha(fs.readFileSync(fileURLToPath(import.meta.url))),
      parent_script_hash: sha(fs.readFileSync(path.join(here, '../simulate.mjs'))),
      baseline_hash: sha(JSON.stringify(config)) },
    assumptions: ['No combat outcome model; fixed card demand.', 'Drops excluded after final boss.',
      '0.7 is an effective utility stress assumption, not a class restriction.',
      'XP timeline assumes only route rewards, 1x multiplier and all victories.',
      'Stock quantiles conditional on financing all fights; not all runs.',
      'No equipment/healing spending, resale, deck draw or rarity utility model.'],
    monotonicity: { baseline: monotonicViolations(config), early_supply: monotonicViolations(variant(config, 'early_supply')),
      candidate: monotonicViolations(monotonicCandidate()) },
    candidate: monotonicCandidate(), experiments: [], exact: {},
  };
  for (const [name, c] of [['baseline', config], ['monotonic', monotonicCandidate()]]) {
    report.exact[name] = {
      supply: analytic(c, c.routes.actual_airain),
      central: exactFirstShortage(c, c.routes.actual_airain, c.profiles.central),
      intensive: exactFirstShortage(c, c.routes.actual_airain, c.profiles.intensive),
    };
    for (const profile of ['central', 'intensive']) for (const usefulness of [1, .7]) {
      for (const policy of ['none', 'refuges']) report.experiments.push({ variant: name, profile,
        usefulness, policy, ...monteCarlo(c, c.routes.actual_airain, c.profiles[profile],
          c.economy.shop_policies[policy], usefulness, samples, seed) });
    }
  }
  report.progression = progression(numberArray(texts[0], 'XP'), numberArray(texts[0], 'COMBAT_DEPTHS'),
    numberArray(texts[1], 'cumulative_xp_thresholds', 'resource'),
    numberArray(texts[1], 'base_hp_by_level', 'resource'),
    numberArray(texts[1], 'base_prowess_by_level', 'resource'));
  const baseRows = texts[2].split('const ROWS := [')[1]?.split('\n]')[0];
  const advancedRows = texts[3].split('const ADVANCED := [')[1]?.split('\n]')[0];
  if (!baseRows || !advancedRows) throw Error('Missing catalog sections');
  report.structural_duplicates = duplicateGroups(baseRows + '\n' + advancedRows);
  const pImmortal = report.exact.baseline.supply.at_least_one[5];
  report.examples = {
    variance_equal_mean: { one_bag_of_3: bagVariance(.5, 3), three_single_cards: 3 * bagVariance(.5, 1), mean_both: 1.5 },
    immortal: { run_probability: pImmortal, runs_for_95percent_at_least_one: Math.ceil(Math.log(.05) / Math.log(1 - pImmortal)),
      runs_for_approx_20percent_relative_precision: relativeSampleSize(pImmortal), expected_events_in_20000_runs: 20000 * pImmortal },
    mastery_rank2_to3_relative_gain: 1.3 / 1.2 - 1,
    prowess_gear9_relative_to_base: [18, 57, 100, 112].map(p => ({base: p, relative: 9 / p})),
    additive_vs_multiplicative: { additive: 1 + .4 + .35 + .45, multiplicative: 1.4 * 1.35 * 1.45 },
    activation_thresholds: [49, 50, 99, 100].map(d => ({hp: 100, damage: d, hits: Math.ceil(100 / d)})),
    effective_hp_example: [.2, .4, .6, .8].map(r => ({hp: 100, mitigation: r, effective_hp: 100 / (1 - r)})),
    opening: [15, 20, 30].flatMap(deck => [1, 2, 3].map(copies => ({deck, copies, hand: 4, probability: openingChance(deck, copies, 4)}))),
    current_first_reward: { expectation: .49 + .16, zero_probability: (1 - .49) * (1 - .16) },
  };
  const output = path.resolve(root, get('--out', 'artifacts/dev/card-economy-systems'));
  fs.mkdirSync(output, { recursive: true });
  fs.writeFileSync(path.join(output, 'systems.json'), JSON.stringify(report, null, 2) + '\n');
  const csv = ['variant,profile,usefulness,policy,runs,budget_completion,wilson_low,wilson_high,stock_p10_if_complete,stock_p50_if_complete,stock_p90_if_complete,average_gold_spent_all_runs'];
  for (const e of report.experiments) csv.push([e.variant,e.profile,e.usefulness,e.policy,e.samples,e.completed_budget_rate,
    ...e.wilson95,e.conditional_on_completion.stock_p10,e.conditional_on_completion.stock_p50,e.conditional_on_completion.stock_p90,e.average_spend_all_runs].join(','));
  fs.writeFileSync(path.join(output, 'systems.csv'), csv.join('\n') + '\n');
  console.log(JSON.stringify({output, cases: report.experiments.length, monotonicity: report.monotonicity,
    progression: report.progression, duplicate_groups: report.structural_duplicates, examples: report.examples,
    experiments: report.experiments.map(e => ({variant:e.variant,profile:e.profile,usefulness:e.usefulness,policy:e.policy,
      financed:e.completed_budget_rate,stock_median:e.conditional_on_completion.stock_p50})),
    expected_normal_candidate: report.exact.monotonic.supply.expected[0]}, null, 2));
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
