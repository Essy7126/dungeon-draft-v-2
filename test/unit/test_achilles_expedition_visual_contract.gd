extends GutTest

const CANONICAL := preload("res://data/units/allies/achilles.tres")
const FLIGHT_IDS := [
	"exp_tir_de_guet", "exp_rupture", "exp_rupture_mutation", "exp_rupture_legend",
	"exp_marque", "exp_marque_signature", "exp_braise", "exp_braise_mutation", "exp_braise_legend",
	"exp_givre", "exp_givre_signature", "exp_foudre",
]
const DIRECTIONS := {"N": Vector2i.UP, "E": Vector2i.RIGHT, "S": Vector2i.DOWN, "W": Vector2i.LEFT}
const BODY_CONTRACTS := {
	"exp_braise": {"stem": "bow", "projectile": "fire", "release": 0.34, "duration": 0.74},
	"exp_givre": {"stem": "bow", "projectile": "frost", "release": 0.34, "duration": 0.74},
	"exp_foudre": {"stem": "bow_death", "projectile": "arrow_lightning", "release": 0.44, "duration": 0.86},
	"exp_tir_de_guet": {"stem": "bow", "projectile": "arrow", "release": 0.34, "duration": 0.74},
	"exp_rupture": {"stem": "bow", "projectile": "arrow_heavy", "release": 0.34, "duration": 0.74},
	"exp_rupture_mutation": {"stem": "bow_piercing", "projectile": "arrow_piercing", "release": 0.38, "duration": 0.78},
	"exp_rupture_legend": {"stem": "bow_death", "projectile": "arrow_death_line", "release": 0.44, "duration": 0.86},
}


func test_current_catalog_schedules_only_the_twelve_real_ranged_techniques_before_impact() -> void:
	var catalog := ExpeditionBuildCatalog.new()
	var delayed: Array[String] = []
	var expedition_count := 0
	for spell: Spell in catalog.all_spells():
		var id := str(spell.get_effective_spell_id())
		if not id.begins_with("exp_"):
			continue
		expedition_count += 1
		if spell.impact_delay_seconds > 0.0:
			delayed.append(id)
		assert_almost_eq(spell.impact_delay_seconds, 0.2 if id in FLIGHT_IDS else 0.0, 0.000001, id)
	var expected: Array[String] = []
	expected.assign(FLIGHT_IDS)
	expected.sort()
	delayed.sort()
	assert_eq(delayed, expected, "Native ranged techniques must reach the existing delayed impact scheduler")
	assert_eq(expedition_count, 42, "All current Catabase spell identities are audited")
	# The render contract must keep the actual line geometry, push and costs.
	for row in [["exp_tir_de_guet", 3, 2, 6, Spell.AoeShape.SINGLE, 0],
		["exp_rupture", 2, 2, 5, Spell.AoeShape.SINGLE, 1],
		["exp_rupture_mutation", 3, 2, 5, Spell.AoeShape.LINE, 0],
		["exp_rupture_legend", 4, 3, 7, Spell.AoeShape.LINE, 0]]:
		var spell := catalog.get_spell(str(row[0]))
		assert_not_null(spell)
		if spell != null:
			assert_eq([spell.ap_cost, spell.minimum_range, spell.spell_range, spell.aoe_shape, spell.push_distance], row.slice(1), str(row[0]))


func test_actual_classic_scene_selects_current_run_bow_forms_in_every_direction() -> void:
	var owner := Node2D.new()
	add_child_autofree(owner)
	var visual := CANONICAL.visual_scene.instantiate() as AchillesIsoUnitView
	owner.add_child(visual)
	await wait_process_frames(3)
	visual.set_process(false)
	visual.sprite_backend.set_process(false)
	assert_eq(visual.sprite_profile.profile_id, &"achilles_polish_sprites_v3")
	var catalog := ExpeditionBuildCatalog.new()
	var sprite := visual.sprite_backend.animated_sprite
	var counts := {"release": 0, "finish": 0}
	visual.cast_release_reached.connect(func() -> void: counts.release += 1)
	visual.animation_finished.connect(func(_clip: StringName) -> void: counts.finish += 1)
	for direction: String in DIRECTIONS:
		for id: String in BODY_CONTRACTS:
			var contract: Dictionary = BODY_CONTRACTS[id]
			var spell := catalog.get_spell(id)
			var before: int = counts.release
			visual.set_facing(DIRECTIONS[direction])
			# Actual catalog Spell, canonical scene and resolver. No fake profile,
			# injected visual identity, animation alias or selected mastery fixture.
			assert_true(visual.play_spell_action(spell), id)
			var presentation := visual.get_action_presentation()
			assert_eq(str(presentation.spell_id), id)
			assert_eq(str(presentation.action_family), "shot", id)
			assert_eq(str(presentation.projectile_animation), str(contract.projectile), id)
			assert_eq(sprite.animation, StringName("%s_%s" % [contract.stem, direction]), id)
			assert_eq(visual.sprite_backend.get_runtime_state().release_frame, 4)
			visual.sprite_backend.advance_simulation(float(contract.release) - 0.001)
			assert_eq(counts.release, before)
			assert_eq(sprite.frame, 3, id)
			visual.sprite_backend.advance_simulation(0.001)
			assert_eq(counts.release, before + 1)
			assert_eq(sprite.frame, 4, id)
			visual.sprite_backend.advance_simulation(float(contract.duration) - float(contract.release) + 0.001)
			assert_eq(counts.finish, before + 1)
			assert_eq(sprite.animation, StringName("idle_" + direction))
			assert_eq(sprite.frame, 0)
			assert_false(sprite.is_playing())
