#!/usr/bin/env node
'use strict';

// Read completed evidence only. This tool neither launches combat nor changes
// fixture outcomes, and never writes a successful report for a partial matrix.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { summarizeTerrain } = require('./terrain_evidence.cjs');
const { summarizeProduction, summarizeCaptures } = require('./production_evidence.cjs');
const ROOT = path.resolve(__dirname, '../..');
const FOLDER = 'artifacts/philosopher_sprite_validation_v1';
const MATRIX = `${FOLDER}/matrix_post_terrain/summary.json`;
const GUT = `${FOLDER}/gut_final`;
const NODE_LOGS = [`${FOLDER}/node_final/stdout.log`, `${FOLDER}/node_final/icons_stdout.log`];
const OUTPUT = 'docs/design/philosopher_mage_validation_v1.json';
const SCENARIOS = ['attack', 'control', 'shield', 'heal_self', 'heal_ally', 'approach', 'repel', 'defeat'];
const DIRECTIONS = ['E', 'N', 'S', 'W'];
const SPELLS = ['philosopher_aegis', 'philosopher_aporia', 'philosopher_axiom', 'philosopher_mending', 'philosopher_refutation'];
const CHARACTER_MANIFEST = 'assets/characters/philosopher_mage/sprites_v1/manifest.json';
const EFFECT_MANIFEST = 'assets/vfx/philosopher_mage/sprites_v1/manifest.json';
const SHUTDOWN_ERROR = /resources still in use at exit|RID allocations .* were leaked at exit|Pages in use exist at exit in PagedAllocator: N12VariantPools12BucketMediumE/;
const readText = relative => fs.readFileSync(path.join(ROOT, relative), 'utf8').replace(/^\uFEFF/, '').replace(/\x1b\[[0-9;]*m/g, '');
const read = relative => JSON.parse(readText(relative));
const sha256 = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const round = value => Math.round(value * 1000000) / 1000000;
const milliseconds = seconds => round(seconds * 1000);
const sum = values => values.reduce((total, value) => total + value, 0);
function requireFact(condition, message) { if (!condition) throw Error(message); }
function number(value, label) {
  requireFact(typeof value === 'number' && Number.isFinite(value), `Missing numeric evidence: ${label}`);
  return value;
}
function errorsIn(log) {
  return log.split(/\r?\n/).filter(line => /^(SCRIPT ERROR:|ERROR:)/.test(line) && !SHUTDOWN_ERROR.test(line));
}
function checkedLogs(directory) {
  const stdout = readText(`${directory}/stdout.log`);
  const stderr = readText(`${directory}/stderr.log`);
  requireFact(errorsIn(`${stdout}\n${stderr}`).length === 0, `Runtime errors in ${directory}`);
  return { stdout, stderr, shutdown: `${stdout}\n${stderr}`.split(/\r?\n/).filter(line => SHUTDOWN_ERROR.test(line)) };
}

function summarizeCase(result) {
  requireFact(result.ok === true && result.exit_code === 0 && result.timed_out === false,
    `Failed or unfinished matrix entry: ${result.name}`);
  requireFact(Array.isArray(result.runtime_errors) && result.runtime_errors.length === 0,
    `Runtime errors in matrix entry: ${result.name}`);
  const report = read(result.report);
  requireFact(report.ok === true && report.errors.length === 0 && report.clean_timing_run === true,
    `Failed or capture-only report: ${result.report}`);
  requireFact(result.name === `${report.configuration.scenario}_${report.configuration.direction}`,
    `Mismatched case identity: ${result.name}`);
  const logs = checkedLogs(path.posix.dirname(result.report));
  const rests = [report.stable_rest_before, report.stable_rest_after].filter(rest => !rest.not_applicable);
  for (const rest of rests) {
    requireFact(rest.sample_count > 0 && rest.unexpected_pose_samples === 0,
      `Rest was not stable in ${result.name}`);
  }
  const rootError = Math.max(
    number(report.maximum_local_ground_anchor_error_px, result.name),
    number(report.maximum_completed_movement_error_px, result.name),
    ...rests.map(rest => number(rest.maximum_screen_anchor_error_px, result.name)));
  const drift = Math.max(...rests.map(rest => number(rest.maximum_screen_foot_drift_px, result.name)));
  requireFact(rootError <= 0.01 && drift <= 0.01, `Ground drift in ${result.name}`);
  const casts = report.real_ai_casts.map(cast => {
    requireFact(cast.release_count === 1 && cast.spell_count === 1 && cast.finish_count === 1,
      `Duplicate or missing cast event in ${result.name}`);
    requireFact(cast.resolved_usec >= cast.release_usec && cast.release_usec > cast.started_usec,
      `Resolution precedes release in ${result.name}`);
    requireFact(cast.ap_after === cast.ap_before - cast.ap_cost && cast.returned_idle === true,
      `AP or idle contract failed in ${result.name}`);
    requireFact(cast.report.automatic === false && cast.report.effective_cast === true,
      `Expected an effective deliberate AI spell in ${result.name}`);
    return {
      spell_id: cast.spell_id, body_clip: cast.animation, ap_cost: cast.ap_cost,
      ap_before: cast.ap_before, ap_after: cast.ap_after,
      release_ms: milliseconds(cast.release_seconds), finish_ms: milliseconds(cast.duration_seconds),
      damage_after_release_ms: cast.facts.filter(fact => fact.kind === 'hp_damage')
        .map(fact => round((fact.time_usec - cast.release_usec) / 1000)),
      release_count: cast.release_count, resolution_count: cast.spell_count, finish_count: cast.finish_count,
      actual_hp_damage: cast.report.hp_damage_total, actual_hp_restored: cast.report.healing_total,
      actual_shield_granted: cast.report.shield_increase_total,
    };
  });
  const facts = report.combat_facts;
  const healing = facts.filter(fact => fact.kind === 'heal').map(fact => ({
    target: fact.target_id, hp_before: fact.target_hp - fact.amount, hp_after: fact.target_hp, restored: fact.amount,
  }));
  const controls = facts.filter(fact => fact.kind === 'hero_activation' && fact.mp < fact.mp_before_statuses)
    .map(fact => ({ mp_before_statuses: fact.mp_before_statuses, playable_mp: fact.mp,
      reduction: fact.mp_before_statuses - fact.mp, player_actions_between_measurements: fact.player_actions_since_start,
      measurement_phase: fact.phase }));
  if (report.configuration.scenario === 'control') {
    requireFact(controls.some(control => control.reduction === 2 && control.player_actions_between_measurements === 0),
      `Missing actual two-MP control in ${result.name}`);
  }
  const shields = facts.filter(fact => fact.kind === 'shield_absorbed')
    .map(fact => ({ target: fact.target_id, absorbed: fact.amount, shield_after: fact.target_shield }));
  if (report.configuration.scenario === 'shield') requireFact(shields.some(shield => shield.absorbed > 0), `No absorption in ${result.name}`);
  if (report.configuration.scenario.startsWith('heal_')) requireFact(healing.some(heal => heal.restored > 0), `No real healing in ${result.name}`);
  const deaths = report.reactions.filter(reaction => reaction.action === 'death');
  if (report.configuration.scenario === 'defeat') {
    requireFact(deaths.length === 1 && report.death_events === 1 && report.death_visual_finishes === 1 &&
      report.death_finish_alpha === 0 && report.mage_view_removed === true && report.final_mage.alive === false,
    `Incomplete real death or cleanup in ${result.name}`);
  }
  const effects = report.effects.map(effect => ({ animation: effect.animation, spell_id: effect.spell_id,
    observed_phases: effect.phases, actual_atlas_sprites: effect.maximum_sprite_count,
    canonical_atlas_observed: effect.canonical_atlas_observed }));
  requireFact(effects.every(effect => effect.actual_atlas_sprites > 0 && effect.canonical_atlas_observed === true),
    `Noncanonical effect in ${result.name}`);
  return {
    name: result.name, ok: true, direction: report.configuration.direction, scenario: report.configuration.scenario,
    scene: report.actual_scene, terrain_plan: report.actual_terrain_plan,
    classification_catalog: report.configuration.action_classification_catalog,
    progression_fixture: { level: report.progression_fixture.level,
      awarded_xp_before_combat: report.progression_fixture.xp_award?.gained_xp || 0,
      scope: report.progression_fixture.scope },
    initial_placement: { mage: report.initial_mage.cell, hero: report.placement_fixture.hero_cell,
      ally: report.initial_ally?.cell || null, formation: report.placement_fixture.initial_formation?.method || 'Single enemy spawn' },
    maximum_ground_anchor_error_px: rootError, maximum_idle_foot_drift_px: drift,
    duplicate_cast_events: 0, ai_casts: casts,
    ai_movements: report.real_ai_movements.map(move => ({ path: move.path, paid_mp: move.actual_cost,
      duration_ms: round((move.finished_usec - move.started_usec) / 1000), destination_error_px: move.destination_error_px })),
    actual_healing: healing, actual_control: controls, actual_shield_absorption: shields,
    actual_pushes: facts.filter(fact => fact.kind === 'push').map(fact => ({ from: fact.from, to: fact.to })),
    hit_reactions: report.reactions.filter(reaction => reaction.action === 'hit').map(reaction => ({
      body_clip: reaction.animation, duration_ms: milliseconds(reaction.duration_seconds),
      superseded_by_lethal_hit: reaction.duration_seconds < 0.1 && deaths.length === 1,
    })),
    death: deaths.length ? { body_clip: deaths[0].animation, duration_ms: milliseconds(deaths[0].duration_seconds),
      death_events: report.death_events, visual_finishes: report.death_visual_finishes,
      final_alpha: report.death_finish_alpha, view_removed: report.mage_view_removed } : null,
    effects, preserved_shutdown_diagnostics: logs.shutdown.length, report: result.report,
  };
}

function summarize() {
  const matrix = read(MATRIX);
  const names = new Set(DIRECTIONS.flatMap(direction => SCENARIOS.map(scenario => `${scenario}_${direction}`)));
  requireFact(matrix.capture === false && matrix.total === names.size && matrix.passed === names.size &&
    Array.isArray(matrix.results) && matrix.results.length === names.size, 'Combat matrix is incomplete: all 32 timing cases must pass');
  for (const result of matrix.results) {
    requireFact(names.delete(result.name), `Unexpected or repeated matrix case: ${result.name}`);
  }
  requireFact(names.size === 0, `Missing combat cases: ${[...names].join(', ')}`);
  const cases = matrix.results.map(summarizeCase);
  const gutLogs = checkedLogs(GUT);
  const total = label => {
    const match = gutLogs.stdout.match(new RegExp(`^\\s*${label}\\s+(\\d+)\\s*$`, 'm'));
    requireFact(match, `Missing GUT total: ${label}`);
    return Number(match[1]);
  };
  requireFact(gutLogs.stdout.includes('All tests passed!') && total('Tests') > 0 &&
    total('Tests') === total('Passing Tests'), 'Final GUT run has not passed');
  const nodeSuites = NODE_LOGS.map(log => {
    const node = readText(log);
    const nodeTotal = label => {
      const match = node.match(new RegExp(`^(?:#|ℹ)\\s*${label}\\s+(\\d+)\\s*$`, 'm'));
      requireFact(match, `Missing Node test total in ${log}: ${label}`);
      return Number(match[1]);
    };
    requireFact(nodeTotal('tests') > 0 && nodeTotal('tests') === nodeTotal('pass') && nodeTotal('fail') === 0,
      `Final Node pipeline tests have not passed: ${log}`);
    return { tests: nodeTotal('tests'), passing: nodeTotal('pass'), failed: nodeTotal('fail'), log };
  });

  const character = read(CHARACTER_MANIFEST), effect = read(EFFECT_MANIFEST);
  requireFact(character.complete === true && effect.complete === true, 'Production atlas manifests are incomplete');
  const framesPath = 'assets/characters/philosopher_mage/sprites_v1/philosopher_sprite_frames.tres';
  const frames = fs.readFileSync(path.join(ROOT, framesPath));
  requireFact(sha256(frames) === character.sprite_frames_sha256, 'Character frames do not match their manifest');
  requireFact(sha256(fs.readFileSync(path.join(ROOT, effect.atlas.path))) === effect.atlas.sha256, 'Effect atlas does not match its manifest');
  const usedDrawings = new Set([...frames.toString().matchAll(/"texture": SubResource\("((?:base|extra)_[NESW]_\d+)"\)/g)].map(match => match[1]));
  const observedSpells = [...new Set(cases.flatMap(item => item.ai_casts.map(cast => cast.spell_id)))].sort();
  requireFact(JSON.stringify(observedSpells) === JSON.stringify(SPELLS), 'The five canonical spells were not all cast by the real AI');
  const terrain = summarizeTerrain(ROOT);
  const result = {
    schema: 'dd.philosopher.complete-validation.v1', generated_at: new Date().toISOString(),
    source_matrix: MATRIX,
    evidence_sequence: "The final 32 body/spell cases were rerun after the terrain AI extension and final presentation scale. The 24 terrain cases independently verify tactical tile use and size on all five maps. Earlier matrix_final results are historical and are not counted again.",
    terrain_matrix: terrain,
    production_entry: summarizeProduction(ROOT),
    final_gameplay_captures: summarizeCaptures(ROOT),
    gut: { scripts: total('Scripts'), tests: total('Tests'), passing: total('Passing Tests'), assertions: total('Asserts'),
      stdout: `${GUT}/stdout.log`, stderr: `${GUT}/stderr.log`, preserved_shutdown_diagnostics: gutLogs.shutdown.length,
      shutdown_diagnostics_by_kind: { resource_entries: gutLogs.shutdown.filter(line => /resources still in use at exit/.test(line)).length,
        rid_entries: gutLogs.shutdown.filter(line => /RID allocations .* were leaked at exit/.test(line)).length,
        exact_variant_pool_entries: gutLogs.shutdown.filter(line => /Pages in use exist at exit in PagedAllocator: N12VariantPools12BucketMediumE/.test(line)).length } },
    pipeline_tests: { tests: sum(nodeSuites.map(suite => suite.tests)), passing: sum(nodeSuites.map(suite => suite.passing)), failed: sum(nodeSuites.map(suite => suite.failed)), suites: nodeSuites },
    production_art: { authored_body_drawings: character.total_authored_frames, distinct_body_drawings_used: usedDrawings.size,
      animation_clips: character.animation_count, verified_atlas_regions: sum(character.sheets.map(sheet => sheet.atlas_regions_verified)),
      body_manifest: CHARACTER_MANIFEST, clip_overrides: character.clip_overrides,
      authored_effect_drawings: effect.animation_order.length * effect.frames_per_animation, effect_manifest: EFFECT_MANIFEST,
      effects: effect.animation_order, hashes_verified_at_summary: true },
    combat_matrix: { tests: cases.length, passing: cases.length, real_ai_spells: observedSpells,
      maximum_ground_anchor_error_px: Math.max(...cases.map(item => item.maximum_ground_anchor_error_px)),
      maximum_idle_foot_drift_px: Math.max(...cases.map(item => item.maximum_idle_foot_drift_px)),
      duplicate_cast_events: sum(cases.map(item => item.duplicate_cast_events)), cases },
    limitations: [
      'Real production combat uses explicit initial spawn/facing fixtures. Allied cases use the canonical formation planner with fixed initial role distances; all movement and damage thereafter are normal gameplay.',
      'Healing cases award legal XP to level 2 before combat; defeat uses level 10 with no mastery purchases. These are disclosed combat fixtures, not a campaign playthrough.',
      'Timing runs disable GPU capture. Separate gameplay GIFs retain original capture timestamps; they are not substitutes for these timing measurements.',
      'Known resource/RID shutdown diagnostics and the exact PagedAllocator VariantPools BucketMedium shutdown message remain preserved and counted in logs. They are distinguished from script/runtime errors and are not claimed to be fixed.',
    ],
  };
  const destination = path.join(ROOT, OUTPUT);
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  fs.writeFileSync(destination, `${JSON.stringify(result, null, 2)}\n`);
  return result;
}

if (require.main === module) {
  try {
    const result = summarize();
    console.log(JSON.stringify({ gut_tests: result.gut.tests, assertions: result.gut.assertions,
      pipeline_tests: result.pipeline_tests.tests, combats: result.combat_matrix.passing, terrain_combats: result.terrain_matrix.passing,
      real_ai_spells: result.combat_matrix.real_ai_spells, output: OUTPUT }));
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
module.exports = { summarize, summarizeCase, errorsIn };
