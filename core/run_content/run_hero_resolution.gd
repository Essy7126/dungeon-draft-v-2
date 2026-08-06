class_name RunHeroResolution
extends RefCounted

var heroes: Array[UnitData] = []
var hero_profiles: Array[RunHeroProfile] = []
var errors := PackedStringArray()
var warnings := PackedStringArray()
var used_legacy_fallback := false


func is_valid() -> bool:
	return errors.is_empty() and not heroes.is_empty()
