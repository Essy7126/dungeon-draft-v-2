'use strict';

const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const DIRECTORY = 'artifacts/philosopher_sprite_validation_v1/trial_entry_terrain_final';
const REPORT = `${DIRECTORY}/trial_entry_validation.json`;
const MEDIA = 'docs/design/philosopher_mage/media';
const REQUIRED_CAPTURE_MAPS = ['ashen_hell_courtyard_v1', 'lethe_crossing_v1', 'black_oath_temple_v1'];
function ensure(condition, message) { if (!condition) throw Error(message); }
const digest = value => crypto.createHash('sha256').update(value).digest('hex');
const read = file => JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));

function cleanLogs(root, directory) {
  for (const name of ['stdout.log', 'stderr.log']) {
    const text = fs.readFileSync(path.resolve(root, directory, name), 'utf8');
    ensure(!text.split(/\r?\n/).some(line => /^(SCRIPT ERROR:|ERROR:)/.test(line) && !/resources still in use at exit|RID allocations .* were leaked at exit|Pages in use exist at exit in PagedAllocator: N12VariantPools12BucketMediumE/.test(line)),
      `Runtime error in production/capture log ${directory}/${name}`);
  }
}

function summarizeProduction(root) {
  const report = read(path.join(root, REPORT));
  ensure(report.ok === true && report.errors.length === 0, 'Normal production entry did not pass');
  cleanLogs(root, DIRECTORY);
  const observation = report.observations, terrain = observation.terrain;
  ensure(report.production_run === 'res://data/runs/philosopher_trial.tres' && observation.room_path === 'res://data/rooms/philosopher_trial.tres',
    'Production entry used different resources');
  ensure(observation.actual_scene === 'res://battle/painted/registered_terrain/RegisteredTerrainBattle.tscn' &&
    observation.terrain_plan === 'res://data/arenas/lethe_crossing_v1/terrain_plan.json', 'Production trial is not on the real Lethe map');
  ensure(observation.startup_observer_only === true && Object.keys(observation.direct_test_options).length === 0,
    'Normal entry unexpectedly used direct combat fixtures');
  ensure(report.initial_progression.length === 1 && report.initial_progression[0].unit_id === 'achilles' &&
    report.initial_progression[0].progression.current_level === 1 && report.initial_progression[0].progression.current_xp === 0 &&
    report.initial_progression[0].hp === report.initial_progression[0].max_hp, 'Production Achilles did not start normally');
  ensure(report.selection.button_visible === true && report.selection.start_button_enabled === true && report.selection.occluding_panels.length === 0,
    'Production selection card was not usable');
  ensure(observation.units.map(unit => unit.id).sort().join(',') === 'achilles,philosopher_mage,spectre_greatsword', 'Wrong production roster');
  ensure(observation.units.every(unit => unit.sprite_count === 1 && unit.backend === 'Sprite2DBackend' && unit.visible === true),
    'Missing canonical production sprites');
  ensure(observation.mage_painted_visual_scale > 1.4 && observation.mage_to_achilles_scale_ratio >= 0.9 && observation.mage_to_achilles_scale_ratio <= 1.1,
    'Production mage scale mismatches Achilles');
  ensure(terrain.observation_only === true && terrain.permanent_special_cells.length === 8 && terrain.registered_floor_tile_count === 114 && terrain.rendered_terrain_node_count === 114,
    'Production Lethe floor and authored tile counts differ');
  const expectedCounts = { water: 3, ice: 2, lava: 2, electrified_water: 1 };
  for (const [id, count] of Object.entries(expectedCounts)) ensure(terrain.terrain_counts[id] === count, `Wrong production tile count ${id}`);
  ensure(terrain.permanent_special_cells.every(cell => cell.visible && cell.texture === cell.expected_texture && cell.base_terrain_id === cell.terrain_id && cell.apply_on_enter),
    'Production special tile runtime/art mismatch');
  ensure(terrain.vortex_networks.length === 1 && terrain.vortex_networks[0].endpoints.length === 2 &&
    terrain.vortex_networks[0].endpoints.every(endpoint => endpoint.visible && endpoint.has_grid_portal && endpoint.actual_cells.length === 2),
    'Production portal pair was not actually rendered and registered');
  const turn = report.first_turn;
  ensure(report.startup_observer_only === false && JSON.stringify(report.player_combat_intents) === '["end_turn"]' &&
    turn?.ok === true && turn.completed === true && turn.player_end_turn_requests === 1 && turn.player_requested_spells === 0 &&
    turn.stats_or_positions_modified_by_probe === false, 'Missing normal first AI activation after the real End Turn');
  const jump = turn.actual_portal_jump;
  ensure(jump && jump.network_id === 'philosopher_trial_portals' && JSON.stringify(jump.to) === JSON.stringify(jump.actual_cell) &&
    JSON.stringify(jump.from) !== JSON.stringify(jump.to), 'Production mage did not actually traverse the authored portal pair');
  ensure(turn.paid_ap > 0 && turn.paid_ap <= turn.initial_mage.ap && turn.paid_mp > 0 && turn.paid_mp <= turn.initial_mage.mp &&
    turn.ap_expenses.every(expense => expense.paid_ap > 0 && expense.before - expense.after === expense.paid_ap), 'Production first-turn budgets were not paid normally');
  ensure(turn.casts_after_portal.length > 0 && turn.casts_after_portal.every(cast => !cast.failed && !cast.banner_visible &&
    JSON.stringify(cast.caster_cell) === JSON.stringify(jump.to) && cast.time_usec >= jump.time_usec &&
    cast.distance >= cast.minimum_range && cast.distance <= cast.maximum_range && (!cast.needs_line_of_sight || cast.line_of_sight) &&
    (cast.classification !== 'PROJECTILE' || cast.projectile_path)), 'Production post-portal spells were not legal or visible');
  return { ok: true, report: REPORT, entrypoint: report.entrypoint, production_run: report.production_run,
    first_turn: turn,
    ui_actions: report.ui_actions, selection: report.selection, initial_progression: report.initial_progression,
    actual_scene: observation.actual_scene, room: observation.room_path, terrain_plan: observation.terrain_plan,
    units: observation.units, terrain, mage_to_achilles_scale_ratio: observation.mage_to_achilles_scale_ratio,
    screenshots: report.screenshots,
    scope: 'Actual selection, transition and deployment of the authored level-one trial, then one real End Turn: the enemy voluntarily traverses the authored portal and casts from its actual exit. No stats, positions or spells are forced.' };
}

