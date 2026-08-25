@tool
class_name TerrainPlaceableCatalogService
extends RefCounted

## Autorité de la bibliothèque unifiée. Les sols et murs sont découverts dans
## leurs catalogues existants ; les autres familles viennent d'une Resource.

const PLACEABLE_CATALOG_PATH := (
	"res://addons/dungeon_draft_arena_studio/catalog/placeables/terrain_library.tres"
)


static func entries(
		arena: ArenaDefinition,
		guided := true
	) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for terrain_id in ArenaCatalogService.terrain_ids(true):
		var definition := ArenaCatalogService.terrain(terrain_id)
		if definition == null or not definition.editor_placeable:
			continue
		var paintability := ArenaPermanentTerrainPaintService.paintability(
			arena, terrain_id
		)
		result.append(_terrain_entry(definition, paintability))
	for wall_id in ArenaCatalogService.wall_ids():
		var wall := ArenaCatalogService.wall(wall_id)
		if wall != null:
			result.append(_wall_entry(wall))
	var catalog := load(PLACEABLE_CATALOG_PATH) as TerrainPlaceableCatalog
	if catalog != null:
		for definition in catalog.valid_entries():
			if not guided or definition.guided_visible:
				result.append(_entry(definition, definition.editor_placeable))
	result.sort_custom(_sort_entries)
	return result


static func entry_by_id(
		arena: ArenaDefinition,
		stable_id: StringName,
		guided := true
	) -> Dictionary:
	for entry in entries(arena, guided):
		if StringName(entry.get("stable_id", &"")) == stable_id:
			return entry
	return {}


static func family_label(family: int) -> String:
	return ["Sols", "Obstacles", "Départs", "Interactifs", "Décor"][clampi(
		family, TerrainPlaceableDefinition.Family.FLOOR,
		TerrainPlaceableDefinition.Family.DECORATION
	)]


static func _terrain_entry(
		definition: ArenaTerrainDefinition,
		paintability: Dictionary
	) -> Dictionary:
	var descriptor := TerrainPlaceableDefinition.new()
	descriptor.stable_id = StringName("floor:%s" % definition.stable_id)
	descriptor.display_name = definition.display_name
	descriptor.family = TerrainPlaceableDefinition.Family.FLOOR
	descriptor.placement_kind = TerrainPlaceableDefinition.PlacementKind.PERMANENT_TERRAIN
	descriptor.thumbnail = definition.base_texture
	descriptor.payload = {"terrain_id": definition.stable_id}
	descriptor.badges = _terrain_badges(definition)
	descriptor.result_in_game = _terrain_result(definition)
	var entry := _entry(descriptor, bool(paintability.get("enabled", false)))
	var reason_code := StringName(paintability.get("reason_code", &""))
	if reason_code == &"painted_base_floor":
		entry["enabled"] = true
		entry["requires_activation"] = true
	entry["disabled_reason"] = str(paintability.get("reason", ""))
	entry["reason_code"] = reason_code
	return entry


static func _wall_entry(definition: ArenaWallDefinition) -> Dictionary:
	var descriptor := TerrainPlaceableDefinition.new()
	descriptor.stable_id = StringName("wall:%s" % definition.stable_id)
	descriptor.display_name = definition.display_name
	descriptor.family = TerrainPlaceableDefinition.Family.OBSTACLE
	descriptor.placement_kind = TerrainPlaceableDefinition.PlacementKind.WALL
	descriptor.thumbnail = definition.icon if definition.icon != null else definition.base_texture
	descriptor.payload = {"wall_id": definition.stable_id}
	descriptor.badges = PackedStringArray(["Bloque"])
	descriptor.result_in_game = "Bloque le déplacement sur la case."
	return _entry(descriptor, true)


static func _entry(
		descriptor: TerrainPlaceableDefinition,
		enabled: bool
	) -> Dictionary:
	return {
		"definition": descriptor,
		"stable_id": descriptor.stable_id,
		"display_name": descriptor.display_name,
		"family": descriptor.family,
		"family_label": descriptor.family_label(),
		"placement_kind": descriptor.placement_kind,
		"thumbnail": descriptor.thumbnail,
		"badges": descriptor.badges,
		"tooltip": descriptor.tooltip_text(),
		"payload": descriptor.payload.duplicate(true),
		"minimum_cells": descriptor.minimum_cells,
		"maximum_cells": descriptor.maximum_cells,
		"enabled": enabled and descriptor.production_placeable,
		"disabled_reason": "" if enabled else "Indisponible pour ce terrain.",
	}


static func _terrain_badges(definition: ArenaTerrainDefinition) -> PackedStringArray:
	var result := PackedStringArray()
	if definition.unit_effect != null or definition.apply_on_enter \
			or definition.apply_on_turn_start:
		result.append("Effet")
	if not definition.walkable:
		result.append("Bloque")
	if definition.ai_danger_weight > 0.0:
		result.append("Danger")
	return result


static func _terrain_result(definition: ArenaTerrainDefinition) -> String:
	if definition.unit_effect != null:
		return "Applique %s aux unités qui utilisent cette case." % (
			definition.unit_effect.resource_name
			if not definition.unit_effect.resource_name.is_empty() else "un effet de terrain"
		)
	if not definition.walkable:
		return "Cette case ne peut pas être traversée."
	if definition.movement_cost > 1:
		return "Traverser cette case coûte %d déplacements." % definition.movement_cost
	return "Sol permanent praticable, sans effet supplémentaire."


static func _sort_entries(left: Dictionary, right: Dictionary) -> bool:
	var left_family := int(left.get("family", 0))
	var right_family := int(right.get("family", 0))
	if left_family != right_family:
		return left_family < right_family
	return str(left.get("display_name", "")) < str(right.get("display_name", ""))
