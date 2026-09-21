@tool
class_name StudioPreviewParty
extends RefCounted

## A quick test still needs the current hero's playable progression profile.
## Loading only his base UnitData would produce a hero without techniques.
const HERO_PATH := "res://data/units/allies/achilles.tres"
const RUN_PATH := "res://data/runs/odyssey.tres"


static func resolve() -> Array[UnitData]:
	var run := load(RUN_PATH) as RunData
	return RunHeroResolver.resolve_runtime_hero_data(run, false).heroes


static func resolve_sources(sources: Array) -> Array:
	var result: Array = []
	for source in sources:
		if source is String and source == HERO_PATH:
			result.append_array(resolve())
		else:
			result.append(source)
	return result
