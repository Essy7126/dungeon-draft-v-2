extends GutTest

# Contrat de la fiche d'animations : la Resource est l'autorité de la table
# événement -> clip. Les scripts visuels ne font que la référencer et gardent
# leurs constantes de clips pour leurs comportements spécialisés.

const MAGE_PATH := "res://data/units/alliés/mage.tres"
const WARRIOR_PATH := "res://data/units/alliés/Guerrier.tres"
const ELF_PATH := "res://data/units/alliés/elfe.tres"
const PREVIEW_SCENE := preload("res://ui/characters/CharacterPreview3D.tscn")
const RAW_MAGE_MODEL := preload("res://assets/characters/mage/mage_godot_baseline.glb")

const HEROES := {
	MAGE_PATH: "res://characters/mage/MageVisual3D.tscn",
	WARRIOR_PATH: "res://characters/warrior/WarriorVisual3D.tscn",
	ELF_PATH: "res://characters/elf/ElfVisual3D.tscn",
}


func _handle_known_production_uid_warning() -> void:
	for tracked_error in get_errors():
		if tracked_error.contains_text("frappe_lourde.tres") \
				and tracked_error.contains_text("invalid UID"):
			tracked_error.handled = true


# ============================================================
# La ressource elle-même
# ============================================================

func test_entries_are_read_written_and_erased_by_action_id() -> void:
	var animation_set := CharacterAnimationSetData.new()
	assert_true(animation_set.is_empty())
	assert_eq(animation_set.get_animation_name(&"idle"), &"")
	animation_set.set_animation_name(&"idle", &"Hero_Idle")
	assert_eq(animation_set.get_animation_name(&"idle"), &"Hero_Idle")
	assert_true(animation_set.has_animation_name(&"idle"))
	assert_eq(animation_set.configured_action_ids(), [&"idle"] as Array[StringName])
	animation_set.set_animation_name(&"idle", &"")
	assert_false(animation_set.has_animation_name(&"idle"))
	assert_true(animation_set.is_empty())


func test_action_id_is_a_free_name_not_a_closed_list() -> void:
	# Une granularité par sort pourra s'ajouter sans migrer les fiches.
	var animation_set := CharacterAnimationSetData.new()
	animation_set.set_animation_name(&"cast:warrior_whirlwind", &"DD_Warrior_SpinAttack")
	assert_eq(
		animation_set.get_animation_name(&"cast:warrior_whirlwind"),
		&"DD_Warrior_SpinAttack"
	)


func test_cast_action_id_helper_is_stable_and_reversible() -> void:
	var action_id := CharacterAnimationSetData.cast_action_id_for_spell_id(
		&"achilles_guard"
	)
	assert_eq(action_id, &"cast:achilles_guard")
	assert_true(CharacterAnimationSetData.is_cast_action_id(action_id))
	assert_eq(
		CharacterAnimationSetData.spell_id_from_cast_action_id(action_id),
		&"achilles_guard"
	)
	assert_eq(
		CharacterAnimationSetData.cast_action_id_for_spell_id(&""),
		&""
	)
	assert_false(CharacterAnimationSetData.is_cast_action_id(&"cast:"))
	assert_eq(
		CharacterAnimationSetData.spell_id_from_cast_action_id(&"cast"),
		&""
	)


func test_names_with_never_mutates_the_stored_dictionary() -> void:
	# L'historique d'annulation du Studio dépend de cette copie.
	var animation_set := CharacterAnimationSetData.new()
	animation_set.set_animation_name(&"idle", &"Hero_Idle")
	var updated := animation_set.names_with(&"idle", &"Hero_Autre")
	assert_eq(animation_set.get_animation_name(&"idle"), &"Hero_Idle")
	assert_eq(StringName(updated.get(&"idle")), &"Hero_Autre")


# ============================================================
# Le repli : sans fiche, rien ne change
# ============================================================

