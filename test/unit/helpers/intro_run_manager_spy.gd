extends Node

var start_call_count := 0
var received_run_data: RunData = null
var received_hero_sources: Array = []
var next_run_data: RunData = null
var used_run_content_resolver := false


func peek_next_run_data() -> RunData:
	return next_run_data


func has_next_run_configuration() -> bool:
	return next_run_data != null


func start_configured_run() -> bool:
	var selected_run := next_run_data
	if selected_run == null:
		return false
	next_run_data = null
	start_run(selected_run)
	return true


func take_next_run_data(default_run_data: RunData) -> RunData:
	var selected_run := next_run_data
	next_run_data = null
	return selected_run if selected_run != null else default_run_data


func start_preconfigured_run(run_data: RunData, hero_sources: Array) -> void:
	start_call_count += 1
	received_run_data = run_data
	received_hero_sources = hero_sources.duplicate()
	used_run_content_resolver = false


func start_run(run_data: RunData) -> void:
	start_call_count += 1
	received_run_data = run_data
	var resolution := RunHeroResolver.resolve_runtime_hero_data(run_data, false)
	received_hero_sources.assign(resolution.heroes)
	used_run_content_resolver = resolution.is_valid()