function summarizeCaptures(root) {
  const files = fs.readdirSync(path.join(root, MEDIA)).filter(name => /\.encode_report\.json$/.test(name))
    .map(name => ({ name, encoding: read(path.join(root, MEDIA, name)) }))
    .filter(item => /terrain_capture_|captures_final_E/.test(item.encoding.input));
  const observedMaps = new Set(), observedBaseScenarios = new Set();
  const captures = files.map(({ name, encoding }) => {
    const relative = `${MEDIA}/${name}`;
    const manifest = read(encoding.input), captureDirectory = path.dirname(path.dirname(encoding.input));
    const report = read(path.join(captureDirectory, 'runtime_validation.json'));
    ensure(report.ok === true && report.errors.length === 0 && report.capture_clip.enabled === true && report.clean_timing_run === false,
      `Failed or non-capture media source ${name}`);
    cleanLogs(root, captureDirectory);
    ensure(manifest.frame_limit_reached === false && encoding.source_images_checked_in_order === manifest.frame_count && encoding.frames === manifest.frame_count,
      `Incomplete captured timeline ${name}`);
    ensure(digest(fs.readFileSync(encoding.input)) === encoding.source_manifest_sha256 && digest(fs.readFileSync(encoding.output)) === encoding.gif_sha256,
      `Stale capture/encoded media ${name}`);
    ensure(Math.abs(encoding.encoded_duration_ms - encoding.source_duration_ms) <= 10,
      `Capture was sped up or slowed down ${name}`);
    const map = report.configuration.room_path.split('/').at(-2);
    observedMaps.add(map);
    if (/captures_final_E/.test(encoding.input)) observedBaseScenarios.add(report.configuration.scenario);
    const relativePath = file => path.relative(root, file).replace(/\\/g, '/');
    return { map, scenario: report.configuration.scenario, direction: report.configuration.direction,
      gif: relativePath(encoding.output), poster: relativePath(encoding.output.replace(/\.gif$/i, '.poster.png')),
      encode_report: relative, capture_report: relativePath(path.join(captureDirectory, 'runtime_validation.json')),
      source_frames: encoding.frames, encoded_frames: encoding.encoded_frames,
      original_duration_ms: encoding.source_duration_ms, encoded_duration_ms: encoding.encoded_duration_ms,
      source_manifest_sha256: encoding.source_manifest_sha256, gif_sha256: encoding.gif_sha256,
      scope: 'Real graphical combat capture; original timestamps, verified chronological image order. Separate runs establish animation cadence.' };
  });
  ensure(REQUIRED_CAPTURE_MAPS.every(map => observedMaps.has(map)), 'Final visual captures missing for Ashen, Lethe or Black Oath Temple');
  ensure(['heal_ally', 'shield'].every(scenario => observedBaseScenarios.has(scenario)), 'Final real heal and shield captures are missing');
  return captures;
}

module.exports = { summarizeProduction, summarizeCaptures, REPORT, DIRECTORY, MEDIA };