func test_missing_override_or_entry_keeps_the_resource_backed_default() -> void:
	var visual := (load(HEROES[MAGE_PATH]) as PackedScene).instantiate() as CharacterVisual3D
	add_child_autofree(visual)
	var before := visual.animation_idle
	assert_false(visual.apply_animation_set(null))
	assert_eq(visual.animation_idle, before)
	var partial := CharacterAnimationSetData.new()
	partial.set_animation_name(&"walk", &"DD_Mage_Run")
	visual.apply_animation_set(partial)
	assert_eq(visual.animation_idle, before, "un événement absent garde son clip")
	assert_eq(visual.animation_walk, &"DD_Mage_Run", "un événement réglé est appliqué")


func test_every_declared_event_can_be_read_and_written_by_id() -> void:
	var visual := (load(HEROES[ELF_PATH]) as PackedScene).instantiate() as CharacterVisual3D
	add_child_autofree(visual)
	assert_eq(CharacterVisual3D.ACTION_ORDER.size(), 9)
	for action in CharacterVisual3D.ACTION_ORDER:
		assert_true(
			visual.set_animation_name_for_action(action, &"Sonde"),
			"événement écrivable : %s" % action
		)
		assert_eq(visual.get_animation_name_for_action(action), &"Sonde")
	assert_false(visual.set_animation_name_for_action(&"inconnu", &"Sonde"))


# ============================================================
# La migration des trois héros : aucun changement visible en jeu
# ============================================================

func test_the_three_heroes_share_their_set_with_the_visual_default() -> void:
	for unit_path in HEROES:
		var unit := load(unit_path) as UnitData
		assert_not_null(unit.animation_set, "fiche présente : %s" % unit_path)
		var visual := (load(HEROES[unit_path]) as PackedScene).instantiate() as CharacterVisual3D
		add_child_autofree(visual)
		assert_same(
			visual.default_animation_set,
			unit.animation_set,
			"la scène et UnitData référencent une seule autorité : %s" % unit_path
		)
		var defaults := {}
		for action in CharacterVisual3D.ACTION_ORDER:
			defaults[action] = visual.get_animation_name_for_action(action)
		assert_false(
			visual.apply_animation_set(unit.animation_set),
			"appliquer la fiche ne change aucun clip : %s" % unit_path
		)
		for action in CharacterVisual3D.ACTION_ORDER:
			assert_eq(
				visual.get_animation_name_for_action(action),
				defaults[action],
				"%s · %s inchangé" % [unit_path, action]
			)
			assert_eq(
				unit.animation_set.get_animation_name(action),
				defaults[action],
				"%s · %s présent dans la fiche" % [unit_path, action]
			)


func test_each_hero_set_only_names_clips_present_in_its_model() -> void:
	for unit_path in HEROES:
		var unit := load(unit_path) as UnitData
		var visual := (load(HEROES[unit_path]) as PackedScene).instantiate() as CharacterVisual3D
		add_child_autofree(visual)
		await wait_process_frames(2)
		var player := visual.get_animation_player()
		assert_not_null(player, "lecteur trouvé : %s" % unit_path)
		for action in unit.animation_set.configured_action_ids():
			assert_true(
				player.has_animation(unit.animation_set.get_animation_name(action)),
				"%s · %s pointe un clip réel" % [unit_path, action]
			)


# ============================================================
# L'aperçu 3D
# ============================================================

func test_preview_plays_a_named_clip_on_a_model_without_a_driving_script() -> void:
	# Reproduit le contexte du Studio : le script du personnage ne tourne pas,
	# l'aperçu doit reprendre le lecteur d'animations à son compte.
	var preview := PREVIEW_SCENE.instantiate() as CharacterPreview3D
	add_child_autofree(preview)
	await wait_process_frames(2)
	preview.configure(RAW_MAGE_MODEL)
	var clips := preview.get_available_clips()
	assert_eq(clips.size(), 6)
	assert_true(clips.has(&"DD_Mage_Run"))
	assert_true(preview.has_clip(&"DD_Mage_Run"))
	assert_false(preview.has_clip(&"Inexistant"))
	assert_true(preview.play_clip(&"DD_Mage_Run"))
	assert_false(preview.play_clip(&"Inexistant"))
	assert_false(preview.is_using_fallback())


