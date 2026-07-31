class_name SkillTreeRefinedConfig
extends Resource

@export_category("Reveal policy")
@export_range(0, 3, 1) var reveal_depth := 1
@export var show_next_rank_names := false
@export var show_next_rank_icons := true
@export var hide_future_connections := true
@export var hidden_rank_label_format := "RANG %d VERROUILLÉ"
@export var locked_rank_label_format := "RANG %d REQUIS"
@export_range(0.0, 1.0, 0.01) var locked_node_opacity := 0.42
@export_range(0.0, 1.0, 0.01) var hidden_node_opacity := 0.22

@export_category("Functional lock")
@export var lock_icon_texture: Texture2D = null
@export var lock_icon_sizes: Dictionary = {
	&"large": 32.0,
	&"medium": 28.0,
	&"compact": 24.0,
}

@export_category("Node geometry")
@export var node_sizes: Dictionary = {
	&"large": {&"root": 92.0, &"standard": 82.0, &"specialization": 92.0, &"capstone": 108.0, &"rank_gate": 88.0},
	&"medium": {&"root": 88.0, &"standard": 78.0, &"specialization": 88.0, &"capstone": 104.0, &"rank_gate": 84.0},
	&"compact": {&"root": 86.0, &"standard": 76.0, &"specialization": 86.0, &"capstone": 100.0, &"rank_gate": 80.0},
}
@export var icon_sizes: Dictionary = {
	&"large": {&"standard": 54.0, &"major": 68.0},
	&"medium": {&"standard": 50.0, &"major": 64.0},
	&"compact": {&"standard": 46.0, &"major": 60.0},
}
@export var badge_sizes: Dictionary = {
	&"large": Vector2(36.0, 36.0),
	&"medium": Vector2(34.0, 34.0),
	&"compact": Vector2(30.0, 30.0),
}
@export var connection_widths: Dictionary = {
	&"acquired": 4.0,
	&"available": 3.0,
	&"locked": 2.0,
	&"excluded": 2.0,
	&"rank_gate": 3.0,
}
@export var accent_intensities: Dictionary = {
	&"surface": 0.12,
	&"selected": 0.34,
	&"available": 0.26,
	&"acquired": 0.42,
}


func get_node_size(profile: StringName, kind: StringName) -> float:
	var profile_sizes: Dictionary = node_sizes.get(profile, node_sizes[&"large"])
	return float(profile_sizes.get(kind, profile_sizes.get(&"standard", 82.0)))


func get_icon_size(profile: StringName, major: bool) -> float:
	var profile_sizes: Dictionary = icon_sizes.get(profile, icon_sizes[&"large"])
	return float(profile_sizes.get(&"major" if major else &"standard", 54.0))


func get_badge_size(profile: StringName) -> Vector2:
	return badge_sizes.get(profile, badge_sizes[&"large"]) as Vector2


func get_lock_icon_size(profile: StringName) -> float:
	return float(lock_icon_sizes.get(profile, lock_icon_sizes[&"large"]))
