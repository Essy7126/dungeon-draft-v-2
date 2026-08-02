extends GutTest

const Factory = preload("res://test/support/factory.gd")

class TerrainOnArrivalMod:
	extends SpellModifier
	var effect: TerrainEffectData = null

	func on_movement_resolved(ctx) -> void:
		for move in ctx.movement:
			if move["to"] != move["from"]:
				ctx.terrain.place_effect(move["to"], effect, ctx.caster, ctx.spell)

func _make_effect(effect_name: String) -> TerrainEffectData:
	var effect := TerrainEffectData.new()
	effect.effect_name = effect_name
	effect.duration = 2
	return effect

func test_modifier_places_terrain_at_push_destination() -> void:
	var battlefield := Factory.make_battlefield(8, 1)
	var hero := Factory.make_unit("Heros", 0)
	var enemy := Factory.make_unit("Cible", 1)
	battlefield.grid.place_unit(hero, Vector2i(0, 0))
	battlefield.grid.place_unit(enemy, Vector2i(1, 0))
	var spell := Factory.make_spell({"ap_cost": 1, "push_distance": 3, "spell_range": 5})
	var modifier := TerrainOnArrivalMod.new()
	modifier.effect = _make_effect("marque_test")
	spell.modifiers.append(modifier)
	var report: Dictionary = battlefield.caster.cast(hero, spell, Vector2i(1, 0))
	assert_true(report["pushed"])
	assert_eq(enemy.grid_pos, Vector2i(4, 0))
	var placed = battlefield.terrain.get_effect_data(Vector2i(4, 0))
	assert_not_null(placed)
	if placed != null:
		assert_eq(placed.effect_name, "marque_test")

func test_modifier_filters_by_spell_name() -> void:
	var battlefield := Factory.make_battlefield(8, 1)
	var hero := Factory.make_unit("Heros", 0)
	var enemy := Factory.make_unit("Cible", 1)
	battlefield.grid.place_unit(hero, Vector2i(0, 0))
	battlefield.grid.place_unit(enemy, Vector2i(1, 0))
	var spell := Factory.make_spell({"ap_cost": 1, "push_distance": 3, "spell_range": 5})
	var modifier := TerrainOnArrivalMod.new()
	modifier.effect = _make_effect("marque_test")
	modifier.target_spell_name = "Un autre sort"
	spell.modifiers.append(modifier)
	battlefield.caster.cast(hero, spell, Vector2i(1, 0))
	assert_null(battlefield.terrain.get_effect_data(Vector2i(4, 0)))
