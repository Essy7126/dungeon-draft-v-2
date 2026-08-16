extends GutTest

const PRODUCTION_HERO_PATH := "res://data/units/alliés/elfe.tres"
const PROFILE_SAVE_ROOT := "user://skill_tree_tutorial_profile_save"


class DeferredFilesystem:
	extends RefCounted

	var scan_count := 0

	func scan_changes() -> void:
		scan_count += 1


class DeferredEditorInterface:
	extends RefCounted

	var filesystem := DeferredFilesystem.new()

	func get_resource_filesystem():
		return filesystem


var _sandbox_records: Array[Dictionary] = []
var _temporary_files := PackedStringArray()


func after_each() -> void:
	for record in _sandbox_records:
		var session := record.get("session") as SkillTreeEditSession
		var service := record.get("service") as SkillTreeTutorialSandboxService
		if session != null:
			session.release_document(false)
		if service != null:
			service.cleanup_owned_fixture(session)
	_sandbox_records.clear()
	for path in _temporary_files:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_temporary_files.clear()


func test_tutorial_has_ten_chapters_104_unique_pages_and_33_effects() -> void:
	assert_eq(SkillTreeGuidedTour.CHAPTERS.size(), 10)
	assert_eq(SkillTreeGuidedTour.EFFECT_PAGES.size(), 33)
	assert_eq(SkillTreeGuidedTour.total_page_count(), 104)
	var ids := SkillTreeGuidedTour.all_page_ids()
	assert_eq(ids.size(), 104)
	var unique := {}
	for page_id in ids:
		assert_false(page_id.is_empty())
		assert_false(unique.has(page_id), "Étape dupliquée : %s" % page_id)
		unique[page_id] = true
	for required_id in [
		"character_identity", "discipline_settings", "graph_reading",
		"spell_cost_range", "effect_common_fields", "compare_runs",
		"save_review", "readonly_character", "readonly_spell",
		"readonly_effect", "sandbox_launch",
	]:
		assert_true(unique.has(required_id), "Étape absente : %s" % required_id)


func test_every_tutorial_page_has_a_title_target_and_pedagogical_body() -> void:
	var tour := SkillTreeGuidedTour.new()
	add_child_autofree(tour)
	await get_tree().process_frame
	for chapter_index in range(SkillTreeGuidedTour.CHAPTERS.size()):
		var pages := tour._pages_for_chapter(chapter_index)
		assert_false(pages.is_empty())
		for page_value in pages:
			var page := page_value as Array
			assert_gte(page.size(), 4)
			assert_false(str(page[SkillTreeGuidedTour.PAGE_TITLE]).is_empty())
			assert_false(str(page[SkillTreeGuidedTour.PAGE_TARGET]).is_empty())
			assert_gt(str(page[SkillTreeGuidedTour.PAGE_BODY]).length(), 45)


func test_tutorial_navigation_is_manual_and_emits_requested_targets() -> void:
	var tour := SkillTreeGuidedTour.new()
	var targets: Array[StringName] = []
	var sandbox_requests := []
	tour.target_requested.connect(func(target: StringName): targets.append(target))
	tour.sandbox_requested.connect(func(): sandbox_requests.append(true))
	add_child_autofree(tour)
	await get_tree().process_frame
	tour.start_chapter(&"readonly")
	await get_tree().process_frame
	assert_eq(tour.current_chapter_id(), &"readonly")
	assert_eq(tour.current_page_id(), &"readonly_principle")
	assert_eq(targets.back(), &"inspector_advanced")
	await get_tree().process_frame
	assert_eq(
		tour.current_page_id(), &"readonly_principle",
		"Le tutoriel ne doit jamais avancer automatiquement."
	)
	tour.start_chapter(&"sandbox")
	await get_tree().process_frame
	tour._page_index = 2
	tour._refresh()
	tour._action_button.pressed.emit()
	assert_eq(sandbox_requests.size(), 1)


