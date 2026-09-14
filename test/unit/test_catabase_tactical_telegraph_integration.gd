extends GutTest

const Factory := preload("res://test/support/factory.gd")
const Cleanup := preload("res://test/support/isolated_battlefield_cleanup.gd")


class TelegraphBattle extends "res://battle/battle.gd":
	func _ready() -> void:
		pass


func test_real_battle_wires_delayed_warning_to_grid_and_disposes_it() -> void:
	var battle := TelegraphBattle.new()
	add_child_autofree(battle)
	battle.grid = GridData.new(12, 4)
	battle._setup_view()
	var layer := battle._tactical_telegraphs as TacticalTelegraphLayer
	assert_not_null(layer)
	assert_same(layer.get_parent(), battle.grid_view)
	assert_eq(layer.name, "TacticalTelegraphs")
	assert_gt(layer.z_index, 0)

	var enemy := Factory.make_unit("Exécuteur", 1)
	var hero := Factory.make_unit("Achille", 0)
	battle.grid.place_unit(enemy, Vector2i(2, 1))
	battle.grid.place_unit(hero, Vector2i(5, 1))
	var spell := Factory.make_spell(
		{
			"spell_id": &"catabase_evolution_execution",
			"delayed_resolution": Spell.DelayedResolution.RANGED_STRIKE,
		}
	)
	EventBus.ability_telegraphed.emit(
		enemy,
		spell,
		{
			"cell": hero.grid_pos,
			"target": hero,
			"label": "Sentence — quittez le contact",
			"color": Color.ORANGE_RED,
		},
	)

	assert_eq(layer.get_telegraph_count(), 1)
	assert_true(layer.is_processing(), "Canvas scale is watched only while a warning is visible")
	var warning: Dictionary = layer.get_debug_snapshot()[0]
	assert_eq(warning.spell_id, &"catabase_evolution_execution")
	assert_eq(warning.source_cell, Vector2i(2, 1))
	assert_eq(warning.target_cell, Vector2i(5, 1))
	assert_eq(warning.source_position, battle.grid_view.grid_to_world(Vector2i(2, 1)))
	assert_eq(warning.target_position, battle.grid_view.grid_to_world(Vector2i(5, 1)))
	assert_true(str(warning.label).contains("quittez"))
	var foreign_enemy := Factory.make_unit("Autre combat", 1)
	EventBus.ability_telegraphed.emit(
		foreign_enemy,
		spell,
		{ "cell": hero.grid_pos, "target": hero, "label": "Événement étranger" },
	)
	assert_eq(layer.get_telegraph_count(), 1)

	battle.grid.relocate_unit(hero, Vector2i(6, 1))
	assert_eq(layer.get_debug_snapshot()[0].target_cell, Vector2i(6, 1))
	EventBus.telegraph_cleared.emit(enemy)
	assert_eq(layer.get_telegraph_count(), 0)
	assert_false(layer.is_processing())

	EventBus.ability_telegraphed.emit(
		enemy,
		spell,
		{ "cell": hero.grid_pos, "target": hero, "label": "Sentence" },
	)
	assert_eq(layer.get_telegraph_count(), 1)
	battle._begin_battle_shutdown()
	assert_eq(layer.get_telegraph_count(), 0)
	assert_false(layer.is_processing())
	EventBus.ability_telegraphed.emit(
		enemy,
		spell,
		{ "cell": hero.grid_pos, "target": hero, "label": "Après fermeture" },
	)
	assert_eq(layer.get_telegraph_count(), 0)

	Cleanup.dispose_grid(battle.grid)


func test_delayed_warning_keeps_name_and_counterplay_on_two_lines() -> void:
	assert_eq(
		TacticalTelegraphLayer._telegraph_label_lines(
			"Trait d’ombre — brisez la ligne de vue"
		),
		PackedStringArray(["Trait d’ombre", "brisez la ligne de vue"]),
	)
	assert_eq(
		TacticalTelegraphLayer._telegraph_label_lines("Prochaine activation"),
		PackedStringArray(["Prochaine activation"]),
	)


func test_warning_text_compensates_its_canvas_scale() -> void:
	var scaled_parent := Node2D.new()
	scaled_parent.scale = Vector2(0.5, 0.5)
	add_child_autofree(scaled_parent)
	var layer := TacticalTelegraphLayer.new()
	scaled_parent.add_child(layer)
	assert_almost_eq(layer._local_pixels_per_screen_pixel(), 2.0, 0.001)
	layer.queue_free()
