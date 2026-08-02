extends Node

var start_call_count := 0
var received_run_data: RunData = null
var received_hero_sources: Array = []


func start_preconfigured_run(run_data: RunData, hero_sources: Array) -> void:
	start_call_count += 1
	received_run_data = run_data
	received_hero_sources = hero_sources.duplicate()
