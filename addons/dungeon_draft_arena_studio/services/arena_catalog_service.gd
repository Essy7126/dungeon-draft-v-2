@tool
class_name ArenaCatalogService
extends RefCounted

const TERRAIN_ROOT := "res://addons/dungeon_draft_arena_studio/catalog/terrains"
const WALL_ROOT := "res://addons/dungeon_draft_arena_studio/catalog/walls"
const THEME_ROOT := "res://addons/dungeon_draft_arena_studio/catalog/themes"
const SURFACE_ROOT := "res://addons/dungeon_draft_arena_studio/catalog/surfaces"
const INTERACTIVE_ROOT := "res://addons/dungeon_draft_arena_studio/catalog/interactives"

const TERRAIN_PATHS := [
	TERRAIN_ROOT + "/void.tres",
	TERRAIN_ROOT + "/normal.tres",
	TERRAIN_ROOT + "/stone.tres",
	TERRAIN_ROOT + "/neutral.tres",
	TERRAIN_ROOT + "/water.tres",
	TERRAIN_ROOT + "/ice.tres",
	TERRAIN_ROOT + "/lava.tres",
	TERRAIN_ROOT + "/wall.tres",
	TERRAIN_ROOT + "/hole.tres",
	TERRAIN_ROOT + "/shadow.tres",
	TERRAIN_ROOT + "/rune.tres",
]
const WALL_PATHS := [
	WALL_ROOT + "/normal.tres",
	WALL_ROOT + "/fire.tres",
	WALL_ROOT + "/ice.tres",
]
const THEME_PATHS := [THEME_ROOT + "/forest.tres"]
const SURFACE_PATHS := [
	SURFACE_ROOT + "/steam.tres",
	SURFACE_ROOT + "/poison.tres",
	SURFACE_ROOT + "/electrified_water.tres",
]
const INTERACTIVE_PATHS := [INTERACTIVE_ROOT + "/vortex.tres"]

static var _terrains := {}
static var _walls := {}
static var _themes := {}
static var _theme_aliases := {}
static var _surfaces := {}
static var _interactives := {}


static func reset_cache() -> void:
	_terrains.clear()
	_walls.clear()
	_themes.clear()
	_theme_aliases.clear()
	_surfaces.clear()
	_interactives.clear()


static func terrain(terrain_id: StringName) -> ArenaTerrainDefinition:
	_ensure_loaded()
	return _terrains.get(terrain_id) as ArenaTerrainDefinition


static func wall(wall_id: StringName) -> ArenaWallDefinition:
	_ensure_loaded()
	return _walls.get(wall_id) as ArenaWallDefinition


static func theme(theme_id: StringName) -> ArenaThemeDefinition:
	_ensure_loaded()
	var canonical := StringName(_theme_aliases.get(theme_id, theme_id))
	return _themes.get(canonical) as ArenaThemeDefinition


static func surface_visual(visual_id: StringName) -> ArenaSurfaceVisualDefinition:
	_ensure_loaded()
	return _surfaces.get(visual_id) as ArenaSurfaceVisualDefinition


static func surface_visual_for_reaction(
		reaction_id: StringName
	) -> ArenaSurfaceVisualDefinition:
	_ensure_loaded()
	for definition in _surfaces.values():
		var surface := definition as ArenaSurfaceVisualDefinition
		if surface != null and surface.reaction_id == reaction_id:
			return surface
	return null


static func interactive(
		interactive_id: StringName
	) -> ArenaSpatialInteractiveDefinition:
	_ensure_loaded()
	return _interactives.get(interactive_id) as ArenaSpatialInteractiveDefinition


static func has_terrain(terrain_id: StringName) -> bool:
	return terrain(terrain_id) != null


static func has_wall(wall_id: StringName) -> bool:
	return wall(wall_id) != null


static func has_theme(theme_id: StringName) -> bool:
	return theme(theme_id) != null