func test_preview_still_falls_back_when_no_visual_scene_is_available() -> void:
	var preview := PREVIEW_SCENE.instantiate() as CharacterPreview3D
	add_child_autofree(preview)
	await wait_process_frames(2)
	preview.configure(null)
	assert_true(preview.is_using_fallback())
	assert_null(preview.get_visual_instance())
	assert_false(preview.play_clip(&"DD_Mage_Run"))


func test_preview_applies_the_unit_animation_set_to_a_running_visual() -> void:
	var unit := (load(MAGE_PATH) as UnitData).duplicate() as UnitData
	var animation_set := CharacterAnimationSetData.new()
	animation_set.set_animation_name(&"idle", &"DD_Mage_Walk")
	unit.animation_set = animation_set
	var preview := PREVIEW_SCENE.instantiate() as CharacterPreview3D
	add_child_autofree(preview)
	await wait_process_frames(2)
	preview.configure(unit)
	var visual := preview.get_visual_instance() as CharacterVisual3D
	assert_not_null(visual)
	assert_eq(visual.animation_idle, &"DD_Mage_Walk")


# ============================================================
# Le Studio : édition, annulation, sauvegarde
# ============================================================

func test_animation_screen_lists_known_spells_and_orphaned_cast_mappings() -> void:
	var unit := (load(MAGE_PATH) as UnitData).duplicate(true) as UnitData
	unit.unit_name = "Mage animations dynamiques"
	var guard := Spell.new()
	guard.spell_id = &"achilles_guard"
	guard.spell_name = "Garde d'airain"
	var duplicate_guard := Spell.new()
	duplicate_guard.spell_id = &"achilles_guard"
	duplicate_guard.spell_name = "Doublon ignore"
	var sweep := Spell.new()
	sweep.spell_id = &"achilles_sweep"
	sweep.spell_name = "Balayage"
	var spells: Array[Spell] = [guard, duplicate_guard, sweep]
	unit.spells = spells
	var guard_action := CharacterAnimationSetData.cast_action_id_for_spell_id(
		guard.spell_id
	)
	var sweep_action := CharacterAnimationSetData.cast_action_id_for_spell_id(
		sweep.spell_id
	)
	var orphan_alpha := &"cast:ancien_alpha"
	var orphan_zeta := &"cast:ancien_zeta"
	var animation_set := CharacterAnimationSetData.new()
	animation_set.animation_names = {
		guard_action: &"DD_Mage_Run",
		orphan_zeta: &"DD_Mage_Idle",
		orphan_alpha: &"DD_Mage_Walk",
	}
	unit.animation_set = animation_set
	var screen := SkillTreeAnimationScreen.new()
	add_child_autofree(screen)
	await wait_process_frames(2)

	screen.set_document(unit, MAGE_PATH)

	for index in CharacterVisual3D.ACTION_ORDER.size():
		assert_eq(
			screen._event_actions[index],
			CharacterVisual3D.ACTION_ORDER[index]
		)
	var expected_dynamic: Array[StringName] = [
		guard_action,
		sweep_action,
		orphan_alpha,
		orphan_zeta,
	]
	assert_eq(
		screen._event_actions.slice(CharacterVisual3D.ACTION_ORDER.size()),
		expected_dynamic
	)
	assert_eq(
		screen.event_list.item_count,
		CharacterVisual3D.ACTION_ORDER.size() + expected_dynamic.size()
	)
	assert_true(screen._rows.has(guard_action))
	assert_true(screen._rows.has(orphan_alpha))
	assert_string_contains(screen._label_for(guard_action), "Garde d'airain")
	assert_string_contains(screen._label_for(orphan_alpha), "non repertorie")
	var orphan_row := screen._rows[orphan_alpha] as Dictionary
	var orphan_option := orphan_row.get("option") as OptionButton
	assert_eq(
		StringName(orphan_option.get_item_metadata(orphan_option.selected)),
		&"DD_Mage_Walk"
	)
	var guard_row := screen._rows[guard_action] as Dictionary
	var guard_option := guard_row.get("option") as OptionButton
	animation_set.set_animation_name(guard_action, &"DD_Mage_Walk")
	screen.set_document(unit, MAGE_PATH)
	await wait_process_frames(1)
	assert_same(
		(screen._rows[guard_action] as Dictionary).get("option"),
		guard_option,
		"une simple modification conserve les listes deroulantes existantes"
	)
	assert_eq(
		StringName(guard_option.get_item_metadata(guard_option.selected)),
		&"DD_Mage_Walk"
	)

	animation_set.set_animation_name(orphan_alpha, &"")
	screen.set_document(unit, MAGE_PATH)
	assert_false(screen._event_actions.has(orphan_alpha))
	assert_true(screen._event_actions.has(orphan_zeta))
	await wait_process_frames(2)


