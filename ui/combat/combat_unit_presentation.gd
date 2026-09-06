class_name CombatUnitPresentation
extends RefCounted


## Resolve a live combat portrait without changing the shared encounter data.
## The Unit remains the authority for its kit and combat form.
static func portrait_unit_data(unit: Unit) -> UnitData:
	if not is_instance_valid(unit):
		return null
	var source := unit.character_data
	var change := unit.combat_form_change
	if source == null or change == null or unit.combat_form_id != change.target_form:
		return source
	var frames := change.preview_sprite_frames
	if frames == null:
		return source
	var presentation := source.duplicate(false) as UnitData
	presentation.preview_sprite_frames = frames
	presentation.preview_sprite_animation = change.preview_sprite_animation
	return presentation
