@tool
class_name ArenaPermanentTerrainPaintService
extends RefCounted

## Autorité unique de la palette et du brush des sols permanents. Une Resource
## existante ne suffit pas : elle doit être productible, supportée par le thème
## et le profil, conforme au contrat visuel et visible dans le mode courant.

const PALETTE_ORDER: Array[StringName] = [
	&"stone", &"neutral", &"water", &"ice", &"lava",
]


static func get_paintable_permanent_terrains(
		arena: ArenaDefinition,
		include_disabled := true
	) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for terrain_id in PALETTE_ORDER:
		var entry := paintability(arena, terrain_id)
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
		return _disabled(
			result, &"topology_tool_required",
			"retrait topologique — utilisez l'outil Retirer ou le clic droit"
		)
	if not definition.dynamic_catalog:
		return _disabled(
			result, &"not_production_placeable", "prototype non productible"
		)
	if definition.base_texture == null:
		return _disabled(
			result, &"permanent_texture_missing", "renderer permanent absent"
		)
	var visual_contract := ArenaTileProjectionService.texture_contract(
		definition.base_texture
	)
	result.visual_contract = visual_contract
	if not bool(visual_contract.valid):
		return _disabled(
			result, &"invalid_visual_contract",
			"texture hors contrat isométrique 256×128"
		)
	var profile := arena.modular_visual_profile
	var theme_id := profile.theme_id if profile != null else arena.theme_id
	var theme := ArenaCatalogService.theme(theme_id)
	if theme == null:
		return _disabled(
			result, &"theme_missing", "thème permanent introuvable : %s" % theme_id
		)
	if not _ids_support(theme.terrain_ids, terrain_id):
		return _disabled(
			result, &"theme_unsupported", "non supportée par ce thème"
		)
	if arena.visual_mode == ArenaDefinition.VisualMode.PAINTED:
		return _disabled(
			result, &"painted_mode",
			"mode PAINTED — le sol peint fait foi"
		)
	if profile == null:
		return _disabled(
			result, &"profile_missing", "profil modulaire absent"
		)
	if not _ids_support(profile.terrain_ids, terrain_id):
		return _disabled(
			result, &"profile_unsupported", "non supportée par ce profil"
		)
	# ArenaRuntimeBridge encode actuellement toute cellule non praticable comme
	# VOID avant les overrides. Activer lava (WALL, playable=false) dans le brush
	# produirait donc une working copy WALL mais un GridData HOLE. Cette mission
	# interdit de changer ce gameplay : l'option reste visible mais désactivée.
	if not definition.walkable:
		return _disabled(
			result, &"runtime_grid_uncertified",
			"parité GridData non certifiée pour ce terrain non praticable"
		)
	if arena.visual_mode == ArenaDefinition.VisualMode.HYBRID:
		match profile.hybrid_floor_policy:
			ArenaModularVisualProfile.HybridFloorPolicy.NONE:
				return _disabled(
					result, &"hybrid_floor_hidden",
					"politique hybride — aucune dalle modulaire"
				)
			ArenaModularVisualProfile.HybridFloorPolicy.NON_BASE_TERRAINS:
				if _same_base_identity(terrain_id, profile.base_terrain_id):
					return _disabled(
						result, &"hybrid_base_hidden",
						"sol de base masqué par la politique hybride"
					)
	result.enabled = true
	result.reason_code = &"paintable"
	result.reason = "terrain permanent peignable et rendu"
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


static func _ids_support(ids: Array[StringName], terrain_id: StringName) -> bool:
	if ids.has(terrain_id):
		return true
	return terrain_id == &"normal" and ids.has(&"stone") \
		or terrain_id == &"stone" and ids.has(&"normal")


static func _same_base_identity(
		terrain_id: StringName,
		base_terrain_id: StringName
	) -> bool:
	if terrain_id == base_terrain_id:
		return true
	return terrain_id in [&"normal", &"stone"] \
		and base_terrain_id in [&"normal", &"stone"]
