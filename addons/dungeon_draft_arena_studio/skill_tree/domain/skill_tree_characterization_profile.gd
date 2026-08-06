@tool
class_name SkillTreeCharacterizationProfile
extends Resource

@export var profile_id: StringName = &""
@export var display_name := ""
@export var observed_at := ""
@export var base_commit := ""
@export var expected_rank_count := 0
@export var expected_thresholds := PackedInt32Array()
@export var expected_choices := PackedInt32Array()
@export var expected_final_configuration_count := -1