func test_studio_spell_specific_mapping_is_undoable() -> void:
	var source := ResourceLoader.load(
		MAGE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	) as UnitData
	var session := SkillTreeEditSession.new()
	assert_true(session.open(source))
	_handle_known_production_uid_warning()
	var action_id := CharacterAnimationSetData.cast_action_id_for_spell_id(
		&"mage_test_spell"
	)
	assert_eq(session.working_unit.animation_set.get_animation_name(action_id), &"")
	assert_true(session.set_animation_clip(
		action_id,
		&"DD_Mage_Run",
		"Sort - Test"
	))
	assert_eq(
		session.working_unit.animation_set.get_animation_name(action_id),
		&"DD_Mage_Run"
	)
	assert_true(session.is_dirty())
	assert_true(session.history_undo())
	assert_eq(session.working_unit.animation_set.get_animation_name(action_id), &"")
	assert_false(session.is_dirty())
	session.release_document(false)


func test_studio_isolates_the_set_and_records_an_undoable_change() -> void:
	var source := ResourceLoader.load(
		MAGE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	) as UnitData
	var session := SkillTreeEditSession.new()
	assert_true(session.open(source))
	_handle_known_production_uid_warning()
	var working_set := session.working_unit.animation_set
	assert_not_null(working_set)
	assert_ne(working_set, source.animation_set, "la copie de travail a sa propre fiche")
	assert_true(session.set_animation_clip(&"run", &"DD_Mage_Walk", "Course"))
	assert_eq(working_set.get_animation_name(&"run"), &"DD_Mage_Walk")
	assert_eq(
		source.animation_set.get_animation_name(&"run"),
		&"DD_Mage_Run",
		"la ressource d’origine reste intacte tant qu’on n’a pas sauvegardé"
	)
	assert_true(session.is_dirty())
	assert_true(session.history_undo())
	assert_eq(working_set.get_animation_name(&"run"), &"DD_Mage_Run")
	assert_false(session.is_dirty())
	session.release_document(false)


func test_studio_plans_to_write_the_set_file() -> void:
	var source := ResourceLoader.load(
		MAGE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	) as UnitData
	var session := SkillTreeEditSession.new()
	assert_true(session.open(source))
	_handle_known_production_uid_warning()
	assert_true(session.set_animation_clip(&"run", &"DD_Mage_Walk", "Course"))
	var planned := PackedStringArray()
	for entry in SkillTreeSaveTransactionService.build_plan(session).writable_entries():
		planned.append(entry.target_path)
	assert_true(
		Array(planned).has("res://data/characters/mage/animations.tres"),
		"la fiche figure au plan de sauvegarde : %s" % str(planned)
	)
	session.release_document(false)


func test_reference_index_and_property_audit_include_the_animation_set() -> void:
	var unit := load(MAGE_PATH) as UnitData
	var index := SkillTreeReferenceIndex.new().build(unit)
	assert_true(index.resources.has(unit.animation_set))
	assert_true(index.incoming_to_resource(unit.animation_set).any(
		func(reference: Dictionary):
			return reference.get("owner") == unit \
				and reference.get("property") == &"animation_set"
	))
	var audit := SkillTreePropertyRegistry.audit(unit)
	assert_true((audit.get("editable", []) as Array).any(
		func(record: Dictionary):
			return record.get("resource") == unit.animation_set \
				and record.get("property") == &"animation_names"
	))


