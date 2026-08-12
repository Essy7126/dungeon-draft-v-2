@tool
class_name ArenaPermanentTerrainPaintService
extends RefCounted

## Autorité unique partagée par la palette et le brush des sols permanents.

const PALETTE_ORDER: Array[StringName] = [
	&"stone", &"neutral", &"water", &"ice", &"lava", &"poison", &"steam",
	&"electrified_water",
]


static func get_placeable_terrain_definitions() -> Array[ArenaTerrainDefinition]:
	var result: Array[ArenaTerrainDefinition] = []
	for terrain_id in PALETTE_ORDER:
		var definition := ArenaCatalogService.terrain(terrain_id)
		if definition != null and definition.editor_placeable \
				and definition.production_placeable:
			result.append(definition)
	return result


static func get_paintable_permanent_terrains(
		arena: ArenaDefinition,
		include_disabled := true
	) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition in get_placeable_terrain_definitions():
		var entry := paintability(arena, definition.stable_id)
		if bool(entry.enabled) or include_disabled:
			result.append(entry)
	if include_disabled:
		result.append({
			"stable_id": &"void",
			"display_name": "VOID",
			"enabled": false,
			"reason_code": &"topology_tool_required",
			"reason": "retrait topologique — utilisez l'outil Retirer ou le clic droit",
			"cell_type": GridData.CellType.HOLE,
			"walkable": false,
			"texture": null,
			"texture_path": "",
			"visual_contract": {"valid": false, "reason": "no_permanent_tile"},
			"role": &"topology_removal",
		})
	return result


static func paintability(
		arena: ArenaDefinition,
		terrain_id: StringName
	) -> Dictionary:
	var definition := ArenaCatalogService.terrain(terrain_id)
	var result := {
		"stable_id": terrain_id,
		"display_name": definition.display_name if definition != null else str(terrain_id),
		"enabled": false,
		"reason_code": &"",
		"reason": "",
		"cell_type": definition.cell_type if definition != null else GridData.CellType.HOLE,
		"walkable": definition.walkable if definition != null else false,
		"texture": definition.base_texture if definition != null else null,
		"texture_path": definition.base_texture.resource_path \
			if definition != null and definition.base_texture != null else "",
		"visual_contract": {},
		"role": &"permanent_terrain",
	}
	if arena == null:
		return _disabled(result, &"document_missing", "aucun document Arena actif")
	if definition == null:
		return _disabled(result, &"catalog_missing", "terrain absent du catalogue")
	if terrain_id == &"void":
		return _disabled(result, &"topology_tool_required", "utilisez l'outil Retirer")
	if not definition.dynamic_catalog or not definition.editor_placeable \
			or not definition.production_placeable:
		return _disabled(
			result, &"not_production_placeable",
			"terrain absent du catalogue de production"
		)
	if definition.base_texture == null:
		return _disabled(result, &"permanent_texture_missing", "texture permanente absente")
	var visual_contract := ArenaTileProjectionService.texture_contract(definition.base_texture)
	result.visual_contract = visual_contract
	if not bool(visual_contract.valid):
		return _disabled(
			result, &"invalid_visual_contract", "texture hors contrat isométrique 256×128"
		)
	result.enabled = true
	result.reason_code = &"paintable"
	result.reason = "terrain permanent peignable, sauvegardable et consommé par le runtime"
	return result


static func can_paint(arena: ArenaDefinition, terrain_id: StringName) -> bool:
	return bool(paintability(arena, terrain_id).enabled)


static func _disabled(
		result: Dictionary,
		code: StringName,
		reason: String
	) -> Dictionary:
	result.enabled = false
	result.reason_code = code
	result.reason = reason
	return result
