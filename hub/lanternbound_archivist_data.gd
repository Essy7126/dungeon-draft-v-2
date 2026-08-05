class_name LanternboundArchivistData
extends Resource

@export var display_name := "Lanternbound Archivist"
@export_multiline var dialogue_text := ""
@export_multiline var trade_prototype_text := ""
@export var available_runs: Array[RunData] = []
@export var hero_sources: Array[String] = []


func get_available_runs() -> Array[RunData]:
	var runs: Array[RunData] = []
	for run_data in available_runs:
		if run_data != null:
			runs.append(run_data)
	return runs
