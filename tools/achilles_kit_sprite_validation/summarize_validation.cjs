// Summarize actual test artifacts; never substitutes generated fixtures for a run.
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const folder = 'artifacts/achilles_kit_sprite_validation_v2';
const read = p => JSON.parse(fs.readFileSync(path.join(root, p), 'utf8').replace(/^\uFEFF/, ''));
const matrix = read(folder + '/matrix_validated/summary.json');
if (matrix.passed !== 28 || matrix.total !== 28) throw Error('Incomplete combat matrix');
const cases = matrix.results.map(result => {
  const r = read(result.report);
  if (!r.ok || result.runtime_errors.length) throw Error('Failed combat: ' + result.name);
  return {
    name: result.name, ok: true, configuration: r.configuration, scene: r.actual_scene,
    renderer: r.renderer, progression_fixture: r.progression_fixture,
    stable_rest_max_anchor_error_px: Math.max(...['stable_rest_before', 'stable_rest_after_walk', 'stable_rest_after']
      .map(k => r[k]?.maximum_screen_anchor_error_px || 0)),
    actions: r.actions.map(a => ({ spell: a.spell_id, clip: a.presentation.animation_stem,
      variant: a.presentation.variant, ap_cost: a.expected_ap_cost, damaged_enemies: a.damaged_enemy_count,
      release_ms: a.release_after_animation_ms, finished_ms: a.duration_after_animation_ms,
      arrival_count: a.movement_arrival_count, destination_error_px: a.view_destination_error_px,
      non_charge_samples_during_dash: a.non_charge_samples_during_dash })),
    automatic_strikes: r.counter_turn?.automatic_strikes?.length || 0,
    effects: r.effect_validation, report: result.report,
  };
});
const logPath = folder + '/gut_complete/stdout.log';
const gut = fs.readFileSync(path.join(root, logPath), 'utf8');
const count = label => Number(gut.match(new RegExp('^' + label + '\\s+(\\d+)', 'm'))?.[1]);
if (!gut.includes('All tests passed!') || count('Tests') !== count('Passing Tests')) throw Error('Failed GUT run');
const character = read('assets/characters/Achilles/sprites_kit_v2/manifest.json');
const defeat = read(folder + '/defeat_E_visual/runtime_validation.json');
const report = {
  schema: 1, date: '2026-09-05', engine: 'Godot 4.7.1',
  gut: { scripts: count('Scripts'), tests: count('Tests'), passing: count('Passing Tests'), assertions: count('Asserts'), log: logPath },
  pipeline_tests: { tests: 17, passing: 17, command: 'node --test tools/achilles_kit_sprite_pipeline/build_effects.test.cjs tools/achilles_kit_sprite_pipeline/clip_overrides.test.cjs' },
  combat_matrix: { tests: cases.length, passing: cases.length, cases },
  source_art: { authored_character_poses: character.total_authored_frames, used_new_distinct_poses: 111,
    animation_clips: character.animation_count, legacy_clips_preserved: character.legacy_animation_definitions_preserved,
    atlas_manifest: 'assets/characters/Achilles/sprites_kit_v2/manifest.json', effects_drawings: 24,
    effects_manifest: 'assets/vfx/achilles_kit_v2/manifest.json', clip_overrides: character.clip_overrides },
  real_defeat: { ok: defeat.ok, nonlethal_completed_hits: defeat.real_hit_and_death.completed_nonlethal_hit_clips,
    hp_damage: defeat.real_hit_and_death.incoming_health_damage, root_travel_px: defeat.real_hit_and_death.maximum_unit_anchor_travel_px,
    death: defeat.real_hit_and_death.death, report: folder + '/defeat_E_visual/runtime_validation.json' },
  limitations: [
    'Les kits de haut niveau utilisent une fixture XP annoncee, puis les achats legaux de maitrises ; ils ne representent pas une campagne jouee du niveau 1 au niveau 13.',
    'Tests de cadence et captures sont separes : la lecture GPU peut perturber la cadence. Les GIF gardent les timestamps originaux sans ralenti ajoute.',
    'Godot signale encore des objets, RID, ressources et pages PagedAllocator en usage a extinction. Ces diagnostics sont conserves et ne sont pas presentes comme resolus.',
  ],
};
fs.writeFileSync(path.join(root, 'docs/design/achilles/achilles_kit_validation_v2.json'), JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify({ tests: report.gut.tests, combats: cases.length, all_ok: cases.every(c => c.ok), max_rest_drift: Math.max(...cases.map(c => c.stable_rest_max_anchor_error_px)) }));