func test_run_session_edits_the_existing_achilles_animation_pool() -> void:
	var run_data: RunData = null
	var hero: RunHeroProfile = null
	for candidate in RunContentCatalogService.discover_runs():
		for candidate_hero in RunContentCatalogService.heroes_for_run(candidate):
			if candidate_hero != null and candidate_hero.character_id == &"achilles":
				run_data = candidate
				hero = candidate_hero
				break
		if hero != null:
			break
	assert_not_null(run_data)
	assert_not_null(hero)
	assert_not_null(hero.base_unit_data.animation_set)
	assert_eq(
		hero.base_unit_data.animation_set.resource_path,
		"res://data/characters/achilles/animations_meshy_v3.tres"
	)
	var session := SkillTreeEditSession.new()
	assert_true(session.open_progression(run_data, hero))
	assert_true(session.set_animation_clip(&"idle", &"Alert", "Repos"))
	assert_same(
		session.working_character_unit.animation_set,
		session.working_unit.animation_set
	)
	var plan := SkillTreeSaveTransactionService.build_plan(session)
	var planned_paths := PackedStringArray()
	var canonical_unit_update := false
	for entry in plan.writable_entries():
		planned_paths.append(entry.target_path)
		if entry.resource is UnitData:
			canonical_unit_update = entry.target_path == hero.base_unit_data.resource_path
	assert_false(
		canonical_unit_update,
		"le UnitData canonique reference deja le pool et ne doit pas etre reecrit"
	)
	assert_true(Array(planned_paths).has(
		"res://data/characters/achilles/animations_meshy_v3.tres"
	))
	session.release_document(false)


func test_enemies_go_through_the_same_animation_pipeline() -> void:
	# Les ennemis utilisent CharacterVisual3D comme les héros : ils sont donc
	# réglables et prévisualisables sans mécanique séparée.
	var enemy := load("res://data/units/ennemie/skeleton_melee.tres") as UnitData
	assert_eq(enemy.team, 1)
	assert_not_null(enemy.preview_visual_scene)
	var visual := enemy.preview_visual_scene.instantiate() as CharacterVisual3D
	assert_not_null(visual, "le visuel d’un ennemi doit être un CharacterVisual3D")
	add_child_autofree(visual)
	await wait_process_frames(2)
	assert_not_null(visual.get_animation_player())
	var preview := PREVIEW_SCENE.instantiate() as CharacterPreview3D
	add_child_autofree(preview)
	await wait_process_frames(2)
	preview.configure(enemy)
	assert_false(preview.is_using_fallback())
	assert_false(preview.get_available_clips().is_empty())
	var session := SkillTreeEditSession.new()
	assert_true(session.open(enemy))
	assert_true(session.set_animation_clip(&"walk", &"DD_Skeleton_Run", "Marche"))
	assert_true(session.is_dirty(), "modifier un ennemi doit activer la sauvegarde")
	assert_eq(
		session.working_unit.animation_set.get_animation_name(&"walk"),
		&"DD_Skeleton_Run"
	)
	session.release_document(false)


func test_studio_creates_a_set_for_a_character_that_has_none() -> void:
	var source := ResourceLoader.load(
		ELF_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	) as UnitData
	var session := SkillTreeEditSession.new()
	assert_true(session.open(source))
	_handle_known_production_uid_warning()
	session.working_unit.animation_set = null
	assert_false(
		session.set_animation_clip(&"idle", &"", "Repos"),
		"choisir « aucune animation » ne crée pas de fichier inutile"
	)
	assert_true(session.set_animation_clip(&"idle", &"Elf_Idle", "Repos"))
	var created := session.working_unit.animation_set
	assert_not_null(created)
	assert_eq(created.get_animation_name(&"idle"), &"Elf_Idle")
	var creations := PackedStringArray()
	for entry in SkillTreeSaveTransactionService.build_plan(session).entries:
		if entry.operation == SkillTreeSavePlanEntry.Operation.CREATE:
			creations.append(entry.target_path)
	assert_true(
		Array(creations).has("res://data/characters/elf/animations.tres"),
		"la nouvelle fiche est écrite dans le dossier du personnage : %s" % str(creations)
	)
	session.release_document(false)
