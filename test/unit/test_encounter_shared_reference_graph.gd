extends GutTest

## Seule la découverte est substituée pour les fixtures user:// ; le parcours,
## le cache, les générations, les signaux et l'annulation sont ceux du service.
class FixtureGraph extends StudioReferenceGraphService:
	var roots: Array[RunData] = []
	var discoveries := 0
	var scans := 0
	var invalidations: Array = []

	func _init() -> void:
		scan_started.connect(func(): scans += 1)
		invalidated.connect(func(keys): invalidations.append(Array(keys)))

	func _discover_runs() -> Array[RunData]:
		discoveries += 1
		return roots


const ROOT := "user://dungeon_draft_studio/encounter_shared_graph"
var _metrics: Array = []


func after_all() -> void:
	var file := FileAccess.open("res://artifacts/encounter_shared_graph/test_metrics.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(_metrics, "  "))


func _record(label: String, graph: FixtureGraph) -> void:
	_metrics.append({"case": label, "scans": graph.scans,
		"discoveries": graph.discoveries, "generation": graph.generation,
		"invalidations": graph.invalidations})


func _fixture() -> Dictionary:
	var path := ROOT.path_join(str(Time.get_ticks_usec()))
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path)), OK)
	var unit := UnitData.new()
	unit.unit_id = &"shared_graph_fixture"
	unit.unit_name = "Garde fixture"
	unit.team = 1
	assert_eq(ResourceSaver.save(unit, path.path_join("unit.tres")), OK)
	unit = load(path.path_join("unit.tres"))
	var encounter := EncounterDefinition.new()
	encounter.roster_units = [unit]
	encounter.roster_counts = PackedInt32Array([1])
	encounter.living_enemy_cap = 1
	encounter.formation_profiles = [&"line"]
	assert_eq(ResourceSaver.save(encounter, path.path_join("encounter.tres")), OK)
	encounter = load(path.path_join("encounter.tres"))
	var layout := RoomGridLayout.new()
	layout.logical_size = Vector2i(8, 8)
	layout.layout_rows = PackedStringArray([
		"........", "........", "........", "........",
		"........", "........", "........", "........"])
	var room := ArenaDefinition.new()
	room.set_identity("Salle graphe", "salle_graphe")
	room.visual_mode = ArenaDefinition.VisualMode.MODULAR
	room.theme_id = &"dynamic_default"
	room.modular_visual_profile = ArenaModularVisualProfile.new()
	room.grid_size = Vector2i(8, 8)
	for y in 8:
		for x in 8:
			ArenaTerrainRegistry.configure_cell(room.ensure_cell(Vector2i(x, y)), &"stone")
	ArenaEditingService.prepare_automatically(room)
	room.room_name = "Salle graphe"
	room.grid_layout = layout
	room.hero_spawn_zone = [Vector2i(0, 0)]
	room.enemy_spawn_zone = [Vector2i(7, 7)]
	room.encounter_definition = encounter
	room.minimum_wave_count = 1
	room.maximum_wave_count = 2
	for index in range(2):
		var wave := RoomWaveData.new()
		wave.wave_name = "Affrontement %d" % index
		wave.encounter_definition = encounter
		room.waves.append(wave)
	assert_eq(ResourceSaver.save(room, path.path_join("room.tres")), OK)
	var run := RunData.new()
	run.run_name = "Partie graphe"
	run.room_flow_mode = RunData.RoomFlowMode.WAVE_CHAIN
	run.maximum_waves_per_room = 3
	run.rooms = [load(path.path_join("room.tres"))]
	assert_eq(ResourceSaver.save(run, path.path_join("run.tres")), OK)
	run = load(path.path_join("run.tres"))
	var graph := FixtureGraph.new()
	graph.roots = [run]
	return {"run": run, "path": run.resource_path, "root": path, "graph": graph}


func _workspace(fixture: Dictionary) -> StudioWorkspace:
	var context := StudioProjectContext.new()
	assert_true(context.request_run(fixture.run).ok)
	var workspace := StudioWorkspace.new()
	workspace.arena_auto_load_enabled = false
	workspace.arena_production_planning_enabled = false
	workspace.setup(null, null, context, fixture.graph)
	add_child_autofree(workspace)
	await wait_process_frames(3)
	return workspace


