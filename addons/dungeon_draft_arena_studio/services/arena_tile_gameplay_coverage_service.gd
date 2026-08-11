@tool
class_name ArenaTileGameplayCoverageService
extends RefCounted

## Matrice factuelle du catalogue étendu. Les valeurs gameplay sont lues dans
## les Resources et services canoniques ; une absence reste explicitement non
## supportée au lieu de recevoir une valeur de conception inventée.

const IDS := [
	&"neutral", &"poison", &"steam", &"electrified_water", &"vortex",
	&"water", &"ice", &"lava",
]


static func build() -> Dictionary:
	var entries: Array[Dictionary] = [
		_permanent_terrain(&"neutral", "res://tools/labs/dynamic_arena/assets/raw/neutre.png"),
		_unsupported_poison(),
		_temporary_surface(&"steam", "res://data/terrain/vapeur.tres"),
		_electrified_water(),
		_vortex(),
		_permanent_terrain(
			&"water", "res://tools/labs/dynamic_arena/assets/normalized/water.png",
			"res://data/terrain/eau.tres"
		),
		_permanent_terrain(
			&"ice", "res://tools/labs/dynamic_arena/assets/normalized/ice.png",
			"res://data/terrain/glace.tres"
		),
		_permanent_terrain(
			&"lava", "res://tools/labs/dynamic_arena/assets/normalized/lava.png",
			"res://data/terrain/lave.tres"
		),
	]
	var unsupported: Array[String] = []
	for entry in entries:
		if not bool(entry.runtime_supported):
			unsupported.append(str(entry.stable_id))
	return {
		"schema_version": 1,
		"generated_from_checkout": true,
		"entries": entries,
		"unsupported_runtime_ids": unsupported,
		"vortex_production_enabled": false,
		"poison_terrain_gameplay_present": false,
		"shock_damage_source": "TerrainSurfaceRuntimeService.REACTION_DAMAGE",
		"steam_duration_source": "res://data/terrain/vapeur.tres",
	}


static func entry(stable_id: StringName) -> Dictionary:
	for value in build().entries:
		if StringName(value.stable_id) == stable_id:
			return value
	return {}


static func _permanent_terrain(
		stable_id: StringName,
		asset_path: String,
		runtime_surface_path := ""
	) -> Dictionary:
	var result := _base_entry(stable_id, asset_path, &"permanent_terrain")
	var terrain := ArenaCatalogService.terrain(stable_id)
	if terrain == null:
		result.notes.append("ArenaTerrainDefinition absente")
		return result
	var properties := GridData.PROPERTIES.get(terrain.cell_type, {}) as Dictionary
	result.display_name = terrain.display_name
	result.runtime_supported = true
	result.canonical_resource = terrain.resource_path
	result.cell_type = terrain.cell_type
	result.walkable = terrain.walkable
	result.transparent = bool(properties.get("transparent", false))
	result.projectile_passable = bool(properties.get("transparent", false))
	result.movement_cost = terrain.movement_cost
	result.visual_terrain_id = str(terrain.stable_id)
	result.editor_placeable = terrain.dynamic_catalog
	result.production_placeable = true
	if not terrain.walkable:
		result.runtime_supported = false
		result.production_placeable = false
		result.notes.append(
			"ArenaRuntimeBridge projette actuellement playable=false en HOLE; "
			+ "la parité du terrain permanent n'est pas certifiée."
		)
	if terrain.interaction_element != &"" and terrain.interaction_element != &"NONE":
		result.interaction_ids.append(str(terrain.interaction_element))
	if not runtime_surface_path.is_empty():
		result.runtime_surface_resource = runtime_surface_path
		_apply_effect(result, load(runtime_surface_path) as TerrainEffectData, false)
	result.evidence = [terrain.resource_path, asset_path]
	return result


static func _temporary_surface(
		stable_id: StringName,
		canonical_path: String
	) -> Dictionary:
	var visual := ArenaCatalogService.surface_visual(stable_id)
	var asset_path := visual.texture.resource_path \
		if visual != null and visual.texture != null else ""
	var result := _base_entry(stable_id, asset_path, &"temporary_surface")
	var effect := load(canonical_path) as TerrainEffectData
	if visual == null or effect == null:
		result.notes.append("Définition visuelle ou TerrainEffectData absente")
		return result
	result.display_name = visual.display_name
	result.runtime_supported = visual.runtime_supported
	result.canonical_resource = canonical_path
	result.visual_terrain_id = str(effect.visual_terrain_id)
	result.editor_placeable = visual.editor_placeable
	result.production_placeable = visual.production_placeable
	_apply_effect(result, effect)
	result.evidence = [canonical_path, visual.resource_path, asset_path]
	return result