static func has_surface_visual(visual_id: StringName) -> bool:
	return surface_visual(visual_id) != null


static func has_interactive(interactive_id: StringName) -> bool:
	return interactive(interactive_id) != null


static func terrain_ids(dynamic_only := false) -> Array[StringName]:
	_ensure_loaded()
	var result: Array[StringName] = []
	for terrain_id in _terrains:
		var definition := _terrains[terrain_id] as ArenaTerrainDefinition
		if not dynamic_only or definition.dynamic_catalog:
			result.append(terrain_id)
	result.sort_custom(func(a: StringName, b: StringName) -> bool: return str(a) < str(b))
	return result


static func wall_ids() -> Array[StringName]:
	_ensure_loaded()
	var result: Array[StringName] = []
	result.assign(_walls.keys())
	result.sort_custom(func(a: StringName, b: StringName) -> bool: return str(a) < str(b))
	return result


static func theme_ids() -> Array[StringName]:
	_ensure_loaded()
	var result: Array[StringName] = []
	result.assign(_themes.keys())
	result.sort_custom(func(a: StringName, b: StringName) -> bool: return str(a) < str(b))
	return result


static func surface_visual_ids() -> Array[StringName]:
	_ensure_loaded()
	var result: Array[StringName] = []
	result.assign(_surfaces.keys())
	result.sort_custom(func(a: StringName, b: StringName) -> bool: return str(a) < str(b))
	return result


static func interactive_ids() -> Array[StringName]:
	_ensure_loaded()
	var result: Array[StringName] = []
	result.assign(_interactives.keys())
	result.sort_custom(func(a: StringName, b: StringName) -> bool: return str(a) < str(b))
	return result


static func terrain_for_lab_surface(surface: int) -> ArenaTerrainDefinition:
	_ensure_loaded()
	# Le Lab historique nomme explicitement sa surface neutre STONE, meme si
	# `normal` partage la meme definition visuelle et mecanique.
	if surface == DynamicCellState.Surface.STONE:
		return _terrains.get(&"stone") as ArenaTerrainDefinition
	for definition in _terrains.values():
		if (definition as ArenaTerrainDefinition).lab_surface == surface:
			return definition
	return null


static func surface_for_terrain(terrain_id: StringName) -> int:
	var definition := terrain(terrain_id)
	return definition.lab_surface if definition != null else -1


static func wall_for_variant(variant: int) -> ArenaWallDefinition:
	_ensure_loaded()
	for definition in _walls.values():
		if (definition as ArenaWallDefinition).variant == variant:
			return definition
	return null


static func _ensure_loaded() -> void:
	if not _terrains.is_empty() and not _walls.is_empty() and not _themes.is_empty() \
			and not _surfaces.is_empty() and not _interactives.is_empty():
		return
	reset_cache()
	for path in TERRAIN_PATHS:
		var definition := load(path) as ArenaTerrainDefinition
		if definition != null and definition.stable_id != &"":
			_terrains[definition.stable_id] = definition
	for path in WALL_PATHS:
		var definition := load(path) as ArenaWallDefinition
		if definition != null and definition.stable_id != &"":
			_walls[definition.stable_id] = definition
	for path in THEME_PATHS:
		var definition := load(path) as ArenaThemeDefinition
		if definition == null or definition.stable_id == &"":
			continue
		_themes[definition.stable_id] = definition
		_theme_aliases[definition.stable_id] = definition.stable_id
		for alias in definition.aliases:
			_theme_aliases[alias] = definition.stable_id
	for path in SURFACE_PATHS:
		var definition := load(path) as ArenaSurfaceVisualDefinition
		if definition != null and definition.stable_id != &"":
			_surfaces[definition.stable_id] = definition
	for path in INTERACTIVE_PATHS:
		var definition := load(path) as ArenaSpatialInteractiveDefinition
		if definition != null and definition.stable_id != &"":
			_interactives[definition.stable_id] = definition
