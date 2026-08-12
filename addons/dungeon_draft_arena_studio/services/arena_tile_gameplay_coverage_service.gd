@tool
class_name ArenaTileGameplayCoverageService
extends RefCounted

## Matrice factuelle du catalogue complet. Les propriétés viennent uniquement
## des Resources canoniques consommées par le bridge Arena -> runtime.

const TERRAIN_IDS: Array[StringName] = [
	&"stone", &"neutral", &"water", &"ice", &"lava", &"poison",
	&"steam", &"electrified_water",
]
const IDS: Array[StringName] = [
	&"stone", &"neutral", &"water", &"ice", &"lava", &"poison",
	&"steam", &"electrified_water", &"vortex",
]


static func build() -> Dictionary:
	var entries: Array[Dictionary] = []
	for stable_id in TERRAIN_IDS:
		entries.append(_permanent_terrain(stable_id))
	entries.append(_vortex())
	var unsupported: Array[String] = []
	for value in entries:
		if not bool(value.runtime_supported):
			unsupported.append(str(value.stable_id))
	return {
		"schema_version": 2,
		"generated_from_checkout": true,
		"entries": entries,
		"unsupported_runtime_ids": unsupported,
		"vortex_production_enabled": unsupported.find("vortex") < 0,
		"poison_terrain_gameplay_present": unsupported.find("poison") < 0,
		"shock_damage_source": "res://data/terrain/eau_electrifiee.tres",
		"steam_duration_source": "res://data/terrain/vapeur.tres",
	}


static func entry(stable_id: StringName) -> Dictionary:
	for value in build().entries:
		if StringName(value.stable_id) == stable_id:
			return value
	return {}


static func _permanent_terrain(stable_id: StringName) -> Dictionary:
	var result := _base_entry(stable_id, &"permanent_terrain")
	var terrain := ArenaCatalogService.terrain(stable_id)
	if terrain == null:
		result.notes.append("ArenaTerrainDefinition absente")
		return result
	result.display_name = terrain.display_name
	result.asset_path = terrain.base_texture.resource_path \
		if terrain.base_texture != null else ""
	result.runtime_supported = terrain.editor_placeable \
		and terrain.production_placeable
	result.canonical_resource = terrain.resource_path
	result.cell_type = terrain.cell_type
	result.walkable = terrain.walkable
	result.transparent = terrain.transparent
	result.projectile_passable = terrain.projectile_passable
	result.movement_cost = terrain.movement_cost
	result.visual_terrain_id = str(terrain.stable_id)
	result.editor_placeable = terrain.editor_placeable
	result.production_placeable = terrain.production_placeable
	result.ai_danger = terrain.ai_danger_weight
	result.trigger = _terrain_trigger(terrain)
	if terrain.interaction_element not in [&"", &"NONE"]:
		result.interaction_ids.append(str(terrain.interaction_element))
	if terrain.unit_effect != null:
		_apply_effect(result, terrain.unit_effect)
		result.runtime_surface_resource = terrain.unit_effect.resource_path
	result.evidence = [terrain.resource_path, result.asset_path]
	if terrain.unit_effect != null:
		result.evidence.append(terrain.unit_effect.resource_path)
	return result


static func _vortex() -> Dictionary:
	var definition := ArenaCatalogService.interactive(&"vortex")
	var result := _base_entry(&"vortex", &"spatial_interactive")
	if definition == null:
		result.notes.append("ArenaSpatialInteractiveDefinition absente")
		return result
	result.display_name = definition.display_name
	result.asset_path = definition.texture.resource_path \
		if definition.texture != null else ""
	result.runtime_supported = definition.runtime_supported \
		and definition.pathfinding_certified and definition.ai_certified
	result.canonical_resource = definition.resource_path
	result.trigger = "enter_cell"
	result.visual_terrain_id = "vortex"
	result.editor_placeable = definition.editor_placeable
	result.production_placeable = definition.is_production_certified()
	result.notes = [
		"Interactif spatial apparié, distinct du renderer de sol.",
		"Traversée bidirectionnelle, coût nul et fin immédiate du déplacement.",
	]
	result.evidence = [definition.resource_path, result.asset_path,
		"res://core/pathfinder.gd",
		"res://battle/dynamic_terrain/terrain_surface_runtime_service.gd"]
	return result


static func _terrain_trigger(terrain: ArenaTerrainDefinition) -> String:
	var triggers: Array[String] = []
	if terrain.apply_on_enter:
		triggers.append("on_enter")
	if terrain.apply_on_turn_start:
		triggers.append("turn_start")
	return "+".join(triggers) if not triggers.is_empty() else "passive"


static func _apply_effect(result: Dictionary, effect: TerrainEffectData) -> void:
	result.duration = effect.duration
	result.damage = effect.damage
	result.status = effect.applied_status.resource_path \
		if effect.applied_status != null else ""
	result.ai_danger = maxf(
		float(result.ai_danger),
		effect.ai_danger_weight if effect.dangerous_for_ai else 0.0
	)
	result.blocks_movement = effect.blocks_movement
	result.blocks_vision = effect.blocks_vision
	result.runtime_surface_cell_type = effect.cell_type
	result.damage_type = effect.damage_type
	result.element = effect.element


static func _base_entry(stable_id: StringName, category: StringName) -> Dictionary:
	return {
		"stable_id": str(stable_id),
		"display_name": str(stable_id),
		"asset_path": "",
		"category": str(category),
		"runtime_supported": false,
		"canonical_resource": "",
		"runtime_surface_resource": "",
		"runtime_surface_cell_type": null,
		"cell_type": null,
		"walkable": null,
		"transparent": null,
		"projectile_passable": null,
		"movement_cost": null,
		"trigger": "none",
		"duration": 0,
		"damage": 0,
		"damage_type": null,
		"element": null,
		"status": "",
		"ai_danger": 0.0,
		"interaction_ids": [],
		"visual_terrain_id": "",
		"editor_placeable": false,
		"production_placeable": false,
		"blocks_movement": false,
		"blocks_vision": false,
		"notes": [],
		"evidence": [],
		"visual_event_supported": true,
		"canonical_producer_present": true,
	}
