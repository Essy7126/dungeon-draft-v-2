@tool
class_name ItemStudioUiStateService
extends RefCounted

var state := {
	"selected_path": "", "search": "", "category": -1, "rarity": "",
	"slot": -2, "character_id": "", "reward_filter": -1,
	"status": "", "sort": "name", "section": "Identité",
	"left_width": 270.0, "right_width": 330.0,
	"comparison_hero": "elf", "comparison_spell": "", "comparison_target_hp": 1.0,
	"scope": "SHARED",
	"filters": {},
}


func restore(snapshot: Dictionary) -> void:
	for key in state:
		if snapshot.has(key):
			state[key] = snapshot[key]


func snapshot() -> Dictionary:
	return state.duplicate(true)


func set_value(key: String, value: Variant) -> void:
	if state.has(key):
		state[key] = value


func get_value(key: String, fallback: Variant = null) -> Variant:
	return state.get(key, fallback)
