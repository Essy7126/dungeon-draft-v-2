class_name DisciplineProgressDelta
extends RefCounted

var character_id: StringName = &""
var spell_id: StringName = &""
var spell_name := ""
var discipline_id: StringName = &""
var display_name := ""
var icon: Texture2D = null
var xp_before := 0
var xp_after := 0
var rank_before := 1
var rank_after := 1
var next_threshold_after := -1
var reached_ranks: Array[int] = []
var acquired_nodes: Array[Dictionary] = []
var thresholds: Array[Dictionary] = []


func has_progress() -> bool:
	return xp_after != xp_before \
		or rank_after != rank_before \
		or not acquired_nodes.is_empty()


func to_dictionary() -> Dictionary:
	return {
		"character_id": character_id,
		"spell_id": spell_id,
		"spell_name": spell_name,
		"discipline_id": discipline_id,
		"display_name": display_name,
		"icon": icon,
		"xp_before": xp_before,
		"xp_after": xp_after,
		"rank_before": rank_before,
		"rank_after": rank_after,
		"next_threshold_after": next_threshold_after,
		"reached_ranks": reached_ranks.duplicate(),
		"acquired_nodes": acquired_nodes.duplicate(true),
		"thresholds": thresholds.duplicate(true),
	}
