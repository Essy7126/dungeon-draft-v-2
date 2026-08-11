@tool
class_name ArenaTerrainRenderPlanService
extends RefCounted

## Autorite pure et deterministe du sol visuel. terrain_id choisit l'image ;
## cell_type reste uniquement une information de gameplay jointe au plan.

static var _cache := {}


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
		"expected_floor_cells": [],
		"expected_floor_hash": "",
		"topology_hash": "",
		"topology": {},
		"skipped_cells": [],
		"skip_reasons": {},
		"warnings": [],
		"errors": [],
	}
	if arena == null:
		plan.errors.append("arena_missing")
		return plan
	var topology := ArenaTopologySignatureService.build(arena)
	plan.topology = topology
	plan.topology_hash = topology.topology_hash
	profile = profile if profile != null else arena.modular_visual_profile
	var cache_key := _cache_key(arena, profile)
	if _cache.has(cache_key):
		var cached := (_cache[cache_key] as Dictionary).duplicate(true)
		cached["cache_hit"] = true
		return cached
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
		var entry := _entry_for(arena, profile, definition, topology.topology_hash)
		plan.entries.append(entry)
		if bool(entry.visible):
			plan.render_entries.append(entry)
			plan.expected_floor_cells.append(
				ArenaTopologySignatureService.coordinate_key(entry.cell)
			)
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
	plan.expected_floor_cells = ArenaTopologySignatureService.normalized_keys(
		plan.expected_floor_cells
	)
	plan.expected_floor_hash = ArenaTopologySignatureService.hash_keys(
		plan.expected_floor_cells
	)
	plan.ok = plan.errors.is_empty()
	plan["cache_hit"] = false
	_cache[cache_key] = plan.duplicate(true)
	return plan


static func clear_cache() -> void:
	_cache.clear()


static func cache_size() -> int:
	return _cache.size()


static func _cache_key(arena: ArenaDefinition, profile: ArenaModularVisualProfile) -> String:
	var profile_signature := "none"
	if profile != null:
		var snapshot := profile.to_dict()
		snapshot.erase("resource_path")
		profile_signature = JSON.stringify(snapshot, "", true).sha256_text()
	return "%s:%s" % [ArenaSnapshotService.arena_fingerprint(arena), profile_signature]


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
	return _entry_for(
		arena, profile, definition,
		str(ArenaTopologySignatureService.build(arena).topology_hash)
	)


static func policy_name(policy: int) -> String:
	return ["NONE", "NON_BASE_TERRAINS", "ALL_DEFINED"][clampi(
		policy,
		ArenaModularVisualProfile.HybridFloorPolicy.NONE,
		ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED
	)]


static func _entry_for(
		arena: ArenaDefinition,
		profile: ArenaModularVisualProfile,
		definition: ArenaCellDefinition,
		topology_hash := ""
	) -> Dictionary:
	var terrain_id := definition.terrain_id
	var entry := {
		"cell": definition.coordinate,
		"terrain_id": terrain_id,
		"texture": null,
		"texture_path": "",
		"resolved_texture_path": "",
		"cell_type": definition.cell_type,
		"polygon": GridTransformService.cell_polygon(
			definition.coordinate, arena.grid_origin, arena.axis_x, arena.axis_y
		),
		"visible": false,
		"skip_reason": &"",
		"visibility_reason": &"",
		"source_definition_present": true,
		"topology_state": &"declared",
		"topology_hash": topology_hash,
		"is_border": definition.border,
		"visual_layer": &"terrain",
		"error": "",
	}
	if not arena.is_in_bounds(definition.coordinate):
		entry.skip_reason = &"out_of_bounds"
		entry.visibility_reason = entry.skip_reason
		entry.error = "cell_out_of_bounds"
		return entry
	if ArenaTopologySignatureService.is_void_definition(definition):
		entry.topology_state = &"void"
		entry.skip_reason = &"cell_void"
		entry.visibility_reason = entry.skip_reason
		return entry
	if definition.border:
		entry.topology_state = &"border"
	elif definition.playable:
		entry.topology_state = &"playable"
	else:
		entry.topology_state = &"blocked_visible"
	if not ArenaTerrainRegistry.has(terrain_id):
		entry.skip_reason = &"unknown_terrain"
		entry.visibility_reason = entry.skip_reason
		entry.error = "unknown_terrain"
		return entry
	var terrain := ArenaTerrainRegistry.get_entry(terrain_id)
	entry.texture_path = str(terrain.get("visual", ""))
	entry.resolved_texture_path = entry.texture_path
	entry.texture = ArenaTerrainRegistry.texture_for(terrain_id)
	if entry.texture != null and terrain_id != &"void":
		var visual_contract := ArenaTileProjectionService.texture_contract(entry.texture)
		entry["visual_contract"] = visual_contract
		if not bool(visual_contract.valid):
			entry.skip_reason = &"invalid_tile_visual_contract"
			entry.visibility_reason = entry.skip_reason
			entry.error = "invalid_tile_visual_contract:%s" % terrain_id
			return entry
	match arena.visual_mode:
		ArenaDefinition.VisualMode.PAINTED:
			entry.skip_reason = &"painted_base_floor"
			entry.visibility_reason = entry.skip_reason
			return entry
		ArenaDefinition.VisualMode.HYBRID:
			if profile == null:
				entry.skip_reason = &"profile_missing"
				entry.visibility_reason = entry.skip_reason
				entry.error = "modular_profile_missing"
				return entry
			match profile.hybrid_floor_policy:
				ArenaModularVisualProfile.HybridFloorPolicy.NONE:
					entry.skip_reason = &"hybrid_policy_none"
					entry.visibility_reason = entry.skip_reason
					return entry
				ArenaModularVisualProfile.HybridFloorPolicy.NON_BASE_TERRAINS:
					if terrain_id == profile.base_terrain_id \
							or (profile.base_terrain_id == &"stone" and terrain_id == &"normal"):
						entry.skip_reason = &"hybrid_base_terrain"
						entry.visibility_reason = entry.skip_reason
						return entry
				ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED:
					pass
				_:
					entry.skip_reason = &"incompatible_policy"
					entry.visibility_reason = entry.skip_reason
					entry.error = "incompatible_policy"
					return entry
		ArenaDefinition.VisualMode.MODULAR:
			pass
		_:
			entry.skip_reason = &"incompatible_visual_mode"
			entry.visibility_reason = entry.skip_reason
			entry.error = "incompatible_visual_mode"
			return entry
	if entry.texture_path.is_empty() or entry.texture == null:
		entry.skip_reason = &"texture_missing"
		entry.visibility_reason = entry.skip_reason
		entry.error = "texture_missing:%s" % terrain_id
		return entry
	entry.visible = true
	entry.visibility_reason = &"rendered"
	return entry


static func _missing_entry(cell: Vector2i, reason: String) -> Dictionary:
	return {
		"cell": cell,
		"terrain_id": &"",
		"texture": null,
		"texture_path": "",
		"resolved_texture_path": "",
		"cell_type": GridData.CellType.HOLE,
		"polygon": PackedVector2Array(),
		"visible": false,
		"skip_reason": StringName(reason),
		"visibility_reason": StringName(reason),
		"source_definition_present": false,
		"topology_state": &"removed",
		"topology_hash": "",
		"is_border": false,
		"visual_layer": &"terrain",
		"error": reason,
	}
