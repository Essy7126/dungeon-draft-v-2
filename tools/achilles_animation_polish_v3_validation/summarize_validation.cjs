'use strict';
// Summarize observed combat reports only. No synthetic successful fixtures.
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const batch = process.argv[2] || 'matrix_final';
if (!/^[a-zA-Z0-9_-]+$/.test(batch)) throw Error('Invalid batch directory');
const read = relative => JSON.parse(fs.readFileSync(path.join(root, relative), 'utf8').replace(/^\uFEFF/, ''));
const folder = `artifacts/achilles_animation_polish_v3_validation/${batch}`;
const matrix = read(`${folder}/summary.json`);
const requireTrue = (value, message) => { if (!value) throw Error(message); };
const main = ['base_combo', 'base_shot', 'chiron_shot', 'volley_shot', 'wrath_combo'];
const expectedNames = ['E', 'N', 'S', 'W'].flatMap(direction => main.map(id => `${id}_${direction}_classic_walk3`));
expectedNames.push('stopping_shot_E_classic_walk3', 'piercing_shot_E_classic_walk3', 'base_shot_E_painted_g_walk1');
requireTrue(matrix.capture === false && matrix.total === 23 && matrix.passed === 23, 'Expected 23 clean timing combats');
requireTrue(matrix.results.length === 23 && new Set(matrix.results.map(r => r.name)).size === 23, 'Missing or duplicate matrix case');
requireTrue(expectedNames.every(name => matrix.results.some(r => r.name === name)), 'Required cardinal or supplementary case missing');
// A targeted rerun can supersede matching successful cases after art-only edits.
// Every replacement is read from a completed clean matrix; nothing is synthesized.
const replacementBatches = [];
for (const replacement of process.argv.slice(3)) {
  requireTrue(/^[a-zA-Z0-9_-]+$/.test(replacement), 'Invalid replacement batch');
  const relative = `artifacts/achilles_animation_polish_v3_validation/${replacement}/summary.json`;
  const rerun = read(relative);
  requireTrue(rerun.capture === false && rerun.total > 0 && rerun.total === rerun.passed && rerun.results.length === rerun.total, 'Incomplete replacement matrix');
  const names = rerun.results.map(result => result.name);
  requireTrue(new Set(names).size === names.length && names.every(name => expectedNames.includes(name)), 'Unknown or duplicate replacement case');
  const replacements = new Map(rerun.results.map(result => [result.name, result]));
  matrix.results = matrix.results.map(result => replacements.get(result.name) || result);
  replacementBatches.push({ summary: relative, superseded_case_names: names });
}
const byName = new Map();
const finiteNearZero = (value, label) => requireTrue(Number.isFinite(value) && value <= 0.01, label);
const expectedHits = { base: 1, stopping: 1, piercing: 2, chiron: 3, volley: 3 };
const cases = matrix.results.map(result => {
  requireTrue(result.ok && result.exit_code === 0 && !result.timed_out && result.runtime_errors.length === 0, `Failed process: ${result.name}`);
  const report = read(result.report);
  requireTrue(report.ok && report.errors.length === 0 && report.clean_timing_run, `Invalid report: ${result.name}`);
  requireTrue(report.polish_validation?.version === 3 && report.real_walk.ok, `V3 observation missing: ${result.name}`);
  for (const field of ['stable_rest_before', 'stable_rest_after_walk', 'stable_rest_after']) {
    const rest = report[field];
    requireTrue(rest?.sample_count > 0 && rest.unexpected_pose_samples === 0 && rest.canvas_settling?.ok, `Rest observation missing: ${result.name}/${field}`);
    finiteNearZero(rest.maximum_screen_anchor_error_px, `Rest anchor drift: ${result.name}/${field}`);
    finiteNearZero(rest.maximum_screen_foot_drift_px, `Rest foot drift: ${result.name}/${field}`);
  }
  finiteNearZero(report.real_walk.maximum_anchor_error_px, `Walk anchor drift: ${result.name}`);
  requireTrue(report.real_walk.monotonic_straight_travel && report.real_walk.distinct_drawn_textures >= 3,
    `Walk not rendered as actual coherent drawings: ${result.name}`);
  requireTrue(report.real_walk.observed_stride_steps.length === report.real_walk.steps, `Missing paid stride: ${result.name}`);
  const shot = report.actions.find(action => action.spell_id === 'achilles_pelion_shot');
  if (shot) {
    requireTrue(shot.damaged_enemy_count === expectedHits[report.configuration.kit], `Arrow target count mismatch: ${result.name}`);
    requireTrue(shot.projectile_observation?.drawn_flight_textures.length && shot.projectile_observation.drawn_impact_textures.length,
      `Actual projectile or impact art missing: ${result.name}`);
    finiteNearZero(shot.projectile_observation.maximum_release_origin_error_px, `Projectile release origin mismatch: ${result.name}`);
  }
  for (const action of report.actions) {
    requireTrue(action.releases === 1 && action.uses_after === action.uses_before + 1, `Duplicate marker/use: ${result.name}`);
    requireTrue(action.after.ap === action.before.ap - action.expected_ap_cost, `Cast AP mismatch: ${result.name}`);
    finiteNearZero(action.view_destination_error_px, `Cast destination mismatch: ${result.name}`);
    if (action.spell_id === 'achilles_fulminant_dash') {
      requireTrue(action.movement_arrival_count === 1 && action.non_charge_samples_during_dash === 0 && action.max_view_travel_px > 1,
        `Dash movement regression: ${result.name}`);
    } else requireTrue(action.finishes === 1, `Cast completion mismatch: ${result.name}`);
  }
  byName.set(result.name, report);
  return { name: result.name, report: result.report, configuration: report.configuration,
    scene: report.actual_scene, visual_scene: report.actual_visual_scene,
    sprite_frames: report.actual_sprite_frames,
    walk: { cells: report.real_walk.steps, mp_cost: report.real_walk.cost,
      distinct_drawings: report.real_walk.distinct_drawn_textures,
      expected_seconds: report.real_walk.expected_travel_seconds,
      observed_seconds: report.real_walk.input_to_idle_seconds,
      anchor_error_px: report.real_walk.maximum_anchor_error_px },
    actions: report.actions.map(action => ({ spell: action.spell_id, stem: action.presentation.animation_stem,
      variant: action.presentation.variant, ap_cost: action.expected_ap_cost, targets: action.damaged_enemy_count,
      release_ms: action.release_after_animation_ms, finished_ms: action.duration_after_animation_ms,
      projectile: action.projectile_observation || null })) };
});
const shotFor = name => byName.get(name).actions.find(action => action.spell_id === 'achilles_pelion_shot');
const differences = [];
for (const direction of ['E', 'N', 'S', 'W']) {
  const base = shotFor(`base_shot_${direction}_classic_walk3`);
  for (const kit of ['chiron', 'volley']) {
    const specialized = shotFor(`${kit}_shot_${direction}_classic_walk3`);
    requireTrue(base.presentation.animation_stem !== specialized.presentation.animation_stem,
      `Specialist body reused base animation: ${kit}/${direction}`);
    const baseArt = new Set(base.projectile_observation.drawn_flight_textures);
    requireTrue(specialized.projectile_observation.drawn_flight_textures.every(texture => !baseArt.has(texture)),
      `Specialist projectile reused base drawing: ${kit}/${direction}`);
    differences.push({ direction, kit, base_body: base.presentation.animation_stem,
      specialized_body: specialized.presentation.animation_stem, projectile_art_is_distinct: true });
  }
}
for (const kit of ['stopping', 'piercing']) {
  const base = shotFor('base_shot_E_classic_walk3');
  const upgraded = shotFor(`${kit}_shot_E_classic_walk3`);
  const baseArt = new Set(base.projectile_observation.drawn_flight_textures);
  requireTrue(upgraded.projectile_observation.drawn_flight_textures.every(texture => !baseArt.has(texture)),
    `Augmented projectile reused base drawing: ${kit}`);
}
const output = { schema: 'dd.achilles.animation-polish-validation.v3',
  generated_at: new Date().toISOString(), combats: cases.length, passed: cases.length,
  source_matrix: `${folder}/summary.json`, replacement_matrices: replacementBatches, case_results: cases, observed_specialization_differences: differences,
  scope: 'Real combat scenes with declared precombat placement/XP fixtures, native deployment and movement/spell input. These are not a completed campaign playthrough.',
  limits: ['Foot alpha bounds are a contact heuristic; anatomical and aesthetic coherence require visual inspection.',
    'Clean timing reports exclude viewport captures. Captured clips are a separate visual pass with original timestamps.',
    'Known shutdown resource/RID diagnostics remain visible in stdout/stderr and are not reported as fixed.'] };
const destination = 'docs/design/achilles/achilles_animation_polish_validation_v3.json';
fs.mkdirSync(path.dirname(path.join(root, destination)), { recursive: true });
fs.writeFileSync(path.join(root, destination), JSON.stringify(output, null, 2) + '\n');
console.log(JSON.stringify({ combats: cases.length, passed: cases.length, report: destination }));
