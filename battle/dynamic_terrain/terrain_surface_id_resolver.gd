class_name TerrainSurfaceIdResolver
extends RefCounted

const LEGACY_IDS := {
	"lave": {"surface_id": &"fire", "visual_terrain_id": &"lava"},
	"feu": {"surface_id": &"fire", "visual_terrain_id": &"lava"},
	"eau": {"surface_id": &"water", "visual_terrain_id": &"water"},
	"glace": {"surface_id": &"ice", "visual_terrain_id": &"ice"},
	"vapeur": {"surface_id": &"steam", "visual_terrain_id": &""},
	"foudre": {"surface_id": &"lightning", "visual_terrain_id": &""},
}

static var _warned_paths := {}


static func resolve(effect: TerrainEffectData) -> Dictionary:
	if effect == null:
		return {
			"surface_id": &"none",
			"visual_terrain_id": &"",
			"legacy_fallback": false,
		}
	var legacy := LEGACY_IDS.get(
		effect.effect_name.strip_edges().to_lower(), {}
	) as Dictionary
	var resolved_surface := effect.surface_id
	var resolved_visual := effect.visual_terrain_id
	var fallback := false
	if resolved_surface == &"":
		resolved_surface = StringName(legacy.get(
			"surface_id", effect.effect_name.strip_edges().to_lower()
		))
		fallback = true
	if resolved_visual == &"" and legacy.has("visual_terrain_id"):
		resolved_visual = StringName(legacy.visual_terrain_id)
		fallback = true
	if fallback and Engine.is_editor_hint():
		var warning_key := effect.resource_path
		if warning_key.is_empty():
			warning_key = effect.effect_name
		if not _warned_paths.has(warning_key):
			_warned_paths[warning_key] = true
			push_warning(
				"TerrainEffectData legacy sans IDs stables : %s" % warning_key
			)
	return {
		"surface_id": resolved_surface,
		"visual_terrain_id": resolved_visual,
		"legacy_fallback": fallback,
	}


static func dynamic_surface(surface_id: StringName) -> int:
	match surface_id:
		&"fire":
			return CellSurfaceState.DynamicSurface.FIRE
		&"water":
			return CellSurfaceState.DynamicSurface.WATER
		&"ice":
			return CellSurfaceState.DynamicSurface.ICE
	return CellSurfaceState.DynamicSurface.NONE


static func surface_id_for_dynamic(surface: int) -> StringName:
	match surface:
		CellSurfaceState.DynamicSurface.FIRE:
			return &"fire"
		CellSurfaceState.DynamicSurface.WATER:
			return &"water"
		CellSurfaceState.DynamicSurface.ICE:
			return &"ice"
	return &"none"


static func visual_id_for_surface(surface_id: StringName) -> StringName:
	match surface_id:
		&"fire":
			return &"lava"
		&"water":
			return &"water"
		&"ice":
			return &"ice"
	return &""


static func default_effect_path(surface_id: StringName) -> String:
	match surface_id:
		&"fire":
			return "res://data/terrain/lave.tres"
		&"water":
			return "res://data/terrain/eau.tres"
		&"ice":
			return "res://data/terrain/glace.tres"
		&"steam":
			return "res://data/terrain/vapeur.tres"
	return ""


static func load_default_effect(surface_id: StringName) -> TerrainEffectData:
	var path := default_effect_path(surface_id)
	return load(path) as TerrainEffectData if not path.is_empty() else null