func test_exact_shared_instance_and_navigation_never_scan() -> void:
	var fixture := _fixture()
	var graph: FixtureGraph = fixture.graph
	var workspace := await _workspace(fixture)
	var ui := workspace.encounter_studio
	assert_same(ui.shared_reference_graph, graph)
	assert_same(workspace.reference_graph, graph)
	assert_eq(graph.scans, 0)
	assert_string_contains(ui._usage_text(ui._usage_summary(ui.session.current_encounter())), "Analyse des usages en cours")
	assert_true(graph.scan().ok)
	var second := _fixture()
	for path in [second.path, fixture.path, second.path, fixture.path]:
		assert_true(ui.open_run(path))
		assert_true(ui._request_room(0, 1))
		ui._refresh_all()
		ui.generate_preview()
		ui._on_filesystem_changed()
		for tab in [0, 1, 2, 1]:
			workspace.tabs.current_tab = tab
	await wait_process_frames(2)
	assert_eq(graph.scans, 1)
	assert_eq(graph.discoveries, 1)
	assert_eq(graph.generation, 1)
	assert_eq(graph.invalidations.size(), 0)
	assert_true(graph.scan().cached)
	assert_eq(graph.scans, 1)
	_record("navigation", graph)


func test_adapter_counts_occurrences_and_distinguishes_embedded_external_and_shared() -> void:
	var fixture := _fixture()
	var external: EncounterDefinition = fixture.run.rooms[0].get_encounter_for_wave(0)
	var room := RoomData.new()
	var wave := RoomWaveData.new()
	wave.encounter_definition = external
	room.waves = [wave, wave]
	room.encounter_definition = external # alias historique, pas un troisième combat
	var legacy := RoomData.new()
	legacy.encounter_definition = external
	var embedded := EncounterDefinition.new()
	var ignored := EncounterDefinition.new()
	var embedded_room := RoomData.new()
	var embedded_wave := RoomWaveData.new()
	embedded_wave.encounter_definition = embedded
	embedded_room.waves = [embedded_wave]
	embedded_room.encounter_definition = ignored
	var first := RunData.new()
	var null_wave_room := RoomData.new()
	null_wave_room.waves = [null]
	null_wave_room.encounter_definition = ignored
	first.rooms = [room, legacy, embedded_room, null_wave_room]
	var second := RunData.new()
	second.rooms = [room]
	var graph: FixtureGraph = fixture.graph
	graph.roots = [first, second]
	graph.scan()
	var summary := EncounterReferenceGraphService.published_summary(external, graph)
	assert_eq(summary.usage_count, 5)
	assert_eq(summary.room_count, 3)
	assert_true(summary.external)
	assert_eq(EncounterReferenceGraphService.published_summary(embedded, graph).usage_count, 1)
	assert_false(EncounterReferenceGraphService.published_summary(embedded, graph).external)
	assert_eq(EncounterReferenceGraphService.published_summary(ignored, graph).usage_count, 0)
	# Sous-ressource persistée : un chemin :: ne signifie pas fichier externe.
	assert_eq(ResourceSaver.save(first, fixture.root.path_join("embedded_run.tres")), OK)
	var disk := ResourceLoader.load(fixture.root.path_join("embedded_run.tres"), "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as RunData
	graph.roots = [disk]
	graph.invalidate(disk)
	graph.scan()
	var embedded_disk := disk.rooms[2].get_encounter_for_wave(0)
	assert_string_contains(embedded_disk.resource_path, "::")
	assert_false(EncounterReferenceGraphService.published_summary(embedded_disk, graph).external)
	var other := RunData.new()
	other.rooms = [disk.rooms[0]]
	assert_eq(ResourceSaver.save(other, fixture.root.path_join("other_run.tres")), OK)
	graph.roots.append(load(fixture.root.path_join("other_run.tres")))
	graph.invalidate(fixture.root.path_join("other_run.tres"))
	graph.scan()
	assert_eq(EncounterReferenceGraphService.published_summary(external, graph).usage_count, 5,
		"Les relectures profondes de deux racines ne dupliquent pas les arêtes de la même salle")
	_record("adapter", graph)


func test_pending_and_cancelled_analysis_never_claim_unique_or_allow_unconfirmed_edit() -> void:
	var fixture := _fixture()
	var graph: FixtureGraph = fixture.graph
	var workspace := await _workspace(fixture)
	var ui := workspace.encounter_studio
	var encounter := ui.session.current_encounter()
	var original := encounter.living_enemy_cap
	ui._edit_encounter_property(&"living_enemy_cap", original + 1, "Modification")
	assert_eq(encounter.living_enemy_cap, original)
	assert_false(ui.shared_dialog.visible)
	var cancel_scan := func(_completed, _total, _label): graph.cancel()
	graph.scan_progress.connect(cancel_scan)
	assert_true(graph.scan().cancelled)
	assert_eq(graph.generation, 0)
	await wait_process_frames(2)
	assert_string_contains(ui._wave_tooltip(ui.session.current_wave(), encounter), "annulée")
	assert_false(ui._wave_tooltip(ui.session.current_wave(), encounter).contains("unique"))
	graph.scan_progress.disconnect(cancel_scan)
	assert_true(graph.scan().ok)
	assert_eq(graph.generation, 1)
	await wait_process_frames(2)
	assert_eq(ui._usage_summary(encounter).published.usage_count, 2)
	_record("cancel_resume", graph)


func test_targeted_invalidation_refreshes_from_disk_and_unrelated_resource_preserves_counts() -> void:
	var fixture := _fixture()
	var graph: FixtureGraph = fixture.graph
	graph.scan()
	var workspace := await _workspace(fixture)
	var ui := workspace.encounter_studio
	var encounter := ui.session.current_encounter()
	assert_eq(ui._usage_summary(encounter).published.usage_count, 2)
	var room_path: String = fixture.root.path_join("room.tres")
	var room := ResourceLoader.load(room_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as RoomData
	room.waves.append(room.waves[0])
	assert_eq(ResourceSaver.save(room, room_path), OK)
	graph.invalidate(room_path)
	graph.invalidate(fixture.path) # même lot, un seul parcours
	await wait_process_frames(3)
	assert_eq(graph.scans, 2)
	assert_eq(graph.generation, 2)
	assert_eq(ui._usage_summary(encounter).published.usage_count, 3)
	var label := ui._usage_label
	assert_string_contains(label.text, "Projet publié : 3 affrontement(s)")
	assert_eq(ui._usage_summary(encounter).local.usage_count, 2)
	graph.invalidate(fixture.run.rooms[0].get_encounter_for_wave(0).roster_units[0])
	await wait_process_frames(3)
	assert_eq(graph.scans, 3)
	assert_eq(ui._usage_summary(encounter).published.usage_count, 3)
	assert_eq(graph.invalidations.size(), 3)
	_record("invalidation", graph)


func test_draft_usage_and_duplicate_remain_local_without_canonical_invalidation() -> void:
	var fixture := _fixture()
	var graph: FixtureGraph = fixture.graph
	graph.scan()
	var workspace := await _workspace(fixture)
	var terrain := workspace.arena_studio
	assert_true(terrain._open_context_room(fixture.run.rooms[0]))
	terrain.show_editor()
	workspace.create_encounters_button.pressed.emit()
	var ui := workspace.encounter_studio
	assert_same(ui.session.draft_room, terrain.room_draft())
	for repeat in 3:
		assert_true(ui.open_room_draft(terrain.room_draft(), fixture.run, fixture.path,
			terrain.room_draft_gameplay_mapping()))
	var shared := ui.session.current_encounter()
	var summary := ui._usage_summary(shared)
	assert_eq(summary.published.usage_count, 2)
	assert_eq(summary.local.scope, "room_draft")
	assert_gte(summary.local.usage_count, 2)
	assert_string_contains(ui._usage_text(summary), "Brouillon courant")
	var before := FileAccess.get_sha256(fixture.root.path_join("encounter.tres"))
	ui._edit_encounter_property(&"living_enemy_cap", shared.living_enemy_cap + 1, "Brouillon")
	assert_true(ui.shared_dialog.visible)
	ui._on_shared_custom_action(&"duplicate")
	var independent := ui.session.current_encounter()
	assert_ne(independent, shared)
	assert_same(ui.session.current_room().waves[1].encounter_definition, shared)
	assert_eq(ui._usage_summary(independent).published.usage_count, 0)
	assert_eq(ui._usage_summary(independent).local.usage_count, 1)
	assert_eq(FileAccess.get_sha256(fixture.root.path_join("encounter.tres")), before)
	for tab in [0, 1, 2, 1]:
		workspace.tabs.current_tab = tab
	ui.generate_preview()
	assert_eq(graph.invalidations.size(), 0)
	assert_eq(graph.scans, 1)
	_record("draft_duplicate", graph)


func test_canonical_shared_choices_preserve_source_and_duplicate_only_current_wave() -> void:
	var fixture := _fixture()
	var graph: FixtureGraph = fixture.graph
	graph.scan()
	var workspace := await _workspace(fixture)
	var ui := workspace.encounter_studio
	var shared := ui.session.current_encounter()
	var original := shared.living_enemy_cap
	ui._edit_encounter_property(&"living_enemy_cap", original + 1, "Partagé")
	assert_true(ui.shared_dialog.visible)
	assert_string_contains(ui.shared_dialog.dialog_text, "projet publié")
	ui.shared_dialog.hide()
	ui.shared_dialog.canceled.emit()
	assert_eq(shared.living_enemy_cap, original)
	ui._edit_encounter_property(&"living_enemy_cap", original + 1, "Partagé")
	ui.shared_dialog.hide()
	ui.shared_dialog.confirmed.emit()
	assert_eq(ui.session.current_room().waves[1].encounter_definition.living_enemy_cap, original + 1)
	assert_eq(ui.session.source_encounter().living_enemy_cap, original)
	ui.session.shared_edit_acknowledged.clear()
	ui._edit_encounter_property(&"living_enemy_cap", original + 2, "Copie")
	ui._on_shared_custom_action(&"duplicate")
	assert_ne(ui.session.current_encounter(), shared)
	assert_eq(shared.living_enemy_cap, original + 1)
	assert_eq(ui.session.current_encounter().living_enemy_cap, original + 2)
	assert_eq(graph.invalidations.size(), 0)
	assert_eq(graph.scans, 1)
	_record("canonical_choices", graph)


func test_publication_invalidates_exact_saved_paths_and_draft_save_does_not() -> void:
	var fixture := _fixture()
	var graph: FixtureGraph = fixture.graph
	graph.scan()
	var workspace := await _workspace(fixture)
	var ui := workspace.encounter_studio
	var room := ui.session.current_room()
	ui._set_property(room, &"room_name", "Salle publiée", "Renommer")
	var result := ui._context_save()
	assert_true(result.ok, str(result))
	var keys: Array = []
	for batch in graph.invalidations:
		keys.append_array(batch)
	assert_eq(keys, result.get("saved_paths", []))
	assert_gt(keys.size(), 0)
	await wait_process_frames(3)
	assert_eq(graph.scans, 2)
	var invalidations := graph.invalidations.size()
	ui._set_property(ui.session.current_room(), &"room_name", "Brouillon", "Renommer")
	assert_true(ui._context_draft().ok)
	assert_eq(graph.invalidations.size(), invalidations)
	ui.session.new_resource_paths[ui.session.duplicate_current_encounter()] = "C:/unsafe.tres"
	assert_false(ui._context_save().ok)
	assert_eq(graph.invalidations.size(), invalidations)
	_record("publication", graph)


func test_repeated_setup_disconnects_previous_graph_and_does_not_duplicate_subscriptions() -> void:
	var fixture := _fixture()
	var workspace := await _workspace(fixture)
	var ui := workspace.encounter_studio
	var old: FixtureGraph = fixture.graph
	var next := FixtureGraph.new()
	next.roots = [fixture.run]
	ui.setup(null, null, workspace.project_context, next)
	ui.setup(null, null, workspace.project_context, next)
	old.invalidate(fixture.path)
	await wait_process_frames(2)
	assert_eq(old.scans, 0)
	assert_eq(next.scans, 0)
	next.invalidate(fixture.path)
	await wait_process_frames(3)
	assert_eq(next.scans, 1)
	assert_eq(next.generation, 1)
	assert_same(ui.shared_reference_graph, next)
	_record("reconnect", next)
