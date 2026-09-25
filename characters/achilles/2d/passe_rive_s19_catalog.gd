extends RefCounted
## Only these seven cards have authored S19 contact effects.
const Data := preload("res://characters/achilles/2d/passe_rive_s19_data.gd")
const ALIASES := {
	"i_a_ambush": "a_ambush", "i_a_dagger": "a_dagger",
	"i_r_shot": "r_shot", "i_t_fire": "t_fire", "i_t_mark": "t_mark",
}


static func card(spell_id: String) -> Dictionary:
	var id := spell_id.trim_prefix("class_")
	return Data.CARDS.get(ALIASES.get(id, id), {})


static func frame_at(clip: String, seconds: float) -> int:
	var remaining := maxf(seconds, 0.0) * 1000.0
	var durations: Array = Data.CLIPS[clip].durations
	for i in durations.size():
		if remaining + 0.00001 < float(durations[i]):
			return i
		remaining -= float(durations[i])
	return durations.size() - 1


static func duration(clip: String) -> float:
	var total := 0.0
	for ms in Data.CLIPS[clip].durations:
		total += float(ms) / 1000.0
	return total


static func fallback(spell_id: String) -> Dictionary:
	# Unauthored cards use a family gesture; they keep their existing gameplay/VFX.
	var id := spell_id.trim_prefix("class_").trim_prefix("i_")
	var reference := "r_shot" if id.begins_with("r_") else "t_mark" if id.begins_with("t_") else "a_ambush"
	return Data.CARDS[reference]
