'use strict';

const fs = require('node:fs');
const path = require('node:path');
const MAPS = ['greek_drawn_courtyard_v1', 'ashen_hell_courtyard_v1', 'silent_judgment_courtyard_v1', 'lethe_crossing_v1', 'black_oath_temple_v1'];
const COMMON = ['push_lava', 'push_water', 'push_ice', 'portal_pair'];
const EXTRAS = ['avoid_fire', 'escape_fire', 'push_electric', 'portal_network'];
const SUMMARY = 'artifacts/philosopher_sprite_validation_v1/terrain_final/summary.json';
const STONE_SHADER = 'res://battle/painted/registered_terrain/shaders/stone_palette.gdshader';
function ensure(value, message) { if (!value) throw Error(message); }

function summarizeTerrain(root) {
  const read = relative => JSON.parse(fs.readFileSync(path.join(root, relative), 'utf8').replace(/^\uFEFF/, ''));
  const summary = read(SUMMARY);
  const expected = new Set(MAPS.flatMap(map => (map === MAPS[0] ? [...COMMON, ...EXTRAS] : COMMON).map(scenario => `${map}:${scenario}`)));
  ensure(summary.capture === false && summary.total === expected.size && summary.passed === expected.size && summary.results.length === expected.size,
    'Terrain matrix incomplete: all 24 real combat cases must pass');
  const cases = summary.results.map(entry => {
    ensure(expected.delete(`${entry.map}:${entry.scenario}`), `Unexpected or duplicate terrain case ${entry.name}`);
    ensure(entry.ok === true && entry.exit_code === 0 && entry.timed_out === false && entry.runtime_errors.length === 0,
      `Failed terrain case ${entry.name}`);
    const report = read(entry.report), evidence = report.terrain_validation;
    ensure(report.ok === true && report.errors.length === 0 && report.clean_timing_run === true && evidence,
      `Missing clean terrain proof ${entry.name}`);
    ensure(report.configuration.scenario === entry.scenario && report.configuration.room_path === `res://data/arenas/${entry.map}/arena.tres`,
      `Wrong canonical map or fixture ${entry.name}`);
    ensure(report.progression_fixture.level === 1 && report.real_hero_actions.length === 0, `Unexpected hero intervention ${entry.name}`);
    ensure(evidence.initial_actors.mage_presentation_scale >= 1.4, `Missing mage map presentation ${entry.name}`);
    ensure(report.maximum_local_ground_anchor_error_px <= 0.01 && report.maximum_completed_movement_error_px <= 0.01,
      `Ground/root drift ${entry.name}`);
    for (const suffix of ['stdout.log', 'stderr.log']) {
      const log = fs.readFileSync(path.join(root, path.posix.dirname(entry.report), suffix), 'utf8');
      ensure(!log.split(/\r?\n/).some(line => /^(SCRIPT ERROR:|ERROR:)/.test(line) && !/resources still in use at exit|RID allocations .* were leaked at exit|Pages in use exist at exit in PagedAllocator: N12VariantPools12BucketMediumE/.test(line)),
        `Runtime error in terrain evidence ${entry.name}`);
    }
    for (const cast of report.real_ai_casts) {
      ensure(cast.release_count === 1 && cast.spell_count === 1 && cast.finish_count === 1 && cast.ap_after === cast.ap_before - cast.ap_cost && cast.report.effective_cast === true,
        `Duplicate, ineffective or unpaid spell ${entry.name}`);
    }
    for (const tile of evidence.tile_visual_contracts) {
      if (tile.kind === 'vortex_network') ensure(tile.has_real_grid_portal && tile.network_cells.length >= 2, `Missing actual portal ${entry.name}`);
      else ensure(tile.visible && tile.actual_texture === tile.expected_texture && tile.actual_visual_id === tile.expected_id && tile.shader_path !== STONE_SHADER,
        `Special tile hidden or recolored as stone ${entry.name}`);
    }
    const facts = report.combat_facts;
    const environmentStatuses = facts.filter(fact => fact.kind === 'status' && fact.environmental_source === true).map(fact => fact.status_id);
    const actualPushes = facts.filter(fact => fact.kind === 'push').map(fact => ({ from: fact.from, to: fact.to }));
    if (entry.scenario.startsWith('push_')) {
      ensure(report.real_ai_casts.some(cast => cast.spell_id === 'philosopher_refutation') && actualPushes.some(push => push.to === report.placement_fixture.hazard_cell),
        `No real enemy push onto the fixture ${entry.name}`);
      const status = { push_lava: 'burn', push_water: 'wet', push_ice: 'frozen', push_electric: 'shock' }[entry.scenario];
      ensure(environmentStatuses.includes(status), `Missing actual terrain status ${entry.name}`);
    }
    if (['push_water', 'push_ice'].includes(entry.scenario)) ensure(evidence.hero_terrain_mp_penalty_observed === true, `Missing playable MP penalty ${entry.name}`);
    if (['push_lava', 'push_electric'].includes(entry.scenario)) ensure(evidence.environment_hp_damage_to_hero > 0, `No real environment damage ${entry.name}`);
    if (entry.scenario === 'push_electric') ensure(evidence.hero_shock_activation_skipped === true, `Shock did not skip activation ${entry.name}`);
    if (entry.scenario.startsWith('portal_')) ensure(evidence.cast_from_actual_portal_exit === true && evidence.actual_portal_jump.to,
      `Missing real portal utility ${entry.name}`);
    if (['avoid_fire', 'escape_fire'].includes(entry.scenario)) ensure(report.real_ai_movements.length > 0 && report.real_ai_casts.length > 0,
      `Missing tactical terrain movement ${entry.name}`);
    return {
      map: entry.map, scenario: entry.scenario, direction: report.configuration.direction, seed: entry.seed, ok: true,
      actual_scene: report.actual_scene, actual_terrain_plan: report.actual_terrain_plan,
      initial_actors: evidence.initial_actors, initial_tiles: report.placement_fixture.permanent_tiles,
      initial_portal_cells: report.placement_fixture.portal_cells,
      environment_hp_damage_to_hero: evidence.environment_hp_damage_to_hero,
      environment_hp_damage_to_mage: evidence.environment_hp_damage_to_mage,
      environmental_statuses: [...new Set(environmentStatuses)],
      actual_pushes: actualPushes, playable_mp_reduction_observed: evidence.hero_terrain_mp_penalty_observed,
      shock_activation_skipped: evidence.hero_shock_activation_skipped,
      actual_portal_jump: evidence.actual_portal_jump, spell_from_real_exit: evidence.cast_from_actual_portal_exit,
      ai_casts: report.real_ai_casts.map(cast => ({ spell: cast.spell_id, caster_cell: cast.actual_caster_cell,
        hero_cell: cast.actual_hero_cell, distance_to_hero: cast.actual_distance_to_hero, ap_cost: cast.ap_cost,
        ap_before: cast.ap_before, ap_after: cast.ap_after, release_count: cast.release_count, resolution_count: cast.spell_count })),
      ai_movements: report.real_ai_movements.map(move => ({ prepared_path: move.path, resolved_path: move.resolved_path,
        actual_destination: move.actual_destination, paid_mp: move.actual_cost, mp_before: move.mp_before, mp_after: move.mp_after,
        destination_error_px: move.destination_error_px })),
      tile_visual_contracts: evidence.tile_visual_contracts,
      maximum_ground_anchor_error_px: report.maximum_local_ground_anchor_error_px,
      maximum_movement_destination_error_px: report.maximum_completed_movement_error_px,
      duplicate_cast_events: 0, report: entry.report,
    };
  });
  ensure(expected.size === 0, 'Missing terrain cases');
  return { tests: cases.length, passing: cases.length, maps: MAPS, source: SUMMARY,
    fixture_scope: summary.fixture_scope,
    rules: { fire: 'Real terrain damage and Burn', water: 'Wet, next playable activation -1 MP',
      ice: 'Frozen, next playable activation -1 MP; no automatic sliding',
      electricity: 'Pre-existing electrified water, real damage and forced-entry Shock activation skipped',
      portals: 'AI voluntarily enters; actual engine exit and subsequent legal cast observed',
      excluded: 'Holy mage spells do not trigger lightning conduction, melting or steam; these reactions are not claimed.' }, cases };
}

module.exports = { summarizeTerrain, MAPS, COMMON, EXTRAS, SUMMARY };
