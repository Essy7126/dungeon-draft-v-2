class_name BattlePresentationProfile
extends Resource

## Presentation propre a une peinture. Ces valeurs n'interviennent jamais dans
## GridData, Pathfinder, TerrainEffects, les spawns ou les regles de combat.

@export var profile_id: StringName = &"painted_room"
@export_range(1.0, 1.25, 0.01) var camera_zoom_multiplier := 1.0
@export var camera_offset_adjustment := Vector2.ZERO
@export var camera_keep_painting_in_view := false
@export_range(0.8, 1.2, 0.01) var global_unit_scale_multiplier := 1.0
@export var unit_profiles: Array[UnitVisualProfile] = []

@export_group("Lisibilite")
@export var contact_shadows_enabled := true
@export var outlines_enabled := false
@export_range(0.0, 4.0, 0.1) var outline_width_px := 1.25
@export var ally_outline_color := Color(0.58, 0.88, 1.0, 0.32)
@export var enemy_outline_color := Color(1.0, 0.47, 0.29, 0.34)
@export var active_outline_color := Color(1.0, 0.88, 0.27, 0.78)
@export var active_ring_color := Color(1.0, 0.87, 0.22, 0.88)

@export_group("Focus d'action")
@export var action_focus_enabled := false
@export_range(0.0, 0.15, 0.01) var action_focus_zoom := 0.0


func profile_for_unit(unit_id: StringName) -> UnitVisualProfile:
	for profile in unit_profiles:
		if profile != null and profile.matches(unit_id):
			return profile
	return null


func final_visual_scale(unit_id: StringName) -> float:
	var profile := profile_for_unit(unit_id)
	return profile.final_visual_scale(global_unit_scale_multiplier) \
		if profile != null else 1.0


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if profile_id == &"":
		errors.append("profile_id est requis.")
	var seen := {}
	for profile in unit_profiles:
		if profile == null:
			errors.append("Un profil de famille est nul.")
			continue
		errors.append_array(profile.validation_errors())
		for unit_id in profile.unit_ids:
			if seen.has(unit_id):
				errors.append("unit_id duplique dans les familles : %s." % unit_id)
			seen[unit_id] = true
	return errors
