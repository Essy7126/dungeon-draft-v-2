@tool
class_name RoomIntegrationFieldPolicy
extends RefCounted

## Autorité explicite utilisée par UPDATE. Une propriété stockée inconnue bloque
## l’intégration au lieu d’être copiée ou abandonnée silencieusement.

const ARENA_OWNED := &"ARENA_OWNED"
const GAMEPLAY_OWNED := &"GAMEPLAY_OWNED"
const IDENTITY_OWNED := &"IDENTITY_OWNED"
const RUN_OWNED := &"RUN_OWNED"
const UNKNOWN := &"UNKNOWN"

const _ARENA_FIELDS := {
	&"background_image": true,
	&"particles_scene": true,
	&"battle_scene": true,
	&"arena_generation_profile": true,
	&"arena_visual_profile": true,
	&"grid_layout": true,
	&"painted_map_visual_data": true,
	&"hero_spawn_zone": true,
	&"enemy_spawn_zone": true,
	&"schema_version": true,
	&"visual_mode": true,
	&"theme_id": true,
	&"modular_visual_profile": true,
	&"background_path": true,
	&"source_image_size": true,
	&"grid_size": true,
	&"grid_origin": true,
	&"axis_x": true,
	&"axis_y": true,
	&"image_offset": true,
	&"image_scale": true,
	&"foreground_path": true,
	&"occlusion_mask_path": true,
	&"foreground_offset": true,
	&"foreground_scale": true,
	&"foreground_occluder_polygon": true,
	&"foreground_occluder_sort_y": true,
	&"foreground_full_hide_rect": true,
	&"camera_offset": true,
	&"camera_zoom": true,
	&"camp_orientation": true,
	&"border_thickness": true,
	&"cells": true,
	&"obstacles": true,
	&"spawns": true,
	&"objectives": true,
	&"decorations": true,
	&"calibration_cells": true,
	&"calibration_pixels": true,
	&"presentation_profile_path": true,
	&"source_room_path": true,
	&"source_visual_path": true,
	&"intentionally_isolated_cells": true,
}

const _GAMEPLAY_FIELDS := {
	&"encounter_definition": true,
	&"waves": true,
	&"minimum_wave_count": true,
	&"maximum_wave_count": true,
	&"ultimate_reward_base_chance": true,
	&"ultimate_reward_min_gain_per_wave": true,
	&"ultimate_reward_max_gain_per_wave": true,
	&"enemies": true,
}

const _IDENTITY_FIELDS := {
	&"resource_local_to_scene": true,
	&"resource_name": true,
	&"resource_scene_unique_id": true,
	&"script": true,
	&"room_name": true,
	&"arena_id": true,
	&"display_name": true,
	&"production_notes": true,
}

const RUN_FIELDS := {
	&"run_path": RUN_OWNED,
	&"room_index": RUN_OWNED,
	&"room_order": RUN_OWNED,
}


static func classification_for(property_name: StringName) -> StringName:
	if _ARENA_FIELDS.has(property_name):
		return ARENA_OWNED
	if _GAMEPLAY_FIELDS.has(property_name):
		return GAMEPLAY_OWNED
	if _IDENTITY_FIELDS.has(property_name):
		return IDENTITY_OWNED
	if RUN_FIELDS.has(property_name):
		return RUN_OWNED
	return UNKNOWN


static func stored_property_names(resource: Resource) -> Array[StringName]:
	var result: Array[StringName] = []
	if resource == null:
		return result
	for property in resource.get_property_list():
		if (int(property.get("usage", 0)) & PROPERTY_USAGE_STORAGE) == 0:
			continue
		result.append(StringName(property.get("name", &"")))
	return result


static func coverage_report(resource: Resource = null) -> Dictionary:
	var inspected := resource if resource != null else ArenaDefinition.new()
	var classified := {}
	var unknown := PackedStringArray()
	for property_name in stored_property_names(inspected):
		var classification := classification_for(property_name)
		classified[str(property_name)] = str(classification)
		if classification == UNKNOWN:
			unknown.append(str(property_name))
	return {
		"ok": unknown.is_empty(),
		"resource_class": inspected.get_class(),
		"classified": classified,
		"unknown": unknown,
		"run_owned": RUN_FIELDS.duplicate(true),
	}