static func _unsupported_poison() -> Dictionary:
	var visual := ArenaCatalogService.surface_visual(&"poison")
	var asset_path := visual.texture.resource_path \
		if visual != null and visual.texture != null else ""
	var result := _base_entry(&"poison", asset_path, &"temporary_surface")
	result.display_name = visual.display_name if visual != null else "Poison"
	result.runtime_supported = false
	result.canonical_resource = ""
	result.visual_terrain_id = "poison"
	result.editor_placeable = false
	result.production_placeable = false
	result.notes = [
		"Aucune TerrainEffectData poison canonique observée.",
		"Le groupe de statut elf_assassin_poison n'est pas une surface de grille.",
	]
	result.evidence = [asset_path, "res://data/characters/elf/disciplines/assassin.tres"]
	return result


static func _electrified_water() -> Dictionary:
	var visual := ArenaCatalogService.surface_visual(&"electrified_water")
	var asset_path := visual.texture.resource_path \
		if visual != null and visual.texture != null else ""
	var result := _base_entry(
		&"electrified_water", asset_path, &"visual_reaction"
	)
	result.display_name = visual.display_name if visual != null else "Eau électrifiée"
	# Le renderer de l'événement est câblé, mais aucun TerrainEffectData
	# lightning canonique n'est porté par le sort électrique observé.
	result.runtime_supported = false
	result.visual_event_supported = visual != null and visual.runtime_supported
	result.canonical_producer_present = false
	result.canonical_resource = (
		visual.canonical_resource_path if visual != null else
		"res://battle/dynamic_terrain/terrain_surface_runtime_service.gd"
	)
	result.cell_type = GridData.CellType.NORMAL
	result.walkable = true
	result.transparent = true
	result.projectile_passable = true
	result.movement_cost = 1
	result.trigger = "reaction:shock"
	result.duration = 0
	result.damage = TerrainSurfaceRuntimeService.REACTION_DAMAGE
	result.status = ""
	result.ai_danger = 0.0
	result.interaction_ids = ["WATER", "LIGHTNING"]
	result.visual_terrain_id = "electrified_water"
	result.editor_placeable = false
	result.production_placeable = false
	result.notes = [
		"Réaction instantanée lightning|water; aucune surface persistante.",
		"Aucun producteur TerrainEffectData lightning canonique n'est observé; la Tempête orageuse n'en porte pas.",
		"Le temps d'affichage n'est pas un temps gameplay et reste à zéro.",
	]
	result.evidence = [
		"res://battle/dynamic_terrain/terrain_interaction_resolver.gd",
		"res://battle/dynamic_terrain/terrain_surface_runtime_service.gd",
		asset_path,
	]
	return result


static func _vortex() -> Dictionary:
	var definition := ArenaCatalogService.interactive(&"vortex")
	var asset_path := definition.texture.resource_path \
		if definition != null and definition.texture != null else ""
	var result := _base_entry(&"vortex", asset_path, &"spatial_interactive")
	result.display_name = definition.display_name if definition != null else "Vortex"
	result.runtime_supported = definition != null and definition.runtime_supported
	result.canonical_resource = definition.resource_path if definition != null else ""
	result.trigger = "enter_cell_authoring_contract"
	result.visual_terrain_id = "vortex"
	result.editor_placeable = definition != null and definition.editor_placeable
	result.production_placeable = definition != null \
		and definition.is_production_certified()
	result.notes = [
		"Ce concept n'est ni un CellType ni une surface.",
		"Aucun consommateur GridData, Pathfinder ou IA de portail n'a été observé.",
	]
	result.evidence = [definition.resource_path if definition != null else "", asset_path]
	return result


static func _apply_effect(
		result: Dictionary,
		effect: TerrainEffectData,
		apply_spatial_properties := true
	) -> void:
	if effect == null:
		return
	result.trigger = ["turn_start", "on_enter", "passive"][clampi(
		effect.trigger, TerrainEffectData.Trigger.TURN_START,
		TerrainEffectData.Trigger.PASSIVE
	)]
	result.duration = effect.duration
	result.damage = effect.damage
	result.status = effect.applied_status.resource_path \
		if effect.applied_status != null else ""
	result.ai_danger = effect.ai_danger_weight if effect.dangerous_for_ai else 0.0
	result.blocks_movement = effect.blocks_movement
	result.blocks_vision = effect.blocks_vision
	result.runtime_surface_cell_type = effect.cell_type
	if apply_spatial_properties and effect.cell_type >= 0:
		result.cell_type = effect.cell_type
		var properties := GridData.PROPERTIES.get(effect.cell_type, {}) as Dictionary
		result.walkable = bool(properties.get("walkable", false))
		result.transparent = bool(properties.get("transparent", false)) \
			and not effect.blocks_vision
		result.projectile_passable = bool(result.transparent)
	result.visual_terrain_id = str(effect.visual_terrain_id)


static func _base_entry(
		stable_id: StringName,
		asset_path: String,
		category: StringName
	) -> Dictionary:
	return {
		"stable_id": str(stable_id),
		"display_name": str(stable_id),
		"asset_path": asset_path,
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
		"visual_event_supported": false,
		"canonical_producer_present": true,
	}