func test_sandbox_remaps_every_creation_saves_and_restores_only_user_data() -> void:
	var production := ResourceLoader.load(
		PRODUCTION_HERO_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as UnitData
	assert_not_null(production)
	var production_bytes := FileAccess.get_file_as_bytes(PRODUCTION_HERO_PATH)
	var session := SkillTreeEditSession.new()
	var service := SkillTreeTutorialSandboxService.new()
	_sandbox_records.append({"session": session, "service": service})
	var started := service.start(session)
	assert_true(started.get("ok", false), str(started))
	assert_true(service.is_active(session))
	assert_true(session.canonical_source_path().begins_with(
		SkillTreeTutorialSandboxService.ROOT
	))
	assert_true(FileAccess.file_exists(str(started.get("initial_path", ""))))
	assert_eq(session.working_unit.disciplines.size(), 0)
	var discipline := session.add_discipline("Alchimie", &"tutorial_alchemy")
	assert_not_null(discipline)
	assert_not_null(session.current_spell())
	assert_true(session.new_resource_paths.values().any(
		func(path): return str(path).begins_with("res://data/")
	))
	var prepared := service.prepare_for_save(session)
	assert_true(prepared.get("ok", false), str(prepared))
	assert_true(session.new_resource_paths.values().all(
		func(path): return str(path).begins_with(service.session_directory)
	))
	var plan := SkillTreeSaveTransactionService.build_plan(
		session, service.save_options()
	)
	assert_false(plan.has_blocking_conflicts(), str(plan.conflicts))
	assert_true(plan.writable_entries().all(func(entry):
		return entry.target_path.begins_with(service.session_directory)
	))
	var saved := SkillTreeSaveService.save(session, null, service.save_options())
	assert_true(saved.get("ok", false), str(saved))
	service.configure_session(session)
	assert_false(session.is_dirty())
	assert_eq(session.working_unit.disciplines.size(), 1)
	var restored := service.restore_initial(session)
	assert_true(restored.get("ok", false), str(restored))
	assert_eq(session.working_unit.disciplines.size(), 0)
	assert_eq(
		FileAccess.get_file_as_bytes(PRODUCTION_HERO_PATH),
		production_bytes,
		"L’exercice ne doit modifier aucun octet du héros de production."
	)


func test_studio_exposes_compact_tutorial_reset_and_review_for_ctrl_s() -> void:
	var studio := SkillTreeStudioMain.new()
	studio.setup(null, null)
	add_child_autofree(studio)
	for _frame in range(12):
		await get_tree().process_frame
	_handle_known_production_uid_warning()
	assert_not_null(studio.tour_menu_button)
	assert_eq(studio.tour_menu_button.text, "?")
	assert_eq(studio.tour_menu_button.get_popup().get_item_count(), 12)
	assert_not_null(studio.compare_dialog)
	assert_not_null(studio.compare_run_option)
	assert_not_null(studio.sandbox_reset_button)
	assert_false(studio.sandbox_reset_button.visible)
	assert_not_null(studio.session.working_unit)
	assert_true(studio.session.change_property(
		studio.session.working_unit,
		&"max_hp",
		studio.session.working_unit.max_hp + 1,
		"Vérifier Ctrl+S"
	))
	var save_event := InputEventKey.new()
	save_event.pressed = true
	save_event.ctrl_pressed = true
	save_event.keycode = KEY_S
	studio._unhandled_key_input(save_event)
	await get_tree().process_frame
	assert_true(studio.save_plan_dialog.visible)
	assert_eq(studio.save_plan_dialog.get_ok_button().text, "Appliquer la transaction")
	studio.save_plan_dialog.hide()
	studio._cancel_save_review()


func test_run_profile_spell_change_produces_a_writable_profile_entry() -> void:
	var run_data := load(
		"res://data/runs/fixed_trio_prototype_run.tres"
	) as RunData
	assert_not_null(run_data)
	var heroes := RunContentCatalogService.heroes_for_run(run_data)
	assert_false(heroes.is_empty())
	var session := SkillTreeEditSession.new()
	assert_true(session.open_progression(run_data, heroes[0]))
	var fireball := session.working_unit.spells.filter(
		func(spell: Spell): return spell.spell_name == "Boule de feu"
	)[0] as Spell
	assert_not_null(fireball)
	# Reproduit une session encore ouverte avec les tableaux partagés par
	# l'ancienne implémentation. La prochaine synchronisation doit la réparer.
	session.source_progression_profile.spells = session.working_unit.spells
	session.source_progression_profile.disciplines = session.working_unit.disciplines
	session.working_progression_profile.spells = session.source_progression_profile.spells
	session.working_progression_profile.disciplines = (
		session.source_progression_profile.disciplines
	)
	assert_true(session.change_property(
		fireball,
		&"spell_range",
		fireball.spell_range + 1,
		"Modifier la portée de Boule de feu"
	))
	assert_true(session.is_dirty())
	assert_not_same(
		session.source_progression_profile.spells[0],
		session.working_progression_profile.spells[0]
	)
	assert_false(session.source_progression_profile.resource_path.is_empty())
	assert_false(
		session.source_progression_profile.is_built_in(),
		"Le profil externe ne doit pas être écarté comme sous-Resource."
	)
	assert_ne(
		SkillTreeSnapshotService.storage_fingerprint(
			session.source_progression_profile
		),
		SkillTreeSnapshotService.storage_fingerprint(
			session.working_progression_profile
		)
	)
	var plan := SkillTreeSaveTransactionService.build_plan(session)
	assert_eq(plan.writable_entries().size(), 1, str(plan.to_dictionary()))
	assert_false(plan.has_blocking_conflicts(), str(plan.to_dictionary()))
	if plan.writable_entries().size() == 1:
		assert_true(plan.writable_entries()[0].resource is CharacterProgressionProfile)
		assert_eq(
			plan.writable_entries()[0].target_path,
			session.source_progression_profile.resource_path
		)
	session.release_document(false)


func test_reopening_ignores_a_progression_profile_polluted_in_resource_cache() -> void:
	assert_eq(DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(PROFILE_SAVE_ROOT)
	), OK)
	var source_run := load(
		"res://data/runs/fixed_trio_prototype_run.tres"
	) as RunData
	var source_hero := RunContentCatalogService.heroes_for_run(source_run)[0]
	var profile_copy := source_hero.progression_profile.duplicate(true) \
		as CharacterProgressionProfile
	profile_copy.set_path_cache("")
	var profile_path := PROFILE_SAVE_ROOT.path_join(
		"polluted_profile_%s.tres" % Time.get_ticks_usec()
	)
	_temporary_files.append(profile_path)
	assert_eq(ResourceSaver.save(profile_copy, profile_path), OK)
	var canonical_profile := ResourceLoader.load(
		profile_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as CharacterProgressionProfile
	var stale_profile := canonical_profile.duplicate(true) \
		as CharacterProgressionProfile
	stale_profile.set_path_cache(profile_path)
	var stale_fireball := stale_profile.spells.filter(
		func(spell: Spell): return spell.spell_name == "Boule de feu"
	)[0] as Spell
	stale_fireball.spell_range += 5
	var hero_fixture := RunHeroProfile.new()
	hero_fixture.character_id = source_hero.character_id
	hero_fixture.base_unit_data = source_hero.base_unit_data
	hero_fixture.progression_profile = stale_profile
	var run_fixture := RunData.new()
	run_fixture.run_name = "Fixture de cache pollué"
	var session := SkillTreeEditSession.new()
	assert_true(session.open_progression(run_fixture, hero_fixture))
	assert_not_same(session.source_progression_profile, stale_profile)
	assert_eq(
		SkillTreeSnapshotService.storage_fingerprint(
			session.source_progression_profile
		),
		SkillTreeSnapshotService.storage_fingerprint(canonical_profile)
	)
	var fireball := session.working_unit.spells.filter(
		func(spell: Spell): return spell.spell_name == "Boule de feu"
	)[0] as Spell
	assert_true(session.change_property(
		fireball, &"spell_range", fireball.spell_range + 1,
		"Modifier après réouverture"
	))
	var plan := SkillTreeSaveTransactionService.build_plan(session, {
		"allowed_roots": PackedStringArray([PROFILE_SAVE_ROOT + "/"]),
	})
	assert_eq(plan.writable_entries().size(), 1, str(plan.to_dictionary()))
	assert_false(plan.has_blocking_conflicts(), str(plan.to_dictionary()))
	assert_eq(ResourceSaver.save(
		session.working_progression_profile, profile_path
	), OK)
	var interrupted_after_write_plan := SkillTreeSaveTransactionService.build_plan(
		session, {
			"allowed_roots": PackedStringArray([PROFILE_SAVE_ROOT + "/"]),
		}
	)
	assert_false(
		interrupted_after_write_plan.has_blocking_conflicts(),
		"Un fichier déjà identique au résultat attendu doit pouvoir être finalisé."
	)
	var externally_changed := ResourceLoader.load(
		profile_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as CharacterProgressionProfile
	externally_changed.active_spell_slots += 1
	assert_eq(ResourceSaver.save(externally_changed, profile_path), OK)
	var conflicting_plan := SkillTreeSaveTransactionService.build_plan(session, {
		"allowed_roots": PackedStringArray([PROFILE_SAVE_ROOT + "/"]),
	})
	assert_true(
		conflicting_plan.has_blocking_conflicts(),
		"Une vraie modification externe après l'ouverture doit rester bloquante."
	)
	session.release_document(false)


func test_run_profile_spell_change_is_saved_and_reloaded_for_runtime() -> void:
	assert_eq(DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(PROFILE_SAVE_ROOT)
	), OK)
	var source_run := load(
		"res://data/runs/fixed_trio_prototype_run.tres"
	) as RunData
	var source_hero := RunContentCatalogService.heroes_for_run(source_run)[0]
	var profile_copy := source_hero.progression_profile.duplicate(true) \
		as CharacterProgressionProfile
	profile_copy.set_path_cache("")
	var suffix := str(Time.get_ticks_usec())
	var profile_path := PROFILE_SAVE_ROOT.path_join("profile_%s.tres" % suffix)
	var run_path := PROFILE_SAVE_ROOT.path_join("run_%s.tres" % suffix)
	_temporary_files.append(profile_path)
	_temporary_files.append(run_path)
	assert_eq(ResourceSaver.save(profile_copy, profile_path), OK)
	var hero_fixture := RunHeroProfile.new()
	hero_fixture.character_id = source_hero.character_id
	hero_fixture.base_unit_data = source_hero.base_unit_data
	hero_fixture.progression_profile = ResourceLoader.load(
		profile_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as CharacterProgressionProfile
	var content := RunContentProfile.new()
	content.profile_id = &"spell_save_regression"
	content.display_name = "Fixture sauvegarde de sort"
	content.hero_profiles = [hero_fixture]
	var run_fixture := RunData.new()
	run_fixture.run_name = "Fixture sauvegarde de sort"
	run_fixture.content_profile = content
	assert_eq(ResourceSaver.save(run_fixture, run_path), OK)
	var canonical_run := ResourceLoader.load(
		run_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as RunData
	var session := SkillTreeEditSession.new()
	assert_true(session.open_progression(
		canonical_run, RunContentCatalogService.heroes_for_run(canonical_run)[0]
	))
	var fireball := session.working_unit.spells.filter(
		func(spell: Spell): return spell.spell_name == "Boule de feu"
	)[0] as Spell
	var expected_range := fireball.spell_range + 3
	assert_true(session.change_property(
		fireball, &"spell_range", expected_range, "Modifier la portée runtime"
	))
	var editor_interface := DeferredEditorInterface.new()
	var saved := SkillTreeSaveService.save(session, editor_interface, {
		"allowed_roots": PackedStringArray([PROFILE_SAVE_ROOT + "/", "res://data/"]),
	})
	assert_true(saved.get("ok", false), str(saved))
	if not saved.get("ok", false):
		session.release_document(false)
		return
	assert_eq(
		editor_interface.filesystem.scan_count, 0,
		"Le rafraîchissement de Godot ne doit pas interrompre la transaction."
	)
	await get_tree().process_frame
	assert_eq(editor_interface.filesystem.scan_count, 1)
	assert_eq(session.working_unit.spells.filter(
		func(spell: Spell): return spell.spell_name == "Boule de feu"
	)[0].spell_range, expected_range)
	var reloaded_profile := ResourceLoader.load(
		profile_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as CharacterProgressionProfile
	assert_eq(reloaded_profile.spells.filter(
		func(spell: Spell): return spell.spell_name == "Boule de feu"
	)[0].spell_range, expected_range)
	session.release_document(false)


func _handle_known_production_uid_warning() -> void:
	for tracked_error in get_errors():
		if tracked_error.contains_text("frappe_lourde.tres") \
				and tracked_error.contains_text("invalid UID"):
			tracked_error.handled = true
