@tool
class_name ArenaModularVisualProfile
extends Resource

enum HybridFloorPolicy {
	NONE,
	NON_BASE_TERRAINS,
	ALL_DEFINED,
}

@export var theme_id: StringName = &"dynamic_default"
@export var terrain_ids: Array[StringName] = [&"stone", &"water", &"ice", &"lava"]
@export var wall_ids: Array[StringName] = [&"normal", &"fire", &"ice"]
@export_enum("Aucune dalle:0", "Terrains hors base:1", "Toutes les dalles:2")
var hybrid_floor_policy: int = HybridFloorPolicy.NON_BASE_TERRAINS
@export var base_terrain_id: StringName = &"stone"
@export var tile_visual_profile: ArenaVisualProfile = null
@export var background_texture: Texture2D = null
@export var foreground_texture: Texture2D = null
@export var environment_scene: PackedScene = null
@export var prop_scenes: Array[PackedScene] = []
@export var ambient_color := Color.WHITE
@export_range(0.0, 4.0, 0.01) var ambient_energy := 1.0
@export var camera_offset := Vector2.ZERO
@export_range(0.25, 3.0, 0.01) var camera_zoom := 1.0


func to_dict() -> Dictionary:
	# Les sous-ressources rechargées reçoivent un chemin volatil du type
	# `arena.tres::Resource_xxx`. Il ne doit jamais entrer dans une empreinte.
	var stable_resource_path := resource_path \
		if resource_path.ends_with(".tres") and not "::" in resource_path else ""
	return {
		"resource_path": stable_resource_path,
		"theme_id": str(theme_id),
		"terrain_ids": Array(terrain_ids).map(func(value): return str(value)),
		"wall_ids": Array(wall_ids).map(func(value): return str(value)),
		"hybrid_floor_policy": hybrid_floor_policy,
		"base_terrain_id": str(base_terrain_id),
		"tile_visual_profile_path": tile_visual_profile.resource_path \
			if tile_visual_profile != null else "",
		"background_texture_path": background_texture.resource_path \
			if background_texture != null else "",
		"foreground_texture_path": foreground_texture.resource_path \
			if foreground_texture != null else "",
		"environment_scene_path": environment_scene.resource_path \
			if environment_scene != null else "",
		"prop_scene_paths": prop_scenes.map(
			func(value): return value.resource_path if value != null else ""
		),
		"ambient_color": ambient_color.to_html(true),
		"ambient_energy": ambient_energy,
		"camera_offset": [camera_offset.x, camera_offset.y],
		"camera_zoom": camera_zoom,
	}


func resolved_tile_visual_profile() -> ArenaVisualProfile:
	if tile_visual_profile != null:
		return tile_visual_profile
	var value := ArenaVisualProfile.new()
	value.normal_texture = ArenaTerrainRegistry.texture_for(&"stone")
	value.wall_texture = ArenaWallRegistry.config_for(&"normal").texture
	value.hole_texture = ArenaTerrainRegistry.texture_for(&"void")
	value.lava_texture = ArenaTerrainRegistry.texture_for(&"lava")
	value.ice_texture = ArenaTerrainRegistry.texture_for(&"ice")
	return value


static func from_dict(data: Dictionary) -> ArenaModularVisualProfile:
	var saved_path := str(data.get("resource_path", ""))
	if not saved_path.is_empty() and ResourceLoader.exists(saved_path):
		var saved := load(saved_path) as ArenaModularVisualProfile
		if saved != null:
			return saved
	var value := ArenaModularVisualProfile.new()
	value.theme_id = StringName(data.get("theme_id", "dynamic_default"))
	value.terrain_ids.assign(data.get("terrain_ids", []))
	value.wall_ids.assign(data.get("wall_ids", []))
	value.hybrid_floor_policy = clampi(
		int(data.get("hybrid_floor_policy", HybridFloorPolicy.NON_BASE_TERRAINS)),
		HybridFloorPolicy.NONE,
		HybridFloorPolicy.ALL_DEFINED
	)
	value.base_terrain_id = StringName(data.get("base_terrain_id", "stone"))
	value.tile_visual_profile = _load_resource(
		str(data.get("tile_visual_profile_path", "")), "ArenaVisualProfile"
	) as ArenaVisualProfile
	value.background_texture = _load_resource(
		str(data.get("background_texture_path", "")), "Texture2D"
	) as Texture2D
	value.foreground_texture = _load_resource(
		str(data.get("foreground_texture_path", "")), "Texture2D"
	) as Texture2D
	value.environment_scene = _load_resource(
		str(data.get("environment_scene_path", "")), "PackedScene"
	) as PackedScene
	value.prop_scenes.clear()
	for path_value in data.get("prop_scene_paths", []):
		var scene := _load_resource(str(path_value), "PackedScene") as PackedScene
		if scene != null:
			value.prop_scenes.append(scene)
	value.ambient_color = Color.from_string(str(data.get("ambient_color", "ffffffff")), Color.WHITE)
	value.ambient_energy = float(data.get("ambient_energy", 1.0))
	value.camera_offset = ArenaDefinition._vector2(data.get("camera_offset", [0.0, 0.0]))
	value.camera_zoom = float(data.get("camera_zoom", 1.0))
	return value


static func _load_resource(path: String, _type_hint: String) -> Resource:
	return load(path) if not path.is_empty() and ResourceLoader.exists(path) else null