static func merge_arena_into_room(
		arena_source: ArenaDefinition,
		target_room: RoomData
	) -> ArenaDefinition:
	if arena_source == null or target_room == null:
		return null
	if not coverage_report(arena_source).get("ok", false) \
			or not coverage_report(target_room).get("ok", false):
		return null
	var merged := ArenaDefinition.new()
	if not merged.restore_snapshot(arena_source.to_snapshot()):
		return null
	for property_name in stored_property_names(arena_source):
		if classification_for(property_name) == ARENA_OWNED \
				and _has_property(merged, property_name):
			merged.set(property_name, arena_source.get(property_name))
	for property_name in stored_property_names(target_room):
		var classification := classification_for(property_name)
		if classification not in [GAMEPLAY_OWNED, IDENTITY_OWNED] \
				or property_name == &"script":
			continue
		if _has_property(merged, property_name):
			merged.set(property_name, target_room.get(property_name))
	if not target_room is ArenaDefinition:
		merged.display_name = target_room.room_name
	merged.room_name = target_room.room_name
	ArenaRuntimeBridge.sync_runtime_resources(merged)
	return merged


static func preserves_signature(
		before: Dictionary,
		after: Dictionary
	) -> bool:
	for property_name in before:
		if not after.has(property_name) or after[property_name] != before[property_name]:
			return false
	return true


static func signature(resource: Resource, classification: StringName) -> Dictionary:
	var result := {}
	if resource == null:
		return result
	for property_name in stored_property_names(resource):
		if classification_for(property_name) != classification \
				or property_name == &"script":
			continue
		result[str(property_name)] = _stable_value(resource.get(property_name), {})
	return result


static func gameplay_summary(room: RoomData) -> PackedStringArray:
	if room == null:
		return PackedStringArray(["Salle cible absente"])
	return PackedStringArray([
		"Rencontre : %s" % (
			room.encounter_definition.resource_path
			if room.encounter_definition != null else "aucune"
		),
		"Vagues : %d" % room.waves.size(),
		"Ennemis directs : %d" % room.enemies.size(),
		"Plage de combats : %d–%d" % [
			room.minimum_wave_count, room.maximum_wave_count,
		],
		"Récompense ultime : %d%% (+%d à +%d par vague)" % [
			room.ultimate_reward_base_chance,
			room.ultimate_reward_min_gain_per_wave,
			room.ultimate_reward_max_gain_per_wave,
		],
	])


static func _has_property(resource: Resource, property_name: StringName) -> bool:
	for property in resource.get_property_list():
		if StringName(property.get("name", &"")) == property_name:
			return true
	return false


static func _stable_value(value: Variant, seen: Dictionary) -> Variant:
	if value is Resource:
		var resource := value as Resource
		# Une sous-ressource sauvegardée reçoit un chemin local `fichier::id` qui
		# change quand elle passe par le staging. Seules les vraies ressources
		# externes sont identifiées par leur chemin ; les sous-ressources sont
		# comparées par contenu.
		if not resource.resource_path.is_empty() and "::" not in resource.resource_path:
			return {"class": resource.get_class(), "path": resource.resource_path}
		var instance_id := resource.get_instance_id()
		if seen.has(instance_id):
			return {"class": resource.get_class(), "cycle": true}
		seen[instance_id] = true
		var properties := {}
		for property_name in stored_property_names(resource):
			# Ces métadonnées d'identité peuvent être attribuées ou normalisées par
			# ResourceSaver lors d'un aller-retour. Elles ne font pas partie du
			# contenu gameplay d'une sous-ressource (par exemple RoomWaveData).
			if property_name in [
				&"script", &"resource_local_to_scene", &"resource_name",
				&"resource_scene_unique_id",
			]:
				continue
			properties[str(property_name)] = _stable_value(
				resource.get(property_name), seen
			)
		seen.erase(instance_id)
		return {"class": resource.get_class(), "properties": properties}
	if value is Array:
		var result: Array = []
		for entry in value:
			result.append(_stable_value(entry, seen))
		return result
	if value is Dictionary:
		var dictionary := value as Dictionary
		var result: Dictionary = {}
		var keys: Array = dictionary.keys()
		keys.sort_custom(func(left, right): return str(left) < str(right))
		for key in keys:
			result[str(key)] = _stable_value(dictionary[key], seen)
		return result
	if value is Vector2:
		return [value.x, value.y]
	if value is Vector2i:
		return [value.x, value.y]
	if value is Rect2:
		return [value.position.x, value.position.y, value.size.x, value.size.y]
	if value is Color:
		return [value.r, value.g, value.b, value.a]
	if value is PackedVector2Array:
		return Array(value).map(func(entry): return [entry.x, entry.y])
	if value is PackedStringArray or value is PackedInt32Array \
			or value is PackedFloat32Array:
		return Array(value)
	return value
