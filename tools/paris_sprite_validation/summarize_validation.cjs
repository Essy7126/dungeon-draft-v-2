#!/usr/bin/env node
'use strict';

// Summarize completed runtime evidence. Never converts partial runs into passes.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const ROOT = path.resolve(__dirname, '../..');
const batch = process.argv[2] || 'matrix_final';
const productionBatch = process.argv[3] || 'final_boss_production';
if (![batch, productionBatch].every(value => /^[a-zA-Z0-9_-]+$/.test(value))) throw Error('Invalid batch directory.');
const folder = `artifacts/paris_sprite_validation_v1/${batch}`;
const readText = p => fs.readFileSync(path.join(ROOT, p), 'utf8').replace(/^\uFEFF/, '').replace(/\x1b\[[0-9;]*m/g, '');
const read = p => JSON.parse(readText(p));
const demand = (condition, message) => { if (!condition) throw Error(message); };
const sha256 = p => crypto.createHash('sha256').update(fs.readFileSync(path.join(ROOT,p))).digest('hex');
const shutdown = /resources still in use at exit|RID allocations .* were leaked at exit|Pages in use exist at exit in PagedAllocator: N12VariantPools12BucketMediumE/;
const expected = ['spectral','ice','fire','vortex','teleport','approach','transform','defeat']
  .flatMap(scenario => ['E','N','S','W'].map(direction => `${scenario}_${direction}`));
const summary = read(`${folder}/summary.json`);
demand(summary.capture === false && summary.total === expected.length && summary.passed === expected.length,
  'A complete clean-timing matrix is required.');
demand(summary.results.length === expected.length && new Set(summary.results.map(row => row.name)).size === expected.length,
  'Every scenario and direction must appear exactly once.');
const cases = summary.results.map(row => {
  demand(expected.includes(row.name) && row.ok === true && row.exit_code === 0 && row.timed_out === false,
    `Failed matrix entry: ${row.name}`);
  demand(path.posix.normalize(row.report).startsWith(folder + '/'), `Report outside batch: ${row.name}`);
  const report = read(row.report);
  demand(report.ok === true && report.errors.length === 0 && report.clean_timing_run === true,
    `Failed or capture-only report: ${row.name}`);
  demand(row.name === `${report.configuration.scenario}_${report.configuration.direction}`, 'Case identity mismatch.');
  const caseFolder = path.posix.dirname(row.report);
  const logs = readText(`${caseFolder}/stdout.log`) + '\n' + readText(`${caseFolder}/stderr.log`);
  const errors = logs.split(/\r?\n/).filter(line => /^(SCRIPT ERROR:|ERROR:)/.test(line) && !shutdown.test(line));
  demand(errors.length === 0, `Runtime errors in ${row.name}: ${errors}`);
  const rests = [report.stable_rest_before, report.stable_rest_after].filter(r => !r.not_applicable);
  demand(rests.every(r => r.sample_count > 0 && r.unexpected_pose_samples === 0 && r.maximum_screen_foot_drift_px <= 0.01),
    `Unstable rest in ${row.name}`);
  demand(report.maximum_local_ground_anchor_error_px <= 0.01 && report.maximum_completed_movement_error_px <= 0.01,
    `Anchor or movement drift in ${row.name}`);
  const casts = report.real_ai_casts.map(cast => {
    demand(cast.release_count === 1 && cast.spell_count === 1 && cast.finish_count === 1,
      `Cast event count failed in ${row.name}`);
    demand(cast.resolved_usec >= cast.release_usec && cast.ap_after === cast.ap_before - cast.ap_cost && cast.returned_idle === true,
      `Resolution, AP or idle failed in ${row.name}`);
    return { spell_id: cast.spell_id, form: cast.combat_form, body_clip: cast.animation,
      ap_paid: cast.ap_cost, release_seconds: cast.release_seconds, duration_seconds: cast.duration_seconds,
      actual_caster_cell: cast.actual_caster_cell, terrain_after: cast.terrain_after,
      hp_damage: cast.report.hp_damage_total, effective_cast: cast.report.effective_cast };
  });
  const transformations = report.transformations.map(change => {
    demand(change.hp > 0 && change.hp * 5 < change.max_hp && change.finish_count === 1 && change.form_after === 'infernal',
      `Invalid transformation in ${row.name}`);
    return { hp: change.hp, max_hp: change.max_hp, shield: change.shield, finish_count: change.finish_count,
      duration_seconds: change.duration_seconds, atlas: change.final_frames };
  });
  if (['transform','defeat'].includes(report.configuration.scenario)) {
    demand(transformations.length === 1 && casts.some(cast => cast.spell_id === 'paris_infernal_whip'),
      `Missing actual infernal turn in ${row.name}`);
  }
  if (report.configuration.scenario === 'defeat') {
    demand(report.death_events === 1 && report.death_visual_finishes === 1 && report.paris_view_removed === true && !report.final_paris.alive,
      `Incomplete real death in ${row.name}`);
  }
  demand(report.effects.length > 0 && report.effects.every(effect => effect.canonical_atlas_observed && effect.maximum_sprite_count > 0),
    `Missing actual sprite effects in ${row.name}`);
  return { name: row.name, ok: true, source_report: row.report, report_sha256: sha256(row.report),
    scene: report.actual_scene, terrain_plan: report.actual_terrain_plan,
    progression_level_before_combat: report.progression_fixture.level,
    initial_hp: report.initial_paris.hp, final_hp: report.final_paris.hp, final_shield: report.final_paris.shield,
    actual_hero_actions: report.real_hero_actions, casts, transformations,
    maximum_ground_anchor_error_px: report.maximum_local_ground_anchor_error_px,
    maximum_movement_arrival_error_px: report.maximum_completed_movement_error_px,
    occupancy_events: report.grid_occupancy_events, form_atlases: report.form_atlas_paths,
    actual_hp_damage_facts: report.combat_facts.filter(fact => fact.kind === 'hp_damage'),
    death_events: report.death_events, death_visual_finishes: report.death_visual_finishes,
    effects: report.effects.map(effect => ({spell_id: effect.spell_id, animation: effect.animation, phases: effect.phases,
      actual_atlas_sprites: effect.maximum_sprite_count})),
    shutdown_resource_diagnostics_present: logs.split(/\r?\n/).some(line => shutdown.test(line)) };
});
// The isolated matrix is insufficient to claim integration into the actual final room.
const productionFolder = 'artifacts/paris_sprite_validation_v1/' + productionBatch;
const productionSummary = read(productionFolder + '/summary.json');
demand(productionSummary.name === 'final_boss_production' && productionSummary.capture === false &&
  productionSummary.ok === true && productionSummary.exit_code === 0 && productionSummary.timed_out === false,
  'A clean-timing production final-room run is required.');
demand(path.posix.normalize(productionSummary.report).startsWith(productionFolder + '/'), 'Production report outside batch.');
const productionReport = read(productionSummary.report);
const productionLogs = readText(productionFolder + '/stdout.log') + '\n' + readText(productionFolder + '/stderr.log');
demand(!productionLogs.split(/\r?\n/).some(line => /^(SCRIPT ERROR:|ERROR:)/.test(line) && !shutdown.test(line)),
  'Runtime errors in the actual final encounter.');
demand(productionReport.ok === true && productionReport.errors.length === 0 && productionReport.clean_timing_run === true,
  'Failed or capture-only final production report.');
demand(productionReport.configuration.scenario === 'production_final' && productionReport.configuration.source_room_index === 4 &&
  productionReport.configuration.room_path === 'res://data/rooms/odyssey/room_05.tres' &&
  productionReport.actual_terrain_plan === 'res://data/arenas/black_oath_temple_v1/terrain_plan.json',
  'The actual final room V must be observed.');
demand(JSON.stringify([...productionReport.actual_roster].sort()) === JSON.stringify(['catabase_shadow_paris','spectre_greatsword','spectre_greatsword']),
  'The production roster must be Paris and two spectres.');
const bossAtStart = productionReport.initial_units.find(unit => unit.id === 'catabase_shadow_paris');
demand(bossAtStart && bossAtStart.hp === bossAtStart.max_hp && bossAtStart.shield === 0,
  'The final boss must start at full HP without a shield.');
demand(productionReport.enemy_turns > 0 && productionReport.real_ai_casts.length > 0,
  'The real final boss must take an offensive turn.');
demand(productionReport.real_ai_casts.every(cast => cast.release_count === 1 && cast.finish_count === 1 && cast.spell_count === 1 &&
  cast.resolved_usec >= cast.release_usec && cast.ap_after === cast.ap_before - cast.ap_cost && cast.returned_idle),
  'Final-room casts must have exactly one correctly timed resolution.');
demand([productionReport.stable_rest_before, productionReport.stable_rest_after].every(rest =>
  rest.sample_count > 0 && rest.unexpected_pose_samples === 0 && rest.maximum_screen_foot_drift_px <= 0.01),
  'Final-room rest must remain stable.');
demand(productionReport.maximum_local_ground_anchor_error_px <= 0.01 && productionReport.maximum_completed_movement_error_px <= 0.01,
  'Final-room anchor or arrival drift.');
demand(productionReport.effects.length > 0 && productionReport.effects.every(effect => effect.canonical_atlas_observed && effect.maximum_sprite_count > 0),
  'The real final-room spells must use the canonical sprite effects.');
const production = { batch: productionBatch, ok: true, source_report: productionSummary.report,
  report_sha256: sha256(productionSummary.report), source_run: productionReport.configuration.source_run_path,
  room_index: 5, room_path: productionReport.configuration.room_path, terrain_plan: productionReport.actual_terrain_plan,
  roster: productionReport.actual_roster, initial_units: productionReport.initial_units,
  progression_level_before_combat: productionReport.progression_fixture.level,
  actual_hero_actions: productionReport.real_hero_actions,
  actual_boss_casts: productionReport.real_ai_casts.map(cast => ({spell_id:cast.spell_id, body_clip:cast.animation,
    release_seconds:cast.release_seconds, duration_seconds:cast.duration_seconds, ap_paid:cast.ap_cost})),
  actual_boss_movements: productionReport.real_ai_movements, turn_order: productionReport.turn_order,
  scope: productionReport.scope };
const result = {schema:'dd.paris.verified-combat-evidence.v1', generated_utc:new Date().toISOString(),
  matrix:{batch,passed:cases.length,total:expected.length,directions:['E','N','S','W']},
  scope:'Real registered-terrain combat using canonical Catabase Paris. Declared precombat spawn, facing, terrain and XP fixtures; no runtime HP/AP/MP/cooldown/position/clock writes. Not a campaign playthrough.',
  production_access:'Normal Catabase selection, final room V: Le Temple du Serment Noir.', production,
  limitations:['Timing and GPU captures are separate runs.', 'Known resource diagnostics on Godot shutdown remain retained in raw logs.'],
  spell_ids_observed:[...new Set(cases.flatMap(row=>row.casts.map(cast=>cast.spell_id)))].sort(), cases};
const output = 'docs/design/paris_combat_validation_v1.json';
fs.mkdirSync(path.dirname(path.join(ROOT,output)),{recursive:true});
fs.writeFileSync(path.join(ROOT,output),JSON.stringify(result,null,2)+'\n');
process.stdout.write(JSON.stringify({output,passed:cases.length,total:expected.length,spells:result.spell_ids_observed})+'\n');
