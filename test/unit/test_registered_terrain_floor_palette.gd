extends GutTest

class PaletteBattle:
	extends "res://battle/painted/registered_terrain/registered_terrain_battle.gd"

	func _ready() -> void:
		pass

	func _exit_tree() -> void:
		pass


class Platform:
	extends Node2D
	var floor_cells := {}
	var pit_cells := {}


func test_stone_palette_preserves_permanent_terrain_art_and_counts_every_floor() -> void:
	var battle := PaletteBattle.new()
	add_child_autofree(battle)
	var terrain := Node2D.new()
	terrain.name = "GreekTerrainComposition"
	battle.add_child(terrain)
	var land := Polygon2D.new()
	land.name = "Land"
	land.color = Color(0.35, 0.5, 0.2)
	terrain.add_child(land)
	var floor := Node2D.new()
	battle.add_child(floor)
	battle.arena_assembly = {"floor_parent": floor}
	var arena := ArenaDefinition.new()
	var platform := Platform.new()
	battle.add_child(platform)
	var preserved := CanvasItemMaterial.new()
	var native_art := GradientTexture2D.new()
	var nodes: Array[Sprite2D] = []
	var terrain_ids: Array[StringName] = [&"stone", &"water", &"lava", &"ice", &"shadow"]
	for index in terrain_ids.size():
		var tile := Node2D.new()
		tile.name = "ArenaTerrain_%d_0" % index
		tile.set_meta("arena_cell", Vector2i(index, 0))
		tile.set_meta("terrain_id", terrain_ids[index])
		floor.add_child(tile)
		var visual := Sprite2D.new()
		visual.name = "Visual"
		visual.texture = native_art
		visual.material = preserved if index > 0 else null
		tile.add_child(visual)
		nodes.append(visual)
	battle._apply_floor_palette(arena, platform)
	assert_eq(battle.registered_floor_tile_count, terrain_ids.size())
	assert_eq(battle.limestone_tile_count, 1)
	assert_eq(battle.get_meta("registered_floor_tile_count"), terrain_ids.size())
	assert_true(nodes[0].material is ShaderMaterial)
	assert_eq((nodes[0].material as ShaderMaterial).shader.resource_path,
		"res://battle/painted/registered_terrain/shaders/stone_palette.gdshader")
	for index in range(1, nodes.size()):
		assert_eq(nodes[index].material, preserved,
			"Special terrain keeps its own material: %s" % terrain_ids[index])
		assert_eq(nodes[index].texture, native_art)
		assert_eq(nodes[index].modulate, Color.WHITE)
