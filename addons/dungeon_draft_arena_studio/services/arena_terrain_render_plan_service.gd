@tool
class_name ArenaTerrainRenderPlanService
extends RefCounted

## Autorite pure et deterministe du sol visuel. terrain_id choisit l'image ;
## cell_type reste uniquement une information de gameplay jointe au plan.


static func build(
		arena: ArenaDefinition,
		profile: ArenaModularVisualProfile = null
	) -> Dictionary:
	var plan := {
		"ok": false,
		"visual_mode": ArenaDefinition.VisualMode.PAINTED,
		"floor_policy": ArenaModularVisualProfile.HybridFloorPolicy.NONE,
		"base_terrain_id": &"stone",
		"base_floor_intentionally_painted": false,
		"entries": [],
		"render_entries": [],
		"expected_terrain_cell_count": 0,
		"expected_by_terrain_id": {},
		"skipped_cells": [],
		"skip_reasons": {},
		"warnings": [],
		"errors": [],
	}
	if arena == null:
		plan.errors.append("arena_missing")
		return plan
	profile = profile if profile != null else arena.modular_visual_profile
	plan.visual_mode = arena.visual_mode
	plan.base_floor_intentionally_painted = (
		arena.visual_mode == ArenaDefinition.VisualMode.PAINTED
	)
	if profile != null:
		plan.floor_policy = profile.hybrid_floor_policy
		plan.base_terrain_id = profile.base_terrain_id
	elif arena.visual_mode in [
		ArenaDefinition.VisualMode.MODULAR,
		ArenaDefinition.VisualMode.HYBRID,
	]:
		plan.errors.append("modular_profile_missing")
	if arena.visual_mode == ArenaDefinition.VisualMode.MODULAR:
		plan.floor_policy = ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED
	elif arena.visual_mode == ArenaDefinition.VisualMode.PAINTED:
		plan.floor_policy = ArenaModularVisualProfile.HybridFloorPolicy.NONE
	var definitions: Array[ArenaCellDefinition] = arena.cells.duplicate()
	definitions.sort_custom(func(a, b):
		if a == null:
			return false
		if b == null:
			return true
		return a.coordinate.y < b.coordinate.y \
			or (a.coordinate.y == b.coordinate.y and a.coordinate.x < b.coordinate.x)
	)
	for definition in definitions:
		if definition == null:
			plan.errors.append("missing_cell_resource")
			continue
		var entry := _entry_for(arena, profile, definition)
		plan.entries.append(entry)
		if bool(entry.visible):
			plan.render_entries.append(entry)
			plan.expected_terrain_cell_count += 1
			var terrain_key := str(entry.terrain_id)
			plan.expected_by_terrain_id[terrain_key] = int(
				plan.expected_by_terrain_id.get(terrain_key, 0)
			) + 1
		else:
			var skipped := {
				"cell": entry.cell,
				"terrain_id": entry.terrain_id,
				"reason": entry.skip_reason,
			}
			plan.skipped_cells.append(skipped)
			var reason := str(entry.skip_reason)
			plan.skip_reasons[reason] = int(plan.skip_reasons.get(reason, 0)) + 1
		var entry_error := str(entry.get("error", ""))
		if not entry_error.is_empty():
			plan.errors.append("%s:%d,%d" % [
				entry_error, definition.coordinate.x, definition.coordinate.y,
			])
	plan.ok = plan.errors.is_empty()
	return plan


static func entry_for(
		arena: ArenaDefinition,
		cell: Vector2i,
		profile: ArenaModularVisualProfile = null
	) -> Dictionary:
	if arena == null:
		return _missing_entry(cell, "arena_missing")
	var definition := arena.get_cell_definition(cell)
	if definition == null:
		return _missing_entry(cell, "cell_undefined")
	profile = profile if profile != null else arena.modular_visual_profile
	return _entry_for(arena, profile, definition)


static func policy_name(policy: int) -> String:
	return ["NONE", "NON_BASE_TERRAINS", "ALL_DEFINED"][clampi(
		policy,
		ArenaModularVisualProfile.HybridFloorPolicy.NONE,
		ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED
	)]


static func _entry_for(
		arena: ArenaDefinition,
		profile: ArenaModularVisualProfile,
		definition: ArenaCellDefinition
	) -> Dictionary:
	var terrain_id := definition.terrain_id
	var entry := {
		"cell": definition.coordinate,
		"terrain_id": terrain_id,
		"texture": null,
		"texture_path": "",
		"cell_type": definition.cell_type,
		"polygon": GridTransformService.cell_polygon(
			definition.coordinate, arena.grid_origin, arena.axis_x, arena.axis_y
		),
		"visible": false,
		"skip_reason": &"",
		"is_border": definition.border,
		"visual_layer": &"terrain",
		"error": "",
	}
	if not arena.is_in_bounds(definition.coordinate):
		entry.skip_reason = &"out_of_bounds"
		entry.error = "cell_out_of_bounds"
		return entry
	if not ArenaTerrainRegistry.has(terrain_id):
		entry.skip_reason = &"unknown_terrain"
		entry.error = "unknown_terrain"
		return entry
	var terrain := ArenaTerrainRegistry.get_entry(terrain_id)
	entry.texture_path = str(terrain.get("visual", ""))
	entry.texture = ArenaTerrainRegistry.texture_for(terrain_id)
	if not definition.defined or terrain_id == &"void":
		entry.skip_reason = &"void"
		return entry
	match arena.visual_mode:
		ArenaDefinition.VisualMode.PAINTED:
			entry.skip_reason = &"painted_base_floor"
			return entry
		ArenaDefinition.VisualMode.HYBRID:
			if profile == null:
				entry.skip_reason = &"profile_missing"
				entry.error = "modular_profile_missing"
				return entry
			match profile.hybrid_floor_policy:
				ArenaModularVisualProfile.HybridFloorPolicy.NONE:
					entry.skip_reason = &"hybrid_policy_none"
					return entry
				ArenaModularVisualProfile.HybridFloorPolicy.NON_BASE_TERRAINS:
					if terrain_id == profile.base_terrain_id \
							or (profile.base_terrain_id == &"stone" and terrain_id == &"normal"):
						entry.skip_reason = &"hybrid_base_terrain"
						return entry
				ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED:
					pass
				_:
					entry.skip_reason = &"incompatible_policy"
					entry.error = "incompatible_policy"
					return entry
		ArenaDefinition.VisualMode.MODULAR:
			pass
		_:
			entry.skip_reason = &"incompatible_visual_mode"
			entry.error = "incompatible_visual_mode"
			return entry
	if entry.texture_path.is_empty() or entry.texture == null:
		entry.skip_reason = &"texture_missing"
		entry.error = "texture_missing:%s" % terrain_id
		return entry
	entry.visible = true
	return entry


static func _missing_entry(cell: Vector2i, reason: String) -> Dictionary:
	return {
		"cell": cell,
		"terrain_id": &"",
		"texture": null,
		"texture_path": "",
		"cell_type": GridData.CellType.HOLE,
		"polygon": PackedVector2Array(),
		"visible": false,
		"skip_reason": StringName(reason),
		"is_border": false,
		"visual_layer": &"terrain",
		"error": reason,
	}
