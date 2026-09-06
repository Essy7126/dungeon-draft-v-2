@tool
class_name CombatFormChangeData
extends Resource

## A one-way, non-lethal health threshold transition. The original Unit remains
## authoritative: no respawn, healing, turn reset, or removal of active statuses.
@export var ability_id: StringName = &"combat_form_change"
@export var initial_form: StringName = &""
@export var target_form: StringName = &""
@export_range(1, 99, 1) var below_hp_percent: int = 20
@export var shield_grant: int = 0
@export var shield_source_id: StringName = &"combat_form"
@export var spells: Array[Spell] = []
# Optional artwork must not prevent encounters and runs from loading.
@export_file("*.tres") var preview_sprite_frames_path: String = ""
@export var preview_sprite_frames: SpriteFrames = null:
	get:
		if preview_sprite_frames != null or preview_sprite_frames_path.is_empty():
			return preview_sprite_frames
		if not ResourceLoader.exists(preview_sprite_frames_path, "SpriteFrames"):
			return null
		return load(preview_sprite_frames_path) as SpriteFrames
@export var preview_sprite_animation: StringName = &"idle_E"
@export var preferred_range: int = 1
@export var minimum_range: int = 1
@export var maximum_range: int = 3
@export var keep_distance: bool = false

func is_valid() -> bool:
	return initial_form != &"" and target_form != &"" \
		and initial_form != target_form and not spells.is_empty() \
		and below_hp_percent > 0 and below_hp_percent < 100
